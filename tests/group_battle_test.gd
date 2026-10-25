extends SceneTree

## Two game instances in one room: both play the same Finite Grid match through
## the server (humans on seats 0 and 2, bots on 1 and 3 run by the host) and must
## end up with the same board. Needs a running server like group_online_test.gd.

const MainScene := preload("res://scenes/main.tscn")

var failures: Array[String] = []
var effects_used: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	if OS.get_environment("INFINITY_GRID_ONLINE").is_empty():
		push_error("Set INFINITY_GRID_ONLINE to the server to test, e.g. ws://127.0.0.1:8787")
		quit(1)
		return
	seed(4711)
	var first := MainScene.instantiate()
	var second := MainScene.instantiate()
	root.add_child(first)
	root.add_child(second)
	await process_frame
	await process_frame
	var host := first.get_node("FfaBattle") as FfaBattle
	var guest := second.get_node("FfaBattle") as FfaBattle
	host.bot_delay = 0.0
	guest.bot_delay = 0.0
	host.create_room({"tiles": true, "effects": true}, 4)
	await _wait_until(func() -> bool: return host.client.code != "")
	_expect(host.client.code.length() == 5, "The host opened a room")
	guest.join_room(host.client.code)
	await _wait_until(func() -> bool: return guest.client.seat >= 0)
	host.client.start_match()
	await _wait_until(func() -> bool: return host._online and guest._online and host.rules != null and guest.rules != null)
	_expect(host._my_seat == 0 and guest._my_seat == 2, "The humans sit opposite each other")
	_expect(host._is_human == [true, false, true, false] and guest._is_human == [true, false, true, false], "Both know who is human")

	var deadline := Time.get_ticks_msec() + 150000
	var reconnect_tested := false
	var reconnect_state := {"completed": false}
	while Time.get_ticks_msec() < deadline:
		await process_frame
		_play_for(host)
		_play_for(guest)
		if not reconnect_tested and host._turns_done >= 4:
			reconnect_tested = true
			guest.client.resumed.connect(func(_info: Dictionary) -> void: reconnect_state["completed"] = true)
			guest.client._socket.close()
			guest.client._on_socket_lost()
			await _wait_until(func() -> bool: return bool(reconnect_state["completed"]) and not guest._reconnecting, 20000)
			await _wait_until(func() -> bool: return host._turns_done == guest._turns_done and not guest._animating_remote, 20000)
			_expect(bool(reconnect_state["completed"]), "A dropped Finite Grid client rejoins")
			_expect(_board(host) == _board(guest) and _hands(host) == _hands(guest), "The resumed board and cards match the authoritative turn history")
		if host.rules.round_number >= 4 or host.rules.winner != FfaRules.RUNNING:
			break
	# Let the last turn arrive and settle.
	await _wait_until(func() -> bool: return host._turns_done == guest._turns_done and not host._animating_remote and not guest._animating_remote, 20000)
	_expect(host._turns_done >= 8, "Several rounds were played (%d turns)" % host._turns_done)
	_expect(effects_used > 0, "Card effects were played (%d)" % effects_used)
	_expect(host._turns_done == guest._turns_done, "Both counted the same turns")
	_expect(_board(host) == _board(guest), "Both ended with the same board")
	_expect(_hands(host) == _hands(guest), "Both ended with the same cards")
	_expect(host.rules.current == guest.rules.current and host.rules.round_number == guest.rules.round_number, "Both agree whose turn it is")
	_expect(reconnect_tested, "The multiplayer test exercised a reconnect")
	host.client.leave()
	guest.client.leave()
	GroupClient.clear_saved_session()
	first.queue_free()
	second.queue_free()
	if failures.is_empty():
		print("GROUP BATTLE TESTS PASSED")
	quit(0 if failures.is_empty() else 1)


## A human of this instance picks a random legal move once it is their turn.
func _play_for(battle: FfaBattle) -> void:
	if not battle._active or battle._busy or battle.rules.winner != FfaRules.RUNNING:
		return
	var seat := battle.rules.current
	if not battle._is_local(seat):
		return
	var moves := battle.rules.legal_moves(seat)
	if moves.is_empty():
		battle._on_card_selected(0, 0)
		return
	if randf() < 0.4 and _try_effect(battle, seat):
		return
	var move: Dictionary = moves[randi() % moves.size()]
	battle._on_cell_clicked(move["from"])
	battle._on_card_selected(0, int(move["slot"]))
	battle._on_cell_clicked(move["to"])


## Aims the effect of a random card at a random target, if there is one.
func _try_effect(battle: FfaBattle, seat: int) -> bool:
	var options: Array[Dictionary] = []
	for origin: Vector2i in battle.rules.cells_of(seat):
		for slot: int in range(2):
			for target: Vector2i in FfaEffects.targets(battle.rules, origin, slot):
				options.append({"from": origin, "slot": slot, "to": target})
	if options.is_empty():
		return false
	var pick: Dictionary = options[randi() % options.size()]
	battle._on_cell_clicked(pick["from"])
	battle._on_card_selected(0, int(pick["slot"]))
	battle._on_effect_requested()
	battle._on_cell_clicked(pick["to"])
	effects_used += 1
	return true


func _board(battle: FfaBattle) -> String:
	var parts: PackedStringArray = []
	var cells: Array = battle.rules.pieces.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for cell: Vector2i in cells:
		parts.append("%d,%d:%d%s" % [cell.x, cell.y, int(battle.rules.pieces[cell]["owner"]), "k" if battle.rules.pieces[cell]["master"] else ""])
	return ";".join(parts)


func _hands(battle: FfaBattle) -> String:
	var parts: PackedStringArray = []
	for hand: Array in battle.rules.hands:
		parts.append("%s+%s" % [hand[0].card_name, hand[1].card_name])
	parts.append(battle.rules.pass_card.card_name)
	return " ".join(parts)


func _wait_until(condition: Callable, timeout_ms: int = 10000) -> void:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		print("FAIL: ", message)
