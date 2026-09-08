extends SceneTree
const Sim = preload("res://simulation/simulation.gd")
const Rollback = preload("res://network/rollback.gd")

func _initialize() -> void:
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
