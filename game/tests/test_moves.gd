extends SceneTree
const Sim = preload("res://simulation/simulation.gd")
const Moves = preload("res://simulation/move_resolver.gd")
const Content = preload("res://content/fight_content.gd")
const Rollback = preload("res://network/rollback.gd")

func _initialize() -> void:
	# Golden trace captured on 4590713 before extracting the resolver.
	var trace := ""
	for scenario in range(4):
		var sim := Sim.new()
		sim.state.fighters[1].x = 360 if scenario != 2 else 820
		if scenario == 3:
			sim.state.fighters[0].health = 8
			sim.state.fighters[1].health = 8
		for tick in range(180):
			var left: int = (8 if tick % 25 < 10 else 0) | (4 if tick % 43 == 0 else 0)
			var right: int = 8 if tick % 27 < 8 else 0
			if scenario == 1:
				left |= 2
				right |= 1
			sim.step([left, right])
			trace += _legacy_checksum(sim)
	assert(trace.sha256_text() == "25bdfec7b19f6f648514f92903aef150b79cdc3bebcf1be07aefc625e87e85ab", "light diverged from 4590713")
	_test_definitions()
	print("PASS pre-migration 720-tick golden trace, phase boundaries, alternate data and rollback")
	quit()

func _test_definitions() -> void:
	var base := Sim.new()
	var light: Dictionary = base.content.move("light")
	for tick in range(21):
		var expected: int = Moves.Phase.STARTUP if tick < 5 else (Moves.Phase.ACTIVE if tick < 8 else (Moves.Phase.RECOVERY if tick < 20 else Moves.Phase.COMPLETE))
		assert(Moves.phase(light, tick) == expected)
	for age: int in [1, 5, 8, 19]:
		for exit_kind: String in ["stun", "ko", "reset"]:
			var interrupted := Sim.new()
			for tick in range(age):
				interrupted.step([8, 0])
			if exit_kind == "stun":
				assert(interrupted.apply_stun(0, Sim.Action.HITSTUN, 3))
			elif exit_kind == "ko":
				interrupted.state.fighters[0].health = 0
				interrupted.step([8, 0])
			else:
				interrupted.reset()
			var fighter: Dictionary = interrupted.state.fighters[0]
			assert(fighter.move == "" and fighter.move_tick == 0 and not fighter.hit)
			assert(not interrupted.attack_active(fighter))
	# New ID and values, only in the fixture, through the production validator.
	var data: Dictionary = JSON.parse_string(base.content.raw_json)
	data.moves.append({"move_id": "test_strike", "behavior_id": "melee", "startup": 2, "active": 1, "recovery": 3, "damage": 13,
		"hit_groups": ["strike"], "hitboxes": [{"box_id":"fist","group_id":"strike","from":2,"to":3,"x":0,"y":-120,"width":150,"height":110}], "hurtbox_windows": []})
	data.fighters[0].moves.light = "test_strike"
	data.fighters[1].moves.light = "test_strike"
	assert(Content.validate(data).is_empty())
	var sim := Sim.new()
	sim.content = Content.new(data)
	sim.reset()
	sim.state.fighters[1].x = 430 # Outside original light range.
	for tick in range(6):
		var saved: Dictionary = sim.snapshot()
		sim.step([8, 0])
		assert(sim.state.fighters[1].health == (100 if tick < 2 else 87))
		assert(sim.state.fighters[0].action == (Sim.Action.NEUTRAL if tick == 5 else Sim.Action.ATTACK))
		var expected: Dictionary = sim.snapshot()
		var checksum: String = sim.checksum()
		sim.restore(saved)
		sim.step([8, 0])
		assert(sim.snapshot() == expected and sim.checksum() == checksum)
	# Zero startup/recovery is supported: collision on press, then clear.
	var instant: Dictionary = data.duplicate(true)
	instant.moves[1].startup = 0
	instant.moves[1].recovery = 0
	instant.moves[1].hitboxes[0].from = 0
	instant.moves[1].hitboxes[0].to = 1
	assert(Content.validate(instant).is_empty())
	var one_tick := Sim.new()
	one_tick.content = Content.new(instant)
	one_tick.reset()
	one_tick.state.fighters[1].x = 430
	one_tick.step([8, 0])
	assert(one_tick.state.fighters[1].health == 87 and one_tick.state.fighters[0].move == "")
	# Actual delayed-input correction through all phases, both default and fixture.
	for catalog: Dictionary in [JSON.parse_string(base.content.raw_json), data]:
		for delay: int in [2, 5, 9]:
			var reference := Sim.new()
			var session := Rollback.new()
			for instance in [reference, session.sim]:
				instance.content = Content.new(catalog)
				instance.reset()
				instance.state.fighters[1].x = 360
			for tick in range(80):
				var bits: int = 8 if tick % 25 == 0 else 0
				reference.step([bits, bits])
				if tick >= delay:
					session.receive(tick - delay, 8 if (tick - delay) % 25 == 0 else 0)
				assert(session.advance(bits))
			for tick in range(80 - delay, 80):
				session.receive(tick, 8 if tick % 25 == 0 else 0)
			assert(session.rollbacks > 0 and session.failure.is_empty())
			assert(session.sim.snapshot() == reference.snapshot())
			assert(session.sim.checksum() == reference.checksum())

func _legacy_checksum(sim: RefCounted) -> String:
	# Projection of exactly the previous runtime, never used for multiplayer.
	var state: Dictionary = sim.state
	var canonical: Array = [state.tick, state.rng, state.projectiles, state.objects]
	for fighter: Dictionary in state.fighters:
		canonical.append([fighter.x, fighter.y, fighter.vy, fighter.health,
			fighter.resource, fighter.cooldown, fighter.effects, fighter.input, fighter.facing, fighter.move, fighter.move_tick, fighter.hit,
			fighter.locomotion, fighter.action, fighter.stun_ticks])
	return JSON.stringify(canonical).sha256_text()
