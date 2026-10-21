class_name LanClient
extends Node

## Browser side of a Wi-Fi match: connects to the PC that served the page and
## exchanges moves with the paired phone through it.

signal connected
signal match_started(team: int, card_names: Array)
signal opponent_moved(message: Dictionary)
signal opponent_left
signal connection_lost

const DEFAULT_PORT: int = 8061

var _socket := WebSocketPeer.new()
var _was_open: bool = false
var _closed: bool = true


## WebSocket address of the host. In the browser it is the PC that served this
## page; desktop test runs use INFINITY_GRID_HOST or localhost.
static func host_url() -> String:
	var host := "127.0.0.1"
	var port := DEFAULT_PORT
	if OS.has_feature("web"):
		host = str(JavaScriptBridge.eval("window.location.hostname"))
		var page_port := str(JavaScriptBridge.eval("window.location.port")).to_int()
		if page_port > 0:
			port = page_port + 1
	elif not OS.get_environment("INFINITY_GRID_HOST").is_empty():
		host = OS.get_environment("INFINITY_GRID_HOST")
	return "ws://%s:%d" % [host, port]


## A page served over HTTPS (GitHub Pages) may not open plain ws:// connections,
## and there is no host there anyway.
static func is_available() -> bool:
	if not OS.has_feature("web"):
		return true
	return str(JavaScriptBridge.eval("window.location.protocol")) == "http:"


func connect_to_host(url: String = "") -> Error:
	_was_open = false
	_closed = false
	return _socket.connect_to_url(host_url() if url.is_empty() else url)


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
			_closed = true
			connection_lost.emit()


func _handle_message(text: String) -> void:
	var message: Variant = JSON.parse_string(text)
	if not message is Dictionary:
		return
	match str(message.get("type", "")):
		"start":
			match_started.emit(int(message["team"]), message["cards"] as Array)
		"move", "pass":
			opponent_moved.emit(message)
		"opponent_left":
			opponent_left.emit()


func _send(message: Dictionary) -> void:
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.send_text(JSON.stringify(message))
