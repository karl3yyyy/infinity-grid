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
	await _test_ranked_clock()
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


## Ranked chess clock: starts with the starter, gains the increment per move,
## keeps running while the player to move reconnects, and a fallen flag is a
## rated loss. Needs RANKED_CLOCK_MS (e.g. 20000; reconnecting takes a few seconds) in server/online/.dev.vars.
func _test_ranked_clock() -> void:
	var tickets: Array[String] = []
	for index: int in range(2):
		tickets.append(await _ranked_ticket("clk%d%d" % [index, Time.get_ticks_msec() % 100000]))
	if "" in tickets:
		_expect(false, "Two signed-in players get ranked tickets")
		return
	var a := _client("ra")
	var b := _client("rb")
	a.connect_to_host(MatchClient.online_ranked_url(tickets[0]))
	b.connect_to_host(MatchClient.online_ranked_url(tickets[1]))
	await _wait_until(func() -> bool: return _count("ra", "start") == 1 and _count("rb", "start") == 1)
	var team0: MatchClient = a if int(_last("ra", "start")[0]) == 0 else b
	var team1: MatchClient = b if team0 == a else a
	var name0 := "ra" if team0 == a else "rb"
	var name1 := "rb" if team0 == a else "ra"
	_expect(await _settle_ping(team0, team1, name0, name1), "A ranked match starts after the Node Ping")
	await _wait_until(func() -> bool: return _count(name0, "clock") > 0 and _count(name1, "clock") > 0)
	var start_clock := _last(name1, "clock")
	var base := int(start_clock[0][0]) if not start_clock.is_empty() else 0
	_expect(base > 0 and int(start_clock[1]) == 0, "The clock starts with the starter once the Node Ping is over")
	if base > 30000:
		_expect(false, "RANKED_CLOCK_MS is set short for the test (got %d ms)" % base)
		return

	await _wait_frames(800)
	var card := MovementCard.cards_from_names(_last(name0, "start")[1])[0]
	var origin := Vector2i(0, 4)
	var target := card.destinations(origin, 0, 5).filter(func(cell: Vector2i) -> bool: return cell.y >= 1 and cell.y <= 3)[0] as Vector2i
	var clocks_before := _count(name1, "clock")
	team0.send_move(0, origin, 0, target)
	await _wait_until(func() -> bool: return _count(name1, "clock") > clocks_before)
	var after_move := _last(name1, "clock")
	_expect(int(after_move[1]) == 1 and int(after_move[0][0]) > base, "After a move the other clock runs and the mover gained the increment")

	# The player to move drops; the clock keeps running while they come back.
	var clocks_before_drop := _count(name1, "clock")
	team1._socket.close()
	team1._on_socket_lost()
	await _wait_until(func() -> bool: return _count(name1, "resume") > 0, 30000)
	await _wait_until(func() -> bool: return _count(name1, "clock") > clocks_before_drop)
	var resumed := _last(name1, "clock")
	_expect(_count(name1, "resume") > 0 and int(resumed[1]) == 1 and int(resumed[0][1]) < base, "A resume carries the clock, still running for the player to move")

	await _wait_until(func() -> bool: return _count(name0, "ranked_result") > 0 and _count(name1, "ranked_result") > 0, base + 8000)
	var winner_result: Dictionary = _last(name0, "ranked_result")[0] if _count(name0, "ranked_result") > 0 else {}
	var loser_result: Dictionary = _last(name1, "ranked_result")[0] if _count(name1, "ranked_result") > 0 else {}
	_expect(str(loser_result.get("reason", "")) == "time" and float(loser_result.get("score", 1.0)) == 0.0 and float(winner_result.get("score", 0.0)) == 1.0, "Running out of time loses the ranked game")
	_expect(int(loser_result.get("delta", 0)) < 0 and int(winner_result.get("delta", 0)) > 0, "A loss on time is rated like any other loss")


## Guest account, e-mail login and username, then a ranked ticket ("" on failure).
func _ranked_ticket(username: String) -> String:
	var account := await _post(AccountService.api_url(), {}, "")
	var code := str(account.get("code", ""))
	await _post(AccountService.api_url().replace("/api/account", "/api/auth") + "/register", {"email": "%s@example.com" % username, "password": "longenough1"}, code)
	await _post(AccountService.api_url() + "/username", {"username": username}, code)
	var ticket := await _post(AccountService.api_url().replace("/api/account", "/api/ranked") + "/ticket", {}, code)
	return str(ticket.get("ticket", ""))


func _post(url: String, body: Dictionary, code: String) -> Dictionary:
	var request := HTTPRequest.new()
	root.add_child(request)
	var headers: PackedStringArray = ["Content-Type: application/json"]
	if not code.is_empty():
		headers.append("Authorization: Bearer " + code)
	request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	var answer: Array = await request.request_completed
	request.queue_free()
	var parsed: Variant = JSON.parse_string((answer[3] as PackedByteArray).get_string_from_utf8())
	return parsed if parsed is Dictionary else {}


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
	client.clock_synced.connect(func(left: Array, to_move: int) -> void: _log(name, "clock", [left, to_move]))
	client.ranked_result.connect(func(result: Dictionary) -> void: _log(name, "ranked_result", [result]))
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
