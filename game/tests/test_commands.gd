extends SceneTree
const Sim = preload("res://simulation/simulation.gd")
const Content = preload("res://content/fight_content.gd")
const Buffer = preload("res://simulation/command_buffer.gd")
const Rollback = preload("res://network/rollback.gd")

func _initialize() -> void:
	_test_edges_and_windows()
	_test_sequences()
	_test_rollback()
	_test_validation()
	print("PASS command edges, expiry, recovery/stun, air/KO/reset, sequences/priority, bounded memory and corrected prediction")
	quit()

func _test_edges_and_windows() -> void:
	var held := Sim.new()
	for tick in range(70):
		held.step([8, 0])
	assert(held.state.fighters[0].attack_sequence == 1)
	assert(held.state.fighters[0].pending_commands.is_empty())
	held.step([0, 0])
	held.step([8, 0])
	assert(held.state.fighters[0].attack_sequence == 2)
	# First move resolves ticks 0..19; earliest next start is 20.
	for pressed: int in [15, 16, 17, 19]:
		var sim := Sim.new()
		for tick in range(21):
			sim.step([8 if tick == 0 or tick == pressed else 0, 0])
			if tick < 20:
				assert(sim.state.fighters[0].attack_sequence == 1, "no early cancel")
		assert(sim.state.fighters[0].attack_sequence == (2 if pressed >= 17 else 1), "valid age < 4")
		if pressed >= 17:
			assert(sim.state.fighters[0].move_tick == 1, "first permitted tick")
		for tick in range(30):
			sim.step([0, 0])
		assert(sim.state.fighters[0].attack_sequence == (2 if pressed >= 17 else 1), "consume once")
	for action: int in [Sim.Action.HITSTUN, Sim.Action.BLOCKSTUN]:
		for duration: int in [3, 4]:
			var sim := Sim.new()
			assert(sim.apply_stun(0, action, duration))
			for tick in range(duration):
				sim.step([8, 0])
				assert(sim.state.fighters[0].attack_sequence == 0)
			sim.step([8, 0])
			assert(sim.state.fighters[0].attack_sequence == (1 if duration == 3 else 0))
	var airborne := Sim.new()
	airborne.step([4, 0])
	airborne.step([8, 0])
	assert(airborne.state.fighters[0].locomotion == Sim.Locomotion.AIRBORNE)
	assert(airborne.state.fighters[0].action == Sim.Action.ATTACK)
	# Fill the bounded queue with valid distinct press edges during long stun.
	var full := Sim.new()
	full.content.commands.light_press.valid_ticks = 32
	assert(full.apply_stun(0, Sim.Action.HITSTUN, 200))
	for tick in range(100):
		full.step([8 if tick % 2 == 0 else 0, 0])
		assert(full.state.fighters[0].input_history.size() <= 32)
		assert(full.state.fighters[0].pending_commands.size() <= 16)
	assert(full.state.fighters[0].pending_commands.size() == 16)
	var saved: Dictionary = full.snapshot()
	var saved_hash: String = full.checksum()
	full.state.fighters[0].pending_commands[0][1] += 1
	assert(full.checksum() != saved_hash and saved.fighters[0].pending_commands[0][1] != full.state.fighters[0].pending_commands[0][1])
	full.restore(saved)
	assert(full.checksum() == saved_hash)
	full.state.fighters[0].input_history[0][1] ^= 1
	assert(full.checksum() != saved_hash)
	full.restore(saved)
	full.state.fighters[0].health = 0
	full.step([8, 0])
	assert(full.state.fighters[0].input_history.is_empty() and full.state.fighters[0].pending_commands.is_empty())
	full.restore(saved)
	full.reset()
	assert(full.snapshot() == Sim.new().snapshot())
	# Lethal damage later in tick also clears commands recorded earlier.
	var lethal := Sim.new()
	lethal.state.fighters[1].x = 360
	lethal.state.fighters[0].health = 8
	for tick in range(6):
		lethal.step([8 if tick == 5 else 0, 8 if tick == 0 else 0])
	assert(lethal.state.fighters[0].action == Sim.Action.KO)
	assert(lethal.state.fighters[0].pending_commands.is_empty() and lethal.state.fighters[0].input_history.is_empty())

func _test_sequences() -> void:
	var base := {"command_id":"light_press","move_id":"light","button":8,"valid_ticks":4,"priority":0,"sequence":[],"sequence_ticks":4}
	var sequence: Dictionary = base.duplicate(true)
	sequence.command_id = "direction_test"
	sequence.move_id = "sequence_move"
	sequence.priority = 2
	sequence.sequence = [-1, 0, 1]
	for facing: int in [-1, 1]:
		var fighter := {"input":0,"facing":facing,"input_history":[],"pending_commands":[]}
		var bits: Array = [1 if facing == 1 else 2, 3, (2 if facing == 1 else 1) | 8]
		for tick in range(3):
			Buffer.record(fighter, bits[tick], tick, [base, sequence])
			fighter.input = bits[tick]
		assert(fighter.pending_commands == [["direction_test", 2]], "one winner per edge")
		assert(Buffer.consume(fighter, [base, sequence]) == "sequence_move")
		assert(Buffer.consume(fighter, [base, sequence]) == "")
	# Sample facing is retained, not retroactively reinterpreted on cross-up.
	var fighter := {"input":0,"facing":1,"input_history":[],"pending_commands":[]}
	Buffer.record(fighter, 1, 0, [base, sequence])
	Buffer.record(fighter, 0, 1, [base, sequence])
	fighter.facing = -1
	Buffer.record(fighter, 9, 2, [base, sequence])
	assert(Buffer.consume(fighter, [base, sequence]) == "sequence_move")
	for final_tick: int in [3, 4]:
		fighter = {"input":0,"facing":1,"input_history":[],"pending_commands":[]}
		Buffer.record(fighter, 1, 0, [base, sequence])
		for tick in range(1, final_tick):
			Buffer.record(fighter, 0, tick, [base, sequence])
		Buffer.record(fighter, 10, final_tick, [base, sequence])
		assert(Buffer.consume(fighter, [base, sequence]) == ("sequence_move" if final_tick == 3 else "light"))
	var tie: Dictionary = base.duplicate(true)
	tie.command_id = "a_tie"
	tie.move_id = "tie_move"
	for definitions: Array in [[base, tie], [tie, base]]:
		fighter = {"input":0,"facing":1,"input_history":[],"pending_commands":[]}
		Buffer.record(fighter, 8, 0, definitions)
		assert(Buffer.consume(fighter, definitions) == "tie_move", "lexical tie independent of data order")
	# Two presses while blocked: higher priority first, no duplicate execution.
	fighter = {"input":0,"facing":1,"input_history":[],"pending_commands":[]}
	Buffer.record(fighter, 8, 0, [base])
	fighter.input = 8
	Buffer.record(fighter, 0, 1, [base, tie])
	fighter.input = 0
	Buffer.record(fighter, 8, 2, [base, tie])
	assert(Buffer.consume(fighter, [base, tie]) == "tie_move")
	assert(Buffer.consume(fighter, [base, tie]) == "light")
	assert(Buffer.consume(fighter, [base, tie]) == "")
	# End-to-end fixture goes through catalog validation and starts its mapped move.
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Content.CONTENT_PATH))
	var move: Dictionary = data.moves[0].duplicate(true)
	move.move_id = "sequence_move"
	data.moves.append(move)
	data.commands.append(sequence)
	for definition: Dictionary in data.fighters:
		definition.command_ids.append("direction_test")
	assert(Content.validate(data).is_empty())
	var sim := Sim.new()
	sim.content = Content.new(data)
	sim.reset()
	sim.step([1, 0])
	sim.step([3, 0])
	sim.step([10, 0])
	assert(sim.state.fighters[0].move == "sequence_move")

func _input(tick: int, player: int) -> int:
	return (8 if tick % 40 in [0, 18, 38] else 0) | (2 if (tick + player) % 13 == 0 else 0)

func _test_rollback() -> void:
	for delay: int in [2, 5, 9]:
		var reference := Sim.new()
		var session := Rollback.new()
		reference.state.fighters[1].x = 360
		session.sim.state.fighters[1].x = 360
		var hashes: Array = []
		for tick in range(100):
			reference.step([_input(tick, 0), _input(tick, 1)])
			hashes.append(reference.checksum())
			if tick >= delay:
				session.receive(tick - delay, _input(tick - delay, 1))
			assert(session.advance(_input(tick, 0)))
		for tick in range(100 - delay, 100):
			session.receive(tick, _input(tick, 1))
		assert(session.rollbacks > 0 and session.failure.is_empty())
		assert(session.sim.snapshot() == reference.snapshot() and session.sim.checksum() == reference.checksum())
		for tick in range(100):
			assert(session.hashes[tick] == hashes[tick], "corrected history diverged")

func _test_validation() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Content.CONTENT_PATH))
	for field: String in ["command_id","move_id","button","valid_ticks","priority","sequence","sequence_ticks"]:
		var data: Dictionary = raw.duplicate(true)
		data.commands[0].erase(field)
		assert(not Content.validate(data).is_empty())
	for mutation: String in ["window","fraction","priority","button","move","sequence","duplicate","reference"]:
		var data: Dictionary = raw.duplicate(true)
		match mutation:
			"window": data.commands[0].valid_ticks = 33
			"fraction": data.commands[0].valid_ticks = 1.5
			"priority": data.commands[0].priority = -1
			"button": data.commands[0].button = 16
			"move": data.commands[0].move_id = "missing"
			"sequence": data.commands[0].sequence = [1, 1]
			"duplicate": data.commands.append(data.commands[0].duplicate(true))
			"reference": data.fighters[0].command_ids = ["missing"]
		assert(not Content.validate(data).is_empty(), mutation)
