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
var signaling_opened: bool = false
var awaiting_room: bool = false
var room_requested_at: int = 0
var local_candidate_count: int = 0
var remote_candidate_count: int = 0
var local_candidate_types: Dictionary = {"host": 0, "srflx": 0, "relay": 0, "other": 0}
var remote_candidate_types: Dictionary = {"host": 0, "srflx": 0, "relay": 0, "other": 0}
var local_candidate_raw: Array[String] = []
var remote_candidate_raw: Array[String] = []
var ice_gathering_state: String = "new"
var ice_connection_state: String = "new"
var connection_state: String = "new"
var local_ice_complete_sent: bool = false
var remote_ice_complete_received: bool = false
var diagnostic_events: Array[String] = []
var browser_diagnostic: Dictionary = {}

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
		if not signaling_opened:
			signaling_opened = true
			status.emit("WebSocket aperto · richiesta alla lobby…")
		if not request.is_empty():
			var send_error: Error = socket.send_text(JSON.stringify(request))
			if send_error != OK:
				_fail("Invio alla lobby fallito: " + error_string(send_error))
				return
			awaiting_room = true
			room_requested_at = Time.get_ticks_msec()
			request = {}
		while socket.get_available_packet_count() > 0:
			var data: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			if data is Dictionary:
				_handle_signal(data)
	elif socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		var close_code: int = socket.get_close_code()
		var stage: String = "dopo apertura" if signaling_opened else "prima dell’apertura"
		_fail("Signaling chiuso %s (codice %d). Ricarica il gioco; se persiste, comunica questo messaggio." % [stage, close_code])
		return
	if peer:
		peer.poll()
		_refresh_webrtc_states()
		if peer.get_connection_state() == WebRTCPeerConnection.STATE_FAILED:
			_fail("WebRTC fallito: %s" % webrtc_summary())
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
		_fail("Timeout WebRTC: %s" % webrtc_summary())
	elif not signaling_opened and Time.get_ticks_msec() - started_at > 15000:
		_fail("Timeout apertura WebSocket (15 s). Verifica accesso all’URL del gioco e rete.")
	elif awaiting_room and Time.get_ticks_msec() - room_requested_at > 10000:
		_fail("WebSocket aperto, ma la lobby non risponde (10 s). Comunica questo messaggio.")

func _handle_signal(data: Dictionary) -> void:
	match str(data.get("type", "")):
		"error":
			awaiting_room = false
			status.emit(str(data.message))
			if opened:
				_fail(str(data.message))
		"room":
			awaiting_room = false
			if not peer:
				status.emit("Lobby connessa · scegli il personaggio e premi Pronto in entrambe le finestre.")
			slot = int(data.slot)
			ice_servers = data.iceServers
			room_updated.emit(data)
		"connect":
			started_at = Time.get_ticks_msec()
			_reset_webrtc_diagnostics()
			peer = WebRTCPeerConnection.new()
			peer.session_description_created.connect(_description)
			peer.ice_candidate_created.connect(func(mid: String, index: int, candidate: String) -> void:
				local_candidate_count += 1
				local_candidate_raw.append(candidate)
				var candidate_type: String = _candidate_type(candidate)
				local_candidate_types[candidate_type] = int(local_candidate_types.get(candidate_type, 0)) + 1
				_log_event("ICE locale %s mline=%d raw=%s" % [candidate_type, index, candidate])
				send_signal({"type": "ice", "mid": mid, "index": index, "candidate": candidate}))
			var config: Dictionary = {"iceServers": ice_servers}
			if OS.has_feature("web"):
				config["iceTransportPolicy"] = "all"
			_log_event("RTCPeerConnection config=" + JSON.stringify(config))
			var err: Error = peer.initialize(config)
			if err != OK:
				_fail("WebRTC non disponibile: " + error_string(err))
				return
			channel = peer.create_data_channel("inputs", {"negotiated": true, "id": 1, "ordered": false, "maxRetransmits": 0})
			if channel == null:
				_fail("Creazione canale dati fallita")
				return
			_log_event("Canale dati creato prima dell'offerta")
			status.emit("Negoziazione WebRTC…")
			if slot == 0:
				var offer_error: Error = peer.create_offer()
				if offer_error != OK:
					_fail("Creazione offerta fallita: " + error_string(offer_error))
		"sdp":
			if peer:
				_log_event("SDP remota %s ricevuta" % str(data.kind))
				var err: Error = peer.set_remote_description(str(data.kind), str(data.sdp))
				if err != OK:
					_fail("SDP remota rifiutata: " + error_string(err))
					return
				remote_description = true
				for candidate: Dictionary in pending_ice:
					_add_ice(candidate)
				pending_ice.clear()
				_log_event("SDP remota applicata")
		"ice":
			remote_candidate_count += 1
			var raw_candidate: String = str(data.candidate)
			remote_candidate_raw.append(raw_candidate)
			var remote_type: String = _candidate_type(raw_candidate)
			remote_candidate_types[remote_type] = int(remote_candidate_types.get(remote_type, 0)) + 1
			_log_event("ICE remoto %s raw=%s" % [remote_type, raw_candidate])
			if not remote_description:
				pending_ice.append(data)
				_log_event("ICE remoto accodato prima della SDP")
			else:
				_add_ice(data)
		"ice-complete":
			remote_ice_complete_received = true
			_log_event("Fine raccolta ICE remota ricevuta")

func _description(kind: String, sdp: String) -> void:
	var err: Error = peer.set_local_description(kind, sdp)
	if err != OK:
		_fail("SDP locale rifiutata: " + error_string(err))
		return
	_log_event("SDP locale %s inviata" % kind)
	send_signal({"type": "sdp", "kind": kind, "sdp": sdp})

func _add_ice(data: Dictionary) -> void:
	var err: Error = peer.add_ice_candidate(str(data.mid), int(data.index), str(data.candidate))
	if err != OK:
		_log_event("ICE remoto rifiutato: " + error_string(err))
	else:
		_log_event("ICE remoto aggiunto")

func _refresh_webrtc_states() -> void:
	var next_gathering: String = _gathering_state_name(int(peer.get_gathering_state()))
	var next_connection: String = _connection_state_name(int(peer.get_connection_state()))
	if next_gathering != ice_gathering_state:
		ice_gathering_state = next_gathering
		_log_event("iceGatheringState=" + ice_gathering_state)
	if next_connection != connection_state:
		connection_state = next_connection
		ice_connection_state = next_connection
		_log_event("connectionState=" + connection_state)
	if ice_gathering_state == "complete" and not local_ice_complete_sent:
		local_ice_complete_sent = true
		_log_event("Fine raccolta ICE locale inviata")
		send_signal({"type": "ice-complete"})

func _reset_webrtc_diagnostics() -> void:
	local_candidate_count = 0
	remote_candidate_count = 0
	local_candidate_types = {"host": 0, "srflx": 0, "relay": 0, "other": 0}
	remote_candidate_types = {"host": 0, "srflx": 0, "relay": 0, "other": 0}
	local_candidate_raw.clear()
	remote_candidate_raw.clear()
	ice_gathering_state = "new"
	ice_connection_state = "new"
	connection_state = "new"
	local_ice_complete_sent = false
	remote_ice_complete_received = false
	diagnostic_events.clear()
	browser_diagnostic = {}

func _candidate_type(candidate: String) -> String:
	var parts: PackedStringArray = candidate.split(" ", false)
	for i: int in range(parts.size() - 1):
		if parts[i] == "typ":
			var value: String = parts[i + 1]
			return value if value in ["host", "srflx", "relay"] else "other"
	return "other"

func _gathering_state_name(value: int) -> String:
	return ["new", "gathering", "complete"][clampi(value, 0, 2)]

func _connection_state_name(value: int) -> String:
	return ["new", "connecting", "connected", "disconnected", "failed", "closed"][clampi(value, 0, 5)]

func _log_event(message: String) -> void:
	diagnostic_events.append(message)
	if diagnostic_events.size() > 12:
		diagnostic_events.pop_front()

func webrtc_summary() -> String:
	return "gathering %s · ice %s · conn %s · locali %d %s · remoti %d %s · fine locale %s/remota %s" % [ice_gathering_state, ice_connection_state, connection_state, local_candidate_count, JSON.stringify(local_candidate_types), remote_candidate_count, JSON.stringify(remote_candidate_types), "sì" if local_ice_complete_sent else "no", "sì" if remote_ice_complete_received else "no"]

func _fail(message: String) -> void:
	active = false
	if peer:
		peer.close()
	socket.close()
	status.emit(message)
