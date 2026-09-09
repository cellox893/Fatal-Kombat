extends SceneTree
const Sim = preload("res://simulation/simulation.gd")
const Moves = preload("res://simulation/move_resolver.gd")
const Content = preload("res://content/fight_content.gd")
const Rollback = preload("res://network/rollback.gd")

func _initialize() -> void:
	_test_edges()
	_test_registry()
	_test_hurt_windows()
	_test_validation()
	print("PASS integer boxes, mirrored edges, windows, dedup/groups, attack IDs, registry replay/rollback and validation")
	quit()

func _catalog() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(Content.CONTENT_PATH))

func _sim(data: Dictionary) -> RefCounted:
	assert(Content.validate(data).is_empty())
	var sim := Sim.new()
	sim.content = Content.new(data)
	sim.reset()
	sim.state.fighters[1].x = 360
	return sim

func _test_edges() -> void:
	var move: Dictionary = _catalog().moves[0]
	for tick in range(21):
		assert(Moves.active_hitboxes(move, tick).size() == (1 if tick >= 5 and tick < 8 else 0))
	for facing: int in [-1, 1]:
		var fighter := {"x":500,"y":550,"facing":facing}
		var hit: Dictionary = Moves.world_box(fighter, move.hitboxes[0])
		var base: Dictionary = _catalog().fighters[0].hurtboxes[0]
		for distance: int in [-25, -24, -23, 95, 96, 97]:
			var target := {"x":500 + facing * distance,"y":550,"facing":-facing}
			assert(Moves.overlaps(hit, Moves.world_box(target, base)) == (distance > -24 and distance < 96))
		for y: int in [459, 460, 461, 632, 633, 634]:
			var target := {"x":500 + facing * 40,"y":y,"facing":-facing}
			assert(Moves.overlaps(hit, Moves.world_box(target, base)) == (y > 460 and y < 633))
		var sim := _sim(_catalog())
		sim.state.fighters[0].x = 500
		sim.state.fighters[1].x = 500 + facing * 60
		for tick in range(6):
			sim.step([8, 0])
		assert(sim.state.fighters[1].health == 92)

func _multi() -> Dictionary:
	var data := _catalog()
	var move: Dictionary = data.moves[0]
	var duplicate: Dictionary = move.hitboxes[0].duplicate(true)
	duplicate.box_id = "second_rectangle"
	move.hitboxes.append(duplicate)
	move.hit_groups.append("second_hit")
	var second: Dictionary = duplicate.duplicate(true)
	second.box_id = "second_hit_rectangle"
	second.group_id = "second_hit"
	second.from = 7
	move.hitboxes.append(second)
	return data

func _test_registry() -> void:
	var data := _multi()
	var sim := _sim(data)
	for tick in range(8):
		var before: Dictionary = sim.snapshot()
		sim.step([8, 0])
		assert(sim.state.fighters[1].health == (100 if tick < 5 else (92 if tick < 7 else 84)))
		assert(sim.state.fighters[0].hit_targets.size() == (0 if tick < 5 else (1 if tick < 7 else 2)))
		var after: Dictionary = sim.snapshot()
		var hash_after: String = sim.checksum()
		sim.restore(before)
		sim.step([8, 0])
		assert(sim.snapshot() == after and sim.checksum() == hash_after)
	var id: Array = sim.state.fighters[0].attack_id.duplicate()
	assert(id == [0, 1])
	for tick in range(12):
		sim.step([0, 0])
	assert(sim.state.fighters[0].hit_targets.is_empty() and sim.state.fighters[0].attack_id.is_empty())
	for tick in range(6):
		sim.step([8, 0])
	assert(sim.state.fighters[0].attack_id == [0, 2])
	assert(sim.state.fighters[1].health == 76, "new instance can hit same target")
	for field: String in ["attack_sequence", "attack_id", "hit_targets"]:
		var before: Dictionary = sim.snapshot()
		var original: String = sim.checksum()
		if field == "attack_sequence":
			sim.state.fighters[0][field] += 1
		else:
			sim.state.fighters[0][field].append(99)
		assert(sim.checksum() != original)
		sim.restore(before)
	for reason: String in ["stun", "ko", "reset"]:
		var before: Dictionary = sim.snapshot()
		if reason == "stun":
			assert(sim.apply_stun(0, Sim.Action.HITSTUN, 2))
		elif reason == "ko":
			sim.state.fighters[0].health = 0
			sim.step([8, 0])
		else:
			sim.reset()
		assert(sim.state.fighters[0].hit_targets.is_empty() and sim.state.fighters[0].attack_id.is_empty())
		if reason == "reset":
			assert(sim.state.fighters[0].attack_sequence == 0)
		sim.restore(before)
	for delay: int in [2, 5, 9]:
		var reference := _sim(data)
		var session := Rollback.new()
		session.sim = _sim(data)
		for tick in range(60):
			var bits: int = 8 if tick % 25 == 0 else 0
			reference.step([bits, bits])
			if tick >= delay:
				session.receive(tick - delay, 8 if (tick - delay) % 25 == 0 else 0)
			assert(session.advance(bits))
		for tick in range(60 - delay, 60):
			session.receive(tick, 8 if tick % 25 == 0 else 0)
		assert(session.rollbacks > 0 and session.failure.is_empty())
		assert(session.sim.snapshot() == reference.snapshot() and session.sim.checksum() == reference.checksum())

func _test_hurt_windows() -> void:
	var data := _catalog()
	data.moves[0].hurtbox_windows = [{"from":5,"to":6,"boxes":[{"box_id":"raised","x":-24,"y":-300,"width":48,"height":20}]}]
	for tick: int in [4, 5, 6]:
		var sim := _sim(data)
		for fighter: Dictionary in sim.state.fighters:
			fighter.action = Sim.Action.ATTACK
			fighter.move = "light"
			fighter.move_tick = tick
		sim.step([0, 0])
		var expected: int = 92 if tick == 6 else 100
		assert(sim.state.fighters[0].health == expected and sim.state.fighters[1].health == expected, "hurt window uses same pre-resolution tick in both slots")

func _test_validation() -> void:
	for field: String in ["x", "y", "width", "height", "from", "to", "box_id", "group_id"]:
		var data := _catalog()
		data.moves[0].hitboxes[0].erase(field)
		assert(not Content.validate(data).is_empty(), field)
	for field: String in ["width", "height"]:
		for value: Variant in [0, -1, 0.5, "2", true, INF, 1000001]:
			var data := _catalog()
			data.fighters[0].hurtboxes[0][field] = value
			assert(not Content.validate(data).is_empty())
	for bounds: Array in [[4,8], [5,9], [6,6], [8,7], [-1,3], [5.5,8]]:
		var data := _catalog()
		data.moves[0].hitboxes[0].from = bounds[0]
		data.moves[0].hitboxes[0].to = bounds[1]
		assert(not Content.validate(data).is_empty())
	for mutation: String in ["group", "duplicate_box", "duplicate_group", "overlap_hurt", "hurt_outside"]:
		var data := _catalog()
		var move: Dictionary = data.moves[0]
		match mutation:
			"group": move.hitboxes[0].group_id = "missing"
			"duplicate_box": move.hitboxes.append(move.hitboxes[0].duplicate(true))
			"duplicate_group": move.hit_groups.append(move.hit_groups[0])
			"overlap_hurt":
				move.hurtbox_windows = [{"from":0,"to":3,"boxes":data.fighters[0].hurtboxes}, {"from":2,"to":4,"boxes":data.fighters[0].hurtboxes}]
			"hurt_outside":
				move.hurtbox_windows = [{"from":0,"to":21,"boxes":data.fighters[0].hurtboxes}]
		assert(not Content.validate(data).is_empty(), mutation)
