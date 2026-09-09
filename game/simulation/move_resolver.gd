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

static func begin(fighter: Dictionary, move_id: String, slot: int) -> void:
	fighter.attack_sequence = int(fighter.attack_sequence) + 1
	fighter.attack_id = [slot, fighter.attack_sequence]
	fighter.hit_targets = []
	fighter.move = move_id
	fighter.move_tick = 0
	fighter.hit = false

static func clear(fighter: Dictionary) -> void:
	fighter.attack_id = []
	fighter.hit_targets = []
	fighter.move = ""
	fighter.move_tick = 0
	fighter.hit = false

## Called after both fighters move, before the simultaneous KO pass.
## Returns true after the last recovery tick (or active tick with zero recovery).
static func resolve(fighter: Dictionary, target: Dictionary, hurt: Array, move: Dictionary, target_slot: int) -> bool:
	assert(supports(move.behavior_id), "Unvalidated move behavior")
	for group_id: String in move.hit_groups:
		var key: Array = [group_id, target_slot]
		if fighter.hit_targets.has(key):
			continue
		var collided := false
		for box: Dictionary in active_hitboxes(move, int(fighter.move_tick)):
			if box.group_id != group_id:
				continue
			for target_box: Dictionary in hurt:
				if overlaps(world_box(fighter, box), target_box):
					collided = true
		if collided:
			fighter.hit_targets.append(key)
			target.health = maxi(0, int(target.health) - int(move.damage))
			fighter.hit = true # Legacy diagnostic; registry is the collision authority.
	fighter.move_tick = int(fighter.move_tick) + 1
	return int(fighter.move_tick) >= duration(move)

static func active_hitboxes(move: Dictionary, tick: int) -> Array:
	var boxes: Array = []
	for box: Dictionary in move.hitboxes:
		if tick >= int(box.from) and tick < int(box.to):
			boxes.append(box)
	return boxes

static func hurtboxes(fighter: Dictionary, definition: Dictionary, move: Dictionary) -> Array:
	var boxes: Array = definition.hurtboxes
	if not move.is_empty():
		for window: Dictionary in move.hurtbox_windows:
			if int(fighter.move_tick) >= int(window.from) and int(fighter.move_tick) < int(window.to):
				boxes = window.boxes
	var result: Array = []
	for box: Dictionary in boxes:
		result.append(world_box(fighter, box))
	return result

static func world_box(fighter: Dictionary, box: Dictionary) -> Dictionary:
	var x: int = int(box.x) if int(fighter.facing) > 0 else -int(box.x) - int(box.width)
	return {"x": int(fighter.x) + x, "y": int(fighter.y) + int(box.y), "width": int(box.width), "height": int(box.height)}

static func overlaps(a: Dictionary, b: Dictionary) -> bool:
	return int(a.x) < int(b.x) + int(b.width) and int(a.x) + int(a.width) > int(b.x) and int(a.y) < int(b.y) + int(b.height) and int(a.y) + int(a.height) > int(b.y)
