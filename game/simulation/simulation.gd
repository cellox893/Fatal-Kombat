class_name FightSimulation
extends RefCounted
## Integer-only state. One unit = one logical pixel; velocities = units/tick.
const Content = preload("res://content/fight_content.gd")
enum Locomotion { IDLE, MOVING, AIRBORNE }
enum Action { NEUTRAL, ATTACK, HITSTUN, BLOCKSTUN, KO }
var content := Content.new()
var characters: Array[String] = []
var state: Dictionary

func _init() -> void:
	if not content.is_valid():
		push_error("Fight simulation cannot start with invalid content")
	characters.assign(content.default_fighters)
	reset()

func set_fighters(fighter_ids: Array[String]) -> Error:
	if fighter_ids.size() != 2:
		return ERR_INVALID_PARAMETER
	for fighter_id: String in fighter_ids:
		if not content.has_fighter(fighter_id):
			return ERR_DOES_NOT_EXIST
	characters.assign(fighter_ids)
	reset()
	return OK

func reset() -> void:
	state = {"tick": 0, "rng": 12345, "projectiles": [], "objects": [], "fighters": []}
	for i in range(2):
		var definition: Dictionary = content.fighter(characters[i])
		state.fighters.append({"x": 300 + i * 520, "y": int(content.arena.floor), "vy": 0, "health": int(definition.health),
			"resource": 100, "cooldown": 0, "effects": [], "input": 0, "facing": 1 if i == 0 else -1,
			"move": "", "move_tick": 0, "hit": false,
			"locomotion": Locomotion.IDLE, "action": Action.NEUTRAL, "stun_ticks": 0})

## Simulation-only effect entry point. Durations count subsequent blocked ticks.
## Light has no stun effect yet; no new input bit or guard mechanic is introduced.
func apply_stun(player: int, action: Action, ticks: int) -> bool:
	if player < 0 or player >= 2 or ticks <= 0 or action not in [Action.HITSTUN, Action.BLOCKSTUN]:
		return false
	var fighter: Dictionary = state.fighters[player]
	if int(fighter.action) == Action.KO or int(fighter.health) <= 0:
		return false
	if action == Action.BLOCKSTUN and int(fighter.action) not in [Action.NEUTRAL, Action.BLOCKSTUN]:
		return false
	_clear_move(fighter)
	fighter.action = action
	fighter.stun_ticks = ticks
	if int(fighter.locomotion) == Locomotion.MOVING:
		fighter.locomotion = Locomotion.IDLE
	return true

func _clear_move(fighter: Dictionary) -> void:
	fighter.move = ""
	fighter.move_tick = 0
	fighter.hit = false

func _enter_ko(fighter: Dictionary) -> void:
	_clear_move(fighter)
	fighter.action = Action.KO
	fighter.stun_ticks = 0
	if int(fighter.y) == int(content.arena.floor):
		fighter.locomotion = Locomotion.IDLE

func step(inputs: Array) -> void:
	for i in range(2):
		var fighter: Dictionary = state.fighters[i]
		var definition: Dictionary = content.fighter(characters[i])
		var bits: int = int(inputs[i])
		if int(fighter.health) <= 0:
			_enter_ko(fighter)
		if int(fighter.action) == Action.NEUTRAL:
			var opponent: Dictionary = state.fighters[1 - i]
			if int(opponent.x) != int(fighter.x):
				fighter.facing = 1 if int(opponent.x) > int(fighter.x) else -1
			if bits & 8 and not int(fighter.input) & 8:
				fighter.move = str(definition.moves.light)
				fighter.action = Action.ATTACK
				fighter.move_tick = 0
				fighter.hit = false
		var axis: int = int(bool(bits & 2)) - int(bool(bits & 1))
		if int(fighter.action) != Action.NEUTRAL:
			axis = 0
		fighter.x = clampi(int(fighter.x) + axis * int(definition.speed), int(content.arena.left), int(content.arena.right))
		if int(fighter.action) == Action.NEUTRAL and bits & 4 and not int(fighter.input) & 4 and int(fighter.y) == int(content.arena.floor):
			fighter.vy = int(definition.jump)
		fighter.y = mini(int(content.arena.floor), int(fighter.y) + int(fighter.vy))
		fighter.vy = 0 if int(fighter.y) == int(content.arena.floor) else int(fighter.vy) + 1
		fighter.cooldown = maxi(0, int(fighter.cooldown) - 1)
		fighter.input = bits
		fighter.locomotion = Locomotion.AIRBORNE if int(fighter.y) < int(content.arena.floor) else (Locomotion.MOVING if axis != 0 else Locomotion.IDLE)
		if int(fighter.action) in [Action.HITSTUN, Action.BLOCKSTUN]:
			fighter.stun_ticks = int(fighter.stun_ticks) - 1
			if int(fighter.stun_ticks) == 0:
				fighter.action = Action.NEUTRAL
	# Resolve both attacks after movement; simultaneous hits trade.
	for i in range(2):
		var fighter: Dictionary = state.fighters[i]
		if int(fighter.action) != Action.ATTACK:
			continue
		var move: Dictionary = content.move(str(fighter.move))
		if attack_active(fighter) and not bool(fighter.hit):
			var target: Dictionary = state.fighters[1 - i]
			var hurt: Dictionary = content.fighter(characters[1 - i])
			var distance: int = (int(target.x) - int(fighter.x)) * int(fighter.facing)
			if distance + int(hurt.hurt_width) > 0 and distance - int(hurt.hurt_width) < int(move.reach) and int(target.y) > int(fighter.y) - int(move.top) and int(target.y) - int(hurt.hurt_height) < int(fighter.y) - int(move.bottom):
				target.health = maxi(0, int(target.health) - int(move.damage))
				fighter.hit = true
		fighter.move_tick = int(fighter.move_tick) + 1
		if int(fighter.move_tick) >= int(move.startup) + int(move.active) + int(move.recovery):
			_clear_move(fighter)
			fighter.action = Action.NEUTRAL
	# Apply KO only after both attacks, preserving simultaneous (including lethal) trades.
	for fighter: Dictionary in state.fighters:
		if int(fighter.health) <= 0:
			_enter_ko(fighter)
	state.tick = int(state.tick) + 1

func attack_active(fighter: Dictionary) -> bool:
	if int(fighter.action) != Action.ATTACK:
		return false
	var move: Dictionary = content.move(str(fighter.move))
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
			fighter.resource, fighter.cooldown, fighter.effects, fighter.input, fighter.facing, fighter.move, fighter.move_tick, fighter.hit,
			fighter.locomotion, fighter.action, fighter.stun_ticks])
	return JSON.stringify(canonical).sha256_text()

static func compatibility() -> String:
	return "lab-3:" + Content.new().raw_json.sha256_text()
