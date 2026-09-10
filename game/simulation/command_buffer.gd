extends RefCounted
## Pure tick-based recognition. No device/browser/clock access.
const HISTORY_TICKS := 32
const MAX_PENDING := 16

static func clear(fighter: Dictionary) -> void:
	fighter.input_history = []
	fighter.pending_commands = []

static func record(fighter: Dictionary, bits: int, tick: int, definitions: Array) -> void:
	var history: Array = fighter.input_history
	history.append([tick, bits, int(fighter.facing)])
	while history.size() > HISTORY_TICKS:
		history.pop_front()
	var pending: Array = fighter.pending_commands
	for index in range(pending.size() - 1, -1, -1):
		var command: Dictionary = _definition(definitions, str(pending[index][0]))
		if command.is_empty() or tick - int(pending[index][1]) >= int(command.valid_ticks):
			pending.remove_at(index)
	if not (bits & 8) or int(fighter.input) & 8:
		return
	var winner: Dictionary = {}
	for command: Dictionary in definitions:
		if _matches(history, command, tick) and (winner.is_empty() or _preferred(command, winner)):
			winner = command
	if not winner.is_empty():
		pending.append([str(winner.command_id), tick])
		if pending.size() > MAX_PENDING:
			pending.pop_front()

static func consume(fighter: Dictionary, definitions: Array) -> String:
	var pending: Array = fighter.pending_commands
	var best := -1
	var winner: Dictionary = {}
	for index in range(pending.size()):
		var command: Dictionary = _definition(definitions, str(pending[index][0]))
		# Same command/priority keeps the oldest entry (stable insertion order).
		if winner.is_empty() or _preferred(command, winner):
			best = index
			winner = command
	if best < 0:
		return ""
	pending.remove_at(best)
	return str(winner.move_id)

static func _definition(definitions: Array, id: String) -> Dictionary:
	for command: Dictionary in definitions:
		if command.command_id == id:
			return command
	return {}

static func _preferred(a: Dictionary, b: Dictionary) -> bool:
	return int(a.priority) > int(b.priority) or (int(a.priority) == int(b.priority) and str(a.command_id) < str(b.command_id))

static func _matches(history: Array, command: Dictionary, tick: int) -> bool:
	var sequence: Array = command.sequence
	if sequence.is_empty():
		return true
	# Consecutive directional runs, relative to facing AT EACH recorded sample.
	var runs: Array = []
	for sample: Array in history:
		if int(sample[0]) < tick - int(command.sequence_ticks) + 1:
			continue
		var bits: int = sample[1]
		var direction: int = (int(bool(bits & 2)) - int(bool(bits & 1))) * int(sample[2])
		if runs.is_empty() or runs.back() != direction:
			runs.append(direction)
	if runs.size() < sequence.size():
		return false
	for index in range(sequence.size()):
		if int(runs[runs.size() - sequence.size() + index]) != int(sequence[index]):
			return false
	return true
