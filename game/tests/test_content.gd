extends SceneTree
const Content = preload("res://content/fight_content.gd")

func _initialize() -> void:
	var content := Content.new()
	assert(Content.validate(_valid_data()).is_empty())
	for behavior: Variant in [null, "", "projectile", "res://arbitrary.gd", 3]:
		var data := _valid_data()
		data.moves[0].behavior_id = behavior
		_assert_problem(Content.validate(data), "behavior_id")
	var absent := _valid_data()
	absent.moves[0].erase("behavior_id")
	_assert_problem(Content.validate(absent), "behavior_id")
	for field: String in ["startup", "active", "recovery"]:
		for invalid: Variant in [-1, 1.5, "2", true]:
			var data := _valid_data()
			data.moves[0][field] = invalid
			_assert_problem(Content.validate(data), field)
		var data := _valid_data()
		data.moves[0].erase(field)
		_assert_problem(Content.validate(data), field)
	var zero := _valid_data()
	zero.moves[0].active = 0
	_assert_problem(Content.validate(zero), "active")
	assert(content.is_valid(), "default content must validate: " + "; ".join(content.errors))
	assert(content.schema_version == 1)
	assert(content.has_fighter("leonidas") and content.has_fighter("tesla"))
	assert(content.move("light").move_id == "light")
	var duplicate := _valid_data()
	duplicate.fighters[1].fighter_id = "leonidas"
	_assert_problem(Content.validate(duplicate), "duplicate leonidas")
	var duplicate_move := _valid_data()
	duplicate_move.moves.append(duplicate_move.moves[0].duplicate(true))
	_assert_problem(Content.validate(duplicate_move), "duplicate light")
	var missing := _valid_data()
	missing.fighters[0].erase("fighter_id")
	_assert_problem(Content.validate(missing), "fighter_id")
	var missing_move := _valid_data()
	missing_move.fighters[0].moves.light = "does_not_exist"
	_assert_problem(Content.validate(missing_move), "unknown move does_not_exist")
	var missing_fighter := _valid_data()
	missing_fighter.default_fighters[1] = "does_not_exist"
	_assert_problem(Content.validate(missing_fighter), "unknown fighter does_not_exist")
	var invalid_value := _valid_data()
	invalid_value.moves[0].damage = 0
	_assert_problem(Content.validate(invalid_value), "damage")
	var required := _valid_data()
	required.fighters[0].erase("health")
	_assert_problem(Content.validate(required), "health")
	print("PASS content schema, stable IDs, references, required fields and values")
	quit()

func _assert_problem(problems: Array[String], expected: String) -> void:
	for problem: String in problems:
		if expected in problem:
			return
	assert(false, "expected validation error containing %s, got %s" % [expected, problems])

func _valid_data() -> Dictionary:
	return {
		"schema_version": 1,
		"arena": {"arena_id": "arena", "left": 0, "right": 100, "floor": 10},
		"moves": [{"move_id": "light", "behavior_id": "melee", "startup": 1, "active": 1, "recovery": 1, "damage": 1, "reach": 1, "bottom": 0, "top": 1}],
		"fighters": [
			{"fighter_id": "leonidas", "label": "Leonidas", "speed": 1, "jump": -1, "health": 100, "color": "ffffff", "moves": {"light": "light"}, "hurt_width": 1, "hurt_height": 1},
			{"fighter_id": "tesla", "label": "Tesla", "speed": 1, "jump": -1, "health": 100, "color": "000000", "moves": {"light": "light"}, "hurt_width": 1, "hurt_height": 1}
		],
		"default_fighters": ["leonidas", "tesla"]
	}
