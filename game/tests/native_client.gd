extends SceneTree
var lab: Node
var started: int

func _initialize() -> void:
	started = Time.get_ticks_msec()
	call_deferred("launch")

func launch() -> void:
	lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.net.room_updated.connect(func(data: Dictionary) -> void:
		if not bool(data.players[int(data.slot)].ready):
			lab.net.send_signal({"type": "ready", "character": "tesla", "ready": true}))
	lab.net.enter("ws://127.0.0.1:8001", OS.get_cmdline_user_args()[0])

func _process(_delta: float) -> bool:
	if lab:
		if not lab.session.failure.is_empty():
			push_error(lab.session.failure)
			quit(1)
		if lab.session.confirmed > 180:
			print("PASS native Linux / browser WebRTC, confirmed=", lab.session.confirmed, " desync=", lab.desyncs)
			quit()
	if Time.get_ticks_msec() - started > 45000:
		push_error("Native/browser timeout")
		quit(1)
	return false
