extends SceneTree
var peers: Array[WebRTCPeerConnection] = []
var channels: Array[WebRTCDataChannel] = []
var start: int
var sent: bool = false
var received: Array = [false, false]

func _initialize() -> void:
	start = Time.get_ticks_msec()
	for i in range(2):
		var peer := WebRTCPeerConnection.new()
		assert(peer.initialize({"iceServers": []}) == OK)
		peers.append(peer)
		channels.append(peer.create_data_channel("inputs", {"negotiated": true, "id": 1, "ordered": false, "maxRetransmits": 0}))
		peer.session_description_created.connect(func(kind: String, sdp: String) -> void:
			assert(peers[i].set_local_description(kind, sdp) == OK)
			assert(peers[1 - i].set_remote_description(kind, sdp) == OK))
		peer.ice_candidate_created.connect(func(mid: String, index: int, candidate: String) -> void:
			peers[1 - i].add_ice_candidate(mid, index, candidate))
	assert(peers[0].create_offer() == OK)

func _process(_delta: float) -> bool:
	for peer in peers:
		peer.poll()
	if not sent and channels.all(func(c: WebRTCDataChannel) -> bool: return c.get_ready_state() == WebRTCDataChannel.STATE_OPEN):
		for channel in channels:
			assert(channel.put_packet('{"tick":42,"input":2}'.to_utf8_buffer()) == OK)
		sent = true
	for i in range(2):
		if channels[i].get_available_packet_count() > 0:
			var data: Dictionary = JSON.parse_string(channels[i].get_packet().get_string_from_utf8())
			assert(int(data.tick) == 42 and int(data.input) == 2)
			received[i] = true
	if received.all(func(value: bool) -> bool: return value):
		print("PASS native WebRTC: two peers in one process, bidirectional tick input")
		for peer in peers:
			peer.close()
		quit()
	elif Time.get_ticks_msec() - start > 15000:
		push_error("WebRTC native timed out")
		quit(1)
	return false
