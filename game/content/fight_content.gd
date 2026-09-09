class_name FightContent
extends RefCounted
## Validated, versioned combat content. The simulation consumes only stable IDs.

const CONTENT_PATH := "res://content/fighters.json"
const SCHEMA_VERSION := 1

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
			_validate_positive_integer(move, "active", path, problems)
			_validate_positive_integer(move, "recovery", path, problems, true)
			_validate_positive_integer(move, "damage", path, problems)
			_validate_positive_integer(move, "reach", path, problems)
			_validate_positive_integer(move, "bottom", path, problems, true)
			_validate_positive_integer(move, "top", path, problems)
			if _is_integer(move.get("top")) and _is_integer(move.get("bottom")) and int(move.top) <= int(move.bottom):
				problems.append(path + ": top must exceed bottom")
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
			_validate_positive_integer(fighter, "hurt_width", path, problems)
			_validate_positive_integer(fighter, "hurt_height", path, problems)
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
	return (value is int or value is float) and float(value) == floorf(float(value))

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
