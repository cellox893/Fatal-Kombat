extends SceneTree
const Sim = preload("res://simulation/simulation.gd")
const Rollback = preload("res://network/rollback.gd")

func _initialize() -> void:
	_test_states()
	_test_content_selection()
	_test_combat()
	var baseline := Sim.new()
	var saved: Dictionary
	for tick in range(600):
		if tick == 100:
			saved = baseline.snapshot()
		baseline.step([input_at(tick, 0), input_at(tick, 1)])
	var populated := Sim.new()
	populated.state.projectiles.append({"id": 7, "x": 12, "ttl": 9})
	populated.state.objects.append({"id": 8, "ttl": 30})
	populated.state.fighters[0].resource = 63
	populated.state.fighters[0].cooldown = 20
	populated.state.fighters[0].effects.append({"id": "slow", "ttl": 12})
	var full: Dictionary = populated.snapshot()
	var full_hash: String = populated.checksum()
	populated.state.projectiles[0].x = 99
	populated.state.objects.clear()
	populated.state.fighters[0].effects.clear()
	populated.state.rng = 999
	populated.restore(full)
	assert(populated.checksum() == full_hash, "full state did not restore")
	var expected: String = baseline.checksum()
	baseline.restore(saved)
	baseline.state.fighters[0].effects.append({"ttl": 2})
	assert(saved.fighters[0].effects.is_empty(), "snapshot aliases mutable state")
	baseline.restore(saved)
	for tick in range(100, 600):
		baseline.step([input_at(tick, 0), input_at(tick, 1)])
	assert(expected == baseline.checksum(), "restore/replay diverged")
	for delay in [2, 3, 5, 9]:
		var session := Rollback.new()
		for tick in range(600):
			if tick >= delay:
				session.receive(tick - delay, input_at(tick - delay, 1))
				session.receive(tick - delay, input_at(tick - delay, 1))
			assert(session.advance(input_at(tick, 0)))
		for tick in range(600 - delay, 600):
			session.receive(tick, input_at(tick, 1))
		assert(session.sim.checksum() == expected, "rollback diverged")
		assert(session.rollbacks > 0)
		print("PASS delayed input ticks=", delay, " rollbacks=", session.rollbacks)
	for rtt_ms in [50, 100, 150]:
		_test_network(rtt_ms, expected)
	var stalled := Rollback.new()
	for tick in range(12):
		assert(stalled.advance(0))
	assert(not stalled.advance(0), "must stop prediction at window")
	print("PASS snapshot, restore, replay, duplicate inputs, bounded prediction; checksum=", expected)
	quit()

func _test_states() -> void:
	var sim := Sim.new()
	var fighter: Dictionary = sim.state.fighters[0]
	assert(fighter.action == Sim.Action.NEUTRAL and fighter.locomotion == Sim.Locomotion.IDLE)
	sim.step([2, 0])
	assert(fighter.locomotion == Sim.Locomotion.MOVING)
	sim.step([0, 0])
	assert(fighter.locomotion == Sim.Locomotion.IDLE)
	sim.step([4, 0])
	assert(fighter.locomotion == Sim.Locomotion.AIRBORNE and fighter.action == Sim.Action.NEUTRAL)
	sim.step([0, 0])
	sim.step([4, 0])
	assert(fighter.vy == -13, "no second jump in air")
	sim.step([8, 0])
	assert(fighter.action == Sim.Action.ATTACK and fighter.locomotion == Sim.Locomotion.AIRBORNE)
	var x: int = fighter.x
	sim.step([6, 0])
	assert(fighter.x == x and fighter.move_tick == 2, "attack forbids walking/jumping")
	var before: String = sim.checksum()
	assert(not sim.apply_stun(0, Sim.Action.BLOCKSTUN, 3))
	assert(not sim.apply_stun(0, Sim.Action.HITSTUN, 0))
	assert(not sim.apply_stun(-1, Sim.Action.HITSTUN, 3))
	assert(sim.checksum() == before, "invalid transitions are atomic")
	assert(sim.apply_stun(0, Sim.Action.HITSTUN, 3))
	assert(fighter.move == "" and not sim.attack_active(fighter), "hitstun interrupts attack")
	var saved: Dictionary = sim.snapshot()
	for tick in range(3):
		sim.step([14, 0])
		assert(fighter.x == x and fighter.move == "")
		assert(fighter.stun_ticks == 2 - tick)
	assert(fighter.action == Sim.Action.NEUTRAL)
	var expected: String = sim.checksum()
	sim.restore(saved)
	for tick in range(3):
		sim.step([14, 0])
	assert(sim.checksum() == expected, "stun snapshot replay")
	sim.step([8, 0])
	assert(sim.state.fighters[0].action == Sim.Action.NEUTRAL, "held attack is not buffered through stun")
	for tick in range(40):
		sim.step([0, 0])
	assert(sim.state.fighters[0].locomotion == Sim.Locomotion.IDLE, "landing returns to idle")
	assert(sim.apply_stun(0, Sim.Action.BLOCKSTUN, 2))
	for tick in range(2):
		sim.step([14, 0])
	assert(sim.state.fighters[0].action == Sim.Action.NEUTRAL)
	# Every new field must affect the canonical checksum.
	for field: String in ["action", "locomotion", "stun_ticks"]:
		var original: Dictionary = sim.snapshot()
		before = sim.checksum()
		sim.state.fighters[0][field] += 1
		assert(sim.checksum() != before, field + " absent from checksum")
		sim.restore(original)
	# Delayed remote input crosses stun expiry, attack startup and simultaneous KO.
	for stun_action: int in [Sim.Action.HITSTUN, Sim.Action.BLOCKSTUN]:
		for delay: int in [2, 5, 9]:
			var session := Rollback.new()
			var reference := Sim.new()
			for instance in [session.sim, reference]:
				instance.state.fighters[1].x = 360
				for player in range(2):
					instance.state.fighters[player].health = 8
					assert(instance.apply_stun(player, stun_action, 3))
			for tick in range(40):
				var bits: int = 8 if tick == 4 else 0
				reference.step([bits, bits])
				if tick >= delay:
					session.receive(tick - delay, 8 if tick - delay == 4 else 0)
				assert(session.advance(bits))
			for tick in range(40 - delay, 40):
				session.receive(tick, 0)
			assert(session.rollbacks > 0 and session.failure.is_empty())
			assert(session.sim.checksum() == reference.checksum(), "state transition rollback")
			for player in range(2):
				assert(reference.state.fighters[player].action == Sim.Action.KO, "lethal trade must KO both")
				assert(not reference.apply_stun(player, Sim.Action.HITSTUN, 2))
			var positions: Array = [reference.state.fighters[0].x, reference.state.fighters[1].x]
			for tick in range(10):
				reference.step([14, 13])
			for player in range(2):
				assert(reference.state.fighters[player].x == positions[player])
				assert(reference.state.fighters[player].move == "")
			reference.reset()
			assert(reference.state.fighters[0].action == Sim.Action.NEUTRAL)
	print("PASS locomotion/action transitions, forbidden inputs, stun expiry, KO, checksum and delayed rollback")

func _test_content_selection() -> void:
	var sim := Sim.new()
	assert(sim.characters == ["leonidas", "tesla"], "default fighter IDs must be stable strings")
	assert(sim.set_fighters(["tesla", "leonidas"]) == OK)
	assert(sim.characters == ["tesla", "leonidas"])
	sim.content.fighter("tesla").health = 137
	sim.reset()
	assert(sim.state.fighters[0].health == 137, "reset must use configured health")
	assert(sim.set_fighters(["tesla", "unknown"]) == ERR_DOES_NOT_EXIST, "unknown fighter reference must fail")
	assert(sim.characters == ["tesla", "leonidas"], "invalid selection must not change fighters")
	print("PASS stable fighter IDs and configured reset statistics")

func input_at(tick: int, player: int) -> int:
	return (1 if (tick + player * 37) % 80 < 40 else 2) | (4 if tick % 61 == 0 else 0)

func _test_network(rtt_ms: int, expected: String) -> void:
	var session := Rollback.new()
	var queue: Array = []
	var next_remote: int = 0
	for clock_tick in range(900):
		if next_remote < 600:
			next_remote += 1
		# One-way RTT/2, +/- one tick deterministic jitter, 10% packet loss.
		# Every surviving packet repeats the latest 120 inputs.
		if clock_tick % 10 != 3:
			var delay: int = maxi(1, int(round(rtt_ms / 2.0 / (1000.0 / 60.0))) + clock_tick % 3 - 1)
			queue.append({"arrival": clock_tick + delay, "end": next_remote})
		for i in range(queue.size() - 1, -1, -1):
			if queue[i].arrival <= clock_tick:
				for t in range(maxi(0, int(queue[i].end) - 120), int(queue[i].end)):
					session.receive(t, input_at(t, 1))
				queue.remove_at(i)
		if int(session.sim.state.tick) < 600:
			session.advance(input_at(int(session.sim.state.tick), 0))
	assert(session.failure.is_empty(), session.failure)
	assert(session.confirmed == 599)
	assert(session.sim.checksum() == expected, "jitter/loss replay mismatch")
	print("PASS synthetic RTT=", rtt_ms, "ms, jitter +/-1 tick, 10% packet loss, reordering/redundancy")


func _test_combat() -> void:
	var sim := Sim.new()
	sim.state.fighters[1].x = 360
	for tick in range(5):
		sim.step([8, 8])
	assert(sim.state.fighters[0].health == 100, "startup must not damage")
	var saved: Dictionary = sim.snapshot()
	sim.step([8, 8])
	assert(sim.state.fighters[0].health == 92 and sim.state.fighters[1].health == 92, "simultaneous hits must trade")
	for tick in range(30):
		sim.step([8, 8])
	assert(sim.state.fighters[0].health == 92, "one hit per move; holding must not repeat")
	var expected: String = sim.checksum()
	sim.restore(saved)
	for tick in range(31):
		sim.step([8, 8])
	assert(sim.checksum() == expected, "combat snapshot replay")
	var distant := Sim.new()
	for tick in range(20):
		distant.step([8, 0])
	assert(distant.state.fighters[1].health == 100, "out of reach")
	var airborne := Sim.new()
	airborne.state.fighters[1].x = 360
	airborne.state.fighters[1].y = 300
	for tick in range(9):
		airborne.step([8, 0])
	assert(airborne.state.fighters[1].health == 100, "vertical miss")
	for delay in [2, 5, 9]:
		var session := Rollback.new()
		var reference := Sim.new()
		session.sim.state.fighters[1].x = 360
		reference.state.fighters[1].x = 360
		for tick in range(80):
			var bits: int = 8 if tick % 25 == 0 else 0
			reference.step([bits, bits])
			if tick >= delay:
				session.receive(tick - delay, 8 if (tick - delay) % 25 == 0 else 0)
			assert(session.advance(bits))
		for tick in range(80 - delay, 80):
			session.receive(tick, 8 if tick % 25 == 0 else 0)
		assert(session.failure.is_empty())
		assert(session.sim.checksum() == reference.checksum(), "combat rollback mismatch")
		assert(session.rollbacks > 0)
		assert(reference.state.fighters[0].health < 100)
	print("PASS melee startup, trade, single hit, reach, vertical miss, snapshot and combat rollback")
