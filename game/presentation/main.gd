extends Node2D
const Rollback = preload("res://network/rollback.gd")
const Transport = preload("res://network/transport.gd")
var session := Rollback.new()
var net := Transport.new()
var endpoint := LineEdit.new()
var code := LineEdit.new()
var notice := Label.new()
var telemetry := Label.new()
var selection := OptionButton.new()
var start_button := Button.new()
var running: bool = false
var outgoing: Dictionary = {}
var remote_hashes: Dictionary = {}
var desyncs: int = 0
var frame_ms: float = 0.0
var frame_peak: float = 0.0
var stalled_at: int = 0
var characters: Array = [0, 1]
var room_label := Label.new()
var room_code: String = ""
var next_web_diagnostic_at: int = 0

func _ready() -> void:
	add_child(net)
	net.status.connect(func(message: String) -> void:
		notice.text = message
		if not net.active:
			running = false)
	net.room_updated.connect(_room)
	net.packet.connect(_packet)
	net.connected.connect(func() -> void:
		session.local_player = net.slot
		session.sim.characters = characters.duplicate()
		running = true
		notice.text = "WebRTC connesso · frecce / A D per muoverti, spazio salto, J attacco leggero")
	var panel := VBoxContainer.new()
	panel.position = Vector2(42, 26)
	panel.size = Vector2(1036, 280)
	panel.add_theme_constant_override("separation", 10)
	add_child(panel)
	var title := Label.new()
	title.text = "FATAL KOMBAT   /   COMBAT LAB 02"
	title.add_theme_font_size_override("font_size", 30)
	panel.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Due epoche. Un’arena.  •  Prova tecnica di connessione e rollback, combattimento in sviluppo."
	panel.add_child(subtitle)
	endpoint.placeholder_text = "Endpoint signaling wss://…"
	endpoint.text = "ws://127.0.0.1:8001"
	if OS.has_feature("web"):
		endpoint.text = str(JavaScriptBridge.eval("(location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '/signaling'"))
	else:
		var configured: String = OS.get_environment("SIGNALING_URL")
		if not configured.is_empty():
			endpoint.text = configured
	panel.add_child(endpoint)
	var row := HBoxContainer.new()
	panel.add_child(row)
	var create := Button.new()
	create.text = "Crea stanza privata"
	create.pressed.connect(func() -> void: net.enter(endpoint.text, ""))
	row.add_child(create)
	code.placeholder_text = "Codice invito"
	code.custom_minimum_size.x = 200
	row.add_child(code)
	var join := Button.new()
	join.text = "Entra"
	join.pressed.connect(func() -> void: net.enter(endpoint.text, code.text.strip_edges()))
	row.add_child(join)
	selection.add_item("Leonida · scudo / rame")
	selection.add_item("Tesla · elettricità / ciano")
	row.add_child(selection)
	start_button.text = "Pronto"
	start_button.disabled = true
	start_button.pressed.connect(func() -> void:
		net.send_signal({"type": "ready", "ready": true, "character": "leonidas" if selection.selected == 0 else "tesla"})
		start_button.disabled = true
		selection.disabled = true)
	row.add_child(start_button)
	panel.add_child(room_label)
	notice.text = "Crea una stanza oppure inserisci il codice di un amico."
	panel.add_child(notice)
	telemetry.position = Vector2(42, 608)
	telemetry.add_theme_font_size_override("font_size", 15)
	add_child(telemetry)

func _room(data: Dictionary) -> void:
	room_code = str(data.code)
	room_label.text = "STANZA  " + str(data.code) + "   •   Sei P" + str(int(data.slot) + 1)
	for i in range(data.players.size()):
		characters[i] = 0 if data.players[i].character == "leonidas" else 1
		room_label.text += "   |   P%d: %s" % [i + 1, "pronto" if data.players[i].ready else "in attesa"]
	start_button.disabled = bool(data.players[int(data.slot)].ready)

func _physics_process(_delta: float) -> void:
	if not running:
		return
	var bits: int = int(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	bits |= int(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) * 2
	bits |= int(Input.is_physical_key_pressed(KEY_SPACE)) * 4
	bits |= int(Input.is_physical_key_pressed(KEY_J)) * 8
	var tick: int = int(session.sim.state.tick)
	if session.advance(bits):
		outgoing[tick] = bits
		stalled_at = 0
	else:
		if stalled_at == 0:
			stalled_at = Time.get_ticks_msec()
		if Time.get_ticks_msec() - stalled_at > 5000:
			running = false
			notice.text = "Connessione insufficiente: input mancanti per 5 secondi. Ricarica."
	var batch: Array = []
	for t: int in outgoing.keys():
		if t < tick - 120:
			outgoing.erase(t)
		else:
			batch.append([t, outgoing[t]])
	var confirmed: int = session.confirmed
	net.send_packet({"type": "inputs", "batch": batch, "confirmed": confirmed,
		"hash": session.hashes.get(confirmed, "")})
	_check_hashes()
	if not session.failure.is_empty():
		running = false
		notice.text = session.failure

func _packet(data: Dictionary) -> void:
	if data.get("type") != "inputs" or not data.get("batch") is Array or data.batch.size() > 121:
		return
	for entry: Variant in data.batch:
		if not entry is Array or entry.size() != 2 or not (entry[0] is float or entry[0] is int) or not (entry[1] is float or entry[1] is int):
			session.failure = "Pacchetto input malformato"
			return
		session.receive(int(entry[0]), int(entry[1]))
	var confirmed: int = int(data.get("confirmed", -1))
	if confirmed >= 0 and confirmed <= int(session.sim.state.tick) + 120:
		remote_hashes[confirmed] = str(data.get("hash", ""))

func _check_hashes() -> void:
	for tick: int in remote_hashes.keys():
		if tick <= session.confirmed and session.hashes.has(tick):
			if session.hashes[tick] != remote_hashes[tick]:
				desyncs += 1
				session.failure = "Desincronizzazione al tick %d. Partita interrotta." % tick
			remote_hashes.erase(tick)
		elif tick < int(session.sim.state.tick) - 120:
			remote_hashes.erase(tick)

func _process(delta: float) -> void:
	frame_ms = delta * 1000.0
	frame_peak = maxf(frame_peak, frame_ms)
	if OS.has_feature("web") and Time.get_ticks_msec() >= next_web_diagnostic_at:
		next_web_diagnostic_at = Time.get_ticks_msec() + 250
		var raw: Variant = JavaScriptBridge.eval("JSON.stringify(window.fatalLabRtc || {})")
		var data: Variant = JSON.parse_string(str(raw))
		if data is Dictionary:
			net.browser_diagnostic = data
	var latest_event: String = net.diagnostic_events.back() if not net.diagnostic_events.is_empty() else "—"
	var browser_states: String = ""
	if not net.browser_diagnostic.is_empty():
		browser_states = " · browser ice %s / conn %s" % [str(net.browser_diagnostic.get("iceConnectionState", "—")), str(net.browser_diagnostic.get("connectionState", "—"))]
	telemetry.text = "FPS %d   •   frame %.1f ms / picco %.1f ms   •   tick %d / confermato %d\nRTT %d ms   •   rollback %d / tick risimulati %d   •   desync %d   •   finestra 12 tick\nWebRTC: %s%s\nEvento: %s" % [
		Engine.get_frames_per_second(), frame_ms, frame_peak, session.sim.state.tick,
		session.confirmed, net.rtt, session.rollbacks, session.resimulated, desyncs,
		net.webrtc_summary(), browser_states, latest_event]
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.fatalLab = " + JSON.stringify({"room": room_code, "status": notice.text, "tick": session.sim.state.tick, "confirmed": session.confirmed, "rollback": session.rollbacks, "desyncs": desyncs, "running": running, "checksum": session.sim.checksum(), "health": [session.sim.state.fighters[0].health, session.sim.state.fighters[1].health], "x": session.sim.state.fighters[net.slot].x, "localCandidates": net.local_candidate_count, "remoteCandidates": net.remote_candidate_count, "localCandidateTypes": net.local_candidate_types, "remoteCandidateTypes": net.remote_candidate_types, "iceGatheringState": net.ice_gathering_state, "iceConnectionState": net.ice_connection_state, "connectionState": net.connection_state, "iceCompleteLocal": net.local_ice_complete_sent, "iceCompleteRemote": net.remote_ice_complete_received, "events": net.diagnostic_events, "browser": net.browser_diagnostic}))
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(40, 300, 1040, 275), Color("111d30"))
	for x in range(80, 1080, 80):
		draw_line(Vector2(x, 300), Vector2(x, 550), Color("1c2b3c"), 1)
	draw_circle(Vector2(560, 410), 78, Color("18283a"))
	draw_arc(Vector2(560, 410), 84, 0, TAU, 80, Color("394957"), 2)
	draw_line(Vector2(40, 551), Vector2(1080, 551), Color("d6ac66"), 3)
	for i in range(2):
		var fighter: Dictionary = session.sim.state.fighters[i]
		var id: int = characters[i]
		var color := Color(str(session.sim.content.fighters[id].color))
		var pos := Vector2(int(fighter.x), int(fighter.y))
		var facing: float = float(fighter.facing)
		var sway: float = sin(Time.get_ticks_msec() * 0.004 + i) * 2
		draw_circle(Vector2(pos.x, 553), 25, Color(0, 0, 0, 0.35))
		draw_line(pos + Vector2(-10, 0), pos + Vector2(-8, -35), color, 10)
		draw_line(pos + Vector2(13, 0), pos + Vector2(8, -35), color, 10)
		draw_rect(Rect2(pos + Vector2(-17, -79 + sway), Vector2(34, 47)), color.darkened(0.3))
		draw_circle(pos + Vector2(0, -96 + sway), 15, color)
		if id == 0:
			draw_circle(pos + Vector2(23 * facing, -57), 24, color)
			draw_circle(pos + Vector2(23 * facing, -57), 17, color.darkened(0.35))
			draw_line(pos + Vector2(-22 * facing, -20), pos + Vector2(-22 * facing, -125), color, 3)
		else:
			draw_line(pos + Vector2(10 * facing, -72), pos + Vector2(35 * facing, -65 + sway), color, 7)
			draw_arc(pos + Vector2(40 * facing, -65 + sway), 12, 0, TAU * 0.8, 12, color, 2)
		draw_rect(Rect2(pos + Vector2(-30, -140), Vector2(60, 5)), Color("442222"))
		draw_rect(Rect2(pos + Vector2(-30, -140), Vector2(60 * float(fighter.health) / 100.0, 5)), color)
		if session.sim.attack_active(fighter):
			var move: Dictionary = session.sim.content.moves[fighter.move]
			var offset: float = 0.0 if facing > 0 else -float(move.reach)
			draw_rect(Rect2(pos + Vector2(offset, -float(move.top)), Vector2(float(move.reach), float(move.top) - float(move.bottom))), Color(1, 0.7, 0.2, 0.5))
		if Input.is_physical_key_pressed(KEY_H):
			draw_rect(Rect2(pos + Vector2(-24, -113), Vector2(48, 113)), Color.GREEN, false, 1)
