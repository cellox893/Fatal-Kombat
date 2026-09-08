class_name MatchTransport
extends Node
signal status(message: String)
signal room_updated(data: Dictionary)
signal packet(data: Dictionary)
signal connected
var socket := WebSocketPeer.new()
var peer: WebRTCPeerConnection
var channel: WebRTCDataChannel
var slot: int = 0
var ice_servers: Array = []
var pending_ice: Array = []
var remote_description: bool = false
var opened: bool = false
var active: bool = false
var started_at: int = 0
var last_packet: int = 0
var rtt: int = 0
var ping_at: int = 0
var request: Dictionary = {}

func enter(endpoint: String, code: String) -> void:
	if active:
		status.emit("Sessione già aperta: ricarica per cambiare stanza.")
		return
	request = {"type": "create" if code.is_empty() else "join", "code": code,
		"version": FightSimulation.compatibility()}
	var err: Error = socket.connect_to_url(endpoint)
	if err != OK:
		status.emit("Endpoint non valido: " + error_string(err))
		return
	active = true
	started_at = Time.get_ticks_msec()
	status.emit("Connessione al signaling…")

func send_signal(data: Dictionary) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(data))

func send_packet(data: Dictionary) -> void:
	if channel and channel.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
		channel.put_packet(JSON.stringify(data).to_utf8_buffer())

func _process(_delta: float) -> void:
	if not active:
		return
	socket.poll()
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		if not request.is_empty():
			send_signal(request)
			request = {}
		while socket.get_available_packet_count() > 0:
			var data: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			if data is Dictionary:
				_handle_signal(data)
	elif socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		_fail("Signaling disconnesso. Controlla URL e accesso alla porta 8001, poi ricarica.")
		return
	if peer:
		peer.poll()
		if peer.get_connection_state() == WebRTCPeerConnection.STATE_FAILED:
			_fail("WebRTC fallito: verifica STUN/TURN e rete.")
	if channel and channel.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
		if not opened:
			opened = true
			last_packet = Time.get_ticks_msec()
			connected.emit()
		while channel.get_available_packet_count() > 0:
			var data: Variant = JSON.parse_string(channel.get_packet().get_string_from_utf8())
			if data is Dictionary:
				last_packet = Time.get_ticks_msec()
				if data.get("type") == "ping":
					send_packet({"type": "pong", "time": data.time})
				elif data.get("type") == "pong":
					rtt = Time.get_ticks_msec() - int(data.time)
				else:
					packet.emit(data)
		if Time.get_ticks_msec() - ping_at > 1000:
			ping_at = Time.get_ticks_msec()
			send_packet({"type": "ping", "time": ping_at})
	if opened and Time.get_ticks_msec() - last_packet > 5000:
		_fail("Timeout: nessun pacchetto dal peer per 5 secondi. Ricarica per riprovare.")
	elif peer and not opened and Time.get_ticks_msec() - started_at > 30000:
		_fail("Timeout WebRTC: potrebbe servire un relay TURN.")
	elif not request.is_empty() and Time.get_ticks_msec() - started_at > 15000:
		_fail("Timeout signaling: apri prima l’URL HTTPS della porta 8001.")

func _handle_signal(data: Dictionary) -> void:
	match str(data.get("type", "")):
		"error":
			status.emit(str(data.message))
			if opened:
				_fail(str(data.message))
		"room":
			slot = int(data.slot)
			ice_servers = data.iceServers
			room_updated.emit(data)
		"connect":
			started_at = Time.get_ticks_msec()
			peer = WebRTCPeerConnection.new()
			peer.session_description_created.connect(_description)
			peer.ice_candidate_created.connect(func(mid: String, index: int, candidate: String) -> void:
				send_signal({"type": "ice", "mid": mid, "index": index, "candidate": candidate}))
			var err: Error = peer.initialize({"iceServers": ice_servers})
			if err != OK:
				_fail("WebRTC non disponibile: " + error_string(err))
				return
			channel = peer.create_data_channel("inputs", {"negotiated": true, "id": 1, "ordered": false, "maxRetransmits": 0})
			status.emit("Negoziazione WebRTC…")
			if slot == 0:
				peer.create_offer()
		"sdp":
			if peer:
				var err: Error = peer.set_remote_description(str(data.kind), str(data.sdp))
				if err != OK:
					_fail("SDP rifiutato")
					return
				remote_description = true
				for candidate: Dictionary in pending_ice:
					_add_ice(candidate)
				pending_ice.clear()
		"ice":
			if not remote_description:
				pending_ice.append(data)
			else:
				_add_ice(data)

func _description(kind: String, sdp: String) -> void:
	peer.set_local_description(kind, sdp)
	send_signal({"type": "sdp", "kind": kind, "sdp": sdp})

func _add_ice(data: Dictionary) -> void:
	peer.add_ice_candidate(str(data.mid), int(data.index), str(data.candidate))

func _fail(message: String) -> void:
	active = false
	if peer:
		peer.close()
	socket.close()
	status.emit(message)
