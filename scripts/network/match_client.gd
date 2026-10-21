class_name MatchClient
extends Node

## Connects a match to another device, either through the PC host in the same
## Wi-Fi or through the online server, and exchanges moves with it. Both
## servers speak the same protocol: /play?mode=quick | create | join&code=1234.

signal connected
signal room_created(code: String)
signal match_started(team: int, card_names: Array)
signal opponent_moved(message: Dictionary)
signal opponent_left
signal rejected(reason: String)
signal connection_lost

## Online relay deployed from server/online (Cloudflare Worker).
const ONLINE_SERVER_URL: String = "wss://infinity-grid.infinitygrid.workers.dev"
const LAN_WEBSOCKET_PORT: int = 8061

var _socket := WebSocketPeer.new()
var _was_open: bool = false
var _closed: bool = true


## Address of the PC host. In the browser it is the PC that served this page;
## desktop test runs use INFINITY_GRID_HOST or localhost.
static func lan_url() -> String:
	var host := "127.0.0.1"
	var port := LAN_WEBSOCKET_PORT
	if OS.has_feature("web"):
		host = str(JavaScriptBridge.eval("window.location.hostname"))
		var page_port := str(JavaScriptBridge.eval("window.location.port")).to_int()
		if page_port > 0:
			port = page_port + 1
	elif not OS.get_environment("INFINITY_GRID_HOST").is_empty():
		host = OS.get_environment("INFINITY_GRID_HOST")
	return "ws://%s:%d/play?mode=quick" % [host, port]


## A page served over HTTPS (GitHub Pages) may not open plain ws:// connections,
## and there is no PC host there anyway.
static func is_lan_available() -> bool:
	if not OS.has_feature("web"):
		return true
	return str(JavaScriptBridge.eval("window.location.protocol")) == "http:"


## INFINITY_GRID_ONLINE overrides the address on desktop, e.g. to test against
## the PC host (ws://127.0.0.1:8061), which speaks the same protocol.
static func online_server_url() -> String:
	var override := OS.get_environment("INFINITY_GRID_ONLINE")
	return override if not override.is_empty() else ONLINE_SERVER_URL


static func is_online_available() -> bool:
	return not online_server_url().is_empty()


static func online_create_url() -> String:
	return online_server_url() + "/play?mode=create"


static func online_join_url(code: String) -> String:
	return online_server_url() + "/play?mode=join&code=" + code.uri_encode()


func connect_to_host(url: String) -> Error:
	_was_open = false
	_closed = false
	_socket = WebSocketPeer.new()
	return _socket.connect_to_url(url)


func disconnect_from_host() -> void:
	_closed = true
	_socket.close()


func send_move(from: Vector2i, slot: int, to: Vector2i) -> void:
	_send({"type": "move", "from": [from.x, from.y], "slot": slot, "to": [to.x, to.y]})


func send_pass(slot: int) -> void:
	_send({"type": "pass", "slot": slot})


func _process(_delta: float) -> void:
	if _closed:
		return
	_socket.poll()
	match _socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _was_open:
				_was_open = true
				connected.emit()
			while _socket.get_available_packet_count() > 0:
				_handle_message(_socket.get_packet().get_string_from_utf8())
		WebSocketPeer.STATE_CLOSED:
			# Messages sent right before the close (an error reason) are still queued.
			while _socket.get_available_packet_count() > 0:
				_handle_message(_socket.get_packet().get_string_from_utf8())
			_closed = true
			connection_lost.emit()


func _handle_message(text: String) -> void:
	var message: Variant = JSON.parse_string(text)
	if not message is Dictionary:
		return
	match str(message.get("type", "")):
		"room":
			room_created.emit(str(message.get("code", "")))
		"start":
			match_started.emit(int(message["team"]), message["cards"] as Array)
		"move", "pass":
			opponent_moved.emit(message)
		"opponent_left":
			disconnect_from_host()
			opponent_left.emit()
		"error":
			# The server leaves closing to us so the reason arrives intact.
			disconnect_from_host()
			rejected.emit(str(message.get("reason", "")))


func _send(message: Dictionary) -> void:
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.send_text(JSON.stringify(message))
