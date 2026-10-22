class_name MatchClient
extends Node

## Connects a match to another device, either through the PC host in the same
## Wi-Fi or through the online server, and exchanges moves with it. Both
## servers speak the same basic protocol (see server/online/worker.js); online
## matches can also be resumed after the connection drops.

signal connected
signal queued
signal room_created(code: String)
signal match_started(team: int, card_names: Array)
## A dropped online match came back; moves holds every turn played so far.
signal resumed(team: int, card_names: Array, moves: Array)
signal opponent_moved(message: Dictionary)
signal opponent_away(seconds: int)
signal opponent_back
signal opponent_left
signal rejected(reason: String)
## The connection dropped and the client is trying to get back in.
signal reconnecting
signal connection_lost

## Online relay deployed from server/online (Cloudflare Worker).
const ONLINE_SERVER_URL: String = "wss://infinity-grid.infinitygrid.workers.dev"
const LAN_WEBSOCKET_PORT: int = 8061
const SESSION_PATH := "user://online_session.cfg"
## A saved match is offered for resuming only this long; the server keeps an
## abandoned seat for 60 s, but a page reload may take a while on phones.
const SESSION_MAX_AGE_SECONDS: int = 10 * 60
const RECONNECT_GIVE_UP_SECONDS: float = 75.0
const RECONNECT_INTERVAL_SECONDS: float = 2.0
const PING_INTERVAL_SECONDS: float = 15.0
const PONG_TIMEOUT_SECONDS: float = 8.0

var _socket := WebSocketPeer.new()
var _was_open: bool = false
var _closed: bool = true
## Online match identity, needed to resume: {"base", "code", "token", "team"}.
var _session: Dictionary = {}
## Moves sent while the connection was down; resent after resuming.
var _outbox: Array[Dictionary] = []
var _reconnect_time_left: float = -1.0
var _reconnect_wait: float = 0.0
var _ping_wait: float = PING_INTERVAL_SECONDS
var _pong_wait: float = -1.0
var _quick_base: String = ""


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
## a local "wrangler dev" (ws://127.0.0.1:8787).
static func online_server_url() -> String:
	var override := OS.get_environment("INFINITY_GRID_ONLINE")
	return override if not override.is_empty() else ONLINE_SERVER_URL


static func is_online_available() -> bool:
	return not online_server_url().is_empty()


static func online_create_url() -> String:
	return online_server_url() + "/play?mode=create"


static func online_join_url(code: String) -> String:
	return online_server_url() + "/play?mode=join&code=" + code.uri_encode()


static func online_quick_url() -> String:
	return online_server_url() + "/play?mode=quick"


## The last online match if it may still be running, else {}.
static func saved_session() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(SESSION_PATH) != OK:
		return {}
	var saved_at := int(config.get_value("match", "saved_at", 0))
	if Time.get_unix_time_from_system() - saved_at > SESSION_MAX_AGE_SECONDS:
		return {}
	return {
		"base": str(config.get_value("match", "base", "")),
		"code": str(config.get_value("match", "code", "")),
		"token": str(config.get_value("match", "token", "")),
		"team": int(config.get_value("match", "team", 0)),
	}


static func clear_saved_session() -> void:
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))


static func _resume_url(session: Dictionary) -> String:
	return "%s/play?mode=resume&code=%s&token=%s" % [session["base"], str(session["code"]).uri_encode(), str(session["token"]).uri_encode()]


func connect_to_host(url: String) -> Error:
	_quick_base = url.get_slice("/play", 0) if url.contains("mode=quick") else ""
	return _open(url)


## Rejoins a saved match, e.g. after the page was reloaded.
func resume_session(session: Dictionary) -> Error:
	_session = session.duplicate()
	return _open(_resume_url(_session))


## Ends the match for good: the opponent is told and nothing is resumed.
func leave() -> void:
	_send_now({"type": "leave"})
	_session.clear()
	clear_saved_session()
	disconnect_from_host()


## The match ended normally; there is nothing left to resume.
func forget_session() -> void:
	_session.clear()
	clear_saved_session()


func disconnect_from_host() -> void:
	_closed = true
	_reconnect_time_left = -1.0
	_socket.close()


func send_move(seq: int, from: Vector2i, slot: int, to: Vector2i) -> void:
	_send_turn({"type": "move", "seq": seq, "from": [from.x, from.y], "slot": slot, "to": [to.x, to.y]})


func send_pass(seq: int, slot: int) -> void:
	_send_turn({"type": "pass", "seq": seq, "slot": slot})


func is_reconnecting() -> bool:
	return _reconnect_time_left >= 0.0


func _open(url: String) -> Error:
	if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_socket.close()
	_was_open = false
	_closed = false
	_pong_wait = -1.0
	_ping_wait = PING_INTERVAL_SECONDS
	_socket = WebSocketPeer.new()
	return _socket.connect_to_url(url)


func _process(delta: float) -> void:
	if _reconnect_time_left >= 0.0:
		_tick_reconnect(delta)
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
			_tick_heartbeat(delta)
		WebSocketPeer.STATE_CLOSED:
			# Messages sent right before the close (an error reason) are still queued.
			while _socket.get_available_packet_count() > 0:
				_handle_message(_socket.get_packet().get_string_from_utf8())
			if not _closed:
				_on_socket_lost()


## Phones silently drop sockets when the app goes to the background, so the
## client pings and treats a missing answer as a lost connection.
func _tick_heartbeat(delta: float) -> void:
	if _session.is_empty():
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
	if _session.has("token"):
		if _reconnect_time_left < 0.0:
			_reconnect_time_left = RECONNECT_GIVE_UP_SECONDS
			_reconnect_wait = 0.0
			reconnecting.emit()
		return
	connection_lost.emit()


func _tick_reconnect(delta: float) -> void:
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
		_open(_resume_url(_session))


func _handle_message(text: String) -> void:
	if text == "pong":
		_pong_wait = -1.0
		return
	var message: Variant = JSON.parse_string(text)
	if not message is Dictionary:
		return
	match str(message.get("type", "")):
		"queued":
			queued.emit()
		"matched":
			# The lobby found an opponent; the match itself runs in its own room.
			_open("%s/play?mode=match&code=%s&team=%d" % [_quick_base, str(message["code"]), int(message["team"])])
		"room":
			room_created.emit(str(message.get("code", "")))
		"start":
			_remember(message)
			match_started.emit(int(message["team"]), message["cards"] as Array)
		"resume":
			_remember(message)
			_reconnect_time_left = -1.0
			resumed.emit(int(message["team"]), message["cards"] as Array, message.get("moves", []) as Array)
			_flush_outbox()
		"move", "pass":
			opponent_moved.emit(message)
		"opponent_away":
			opponent_away.emit(int(message.get("seconds", 60)))
		"opponent_back":
			opponent_back.emit()
		"opponent_left":
			forget_session()
			disconnect_from_host()
			opponent_left.emit()
		"error":
			var reason := str(message.get("reason", ""))
			if reason == "match_failed" and not _quick_base.is_empty():
				# The paired player never showed up; queue again.
				_open(_quick_base + "/play?mode=quick")
				return
			if reason == "not_found" and _session.has("token"):
				# Resuming failed: the match ended while we were away.
				reason = "match_over"
				forget_session()
			# The server leaves closing to us so the reason arrives intact.
			disconnect_from_host()
			rejected.emit(reason)


## Only online starts carry a token; the PC host has no resume support.
func _remember(message: Dictionary) -> void:
	if not message.has("token"):
		return
	var base := online_server_url() if _session.is_empty() else str(_session["base"])
	if not _quick_base.is_empty():
		base = _quick_base
	_session = {"base": base, "code": str(message["code"]), "token": str(message["token"]), "team": int(message["team"])}
	var config := ConfigFile.new()
	for key: String in _session:
		config.set_value("match", key, _session[key])
	config.set_value("match", "saved_at", int(Time.get_unix_time_from_system()))
	config.save(SESSION_PATH)


func _send_turn(message: Dictionary) -> void:
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN and not is_reconnecting():
		_send_now(message)
	else:
		_outbox.append(message)
	# Keep the saved session fresh while the match goes on.
	if not _session.is_empty():
		var config := ConfigFile.new()
		if config.load(SESSION_PATH) == OK:
			config.set_value("match", "saved_at", int(Time.get_unix_time_from_system()))
			config.save(SESSION_PATH)


func _flush_outbox() -> void:
	# The server drops turns it already has, so resending is always safe.
	for message: Dictionary in _outbox:
		_send_now(message)
	_outbox.clear()


func _send_now(message: Dictionary) -> void:
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.send_text(JSON.stringify(message))
