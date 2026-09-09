class_name FightContent
extends RefCounted
## Validated, versioned combat content. The simulation consumes only stable IDs.

const CONTENT_PATH := "res://content/fighters.json"
const SCHEMA_VERSION := 2
const Resolver = preload("res://simulation/move_resolver.gd")

var schema_version: int = 0
var arena: Dictionary = {}
var fighters: Dictionary = {}
var moves: Dictionary = {}
var default_fighters: Array[String] = []
var errors: Array[String] = []
var raw_json: String = ""

func _init(data: Dictionary = {}) -> void:
	raw_json = FileAccess.get_file_as_string(CONTENT_PATH) if data.is_empty() else JSON.stringify(data)
	var parsed: Variant = JSON.parse_string(raw_json)
	if not parsed is Dictionary:
		errors.append("root: JSON object expected")
		return
	_load(parsed)

static func validate(data: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	if not _is_integer(data.get("schema_version")) or int(data.get("schema_version")) != SCHEMA_VERSION:
		problems.append("schema_version: expected integer %d" % SCHEMA_VERSION)
	_validate_arena(data.get("arena"), problems)
	var move_ids: Dictionary = {}
	if not data.get("moves") is Array or data.moves.is_empty():
		problems.append("moves: non-empty array required")
	else:
		for index: int in data.moves.size():
			var move: Variant = data.moves[index]
			var path := "moves[%d]" % index
			if not move is Dictionary:
				problems.append(path + ": object required")
				continue
			var move_id := str(move.get("move_id", ""))
			if not _valid_id(move_id):
				problems.append(path + ".move_id: stable ID required")
			elif move_ids.has(move_id):
				problems.append(path + ".move_id: duplicate " + move_id)
			else:
				move_ids[move_id] = true
			_validate_positive_integer(move, "startup", path, problems, true)
			if not Resolver.supports(move.get("behavior_id")):
				problems.append(path + ".behavior_id: required known behavior (melee)")
			_validate_positive_integer(move, "active", path, problems)
			_validate_positive_integer(move, "recovery", path, problems, true)
			_validate_positive_integer(move, "damage", path, problems)
			_validate_move_boxes(move, path, problems)
	var fighter_ids: Dictionary = {}
	if not data.get("fighters") is Array or data.fighters.size() < 2:
		problems.append("fighters: array with at least two fighters required")
	else:
		for index: int in data.fighters.size():
			var fighter: Variant = data.fighters[index]
			var path := "fighters[%d]" % index
			if not fighter is Dictionary:
				problems.append(path + ": object required")
				continue
			var fighter_id := str(fighter.get("fighter_id", ""))
			if not _valid_id(fighter_id):
				problems.append(path + ".fighter_id: stable ID required")
			elif fighter_ids.has(fighter_id):
				problems.append(path + ".fighter_id: duplicate " + fighter_id)
			else:
				fighter_ids[fighter_id] = true
			if not fighter.get("label") is String or str(fighter.label).strip_edges().is_empty():
				problems.append(path + ".label: non-empty string required")
			_validate_positive_integer(fighter, "speed", path, problems)
			if not fighter.has("jump") or not _is_integer(fighter.get("jump")):
				problems.append(path + ".jump: integer required")
			elif int(fighter.jump) >= 0:
				problems.append(path + ".jump: must be negative")
			_validate_positive_integer(fighter, "health", path, problems)
			_validate_boxes(fighter.get("hurtboxes"), path + ".hurtboxes", problems)
			if not _valid_color(str(fighter.get("color", ""))):
				problems.append(path + ".color: six hexadecimal digits required")
			if not fighter.get("moves") is Dictionary or not fighter.moves.has("light"):
				problems.append(path + ".moves.light: move reference required")
			else:
				for action_id: Variant in fighter.moves:
					var move_id := str(fighter.moves[action_id])
					if not move_ids.has(move_id):
						problems.append(path + ".moves.%s: unknown move %s" % [action_id, move_id])
	if not data.get("default_fighters") is Array or data.default_fighters.size() != 2:
		problems.append("default_fighters: exactly two fighter IDs required")
	else:
		for index: int in data.default_fighters.size():
			var fighter_id := str(data.default_fighters[index])
			if not fighter_ids.has(fighter_id):
				problems.append("default_fighters[%d]: unknown fighter %s" % [index, fighter_id])
	return problems

func is_valid() -> bool:
	return errors.is_empty()

func has_fighter(fighter_id: String) -> bool:
	return fighters.has(fighter_id)

func fighter(fighter_id: String) -> Dictionary:
	return fighters.get(fighter_id, {})

func move(move_id: String) -> Dictionary:
	return moves.get(move_id, {})

func _load(data: Dictionary) -> void:
	errors = validate(data)
	if not errors.is_empty():
		push_error("Invalid fight content: " + "; ".join(errors))
		return
	schema_version = int(data.schema_version)
	arena = data.arena.duplicate(true)
	for source: Dictionary in data.moves:
		moves[str(source.move_id)] = source.duplicate(true)
	for source: Dictionary in data.fighters:
		fighters[str(source.fighter_id)] = source.duplicate(true)
	for fighter_id: Variant in data.default_fighters:
		default_fighters.append(str(fighter_id))

static func _validate_arena(value: Variant, problems: Array[String]) -> void:
	if not value is Dictionary:
		problems.append("arena: object required")
		return
	if not _valid_id(str(value.get("arena_id", ""))):
		problems.append("arena.arena_id: stable ID required")
	for field in ["left", "right", "floor"]:
		_validate_positive_integer(value, field, "arena", problems, field != "right")
	if _is_integer(value.get("left")) and _is_integer(value.get("right")) and int(value.left) >= int(value.right):
		problems.append("arena: left must be lower than right")

static func _validate_positive_integer(source: Dictionary, field: String, path: String, problems: Array[String], allow_zero: bool = false) -> void:
	if not source.has(field):
		problems.append(path + "." + field + ": required")
		return
	if not _is_integer(source[field]) or int(source[field]) < 0 or (not allow_zero and int(source[field]) == 0):
		problems.append(path + "." + field + ": " + ("non-negative" if allow_zero else "positive") + " integer required")

static func _is_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) <= 1000000 and float(value) == floorf(float(value))

static func _validate_boxes(value: Variant, path: String, problems: Array[String]) -> void:
	if not value is Array or value.is_empty():
		problems.append(path + ": non-empty box array required")
		return
	var ids: Dictionary = {}
	for box: Variant in value:
		if not box is Dictionary:
			problems.append(path + ": box object required")
			continue
		var id: Variant = box.get("box_id")
		if not id is String or not _valid_id(str(id)) or ids.has(id):
			problems.append(path + ".box_id: missing, invalid or duplicate")
		else:
			ids[id] = true
		for field: String in ["x", "y"]:
			if not _is_integer(box.get(field)):
				problems.append(path + "." + field + ": bounded integer required")
		for field: String in ["width", "height"]:
			_validate_positive_integer(box, field, path, problems)

static func _valid_window(window: Dictionary, start: int, end: int, path: String, problems: Array[String]) -> bool:
	if not _is_integer(window.get("from")) or not _is_integer(window.get("to")):
		problems.append(path + ": integer from/to required")
		return false
	if int(window.from) < start or int(window.to) > end or int(window.from) >= int(window.to):
		problems.append(path + ": invalid window")
		return false
	return true

static func _validate_move_boxes(move: Dictionary, path: String, problems: Array[String]) -> void:
	var groups: Dictionary = {}
	if not move.get("hit_groups") is Array or move.hit_groups.is_empty():
		problems.append(path + ".hit_groups: non-empty ID array required")
	else:
		for id: Variant in move.hit_groups:
			if not id is String or not _valid_id(str(id)) or groups.has(id):
				problems.append(path + ".hit_groups: missing, invalid or duplicate ID")
			else:
				groups[id] = true
	_validate_boxes(move.get("hitboxes"), path + ".hitboxes", problems)
	var timing_valid := true
	for field: String in ["startup", "active", "recovery"]:
		timing_valid = timing_valid and _is_integer(move.get(field))
	if move.get("hitboxes") is Array:
		for box: Variant in move.hitboxes:
			if not box is Dictionary:
				continue
			if not box.get("group_id") is String or not groups.has(box.get("group_id")):
				problems.append(path + ".group_id: unknown hit group")
			if timing_valid:
				_valid_window(box, int(move.startup), int(move.startup) + int(move.active), path + ".hitboxes", problems)
	if not move.get("hurtbox_windows") is Array:
		problems.append(path + ".hurtbox_windows: array required")
		return
	var windows: Array = []
	for window: Variant in move.hurtbox_windows:
		if not window is Dictionary:
			problems.append(path + ".hurtbox_windows: object required")
			continue
		_validate_boxes(window.get("boxes"), path + ".hurtbox_windows.boxes", problems)
		if timing_valid and _valid_window(window, 0, Resolver.duration(move), path + ".hurtbox_windows", problems):
			for previous: Dictionary in windows:
				if int(window.from) < int(previous.to) and int(window.to) > int(previous.from):
					problems.append(path + ".hurtbox_windows: overlapping replacement windows")
			windows.append(window)

static func _valid_id(value: String) -> bool:
	if value.is_empty() or value != value.to_lower() or not "abcdefghijklmnopqrstuvwxyz".contains(value[0]):
		return false
	for character: String in value:
		if not "abcdefghijklmnopqrstuvwxyz0123456789_".contains(character):
			return false
	return true

static func _valid_color(value: String) -> bool:
	if value.length() != 6:
		return false
	for character: String in value:
		if not "0123456789abcdefABCDEF".contains(character):
			return false
	return true
