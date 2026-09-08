class_name RollbackSession
extends RefCounted
const Sim = preload("res://simulation/simulation.gd")
const WINDOW := 12
var sim := Sim.new()
var local_player: int = 0
var history: Dictionary = {}
var remote: Dictionary = {}
var confirmed: int = -1
var rollbacks: int = 0
var resimulated: int = 0
var failure: String = ""
var hashes: Dictionary = {}

func receive(tick: int, bits: int) -> void:
	if tick < confirmed - WINDOW:
		return
	if tick < 0 or tick > int(sim.state.tick) + 120 or bits < 0 or bits > 15:
		failure = "Input remoto non valido"
		return
	if remote.has(tick):
		if remote[tick] != bits:
			failure = "Input duplicato in conflitto"
		return
	remote[tick] = bits
	if tick < int(sim.state.tick):
		if not history.has(tick):
			failure = "Input oltre la finestra rollback"
			return
		if history[tick].used != bits:
			var end: int = int(sim.state.tick)
			sim.restore(history[tick].state)
			for t in range(tick, end):
				var local_bits: int = history[t].local
				_run(t, local_bits)
				resimulated += 1
			rollbacks += 1
	while remote.has(confirmed + 1) and confirmed + 1 < int(sim.state.tick):
		confirmed += 1

func advance(bits: int) -> bool:
	var tick: int = int(sim.state.tick)
	if not failure.is_empty() or tick - confirmed > WINDOW:
		return false
	_run(tick, bits)
	while remote.has(confirmed + 1) and confirmed + 1 < int(sim.state.tick):
		confirmed += 1
	for key: int in history.keys():
		if key < tick - 120:
			history.erase(key)
			remote.erase(key)
			hashes.erase(key)
	return true

func _run(tick: int, bits: int) -> void:
	var prediction: int = 0
	for t in range(tick - 1, maxi(-1, tick - WINDOW - 1), -1):
		if remote.has(t):
			prediction = remote[t] & 3 # Do not predict jump/button presses.
			break
	var used: int = int(remote.get(tick, prediction))
	history[tick] = {"state": sim.snapshot(), "local": bits, "used": used}
	var inputs: Array = [0, 0]
	inputs[local_player] = bits
	inputs[1 - local_player] = used
	sim.step(inputs)
	hashes[tick] = sim.checksum()
