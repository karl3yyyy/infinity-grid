extends SceneTree

## Rooms for up to four players (server/online/group_room.js). Needs a running server:
##   cd server/online && npx wrangler dev --port 8787
##   set INFINITY_GRID_ONLINE=ws://127.0.0.1:8787
##   godot --headless --path . --script res://tests/group_online_test.gd

var failures: Array[String] = []
var events: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	if OS.get_environment("INFINITY_GRID_ONLINE").is_empty():
		push_error("Set INFINITY_GRID_ONLINE to the server to test, e.g. ws://127.0.0.1:8787")
		quit(1)
		return
	await _test_lobby_and_turns()
	await _test_bad_codes()
	if failures.is_empty():
		print("GROUP ONLINE TESTS PASSED")
	else:
		for failure: String in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _client(label: String) -> GroupClient:
	var client := GroupClient.new()
	root.add_child(client)
	for signal_name: String in ["joined", "lobby_changed", "started", "turn_received", "seat_left", "seat_back", "host_changed", "rejected", "seat_away"]:
		client.connect(signal_name, func(first: Variant = null, _second: Variant = null) -> void:
			var key := "%s:%s" % [label, signal_name]
			if not events.has(key):
				events[key] = []
			events[key].append(first))
	return client


func _count(label: String, signal_name: String) -> int:
	return (events.get("%s:%s" % [label, signal_name], []) as Array).size()


func _last(label: String, signal_name: String) -> Variant:
	var entries: Array = events.get("%s:%s" % [label, signal_name], [])
	return entries.back() if not entries.is_empty() else null


func _wait_until(condition: Callable, timeout_ms: int = 8000) -> void:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await process_frame


func _test_lobby_and_turns() -> void:
	var host := _client("host")
	var guest := _client("guest")
	host.create_room(4, {"tiles": true}, "Hanna", "symbol:code")
	await _wait_until(func() -> bool: return _count("host", "joined") == 1)
	var created: Dictionary = _last("host", "joined")
	_expect(created != null and str(created["code"]).length() == 5 and bool(created["host"]) and int(created["seat"]) == 0, "The host gets a five-digit code and seat 0")
	guest.join_room(str(created["code"]), "Gustav", "")
	await _wait_until(func() -> bool: return _count("guest", "joined") == 1 and _count("host", "lobby_changed") >= 1)
	_expect(int(_last("guest", "joined")["seat"]) == 2, "The second human sits opposite")
	var lobby: Dictionary = _last("host", "lobby_changed")
	_expect((lobby["players"] as Array).size() == 2 and bool(lobby["settings"]["tiles"]), "The host sees both players and the settings")
	guest.start_match()
	await get_root().get_tree().create_timer(0.5).timeout
	_expect(_count("guest", "started") == 0, "Only the host can start")
	host.start_match()
	await _wait_until(func() -> bool: return _count("host", "started") == 1 and _count("guest", "started") == 1)
	var a: Dictionary = _last("host", "started")
	var b: Dictionary = _last("guest", "started")
	_expect(a["cards"] == b["cards"] and (a["cards"] as Array).size() == 9 and a["seed"] == b["seed"], "Everybody gets the same nine cards and seed")
	_expect((a["humans"] as Array).map(func(seat: Variant) -> int: return int(seat)) == [0, 2] and int(b["seat"]) == 2, "The start names the human seats")

	host.send_turn({"type": "move", "seq": 0, "seat": 0, "from": Vector2i(4, 8), "slot": 0, "to": Vector2i(4, 7)})
	await _wait_until(func() -> bool: return _count("guest", "turn_received") == 1)
	var turn: Dictionary = _last("guest", "turn_received")
	_expect(turn != null and turn["from"] == Vector2i(4, 8) and turn["to"] == Vector2i(4, 7) and int(turn["seat"]) == 0, "A turn reaches the others with its cells")
	# A player may not move for somebody else's seat; the host plays bots.
	guest.send_turn({"type": "move", "seq": 1, "seat": 1, "from": Vector2i(0, 4), "slot": 0, "to": Vector2i(1, 4)})
	guest.send_turn({"type": "move", "seq": 1, "seat": 0, "from": Vector2i(4, 7), "slot": 0, "to": Vector2i(4, 6)})
	await get_root().get_tree().create_timer(0.5).timeout
	_expect(_count("host", "turn_received") == 0, "A turn for a foreign seat is dropped")
	host.send_turn({"type": "pass", "seq": 1, "seat": 1, "slot": 1})
	await _wait_until(func() -> bool: return _count("guest", "turn_received") == 2)
	_expect(str(_last("guest", "turn_received")["type"]) == "pass", "The host sends the turns of bots")
	host.send_turn({"type": "pass", "seq": 1, "seat": 3, "slot": 0})
	await get_root().get_tree().create_timer(0.5).timeout
	_expect(_count("guest", "turn_received") == 2, "A repeated number is dropped")

	# The host leaves: the guest is told, a bot takes the seat and the guest becomes host.
	host.leave()
	await _wait_until(func() -> bool: return _count("guest", "seat_left") == 1 and _count("guest", "host_changed") == 1)
	_expect(_last("guest", "seat_left") == 0 and guest.is_host, "A leaver is replaced by a bot and the next player hosts")
	guest.leave()
	host.queue_free()
	guest.queue_free()


func _test_bad_codes() -> void:
	var stranger := _client("stranger")
	stranger.join_room("99999", "X", "")
	await _wait_until(func() -> bool: return _count("stranger", "rejected") == 1)
	_expect(_last("stranger", "rejected") == "not_found", "An unknown code is refused")
	stranger.queue_free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		print("FAIL: ", message)
