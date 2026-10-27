class_name GroupClient
extends Node

## Connection to a room for two to four players (server/online/group_room.js).
## The server only relays: it deals the same cards and seed to everybody and
## numbers the turns; every client plays the rules itself (FfaBattle).

signal joined(info: Dictionary)
signal lobby_changed(info: Dictionary)
signal started(info: Dictionary)
signal resumed(info: Dictionary)
signal watch_started(info: Dictionary)
signal turn_received(turn: Dictionary)
signal seat_away(seat: int, seconds: int)
signal seat_back(seat: int)
## A player is gone for good; a bot takes the seat.
signal seat_left(seat: int)
signal host_changed(seat: int)
signal emote_received(seat: int, emote_id: String)
## Node Ping: {picks, signal, winner}; winner -1 is a collision (tap again).
signal ping_result(result: Dictionary)
signal starter_chosen(seat: int)
signal match_ended
signal rejected(reason: String)
signal connection_lost
signal reconnecting

const PING_INTERVAL_SECONDS: float = 15.0
const PONG_TIMEOUT_SECONDS: float = 8.0
const RECONNECT_GIVE_UP_SECONDS: float = 75.0
const RECONNECT_INTERVAL_SECONDS: float = 2.0
const SESSION_PATH := "user://group_session.cfg"
const SESSION_MAX_AGE_SECONDS: int = 30 * 60
## A newly created room asks again if the random code happens to be taken.
const CREATE_RETRIES: int = 3

var seat: int = -1
var code: String = ""
var watch_key: String = ""
var is_host: bool = false
var is_watcher: bool = false

var _socket := WebSocketPeer.new()
var _open: bool = false
var _closed: bool = true
var _ping_wait: float = PING_INTERVAL_SECONDS
var _pong_wait: float = -1.0
var _create_url: String = ""
var _retries_left: int = CREATE_RETRIES
var _session: Dictionary = {}
var _reconnect_time_left: float = -1.0
var _reconnect_wait: float = 0.0


static func is_group_code(text: String) -> bool:
	return text.length() == 5 and text.is_valid_int()


static func saved_session() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(SESSION_PATH) != OK:
		return {}
	var saved_at := int(config.get_value("room", "saved_at", 0))
	if Time.get_unix_time_from_system() - saved_at > SESSION_MAX_AGE_SECONDS:
		clear_saved_session()
		return {}
	return {
		"base": str(config.get_value("room", "base", "")),
		"code": str(config.get_value("room", "code", "")),
		"token": str(config.get_value("room", "token", "")),
		"seat": int(config.get_value("room", "seat", -1)),
	}


static func clear_saved_session() -> void:
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))


static func _resume_url(session: Dictionary) -> String:
	return "%s/play?mode=group_resume&code=%s&token=%s" % [
		session["base"], str(session["code"]).uri_encode(), str(session["token"]).uri_encode(),
	]


## settings: {"tiles": bool, "effects": bool}; max_players: 2 to 4.
func create_room(max_players: int, settings: Dictionary, name: String, avatar: String) -> Error:
	is_watcher = false
	forget_session()
	_create_url = "%s/play?mode=group_create&max=%d&tiles=%d&effects=%d&name=%s&avatar=%s" % [
		MatchClient.online_server_url(), max_players,
		1 if bool(settings.get("tiles", false)) else 0, 1 if bool(settings.get("effects", false)) else 0,
		name.uri_encode(), avatar.uri_encode(),
	]
	_retries_left = CREATE_RETRIES
	return _connect(_create_url)


func join_room(room_code: String, name: String, avatar: String) -> Error:
	is_watcher = false
	forget_session()
	_create_url = ""
	return _connect("%s/play?mode=group_join&code=%s&name=%s&avatar=%s" % [MatchClient.online_server_url(), room_code.uri_encode(), name.uri_encode(), avatar.uri_encode()])


func resume_session(session: Dictionary) -> Error:
	is_watcher = false
	if not session.has("base") or not session.has("code") or not session.has("token"):
		return ERR_INVALID_PARAMETER
	_session = session.duplicate()
	return _connect(_resume_url(_session))


func watch_room(room_code: String, key: String) -> Error:
	is_watcher = true
	_session.clear()
	return _connect("%s/play?mode=group_watch&code=%s&key=%s" % [
		MatchClient.online_server_url(), room_code.uri_encode(), key.uri_encode(),
	])


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
	_touch_session()


func send_node_ping(spot: Vector2) -> void:
	_send({"type": "node_ping", "spot": [spot.x, spot.y]})


## The closest seat names who starts.
func send_choose(starter_seat: int) -> void:
	_send({"type": "choose", "starter": starter_seat})


func send_emote(emote_id: String) -> void:
	_send({"type": "emote", "id": emote_id})


## Tells the room we are gone for good, then hangs up.
func leave() -> void:
	if not is_watcher:
		_send({"type": "leave"})
	forget_session()
	if not _closed:
		_socket.poll()
	disconnect_from_host()


func finish_match() -> void:
	if not is_watcher:
		_send({"type": "finish"})
	forget_session()


func disconnect_from_host() -> void:
	_closed = true
	_open = false
	_reconnect_time_left = -1.0
	_socket.close()


func forget_session() -> void:
	_session.clear()
	clear_saved_session()


func is_connected_to_room() -> bool:
	return _open and not _closed


func _connect(url: String) -> Error:
	if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_socket.close()
	_socket = WebSocketPeer.new()
	_open = false
	_closed = false
	_ping_wait = PING_INTERVAL_SECONDS
	_pong_wait = -1.0
	return _socket.connect_to_url(url)


func _process(delta: float) -> void:
	if _closed:
		_tick_reconnect(delta)
		if _closed:
			return
	_socket.poll()
	match _socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			_open = true
			while _socket.get_available_packet_count() > 0:
				_handle(_socket.get_packet().get_string_from_utf8())
			_tick_heartbeat(delta)
		WebSocketPeer.STATE_CLOSED:
			# An error reason sent right before the close is still queued.
			while _socket.get_available_packet_count() > 0:
				_handle(_socket.get_packet().get_string_from_utf8())
			if not _closed:
				_on_socket_lost()


func _tick_heartbeat(delta: float) -> void:
	if _session.is_empty() and not is_watcher:
		return
	if _pong_wait >= 0.0:
		_pong_wait -= delta
		if _pong_wait < 0.0:
			_socket.close()
			_on_socket_lost()
		return
	_ping_wait -= delta
	if _ping_wait <= 0.0:
		_ping_wait = PING_INTERVAL_SECONDS
		_pong_wait = PONG_TIMEOUT_SECONDS
		_socket.send_text("ping")


func _on_socket_lost() -> void:
	_closed = true
	_open = false
	if _session.has("token"):
		if _reconnect_time_left < 0.0:
			_reconnect_time_left = RECONNECT_GIVE_UP_SECONDS
			_reconnect_wait = 0.0
			reconnecting.emit()
		return
	connection_lost.emit()


func _tick_reconnect(delta: float) -> void:
	if _reconnect_time_left < 0.0:
		return
	_reconnect_time_left -= delta
	if _reconnect_time_left < 0.0:
		_closed = true
		connection_lost.emit()
		return
	if not _closed:
		return
	_reconnect_wait -= delta
	if _reconnect_wait <= 0.0:
		_reconnect_wait = RECONNECT_INTERVAL_SECONDS
		_connect(_resume_url(_session))


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
			watch_key = str(message.get("watch_key", ""))
			is_host = bool(message.get("host", false))
			joined.emit(message)
		"lobby":
			lobby_changed.emit(message)
		"group_start":
			seat = int(message["seat"])
			watch_key = str(message.get("watch_key", ""))
			is_host = bool(message.get("host", false))
			_remember(message)
			started.emit(message)
		"group_resume":
			seat = int(message["seat"])
			code = str(message["code"])
			watch_key = str(message.get("watch_key", ""))
			is_host = bool(message.get("host", false))
			_remember(message)
			_reconnect_time_left = -1.0
			var info: Dictionary = message.duplicate()
			var history: Array = []
			for turn: Variant in message.get("moves", []):
				if turn is Dictionary:
					history.append(_cells_to_vectors(turn))
			info["moves"] = history
			resumed.emit(info)
		"watch_start":
			seat = -1
			is_host = false
			is_watcher = true
			code = str(message.get("code", ""))
			var info: Dictionary = message.duplicate()
			var history: Array = []
			for turn: Variant in message.get("moves", []):
				if turn is Dictionary:
					history.append(_cells_to_vectors(turn))
			info["moves"] = history
			watch_started.emit(info)
		"move", "pass", "effect":
			_touch_session()
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
		"ping_result":
			ping_result.emit(message)
		"starter":
			starter_chosen.emit(int(message["seat"]))
		"match_ended":
			match_ended.emit()
		"emote":
			emote_received.emit(int(message["seat"]), str(message.get("id", "")))
		"error":
			var reason := str(message.get("reason", ""))
			if reason == "code_taken" and not _create_url.is_empty() and _retries_left > 0:
				_retries_left -= 1
				_connect(_create_url)
				return
			if reason == "not_found" and not _session.is_empty():
				forget_session()
			disconnect_from_host()
			rejected.emit(reason)


func _remember(message: Dictionary) -> void:
	if not message.has("token"):
		return
	var base := str(_session.get("base", MatchClient.online_server_url()))
	_session = {
		"base": base,
		"code": str(message["code"]),
		"token": str(message["token"]),
		"seat": int(message["seat"]),
	}
	var config := ConfigFile.new()
	_save_session(config)


func _touch_session() -> void:
	if _session.is_empty():
		return
	var config := ConfigFile.new()
	_save_session(config)


func _save_session(config: ConfigFile) -> void:
	for key: String in _session:
		config.set_value("room", key, _session[key])
	config.set_value("room", "saved_at", int(Time.get_unix_time_from_system()))
	var error := config.save(SESSION_PATH)
	if error != OK:
		push_error("Could not save the Finite Grid session: %s" % error_string(error))


## JSON has no cells: [x, y] arrays become Vector2i.
static func _cells_to_vectors(message: Dictionary) -> Dictionary:
	var turn := message.duplicate()
	for key: String in ["from", "to"]:
		if turn.has(key):
			var pair: Array = turn[key]
			turn[key] = Vector2i(int(pair[0]), int(pair[1]))
	return turn


func _send(message: Dictionary) -> void:
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN and not is_watcher:
		_socket.send_text(JSON.stringify(message))
