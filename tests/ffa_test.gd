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
	_test_effects()
	_test_revive()
	_test_core_rules()
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
	_expect(rules.alive[1] and rules.alive.count(true) == 4 and (rules.last_events["core_lost"] as Array) == [1], "Capturing a Master does not eliminate that player")
	_expect(rules.pieces[FfaRules.start_cell(1, 0)]["owner"] == 1 and not bool(rules.pieces[FfaRules.start_cell(1, 2)]["master"]) if rules.pieces.has(FfaRules.start_cell(1, 2)) else true, "Their echoes stay theirs")
	_expect(rules.hands[0][0] == pass_before, "The used card is exchanged with the pass card")
	_expect(rules.current == 1, "The player without a core still plays")
	rules.alive[1] = false
	rules.current = 0
	_expect(rules.next_after(0) == 2, "Eliminated players are skipped")
	rules.current = 2
	rules.pass_turn(0)
	_expect(rules.pass_giver == 2, "The pass card remembers who gave it")
	var chain := FfaRules.new()
	chain.setup(false)
	chain.pass_turn(0)
	_expect(chain.pass_giver == 0 and chain.next_after(chain.current) == 2, "Cards go on clockwise: seat 1 gives, seat 2 receives, seat 3 follows")
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
	ui.main_menu.ffa_requested.emit(1, true, false)
	await process_frame
	_expect(battle.board_root.visible and battle._units.size() == 20, "The 3D four-player board opens with 20 figures")
	_expect(battle.floor_grid.get_unit_at(FfaRules.start_cell(1, 2)) != null, "Figures stand on the cells of the flat floor")
	_expect(battle._world_hands.visible and not battle._top_row.visible, "The other players' cards lie beside the board")
	_expect(battle.battle_ui.hand_titles[1].text.begins_with("↻ KARTE  GRID"), "The card chain starts with the Grid and names who gets the next card")
	var camera := main.get_node("CameraController") as CameraController
	_expect(camera.board_cells == 9 and not camera.board_wraps, "The camera frames the closed 9x9 board")
	var deadline := Time.get_ticks_msec() + 20000
	while (battle._busy or not battle._is_local(battle.rules.current)) and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(not battle._busy and battle._is_local(battle.rules.current), "The Node Ping names a starter and you may act once it is your turn")
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


## A bare board: masters in the corners, one piece of seat 0 in the middle, an enemy beside it.
func _effect_rules(card_name: String, enemy_cell: Vector2i = Vector2i(4, 3)) -> FfaRules:
	var rules := FfaRules.new()
	rules.setup(false, 1, [], true)
	rules.hands[0][0] = MovementCard.cards_from_names([card_name])[0]
	rules.pieces = {
		Vector2i(0, 8): {"owner": 0, "master": true}, Vector2i(0, 0): {"owner": 1, "master": true},
		Vector2i(8, 0): {"owner": 2, "master": true}, Vector2i(8, 8): {"owner": 3, "master": true},
		Vector2i(4, 4): {"owner": 0, "master": false}, enemy_cell: {"owner": 1, "master": false},
	}
	return rules


func _test_effects() -> void:
	var strike := _effect_rules("Crane")
	_expect(_only(FfaEffects.targets(strike, Vector2i(4, 4), 0), Vector2i(4, 3)), "Strike aims at the adjacent enemy")
	strike.apply_effect(Vector2i(4, 4), 0, Vector2i(4, 3))
	_expect(not strike.pieces.has(Vector2i(4, 3)) and strike.pieces.has(Vector2i(4, 4)) and strike.current == 1, "Strike destroys the enemy, the caster stays, the turn passes")
	_expect(strike.pass_card.card_name == "Crane", "The used card goes to the middle")

	var kill := _effect_rules("Crane", Vector2i(4, 3))
	kill.pieces[Vector2i(4, 3)]["master"] = true
	kill.apply_effect(Vector2i(4, 4), 0, Vector2i(4, 3))
	_expect(kill.alive[1] and (kill.last_events["core_lost"] as Array) == [1], "Losing the core does not knock the player out")

	var push := _effect_rules("Wave")
	_expect(_only(FfaEffects.targets(push, Vector2i(4, 4), 0), Vector2i(4, 3)), "Push aims at the adjacent enemy")
	push.apply_effect(Vector2i(4, 4), 0, Vector2i(4, 3))
	_expect(push.pieces.has(Vector2i(4, 2)) and not push.pieces.has(Vector2i(4, 3)), "Push moves the enemy one cell away")
	var wall := _effect_rules("Wave", Vector2i(4, 3))
	wall.pieces[Vector2i(4, 2)] = {"owner": 2, "master": false}
	_expect(FfaEffects.targets(wall, Vector2i(4, 4), 0).is_empty(), "A blocked push has no target")
	var edge := _effect_rules("Wave", Vector2i(4, 0))
	edge.pieces.erase(Vector2i(4, 4))
	edge.pieces[Vector2i(4, 1)] = {"owner": 0, "master": false}
	_expect(FfaEffects.targets(edge, Vector2i(4, 1), 0).is_empty(), "Nothing is pushed off the closed edge")

	var shield := _effect_rules("Orbit")
	shield.apply_effect(Vector2i(4, 4), 0, Vector2i(4, 4))
	_expect(shield.tiles.protected.has(Vector2i(4, 4)) and not shield.can_enter(1, Vector2i(4, 4)), "A shield protects the piece from captures")
	for _turn: int in range(3):
		shield.pass_turn(0)
	_expect(shield.current == 0 and shield.tiles.protected.is_empty(), "The shield ends when its owner's next turn begins")

	var swap := _effect_rules("Vortex")
	swap.apply_effect(Vector2i(4, 4), 0, Vector2i(0, 8))
	_expect(bool(swap.pieces[Vector2i(4, 4)]["master"]) and not bool(swap.pieces[Vector2i(0, 8)]["master"]), "Swap trades two own pieces")


func _test_revive() -> void:
	var kill := _effect_rules("Crane")
	kill.pieces[Vector2i(4, 3)]["master"] = true
	kill.apply_effect(Vector2i(4, 4), 0, Vector2i(4, 3))
	_expect(kill.cells_of(0).size() == 3 and kill.pieces.has(FfaRules.start_cell(0, 2)) and not bool(kill.pieces[FfaRules.start_cell(0, 2)]["master"]), "Taking a core gives a taker who has a core an echo back on the home line")
	_expect((kill.last_events["revived"] as Array).size() == 1, "The revived piece is reported for the screen")
	var echo := _effect_rules("Crane")
	echo.apply_effect(Vector2i(4, 4), 0, Vector2i(4, 3))
	_expect(echo.cells_of(0).size() == 2 and (echo.last_events["revived"] as Array).is_empty(), "Taking an echo gives nothing back")
	var full := FfaRules.new()
	full.setup(false)
	full.pieces[Vector2i(4, 4)] = {"owner": 0, "master": false}
	full.pieces[Vector2i(4, 3)] = {"owner": 1, "master": true}
	full.pieces.erase(FfaRules.start_cell(0, 0))
	full.hands[0][0] = MovementCard.cards_from_names(["Crane"])[0]
	full.apply_effect(Vector2i(4, 4), 0, Vector2i(4, 3))
	_expect(full.cells_of(0).size() == 5, "Nobody gets more than five pieces")


func _test_core_rules() -> void:
	# A player without a core gets it back by taking one.
	var rules := _effect_rules("Crane")
	rules.pieces.erase(Vector2i(0, 8))
	rules.pieces[Vector2i(4, 3)]["master"] = true
	rules.apply_effect(Vector2i(4, 4), 0, Vector2i(4, 3))
	var home := FfaRules.start_cell(0, 2)
	_expect(rules.pieces.has(home) and bool(rules.pieces[home]["master"]), "Taking a core returns your own core")
	_expect((rules.last_events["revived"] as Array)[0]["master"] == true, "The screen is told it is the core")
	# Without any piece left a player is out.
	var last := _effect_rules("Crane")
	last.pieces.erase(Vector2i(0, 0))
	last.pieces[Vector2i(4, 3)]["master"] = true
	last.apply_effect(Vector2i(4, 4), 0, Vector2i(4, 3))
	_expect(not last.alive[1] and last.alive[0], "A player without any piece is out")
	# The deck: no two turns reach an enemy Master from the start position.
	var cards := FfaDeck.safe_cards()
	_expect(cards.size() >= 18, "Enough cards remain for Finite Grid (%d)" % cards.size())
	var reachable := false
	for attacker: int in range(FfaRules.PLAYERS):
		for index: int in range(FfaRules.PIECES_PER_PLAYER):
			var from := FfaRules.start_cell(attacker, index)
			for defender: int in range(FfaRules.PLAYERS):
				if defender == attacker:
					continue
				var target := FfaRules.start_cell(defender, 2)
				for first: MovementCard in cards:
					for second: MovementCard in cards:
						for a: Vector2i in first.offsets:
							for b: Vector2i in second.offsets:
								if from + FfaRules.step_for(a, attacker) + FfaRules.step_for(b, attacker) == target:
									reachable = true
							# A step plus one effect step next to the target.
							for direction: Vector2i in FfaEffects.DIRECTIONS:
								if from + FfaRules.step_for(a, attacker) + direction == target:
									reachable = true
	_expect(not reachable, "No enemy core can be taken within two turns")
	_expect(cards.all(func(card: MovementCard) -> bool: return card.card_name != "Chaos" and card.card_name != "Rift"), "The strongest cards are not in Finite Grid")
