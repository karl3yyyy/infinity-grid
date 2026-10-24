extends SceneTree

## Wi-Fi play: host serves files, pairs two clients and relays moves; a battle
## manager replays a received opponent move.

const LanHostServerScript := preload("res://scripts/network/lan_host_server.gd")
const MatchClientScript := preload("res://scripts/network/match_client.gd")
const MainScene := preload("res://scenes/main.tscn")
const TEST_PORT: int = 18060

var failures: Array[String] = []
var _server: LanHostServer


func _initialize() -> void:
	call_deferred("_run_tests")


func _process(_delta: float) -> bool:
	if _server != null:
		_server.poll()
	return false


func _run_tests() -> void:
	seed(7)
	var web_root := OS.get_user_data_dir().path_join("lan_test_web")
	DirAccess.make_dir_recursive_absolute(web_root)
	var page := FileAccess.open(web_root.path_join("index.html"), FileAccess.WRITE)
	page.store_string("<html>Infinity Grid</html>")
	page.close()

	_server = LanHostServerScript.new()
	_expect(_server.start(web_root, TEST_PORT) == OK, "Host listens for HTTP and WebSocket")
	var body := await _http_get("/")
	_expect(body == "<html>Infinity Grid</html>", "Host serves the web export's index page")
	_expect((await _http_get("/../project.godot")).begins_with("404"), "Host refuses paths outside the web export")

	var godot_page := "\tconst missing = Engine.getMissingFeatures({\n\t\tthreads: GODOT_THREADS_ENABLED,\n\t});"
	_expect(LanHostServer.allow_plain_http(godot_page).contains("!feature.startsWith('Secure Context')"), "Host lets the page start over plain HTTP in the home network")
	var exported_page := ProjectSettings.globalize_path("res://build/web/index.html")
	if FileAccess.file_exists(exported_page):
		var original := FileAccess.get_file_as_string(exported_page)
		var patched := LanHostServer.allow_plain_http(original)
		_expect(patched.contains("lanFeatureCheck") and patched.contains("\"--audio-driver\",\"Dummy\""), "The plain-HTTP patch matches the current web export")

	var first: MatchClient = MatchClientScript.new()
	var second: MatchClient = MatchClientScript.new()
	root.add_child(first)
	root.add_child(second)
	var starts: Array = []
	var received: Array = []
	var left: Array = []
	first.match_started.connect(func(team: int, cards: Array) -> void: starts.append([0, team, cards]))
	second.match_started.connect(func(team: int, cards: Array) -> void: starts.append([1, team, cards]))
	second.opponent_moved.connect(func(message: Dictionary) -> void: received.append(message))
	second.opponent_left.connect(func() -> void: left.append(true))
	var url := "ws://127.0.0.1:%d/play?mode=quick" % (TEST_PORT + 1)
	first.connect_to_host(url)
	await _wait_until(func() -> bool: return _server.waiting_player_count() == 1)
	second.connect_to_host(url)
	await _wait_until(func() -> bool: return starts.size() == 2)
	_expect(starts.size() == 2, "Two waiting players are paired into one match")
	if starts.size() == 2:
		var teams := [int(starts[0][1]), int(starts[1][1])]
		teams.sort()
		_expect(teams == [0, 1], "Paired players get opposite teams")
		_expect(starts[0][2] == starts[1][2] and (starts[0][2] as Array).size() == 5, "Both players receive the same five cards")
		_expect(MovementCard.cards_from_names(starts[0][2]).size() == 5, "Card names map back to movement cards")
	first.send_move(0, Vector2i(1, 4), 1, Vector2i(1, 3))
	await _wait_until(func() -> bool: return received.size() == 1)
	# JSON turns numbers into floats; the battle manager converts them back with int().
	var relayed: Dictionary = received[0] if received.size() == 1 else {}
	_expect(_ints(relayed.get("from", [])) == [1, 4] and int(relayed.get("slot", -1)) == 1 and _ints(relayed.get("to", [])) == [1, 3], "A move is relayed to the opponent unchanged")
	first.disconnect_from_host()
	await _wait_until(func() -> bool: return left.size() == 1)
	_expect(left.size() == 1, "The opponent learns when a player leaves")
	second.disconnect_from_host()
	await _test_room_codes(first, second)
	_server.stop()
	_server = null
	_test_online_server_cards()
	_test_shop_prices()
	_test_server_rules_cards()

	await _test_remote_move_replay()

	if failures.is_empty():
		print("TEST RESULT: PASS (all LAN assertions succeeded)")
	else:
		for failure: String in failures:
			push_error(failure)
		print("TEST RESULT: FAIL (%d failures)" % failures.size())
	quit(0 if failures.is_empty() else 1)


## Online protocol (also spoken by the PC host): create a room, join by code.
func _test_room_codes(host: MatchClient, guest: MatchClient) -> void:
	var base := "ws://127.0.0.1:%d" % (TEST_PORT + 1)
	var codes: Array = []
	var rejections: Array = []
	var starts: Array = []
	host.room_created.connect(func(code: String) -> void: codes.append(code))
	host.match_started.connect(func(team: int, _cards: Array) -> void: starts.append(["host", team]))
	guest.match_started.connect(func(team: int, _cards: Array) -> void: starts.append(["guest", team]))
	guest.rejected.connect(func(reason: String) -> void: rejections.append(reason))

	guest.connect_to_host(base + "/play?mode=join&code=0000")
	await _wait_until(func() -> bool: return rejections.size() == 1)
	_expect(rejections == ["not_found"], "Joining an unknown room code is rejected")

	host.connect_to_host(base + "/play?mode=create")
	await _wait_until(func() -> bool: return codes.size() == 1)
	_expect(codes.size() == 1 and str(codes[0]).length() == 4 and str(codes[0]).is_valid_int(), "Creating a game hands out a four-digit room code")
	if codes.is_empty():
		return
	guest.connect_to_host(base + "/play?mode=join&code=" + str(codes[0]))
	await _wait_until(func() -> bool: return starts.size() == 2)
	starts.sort_custom(func(a: Array, b: Array) -> bool: return str(a[0]) < str(b[0]))
	_expect(starts == [["guest", 1], ["host", 0]], "The room creator plays first, the guest second")
	host.disconnect_from_host()
	guest.disconnect_from_host()


func _test_online_server_cards() -> void:
	var worker := FileAccess.get_file_as_string("res://server/online/worker.js")
	var missing: Array[String] = []
	for card: MovementCard in MovementCard.create_deck():
		if not worker.contains("\"%s\"" % card.card_name):
			missing.append(card.card_name)
	_expect(not worker.is_empty() and missing.is_empty(), "The online server deals from the same card pool (missing: %s)" % ", ".join(missing))


## The ranked referee (server/online/rules.js) must know the same cards.
func _test_server_rules_cards() -> void:
	var rules := FileAccess.get_file_as_string("res://server/online/rules.js")
	var mismatched: Array[String] = []
	for card: MovementCard in MovementCard.create_deck():
		var parts: PackedStringArray = []
		for offset: Vector2i in card.offsets:
			parts.append("[%d, %d]" % [offset.x, offset.y])
		if not rules.contains("%s: [%s]," % [card.card_name, ", ".join(parts)]):
			mismatched.append(card.card_name)
	_expect(not rules.is_empty() and mismatched.is_empty(), "The ranked referee uses the same card moves (differ: %s)" % ", ".join(mismatched))


func _test_shop_prices() -> void:
	var accounts := FileAccess.get_file_as_string("res://server/online/accounts.js")
	var block := accounts.get_slice("export const PRICES = {", 1).get_slice("};", 0)
	var server_prices := {}
	var pattern := RegEx.create_from_string("\"([a-z]+:[a-z_]+)\": ([0-9]+)")
	for found: RegExMatch in pattern.search_all(block):
		server_prices[found.get_string(1)] = found.get_string(2).to_int()
	_expect(not server_prices.is_empty() and server_prices == CharacterRoster.PRICES, "The shop server charges the prices the game shows")
	var unknown: Array[String] = []
	var lists := {"character": CharacterRoster.CHARACTERS, "skin": CharacterSkins.SKINS, "echo": CharacterRoster.ECHO_STYLES, "board": CharacterRoster.BOARD_SKINS}
	for item: String in CharacterRoster.PRICES:
		var ids: Array = (lists[item.get_slice(":", 0)] as Array).map(func(entry: Dictionary) -> String: return entry["id"])
		if not item.get_slice(":", 1) in ids:
			unknown.append(item)
	_expect(unknown.is_empty(), "Every shop item exists in the collection (unknown: %s)" % ", ".join(unknown))
	var misnamed := CharacterSkins.SKINS.filter(func(skin: Dictionary) -> bool: return not str(skin["id"]).begins_with(str(skin["character"]) + "_"))
	_expect(misnamed.is_empty(), "Skin ids start with their character, as the server expects")
	_expect(CharacterRoster.price("character", CharacterRoster.CHARACTERS[0]["id"]) == 0 and CharacterRoster.price("echo", "echo") == 0 and CharacterRoster.price("board", "standard") == 0, "The default look is free")


func _test_remote_move_replay() -> void:
	var main := MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	var battle := main.get_node("BattleManager") as OnitamaBattleManager
	var ui := main.get_node("BattleUI") as OnitamaUI
	var grid := main.get_node("BattleScene/GridManager") as GridManager
	var network := battle._start_network_match()
	network._on_match_started(1, ["Crane", "Wave", "Comet", "Shell", "Vortex"])
	_expect(battle.network_team == 1 and battle.input_locked and not battle.player_controller.enabled, "Second player waits while the first one moves")
	_expect(battle.hands[0][0].card_name == "Crane" and battle.pass_card.card_name == "Vortex", "Cards are dealt as the host decided")
	_expect(ui.hand_titles[0].text == "DU" and ui.hand_titles[1].text == "GEGNER", "Own hand is at the bottom, the opponent's on top")
	# Turns arrive out of order: number 1 (own) must wait for number 0 (opponent's).
	# Crane (0, 1) moves Player 1's student forward from (0, 4) to (0, 3).
	network._on_opponent_moved({"type": "move", "seq": 1, "from": [0, 0], "slot": 0, "to": [0, 1]})
	network._on_opponent_moved({"type": "move", "seq": 0, "from": [0, 4], "slot": 0, "to": [0, 3]})
	await _wait_until(func() -> bool: return battle.turns_played == 2)
	_expect(grid.get_unit_at(Vector2i(0, 3)) != null and grid.get_unit_at(Vector2i(0, 4)) == null, "The opponent's move is replayed on this board")
	_expect(battle.turns_played == 2 and grid.get_unit_at(Vector2i(0, 1)) != null, "Turns are applied in order by their number, like after a reconnect")
	network._on_opponent_moved({"type": "move", "seq": 0, "from": [0, 4], "slot": 0, "to": [0, 3]})
	await process_frame
	_expect(battle.turns_played == 2, "A turn that was already played is ignored")
	_expect(not battle.input_locked or battle.current_player != battle.network_team, "Input follows whose turn it is")
	battle.end_with_message("GEGNER IST WEG")
	_expect(battle.battle_over and ui.result_label.text == "GEGNER IST WEG", "A lost opponent ends the match with a message")
	main.queue_free()
	await process_frame


func _http_get(path: String) -> String:
	var client := HTTPClient.new()
	client.connect_to_host("127.0.0.1", TEST_PORT)
	await _wait_until(func() -> bool:
		client.poll()
		return client.get_status() == HTTPClient.STATUS_CONNECTED or client.get_status() >= HTTPClient.STATUS_CANT_RESOLVE)
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return ""
	client.request(HTTPClient.METHOD_GET, path, [])
	# Lambdas capture packed arrays by value, so collect chunks in an Array.
	var chunks: Array = []
	await _wait_until(func() -> bool:
		client.poll()
		if client.get_status() == HTTPClient.STATUS_BODY:
			chunks.append(client.read_response_body_chunk())
		return client.get_status() != HTTPClient.STATUS_REQUESTING and client.get_status() != HTTPClient.STATUS_BODY)
	var body := PackedByteArray()
	for chunk: PackedByteArray in chunks:
		body.append_array(chunk)
	return body.get_string_from_utf8()


func _ints(values: Array) -> Array:
	return values.map(func(value: Variant) -> int: return int(value))


func _wait_until(condition: Callable, max_frames: int = 600) -> void:
	for _frame: int in range(max_frames):
		if condition.call():
			return
		await process_frame


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append("FAIL: %s" % description)
