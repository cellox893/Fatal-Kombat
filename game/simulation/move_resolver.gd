extends RefCounted
## Stateless resolver: all mutable move data lives in the fighter snapshot.
const BEHAVIOR_MELEE := "melee"
enum Phase { STARTUP, ACTIVE, RECOVERY, COMPLETE }

static func supports(behavior: Variant) -> bool:
	return behavior is String and behavior == BEHAVIOR_MELEE

static func phase(move: Dictionary, tick: int) -> Phase:
	if tick < int(move.startup):
		return Phase.STARTUP
	if tick < int(move.startup) + int(move.active):
		return Phase.ACTIVE
	if tick < duration(move):
		return Phase.RECOVERY
	return Phase.COMPLETE

static func duration(move: Dictionary) -> int:
	return int(move.startup) + int(move.active) + int(move.recovery)

static func begin(fighter: Dictionary, move_id: String) -> void:
	fighter.move = move_id
	fighter.move_tick = 0
	fighter.hit = false

static func clear(fighter: Dictionary) -> void:
	fighter.move = ""
	fighter.move_tick = 0
	fighter.hit = false

## Called after both fighters move, before the simultaneous KO pass.
## Returns true after the last recovery tick (or active tick with zero recovery).
static func resolve(fighter: Dictionary, target: Dictionary, hurt: Dictionary, move: Dictionary) -> bool:
	assert(supports(move.behavior_id), "Unvalidated move behavior")
	if phase(move, int(fighter.move_tick)) == Phase.ACTIVE and not bool(fighter.hit):
		var distance: int = (int(target.x) - int(fighter.x)) * int(fighter.facing)
		if distance + int(hurt.hurt_width) > 0 and distance - int(hurt.hurt_width) < int(move.reach) and int(target.y) > int(fighter.y) - int(move.top) and int(target.y) - int(hurt.hurt_height) < int(fighter.y) - int(move.bottom):
			target.health = maxi(0, int(target.health) - int(move.damage))
			fighter.hit = true
	fighter.move_tick = int(fighter.move_tick) + 1
	return int(fighter.move_tick) >= duration(move)
