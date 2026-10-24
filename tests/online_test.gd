extends SceneTree

## Online server checks: quick match, room codes, turn order, reconnect.
## Needs a running server, normally the local one:
##   cd server/online && npx wrangler dev --port 8787
##   set INFINITY_GRID_ONLINE=ws://127.0.0.1:8787
##   godot --headless --path . --script res://tests/online_test.gd

const MatchClientScript := preload("res://scripts/network/match_client.gd")

var failures: Array[String] = []
var events: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	if OS.get_environment("INFINITY_GRID_ONLINE").is_empty():
		push_error("Set INFINITY_GRID_ONLINE to the server to test, e.g. ws://127.0.0.1:8787")
		quit(1)
		return
	await _test_quick_match_and_reconnect()
	await _test_room_codes_and_leave()
	if failures.is_empty():
		print("TEST RESULT: PASS (all online assertions succeeded)")
	else:
		for failure: String in failures:
			push_error(failure)
		print("TEST RESULT: FAIL (%d failures)" % failures.size())
	quit(0 if failures.is_empty() else 1)


func _test_quick_match_and_reconnect() -> void:
	var a := _client("a")
	var b := _client("b")
	a.connect_to_host(MatchClient.online_quick_url())
	await _wait_until(func() -> bool: return _count("a", "queued") == 1)
	_expect(_count("a", "queued") == 1, "Quick play waits in the queue")
	b.connect_to_host(MatchClient.online_quick_url())
	await _wait_until(func() -> bool: return _count("a", "start") == 1 and _count("b", "start") == 1)
	_expect(_count("a", "start") == 1 and _count("b", "start") == 1, "Two quick-play players are paired")
	var teams := [_last("a", "start")[0], _last("b", "start")[0]]
	teams.sort()
	_expect(teams == [0, 1] and _last("a", "start")[1] == _last("b", "start")[1], "Paired players get opposite teams and the same cards")
	var first: MatchClient = a if int(_last("a", "start")[0]) == 0 else b
	var second: MatchClient = b if first == a else a
	_expect(await _settle_ping(first, second, "a" if first == a else "b", "b" if first == a else "a"), "Node Ping decides the starter before any move")
	var second_name := "b" if first == a else "a"
	var first_name := "a" if first == a else "b"

	second.send_move(0, Vector2i(0, 0), 0, Vector2i(0, 1))
	first.send_move(0, Vector2i(1, 4), 0, Vector2i(1, 3))
	await _wait_until(func() -> bool: return _count(second_name, "move") == 1)
	await _wait_frames(1000)
	_expect(_count(second_name, "move") == 1 and _count(first_name, "move") == 0, "The server only accepts the side whose turn it is")

	# The second player loses the connection; the first one is told and waits.
	second._socket.close()
	await _wait_until(func() -> bool: return _count(first_name, "opponent_away") == 1)
	_expect(_count(first_name, "opponent_away") == 1, "The opponent hears about a dropped connection")
	await _wait_until(func() -> bool: return _count(second_name, "reconnecting") >= 1)
	_expect(_count(second_name, "reconnecting") >= 1, "The dropped client starts reconnecting by itself")
	# A move made while the connection is down is sent after resuming.
	second.send_move(1, Vector2i(0, 0), 1, Vector2i(0, 1))
	await _wait_until(func() -> bool: return _count(second_name, "resume") == 1, 30000)
	_expect(_count(second_name, "resume") == 1, "The client gets back into its match")
	var moves: Array = _last(second_name, "resume")[2]
	_expect(moves.size() == 1 and int(moves[0]["seq"]) == 0, "Resuming delivers the turns played so far")
	await _wait_until(func() -> bool: return _count(first_name, "opponent_back") == 1 and _count(first_name, "move") == 1)
	_expect(_count(first_name, "opponent_back") == 1, "The opponent hears that the player is back")
	_expect(_count(first_name, "move") == 1 and int(_last(first_name, "move")[0]["seq"]) == 1, "A move made while offline arrives after the reconnect")

	# A page reload: a brand-new client resumes from the saved session.
	var saved := MatchClient.saved_session()
	_expect(not saved.is_empty() and saved["code"].length() == 12, "The match is saved for a page reload")
	var second_session := second._session.duplicate()
	second.disconnect_from_host()
	var reloaded := _client("r")
	reloaded.resume_session(second_session)
	await _wait_until(func() -> bool: return _count("r", "resume") == 1)
	_expect(_count("r", "resume") == 1 and (_last("r", "resume")[2] as Array).size() == 2, "A reloaded page resumes with the full history")
	reloaded.leave()
	first.leave()
	await _wait_frames(1000)


func _test_room_codes_and_leave() -> void:
	var host := _client("h")
	var guest := _client("g")
	host.connect_to_host(MatchClient.online_create_url())
	await _wait_until(func() -> bool: return _count("h", "room") == 1)
	var code := str(_last("h", "room")[0])
	_expect(code.length() == 4, "Creating a game hands out a four-digit code")
	guest.connect_to_host(MatchClient.online_join_url(code))
	await _wait_until(func() -> bool: return _count("h", "start") == 1 and _count("g", "start") == 1)
	_expect(int(_last("h", "start")[0]) == 0 and int(_last("g", "start")[0]) == 1, "The room creator plays first")
	var intruder := _client("i")
	intruder.connect_to_host(MatchClient.online_join_url(code))
	await _wait_until(func() -> bool: return _count("i", "rejected") == 1)
	_expect(_count("i", "rejected") == 1 and _last("i", "rejected")[0] == "full", "A third player cannot join a running room")
	var guest_session := guest._session.duplicate()
	guest.leave()
	await _wait_until(func() -> bool: return _count("h", "opponent_left") == 1)
	_expect(_count("h", "opponent_left") == 1, "Leaving tells the opponent right away")
	var late := _client("l")
	late.resume_session(guest_session)
	await _wait_until(func() -> bool: return _count("l", "rejected") == 1)
	_expect(_count("l", "rejected") == 1 and _last("l", "rejected")[0] == "match_over", "A finished match cannot be resumed")


func _client(name: String) -> MatchClient:
	var client: MatchClient = MatchClientScript.new()
	root.add_child(client)
	events[name] = []
	client.queued.connect(func() -> void: _log(name, "queued", []))
	client.room_created.connect(func(code: String) -> void: _log(name, "room", [code]))
	client.match_started.connect(func(team: int, cards: Array) -> void: _log(name, "start", [team, cards]))
	client.resumed.connect(func(team: int, cards: Array, moves: Array) -> void: _log(name, "resume", [team, cards, moves]))
	client.opponent_moved.connect(func(message: Dictionary) -> void: _log(name, "move", [message]))
	client.opponent_away.connect(func(seconds: int) -> void: _log(name, "opponent_away", [seconds]))
	client.opponent_back.connect(func() -> void: _log(name, "opponent_back", []))
	client.opponent_left.connect(func() -> void: _log(name, "opponent_left", []))
	client.rejected.connect(func(reason: String) -> void: _log(name, "rejected", [reason]))
	client.reconnecting.connect(func() -> void: _log(name, "reconnecting", []))
	client.connection_lost.connect(func() -> void: _log(name, "lost", []))
	client.ping_result.connect(func(result: Dictionary) -> void: _log(name, "ping_result", [result]))
	client.starter_chosen.connect(func(team: int) -> void: _log(name, "starter", [team]))
	return client


func _log(name: String, kind: String, values: Array) -> void:
	(events[name] as Array).append([kind, values])


## Plays Node Pings until one side wins, then lets team 0 start.
## team0/team1 are the clients by team, with their log names.
func _settle_ping(team0: MatchClient, team1: MatchClient, name0: String, name1: String) -> bool:
	for attempt: int in range(12):
		var before := _count(name0, "ping_result")
		team0.send_node_ping(Vector2(randf(), randf()))
		team1.send_node_ping(Vector2(randf(), randf()))
		await _wait_until(func() -> bool: return _count(name0, "ping_result") > before and _count(name1, "ping_result") > before)
		var winner := int((_last(name0, "ping_result")[0] as Dictionary).get("winner", -1))
		if winner < 0:
			continue
		(team0 if winner == 0 else team1).send_choose(0)
		await _wait_until(func() -> bool: return _count(name0, "starter") > 0 and _count(name1, "starter") > 0)
		return int(_last(name0, "starter")[0]) == 0 and int(_last(name1, "starter")[0]) == 0
	return false


func _count(name: String, kind: String) -> int:
	return (events[name] as Array).filter(func(entry: Array) -> bool: return entry[0] == kind).size()


func _last(name: String, kind: String) -> Array:
	var found: Array = []
	for entry: Array in events[name]:
		if entry[0] == kind:
			found = entry[1]
	return found


func _wait_until(condition: Callable, max_msec: int = 15000) -> void:
	var deadline := Time.get_ticks_msec() + max_msec
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return
		await process_frame


func _wait_frames(msec: int) -> void:
	var deadline := Time.get_ticks_msec() + msec
	while Time.get_ticks_msec() < deadline:
		await process_frame


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append("FAIL: %s" % description)
