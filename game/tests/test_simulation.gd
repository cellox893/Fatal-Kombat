extends SceneTree
const Sim = preload("res://simulation/simulation.gd")
const Rollback = preload("res://network/rollback.gd")

func _initialize() -> void:
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
