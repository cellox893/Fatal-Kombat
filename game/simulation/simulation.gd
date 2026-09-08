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
		state.fighters.append({"x": 300 + i * 520, "y": 550, "vy": 0, "health": 100,
			"resource": 100, "cooldown": 0, "effects": [], "input": 0})

func step(inputs: Array) -> void:
	for i in range(2):
		var fighter: Dictionary = state.fighters[i]
		var definition: Dictionary = content.fighters[characters[i]]
		var bits: int = int(inputs[i])
		var axis: int = int(bool(bits & 2)) - int(bool(bits & 1))
		fighter.x = clampi(int(fighter.x) + axis * int(definition.speed), int(content.arena.left), int(content.arena.right))
		if bits & 4 and not int(fighter.input) & 4 and int(fighter.y) == 550:
			fighter.vy = int(definition.jump)
		fighter.y = mini(550, int(fighter.y) + int(fighter.vy))
		fighter.vy = 0 if int(fighter.y) == 550 else int(fighter.vy) + 1
		fighter.cooldown = maxi(0, int(fighter.cooldown) - 1)
		fighter.input = bits
	state.tick = int(state.tick) + 1

func snapshot() -> Dictionary:
	return state.duplicate(true)

func restore(saved: Dictionary) -> void:
	state = saved.duplicate(true)

func checksum() -> String:
	# Fixed-order arrays, integer decimal JSON: independent of dictionary hash order.
	var canonical: Array = [state.tick, state.rng, state.projectiles, state.objects]
	for fighter: Dictionary in state.fighters:
		canonical.append([fighter.x, fighter.y, fighter.vy, fighter.health,
			fighter.resource, fighter.cooldown, fighter.effects, fighter.input])
	return JSON.stringify(canonical).sha256_text()

static func compatibility() -> String:
	return "lab-1:" + FileAccess.get_file_as_string(CONTENT_PATH).sha256_text()
