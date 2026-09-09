class_name FightSimulation
extends RefCounted
## Integer-only state. One unit = one logical pixel; velocities = units/tick.
const CONTENT_PATH := "res://content/fighters.json"
var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONTENT_PATH))
var characters: Array = [0, 1]
var state: Dictionary

func _init() -> void:
	reset()

func reset() -> void:
	state = {"tick": 0, "rng": 12345, "projectiles": [], "objects": [], "fighters": []}
	for i in range(2):
		state.fighters.append({"x": 300 + i * 520, "y": int(content.arena.floor), "vy": 0, "health": 100,
			"resource": 100, "cooldown": 0, "effects": [], "input": 0, "facing": 1 if i == 0 else -1,
			"move": "", "move_tick": 0, "hit": false})

func step(inputs: Array) -> void:
	for i in range(2):
		var fighter: Dictionary = state.fighters[i]
		var definition: Dictionary = content.fighters[characters[i]]
		var bits: int = int(inputs[i])
		if str(fighter.move).is_empty():
			var opponent: Dictionary = state.fighters[1 - i]
			if int(opponent.x) != int(fighter.x):
				fighter.facing = 1 if int(opponent.x) > int(fighter.x) else -1
			if bits & 8 and not int(fighter.input) & 8:
				fighter.move = str(definition.light)
				fighter.move_tick = 0
				fighter.hit = false
		var axis: int = int(bool(bits & 2)) - int(bool(bits & 1))
		if not str(fighter.move).is_empty():
			axis = 0
		fighter.x = clampi(int(fighter.x) + axis * int(definition.speed), int(content.arena.left), int(content.arena.right))
		if str(fighter.move).is_empty() and bits & 4 and not int(fighter.input) & 4 and int(fighter.y) == int(content.arena.floor):
			fighter.vy = int(definition.jump)
		fighter.y = mini(int(content.arena.floor), int(fighter.y) + int(fighter.vy))
		fighter.vy = 0 if int(fighter.y) == int(content.arena.floor) else int(fighter.vy) + 1
		fighter.cooldown = maxi(0, int(fighter.cooldown) - 1)
		fighter.input = bits
	# Resolve both attacks after movement; simultaneous hits trade.
	for i in range(2):
		var fighter: Dictionary = state.fighters[i]
		if str(fighter.move).is_empty():
			continue
		var move: Dictionary = content.moves[fighter.move]
		if attack_active(fighter) and not bool(fighter.hit):
			var target: Dictionary = state.fighters[1 - i]
			var hurt: Dictionary = content.fighters[characters[1 - i]]
			var distance: int = (int(target.x) - int(fighter.x)) * int(fighter.facing)
			if distance + int(hurt.hurt_width) > 0 and distance - int(hurt.hurt_width) < int(move.reach) and int(target.y) > int(fighter.y) - int(move.top) and int(target.y) - int(hurt.hurt_height) < int(fighter.y) - int(move.bottom):
				target.health = maxi(0, int(target.health) - int(move.damage))
				fighter.hit = true
		fighter.move_tick = int(fighter.move_tick) + 1
		if int(fighter.move_tick) >= int(move.startup) + int(move.active) + int(move.recovery):
			fighter.move = ""
			fighter.move_tick = 0
			fighter.hit = false
	state.tick = int(state.tick) + 1

func attack_active(fighter: Dictionary) -> bool:
	if str(fighter.move).is_empty():
		return false
	var move: Dictionary = content.moves[fighter.move]
	return int(fighter.move_tick) >= int(move.startup) and int(fighter.move_tick) < int(move.startup) + int(move.active)

func snapshot() -> Dictionary:
	return state.duplicate(true)

func restore(saved: Dictionary) -> void:
	state = saved.duplicate(true)

func checksum() -> String:
	# Fixed-order arrays, integer decimal JSON: independent of dictionary hash order.
	var canonical: Array = [state.tick, state.rng, state.projectiles, state.objects]
	for fighter: Dictionary in state.fighters:
		canonical.append([fighter.x, fighter.y, fighter.vy, fighter.health,
			fighter.resource, fighter.cooldown, fighter.effects, fighter.input, fighter.facing, fighter.move, fighter.move_tick, fighter.hit])
	return JSON.stringify(canonical).sha256_text()

static func compatibility() -> String:
	return "lab-2:" + FileAccess.get_file_as_string(CONTENT_PATH).sha256_text()
