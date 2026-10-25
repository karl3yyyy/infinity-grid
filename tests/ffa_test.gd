extends SceneTree

const MainScene := preload("res://scenes/main.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	seed(20261026)
	_test_geometry()
	_test_rules()
	_test_self_play()
	await _test_screen()
	if failures.is_empty():
		print("FFA TESTS PASSED")
		quit(0)
	else:
		for failure: String in failures:
			printerr("FAILED: ", failure)
		quit(1)


func _test_geometry() -> void:
	var step := MovementCard.new("Forward", [Vector2i(0, 1)] as Array[Vector2i])
	_expect(_only(FfaRules.destinations(step, Vector2i(4, 8), 0), Vector2i(4, 7)), "Bottom player moves up the screen")
	_expect(_only(FfaRules.destinations(step, Vector2i(0, 4), 1), Vector2i(1, 4)), "Left player moves right")
	_expect(_only(FfaRules.destinations(step, Vector2i(4, 0), 2), Vector2i(4, 1)), "Top player moves down")
	_expect(_only(FfaRules.destinations(step, Vector2i(8, 4), 3), Vector2i(7, 4)), "Right player moves left")
	_expect(FfaRules.destinations(step, Vector2i(4, 0), 0).is_empty(), "The closed edge ends a move")
	var seen: Dictionary = {}
	for player: int in range(4):
		for index: int in range(5):
			var cell := FfaRules.start_cell(player, index)
			_expect(not seen.has(cell) and cell.x >= 0 and cell.y >= 0 and cell.x < 9 and cell.y < 9, "Start cells are unique and on the board")
			seen[cell] = true
	_expect(seen.size() == 20, "Four armies of five")


func _test_rules() -> void:
	var rules := FfaRules.new()
	rules.setup(false)
	_expect(rules.pieces.size() == 20 and rules.current == 0, "Setup places 20 pieces, player 1 starts")
	# Put player 1's master right in front of player 0's piece and capture it.
	var master_cell := FfaRules.start_cell(1, 2)
	var attacker := FfaRules.start_cell(0, 0)
	rules.pieces.erase(attacker)
	rules.pieces[master_cell + Vector2i(1, 0)] = {"owner": 0, "master": false}
	rules.hands[0][0] = MovementCard.new("Back", [Vector2i(-1, 0)] as Array[Vector2i])
	var pass_before := rules.pass_card
	rules.apply_move(master_cell + Vector2i(1, 0), 0, master_cell)
	_expect(not rules.alive[1] and rules.alive.count(true) == 3, "Capturing a Master eliminates that player")
	_expect(rules.pieces[FfaRules.start_cell(1, 0)]["owner"] == FfaRules.NEUTRAL, "Their students stay as neutral ruins")
	_expect(rules.hands[0][0] == pass_before, "The used card is exchanged with the pass card")
	_expect(rules.current == 2, "Eliminated players are skipped")
	var last := FfaRules.new()
	last.setup(false)
	last.alive = [true, false, false, false]
	last._check_winner()
	_expect(last.winner == 0, "The last Master standing wins")


func _test_self_play() -> void:
	for shifting: bool in [false, true]:
		for game: int in range(4):
			var rules := FfaRules.new()
			rules.setup(shifting)
			var bot := FfaBot.new()
			var turns := 0
			while rules.winner == FfaRules.RUNNING and turns < 2000:
				var choice := bot.choose_move(rules, rules.current)
				if choice.has("pass"):
					rules.pass_turn(int(choice["slot"]))
				else:
					rules.apply_move(choice["from"], int(choice["slot"]), choice["to"])
				turns += 1
			_expect(rules.winner != FfaRules.RUNNING, "Bot game %d (tiles %s) ends" % [game, str(shifting)])
			if rules.winner >= 0:
				_expect(rules.alive.count(true) == 1 and rules.alive[rules.winner], "The winner is the only survivor")


func _test_screen() -> void:
	var main := MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	var ui := main.get_node("BattleUI") as GridBattleUI
	var battle := main.get_node("FfaBattle") as FfaBattle
	battle.bot_delay = 0.0
	ui.main_menu.ffa_requested.emit(1, true)
	await process_frame
	_expect(battle.board_root.visible and battle._units.size() == 20, "The 3D four-player board opens with 20 figures")
	_expect(battle.floor_grid.get_unit_at(FfaRules.start_cell(1, 2)) != null, "Figures stand on the cells of the flat floor")
	var camera := main.get_node("CameraController") as CameraController
	_expect(camera.board_cells == 9 and not camera.board_wraps, "The camera frames the closed 9x9 board")
	var deadline := Time.get_ticks_msec() + 20000
	while battle._busy and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(not battle._busy and battle.rules.current == 0, "You move first and may act once the cards are dealt")
	var origin := FfaRules.start_cell(0, 2)
	battle._on_cell_clicked(origin)
	battle._on_card_selected(0, 0)
	_expect(battle._selected != null and battle._selected.grid_position == origin and battle._slot == 0, "Piece and card can be chosen")
	battle.start(0, false)
	deadline = Time.get_ticks_msec() + 60000
	while battle.rules.round_number < 3 and battle.rules.winner == FfaRules.RUNNING and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(battle.rules.round_number >= 3 or battle.rules.winner != FfaRules.RUNNING, "Bots play whole rounds on the 3D board, animated")
	_expect(battle._units.filter(func(unit: BattleUnit) -> bool: return unit.position.distance_to(battle.floor_grid.grid_to_world(unit.grid_position)) > 0.05 and not unit.is_dead).is_empty(), "Every figure stands on its cell after the moves")
	main.queue_free()
	await process_frame


func _only(cells: Array[Vector2i], expected: Vector2i) -> bool:
	return cells.size() == 1 and cells[0] == expected


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
