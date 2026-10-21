class_name LanHostServer
extends RefCounted

## Local Wi-Fi host: serves the web export over HTTP and pairs browser players
## over WebSocket. It only relays moves; every client runs the rules itself.

const MovementCardScript := preload("res://scripts/battle/movement_card.gd")
const CHUNK_SIZE: int = 64 * 1024
const MIME_TYPES: Dictionary = {
	"html": "text/html; charset=utf-8",
	"js": "text/javascript; charset=utf-8",
	"wasm": "application/wasm",
	"pck": "application/octet-stream",
	"png": "image/png",
	"ico": "image/x-icon",
	"svg": "image/svg+xml",
	"json": "application/json",
}

var web_root: String = ""
var http_port: int = 8060
var websocket_port: int = 8061
var match_count: int = 0

var _http_server := TCPServer.new()
var _websocket_server := TCPServer.new()
## Pending HTTP requests and running downloads: {"stream", "request", "header_sent", "data", "offset"}.
var _http_connections: Array[Dictionary] = []
## Connected players: {"id", "socket", "partner"}; partner is another player's id or -1.
var _players: Array[Dictionary] = []
var _next_player_id: int = 1


func start(root_path: String, port: int = 8060) -> Error:
	web_root = root_path.simplify_path()
	http_port = port
	websocket_port = port + 1
	var error := _http_server.listen(http_port)
	if error != OK:
		return error
	return _websocket_server.listen(websocket_port)


func stop() -> void:
	for player: Dictionary in _players:
		(player["socket"] as WebSocketPeer).close()
	_players.clear()
	_http_connections.clear()
	_http_server.stop()
	_websocket_server.stop()


func poll() -> void:
	_poll_http()
	_poll_websockets()


func waiting_player_count() -> int:
	return _players.filter(func(player: Dictionary) -> bool: return int(player["partner"]) < 0).size()


## Private IPv4 addresses phones in the same Wi-Fi can reach.
static func local_addresses() -> PackedStringArray:
	var result: PackedStringArray = []
	for address: String in IP.get_local_addresses():
		if address.begins_with("192.168.") or address.begins_with("10.") or _is_private_172(address):
			result.append(address)
	return result


static func _is_private_172(address: String) -> bool:
	if not address.begins_with("172."):
		return false
	var second := address.get_slice(".", 1).to_int()
	return second >= 16 and second <= 31


func _poll_http() -> void:
	while _http_server.is_connection_available():
		_http_connections.append({"stream": _http_server.take_connection(), "request": "", "header_sent": false})
	for connection: Dictionary in _http_connections.duplicate():
		var stream := connection["stream"] as StreamPeerTCP
		stream.poll()
		if stream.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_close_http(connection)
			continue
		if not connection["header_sent"]:
			_read_http_request(connection)
		else:
			_send_file_chunk(connection)


func _read_http_request(connection: Dictionary) -> void:
	var stream := connection["stream"] as StreamPeerTCP
	var available := stream.get_available_bytes()
	if available > 0:
		connection["request"] = str(connection["request"]) + stream.get_utf8_string(available)
	var request := str(connection["request"])
	if not request.contains("\r\n\r\n"):
		if request.length() > 16384:
			_respond_status(connection, 400, "Bad Request")
		return
	var request_line := request.get_slice("\r\n", 0).split(" ")
	if request_line.size() < 2 or request_line[0] not in ["GET", "HEAD"]:
		_respond_status(connection, 405, "Method Not Allowed")
		return
	var path := request_line[1].get_slice("?", 0).uri_decode().trim_prefix("/")
	if path.is_empty():
		path = "index.html"
	var file_path := web_root.path_join(path).simplify_path()
	if not file_path.begins_with(web_root) or not FileAccess.file_exists(file_path):
		_respond_status(connection, 404, "Not Found")
		return
	var data := FileAccess.get_file_as_bytes(file_path)
	if file_path.get_file() == "index.html":
		data = allow_plain_http(data.get_string_from_utf8()).to_utf8_buffer()
	var header := "HTTP/1.1 200 OK\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: no-cache\r\nConnection: close\r\n\r\n" % [
		MIME_TYPES.get(file_path.get_extension().to_lower(), "application/octet-stream"),
		data.size(),
	]
	stream.put_data(header.to_utf8_buffer())
	connection["header_sent"] = true
	if request_line[0] == "HEAD":
		_close_http(connection)
		return
	connection["data"] = data
	connection["offset"] = 0


## Godot's page refuses to start outside HTTPS ("Secure Context"), and phones
## in a home network cannot get a trusted certificate for the PC. Over plain
## HTTP the single-threaded build runs, except for AudioWorklet, so the host
## drops that one check and starts the engine with the dummy audio driver.
static func allow_plain_http(page: String) -> String:
	return page.replace("\"args\":[]", "\"args\":[\"--audio-driver\",\"Dummy\"]").replace(
		"const missing = Engine.getMissingFeatures(",
		"const lanFeatureCheck = Engine.getMissingFeatures;\n\tEngine.getMissingFeatures = (options) => lanFeatureCheck(options).filter((feature) => !feature.startsWith('Secure Context'));\n\tconst missing = Engine.getMissingFeatures("
	)


func _send_file_chunk(connection: Dictionary) -> void:
	var data := connection.get("data", PackedByteArray()) as PackedByteArray
	var stream := connection["stream"] as StreamPeerTCP
	# Queue a few chunks per frame; put_partial_data reports what the socket accepted.
	for _round: int in range(8):
		var offset := int(connection["offset"])
		if offset >= data.size():
			_close_http(connection)
			return
		var chunk := data.slice(offset, mini(offset + CHUNK_SIZE, data.size()))
		var result: Array = stream.put_partial_data(chunk)
		if int(result[0]) != OK:
			_close_http(connection)
			return
		var sent := int(result[1])
		connection["offset"] = offset + sent
		if sent < chunk.size():
			return


func _respond_status(connection: Dictionary, code: int, reason: String) -> void:
	var body := "%d %s" % [code, reason]
	var response := "HTTP/1.1 %d %s\r\nContent-Type: text/plain\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [code, reason, body.length(), body]
	(connection["stream"] as StreamPeerTCP).put_data(response.to_utf8_buffer())
	_close_http(connection)


func _close_http(connection: Dictionary) -> void:
	(connection["stream"] as StreamPeerTCP).disconnect_from_host()
	_http_connections.erase(connection)


func _poll_websockets() -> void:
	while _websocket_server.is_connection_available():
		var socket := WebSocketPeer.new()
		socket.accept_stream(_websocket_server.take_connection())
		_players.append({"id": _next_player_id, "socket": socket, "partner": -1})
		_next_player_id += 1
	for player: Dictionary in _players.duplicate():
		var socket := player["socket"] as WebSocketPeer
		socket.poll()
		match socket.get_ready_state():
			WebSocketPeer.STATE_OPEN:
				while socket.get_available_packet_count() > 0:
					_on_player_message(player, socket.get_packet().get_string_from_utf8())
			WebSocketPeer.STATE_CLOSED:
				_remove_player(player)
	_pair_waiting_players()


func _on_player_message(player: Dictionary, text: String) -> void:
	var message: Variant = JSON.parse_string(text)
	if not message is Dictionary:
		return
	if str(message.get("type", "")) in ["move", "pass"]:
		var partner := _find_player(int(player["partner"]))
		if not partner.is_empty():
			_send(partner, message)


func _pair_waiting_players() -> void:
	var waiting: Array[Dictionary] = []
	for player: Dictionary in _players:
		if int(player["partner"]) < 0 and (player["socket"] as WebSocketPeer).get_ready_state() == WebSocketPeer.STATE_OPEN:
			waiting.append(player)
	while waiting.size() >= 2:
		var first: Dictionary = waiting.pop_front()
		var second: Dictionary = waiting.pop_front()
		first["partner"] = second["id"]
		second["partner"] = first["id"]
		var card_names: Array[String] = []
		for card: MovementCard in MovementCardScript.draw_match_cards(5):
			card_names.append(card.card_name)
		_send(first, {"type": "start", "team": 0, "cards": card_names})
		_send(second, {"type": "start", "team": 1, "cards": card_names})
		match_count += 1


func _remove_player(player: Dictionary) -> void:
	_players.erase(player)
	var partner := _find_player(int(player["partner"]))
	if not partner.is_empty():
		_send(partner, {"type": "opponent_left"})
		# The partner's match is over; it returns to the menu to play again.
		partner["partner"] = 0


func _find_player(id: int) -> Dictionary:
	for player: Dictionary in _players:
		if int(player["id"]) == id:
			return player
	return {}


func _send(player: Dictionary, message: Dictionary) -> void:
	(player["socket"] as WebSocketPeer).send_text(JSON.stringify(message))
