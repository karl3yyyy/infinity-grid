class_name GroupClient
extends Node

## Connection to a room for two to four players (server/online/group_room.js).
## The server only relays: it deals the same cards and seed to everybody and
## numbers the turns; every client plays the rules itself (FfaBattle).

signal joined(info: Dictionary)
signal lobby_changed(info: Dictionary)
signal started(info: Dictionary)
signal turn_received(turn: Dictionary)
signal seat_away(seat: int, seconds: int)
signal seat_back(seat: int)
## A player is gone for good; a bot takes the seat.
signal seat_left(seat: int)
signal host_changed(seat: int)
signal emote_received(seat: int, emote_id: String)
signal rejected(reason: String)
signal connection_lost

const PING_INTERVAL_SECONDS: float = 15.0
## A newly created room asks again if the random code happens to be taken.
const CREATE_RETRIES: int = 3

var seat: int = -1
var code: String = ""
var is_host: bool = false

var _socket := WebSocketPeer.new()
var _open: bool = false
var _closed: bool = true
var _ping_wait: float = PING_INTERVAL_SECONDS
var _create_url: String = ""
var _retries_left: int = CREATE_RETRIES


static func is_group_code(text: String) -> bool:
	return text.length() == 5 and text.is_valid_int()


## settings: {"tiles": bool, "effects": bool}; max_players: 2 to 4.
func create_room(max_players: int, settings: Dictionary, name: String, avatar: String) -> Error:
	_create_url = "%s/play?mode=group_create&max=%d&tiles=%d&effects=%d&name=%s&avatar=%s" % [
		MatchClient.online_server_url(), max_players,
		1 if bool(settings.get("tiles", false)) else 0, 1 if bool(settings.get("effects", false)) else 0,
		name.uri_encode(), avatar.uri_encode(),
	]
	_retries_left = CREATE_RETRIES
	return _connect(_create_url)


func join_room(room_code: String, name: String, avatar: String) -> Error:
	_create_url = ""
	return _connect("%s/play?mode=group_join&code=%s&name=%s&avatar=%s" % [MatchClient.online_server_url(), room_code.uri_encode(), name.uri_encode(), avatar.uri_encode()])


## The host starts the match once at least two players are in.
func start_match() -> void:
	_send({"type": "start"})


## `turn` is {"type": "move"|"pass"|"effect", "seq", "seat", ...}; cells go out as [x, y].
func send_turn(turn: Dictionary) -> void:
	var message := turn.duplicate()
	for key: String in ["from", "to"]:
		if message.has(key):
			var cell: Vector2i = message[key]
			message[key] = [cell.x, cell.y]
	_send(message)


func send_emote(emote_id: String) -> void:
	_send({"type": "emote", "id": emote_id})


## Tells the room we are gone for good, then hangs up.
func leave() -> void:
	_send({"type": "leave"})
	if not _closed:
		_socket.poll()
	disconnect_from_host()


func disconnect_from_host() -> void:
	_closed = true
	_open = false
	_socket.close()


func is_connected_to_room() -> bool:
	return _open and not _closed


func _connect(url: String) -> Error:
	if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_socket.close()
	_socket = WebSocketPeer.new()
	_open = false
	_closed = false
	_ping_wait = PING_INTERVAL_SECONDS
	return _socket.connect_to_url(url)


func _process(delta: float) -> void:
	if _closed:
		return
	_socket.poll()
	match _socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			_open = true
			while _socket.get_available_packet_count() > 0:
				_handle(_socket.get_packet().get_string_from_utf8())
			_ping_wait -= delta
			if _ping_wait <= 0.0 and not _closed:
				_ping_wait = PING_INTERVAL_SECONDS
				_socket.send_text("ping")
		WebSocketPeer.STATE_CLOSED:
			# An error reason sent right before the close is still queued.
			while _socket.get_available_packet_count() > 0:
				_handle(_socket.get_packet().get_string_from_utf8())
			if not _closed:
				_closed = true
				_open = false
				connection_lost.emit()


func _handle(text: String) -> void:
	if text == "pong":
		return
	var message: Variant = JSON.parse_string(text)
	if not message is Dictionary:
		return
	match str(message.get("type", "")):
		"group":
			seat = int(message["seat"])
			code = str(message["code"])
			is_host = bool(message.get("host", false))
			joined.emit(message)
		"lobby":
			lobby_changed.emit(message)
		"group_start":
			seat = int(message["seat"])
			is_host = bool(message.get("host", false))
			started.emit(message)
		"move", "pass", "effect":
			turn_received.emit(_cells_to_vectors(message))
		"seat_away":
			seat_away.emit(int(message["seat"]), int(message.get("seconds", 60)))
		"seat_back":
			seat_back.emit(int(message["seat"]))
		"seat_left":
			seat_left.emit(int(message["seat"]))
		"host":
			if int(message["seat"]) == seat:
				is_host = true
			host_changed.emit(int(message["seat"]))
		"emote":
			emote_received.emit(int(message["seat"]), str(message.get("id", "")))
		"error":
			var reason := str(message.get("reason", ""))
			if reason == "code_taken" and not _create_url.is_empty() and _retries_left > 0:
				_retries_left -= 1
				_connect(_create_url)
				return
			disconnect_from_host()
			rejected.emit(reason)


## JSON has no cells: [x, y] arrays become Vector2i.
static func _cells_to_vectors(message: Dictionary) -> Dictionary:
	var turn := message.duplicate()
	for key: String in ["from", "to"]:
		if turn.has(key):
			var pair: Array = turn[key]
			turn[key] = Vector2i(int(pair[0]), int(pair[1]))
	return turn


func _send(message: Dictionary) -> void:
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.send_text(JSON.stringify(message))
