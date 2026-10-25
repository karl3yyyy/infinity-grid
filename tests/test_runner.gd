extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const MovementCardScript := preload("res://scripts/battle/movement_card.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	# Fixed seed: dealt cards and bot replies are random, and some assertions
	# below depend on which figures survive the opening moves.
	seed(20261021)
	var main := MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame

	var grid := main.get_node_or_null("BattleScene/GridManager") as GridManager
	var battle := main.get_node_or_null("BattleManager") as GridBattleManager
	var ui := main.get_node_or_null("BattleUI") as GridBattleUI
	var camera := main.get_node_or_null("CameraController") as CameraController
	_expect(grid != null, "GridManager exists")
	_expect(battle != null, "Battle manager exists")
	_expect(ui != null, "Card-selection UI exists")
	_expect(camera != null and camera.projection == Camera3D.PROJECTION_ORTHOGONAL and camera.pitch < deg_to_rad(70.0), "Board uses an oblique camera behind the active side")
	if battle != null and ui != null:
		_expect(ui.main_menu.visible and battle.input_locked and not grid.get_parent().visible, "Opaque main menu opens before the board is shown")
		var menu_rect := ui.main_menu._panel.get_global_rect()
		_expect(menu_rect.position.y >= 0.0 and menu_rect.end.y <= get_root().get_visible_rect().size.y, "Main menu fits inside the visible viewport")
		_expect(ui.main_menu._content.get_children().filter(func(child: Node) -> bool: return child is Button).size() >= 5, "Main menu lists the game modes as entries")
		ui.main_menu.local_multiplayer_requested.emit()
		await process_frame
		_expect(not ui.main_menu.visible and not battle.bot_opponent_enabled and grid.get_parent().visible, "Local multiplayer starts with the second hand enabled")
		battle._show_title_menu()
		_expect(ui.main_menu.visible and not grid.get_parent().visible, "Returning to the title hides the board again")
		ui.main_menu.bot_training_requested.emit()
		await process_frame
		_expect(not ui.main_menu.visible and battle.bot_opponent_enabled and grid.get_parent().visible, "Quick play starts a visible bot match")
	if ui != null:
		ui._apply_responsive_layout(Vector2(720.0, 1280.0))
		var insets := ui.get_board_insets()
		_expect(insets.x > 150.0 and insets.y > 150.0 and insets.x + insets.y < 1280.0 * 0.62, "Portrait HUD keeps opponent cards on top, own cards below and room for the board")
		_expect(ui.hand_anchors[0].size() == 2 and ui.hand_anchors[1].size() == 2 and ui.next_anchors.size() == 2, "Each side reserves room for two 3D cards plus a next-card place")
		_expect(ProjectSettings.get_setting("display/window/size/viewport_height") > ProjectSettings.get_setting("display/window/size/viewport_width"), "Project runs in portrait format")
	if grid != null:
		_expect(grid.cells.size() == 25, "Grid contains 25 cells")
		_expect(grid.wrap_projection_count == 20, "Two projected edge columns appear on each side")
		_expect(Vector2i(4, 2) in grid.get_neighbors(Vector2i(0, 2)), "Left and right edges wrap")
		_expect(Vector2i(0, 2) in grid.get_neighbors(Vector2i(4, 2)), "Wrap works in both directions")
		_expect(grid.manhattan_distance(Vector2i(0, 2), Vector2i(4, 2)) == 1, "Distance uses cylindrical X")
		_expect(grid.world_to_grid(grid.grid_to_world(Vector2i(4, 2)) + Vector3(-7.0, 0.0, 0.0)) == Vector2i(4, 2), "Left projection maps to the same logical tile")
		_expect(grid.world_to_grid(grid.grid_to_world(Vector2i(0, 2)) + Vector3(7.0, 0.0, 0.0)) == Vector2i(0, 2), "Right projection maps to the same logical tile")
		_expect(grid.world_to_grid(Vector3(-20.0, 0.0, 0.0)).x == -1, "Clicks beyond the visible wrap projections are rejected")
		_expect(grid.get_neighbors(Vector2i(2, 0)).size() == 3, "Top and bottom edges remain closed")

	var deck: Array[MovementCard] = MovementCardScript.create_deck()
	_expect(deck.size() >= 16, "Card pool has at least 16 movement cards")
	var pool_names: Dictionary = {}
	for pool_card: MovementCard in deck:
		pool_names[pool_card.card_name] = true
	_expect(pool_names.size() == deck.size(), "Every card in the pool has a unique name")
	for _draw_index: int in range(50):
		var drawn := MovementCardScript.draw_match_cards(5)
		var long_forward_count := 0
		var drawn_names: Dictionary = {}
		for drawn_card: MovementCard in drawn:
			drawn_names[drawn_card.card_name] = true
			if drawn_card.has_long_forward_move():
				long_forward_count += 1
		_expect(drawn.size() == 5 and drawn_names.size() == 5, "A match draws five distinct cards from the pool")
		_expect(long_forward_count <= 1, "At most one card has a two-square forward or diagonal-forward jump")
	_expect(MovementCard.new("Forward 2 straight", [Vector2i(0, 2)] as Array[Vector2i]).has_long_forward_move(), "A two-square straight-forward jump counts")
	_expect(MovementCard.new("Forward 2 diagonal", [Vector2i(1, 2)] as Array[Vector2i]).has_long_forward_move(), "A two-forward/one-side jump counts as a long forward move")
	_expect(not MovementCard.new("Side 2", [Vector2i(2, 0)] as Array[Vector2i]).has_long_forward_move(), "A two-square side jump does not count as a long forward move")
	_expect(Vector2i(2, 1) in deck[0].destinations(Vector2i(2, 2), 0, 5), "Player 1 card moves forward")
	_expect(Vector2i(2, 3) in deck[0].destinations(Vector2i(2, 2), 1, 5), "Player 2 card is mirrored")
	_expect(Vector2i(3, 2) in deck[1].destinations(Vector2i(0, 2), 0, 5), "Card targets wrap horizontally")
	_expect(Vector2i(4, 2) in deck[3].destinations(Vector2i(0, 2), 0, 5), "Player 1 can move from the left edge to the right")
	_expect(Vector2i(4, 2) in deck[3].destinations(Vector2i(0, 2), 1, 5), "Player 2's mirrored card uses the same shared board")
	_expect(deck[0].diagram_cell(Vector2i(0, 1), false) == Vector2i(2, 1), "Own card diagram shows forward as up")
	_expect(deck[0].diagram_cell(Vector2i(0, 1), true) == Vector2i(2, 3), "Opponent card diagram is rotated towards them")
	_expect(deck[1].diagram_cell(Vector2i(-2, 0), false) == Vector2i(0, 2), "Diagram places sideways moves on the outer column")

	if battle != null:
		battle.bot_opponent_enabled = false
		_expect(battle.players.size() == 5 and battle.enemies.size() == 5, "Each player has five figures")
		_expect(battle.players.filter(func(unit: BattleUnit) -> bool: return unit.is_master).size() == 1, "Player 1 has one master")
		_expect(battle.enemies.filter(func(unit: BattleUnit) -> bool: return unit.is_master).size() == 1, "Player 2 has one master")
		_expect(battle.players[0]._wrap_projections.size() == 2, "Each logical figure has only render-only side projections")
		_expect(ui.opponent_is_bot and ui.hand_titles[1].text.begins_with("BOT"), "Second hand is identified as the bot")
		var card_names: Array[String] = []
		for team_hand: Array in battle.hands:
			_expect(team_hand.size() == 2, "Each player receives two cards")
			for card: MovementCard in team_hand:
				card_names.append(card.card_name)
		card_names.append(battle.pass_card.card_name)
		var unique_cards: Dictionary = {}
		for card_name: String in card_names:
			unique_cards[card_name] = true
		_expect(card_names.size() == 5 and unique_cards.size() == 5, "Two hands and pass area contain all five unique cards")
		var move := _find_legal_move(battle, 0)
		_expect(not move.is_empty(), "Player 1 has a legal opening move")
		if not move.is_empty():
			var slot: int = move["slot"]
			var unit: BattleUnit = move["unit"]
			var used_card: MovementCard = battle.hands[0][slot]
			var incoming_card: MovementCard = battle.pass_card
			battle._on_card_selected(0, slot)
			battle._select_unit(unit)
			await battle._perform_move(move["destination"])
			_expect(battle.hands[0][slot] == incoming_card and battle.pass_card == used_card, "Used card swaps with the pass card")
			_expect(battle.current_player == 1, "Turn passes to Player 2 after one move")
			_expect(is_equal_approx(camera.target_yaw, PI), "Player 2 sees the same board rotated 180 degrees")
			var bot_move := battle._choose_bot_move()
			_expect(not bot_move.is_empty(), "Bot can choose a legal card-and-piece move")
			camera.set_player_view(0)
			battle.bot_opponent_enabled = true
			battle.battle_ui.set_opponent_bot(true)
			battle.player_controller.enabled = false
			battle.input_locked = true
			await battle._run_bot_turn()
			_expect(battle.current_player == 0, "Bot completes its move and returns the turn to Player 1")
			_expect(is_zero_approx(camera.target_yaw), "Camera stays behind Player 1 while playing against the bot")
			var seam_attacker := _first_living_student(battle.players)
			var seam_target := _first_living_student(battle.enemies)
			var attacker_origin := seam_attacker.grid_position
			var target_origin := seam_target.grid_position
			var saved_card: MovementCard = battle.hands[0][0]
			grid.remove_occupant(attacker_origin, seam_attacker)
			grid.remove_occupant(target_origin, seam_target)
			seam_attacker.grid_position = Vector2i(0, 2)
			seam_target.grid_position = Vector2i(4, 2)
			grid.set_occupant(seam_attacker.grid_position, seam_attacker)
			grid.set_occupant(seam_target.grid_position, seam_target)
			battle.current_player = 0
			battle.hands[0][0] = MovementCard.new("Wrap Capture", [Vector2i(-1, 0)])
			battle.selected_card_slot = 0
			battle._select_unit(seam_attacker)
			_expect(Vector2i(4, 2) in battle.movement_targets, "An enemy on the opposite edge can be captured on the shared board")
			battle._deselect_unit()
			grid.remove_occupant(seam_attacker.grid_position, seam_attacker)
			grid.remove_occupant(seam_target.grid_position, seam_target)
			seam_attacker.grid_position = attacker_origin
			seam_target.grid_position = target_origin
			grid.set_occupant(attacker_origin, seam_attacker)
			grid.set_occupant(target_origin, seam_target)
			battle.hands[0][0] = saved_card
			battle.selected_card_slot = -1
			var seam_unit := _first_living_student(battle.players)
			var seam_start := Vector2i(0, 2)
			var seam_end := Vector2i(4, 2)
			seam_unit.position = grid.grid_to_world(seam_start)
			await battle.unit_movement.move_unit(seam_unit, [seam_start, seam_end], grid)
			_expect(seam_unit.position.is_equal_approx(grid.grid_to_world(seam_end)), "Wrap animation exits one edge and lands on the opposite edge")
			seam_unit.position = grid.grid_to_world(seam_unit.grid_position)
			await _test_pass_and_draw(battle, ui)

		await _test_bot_levels()
		_test_node_ping()

		if grid != null:
			var master: BattleUnit = battle.players[2]
			var target_master: BattleUnit = battle.enemies[2]
			grid.remove_occupant(master.grid_position, master)
			grid.remove_occupant(target_master.grid_position, target_master)
			master.grid_position = Vector2i(2, 2)
			master.position = grid.grid_to_world(master.grid_position)
			target_master.grid_position = Vector2i(2, 1)
			target_master.position = grid.grid_to_world(target_master.grid_position)
			grid.set_occupant(master.grid_position, master)
			grid.set_occupant(target_master.grid_position, target_master)
			battle.current_player = 0
			battle.hands[0][0] = MovementCard.new("Capture", [Vector2i(0, 1)])
			battle.selected_card_slot = 0
			battle._select_unit(master)
			_expect(Vector2i(2, 1) in battle.movement_targets, "Enemy master is a valid capture target")
			await battle._perform_move(Vector2i(2, 1))
			_expect(battle.battle_over, "Capturing the master ends the game")
			_expect(ui.result_overlay.visible and ui.result_label.text == ("SIEG!" if battle.bot_opponent_enabled else "SPIELER 1 GEWINNT"), "Master capture declares the winning player")

	if failures.is_empty():
		print("TEST RESULT: PASS (all core assertions succeeded)")
	else:
		for failure: String in failures:
			push_error(failure)
		print("TEST RESULT: FAIL (%d failures)" % failures.size())
	main.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _empty_ai_state(cards: Array[MovementCard]) -> Dictionary:
	var pieces := PackedInt32Array()
	var teams := PackedInt32Array()
	pieces.resize(25)
	teams.resize(25)
	return {"pieces": pieces, "teams": teams, "hands": [[0, 1], [2, 3]], "pass": 4, "cards": cards}


func _place(state: Dictionary, coordinate: Vector2i, team: int, master: bool) -> void:
	var cell := coordinate.y * 5 + coordinate.x
	var pieces: PackedInt32Array = state["pieces"]
	var teams: PackedInt32Array = state["teams"]
	pieces[cell] = 2 if master else 1
	teams[cell] = team
	state["pieces"] = pieces
	state["teams"] = teams


func _test_node_ping() -> void:
	_expect(PingPhase.winner_of([Vector2(0.5, 0.5), Vector2(0.2, 0.2)], Vector2(0.5, 0.5)) == 0, "The closer pick wins the Node Ping")
	_expect(PingPhase.winner_of([Vector2(0.75, 0.5), Vector2(0.25, 0.5)], Vector2(0.5, 0.5)) == -1, "Exactly equal distance is a Signal Collision")
	_expect(PingPhase.winner_of([Vector2(0.6, 0.5), Vector2(0.4, 0.5001)], Vector2(0.5, 0.5)) == 0, "A tiny difference still decides the Node Ping")


func _test_bot_levels() -> void:
	var forward := MovementCard.new("Forward", [Vector2i(0, 1)])
	var side := MovementCard.new("Side", [Vector2i(1, 0)])
	var cards: Array[MovementCard] = [
		MovementCard.new("Back", [Vector2i(0, -1)]),
		MovementCard.new("Still", [Vector2i(-1, 0)]),
		forward,
		side,
		MovementCard.new("Spare", [Vector2i(0, 2)]),
	]
	for level: int in range(3):
		# Player 1 master stands right in front of the bot student.
		var state := _empty_ai_state(cards)
		_place(state, Vector2i(2, 3), 0, true)
		_place(state, Vector2i(2, 2), 1, false)
		_place(state, Vector2i(4, 0), 1, true)
		var ai := BotAI.new(level)
		var move := ai.choose_move(state, 1)
		_expect(not move.is_empty() and move["to"] == Vector2i(2, 3), "Bot level %s captures an exposed master" % BotAI.label_for(level))
	for level: int in range(3):
		# A bot student can step onto Player 1's KERN starting square, which wins.
		var temple := _empty_ai_state(cards)
		_place(temple, Vector2i(2, 3), 1, false)
		_place(temple, Vector2i(0, 4), 0, true)
		_place(temple, Vector2i(4, 0), 1, true)
		var temple_move := BotAI.new(level).choose_move(temple, 1)
		_expect(not temple_move.is_empty() and temple_move["to"] == Vector2i(2, 4), "Bot level %s takes the KERN starting square" % BotAI.label_for(level))
	var stuck_cards: Array[MovementCard] = [cards[0], cards[1], forward, MovementCard.new("Leap", [Vector2i(0, 2)]), cards[4]]
	for level: int in range(3):
		# The bot master stands on the far row; both of its cards only move forward off the board.
		var stuck := _empty_ai_state(stuck_cards)
		_place(stuck, Vector2i(2, 0), 0, true)
		_place(stuck, Vector2i(2, 4), 1, true)
		var stuck_move := BotAI.new(level).choose_move(stuck, 1)
		_expect(stuck_move.get("pass", false) and int(stuck_move["slot"]) in [0, 1], "Bot level %s gives a card away when it cannot move" % BotAI.label_for(level))
	var started := Time.get_ticks_msec()
	var opening_cards := MovementCardScript.draw_match_cards(5)
	var opening := _empty_ai_state(opening_cards)
	for column: int in range(5):
		_place(opening, Vector2i(column, 4), 0, column == 2)
		_place(opening, Vector2i(column, 0), 1, column == 2)
	var hard := BotAI.new(BotAI.Difficulty.HARD)
	var hard_move := hard.choose_move(opening, 1)
	var elapsed := Time.get_ticks_msec() - started
	_expect(not hard_move.is_empty(), "Hard bot finds an opening move")
	_expect(elapsed < 4000, "Hard bot answers within the think-time budget (%d ms)" % elapsed)


func _test_pass_and_draw(battle: GridBattleManager, ui: GridBattleUI) -> void:
	battle.bot_opponent_enabled = false
	battle.current_player = 0
	var saved_hand: Array = battle.hands[0].duplicate()
	var saved_pass: MovementCard = battle.pass_card
	var off_board := MovementCard.new("Off Board", [Vector2i(0, 5)])
	var far_off_board := MovementCard.new("Far Off Board", [Vector2i(0, -5)])
	battle.hands[0] = [off_board, far_off_board]
	_expect(not battle._has_legal_move(0), "A side whose cards only leave the board has no legal move")
	battle.must_pass = true
	battle.input_locked = false
	battle._on_cell_clicked(battle.players[2].grid_position)
	_expect(battle.selected_unit == null and battle.current_player == 0, "Figures cannot be selected while a card must be given away")
	battle._on_card_selected(0, 1)
	_expect(battle.hands[0][1] == saved_pass and battle.pass_card == far_off_board, "Passing gives the chosen card to the pass space")
	_expect(battle.current_player == 1 and not battle.battle_over, "Passing ends the turn without moving a figure")

	battle.hands[0] = saved_hand
	battle.pass_card = saved_pass
	battle.current_player = 0
	battle.position_counts.clear()
	battle._record_position()
	# Nothing moves between turns, so the same two positions keep alternating.
	for turn: int in range(3):
		battle._advance_turn()
		_expect(not battle.battle_over, "No draw before the third repetition (turn %d)" % (turn + 1))
	battle._advance_turn()
	_expect(battle.battle_over and ui.result_label.text == "UNENTSCHIEDEN", "Third repetition of a position ends the match in a draw")

	battle.battle_over = false
	battle.must_pass = false
	battle.current_player = 0
	battle.position_counts.clear()
	ui.result_overlay.visible = false


func _first_living_student(team: Array[BattleUnit]) -> BattleUnit:
	for unit: BattleUnit in team:
		if not unit.is_dead and not unit.is_master:
			return unit
	return null


func _find_legal_move(battle: GridBattleManager, team_id: int) -> Dictionary:
	var team: Array[BattleUnit] = battle.players if team_id == 0 else battle.enemies
	for unit: BattleUnit in team:
		for slot: int in range(2):
			var card: MovementCard = battle.hands[team_id][slot]
			for destination: Vector2i in card.destinations(unit.grid_position, team_id, battle.grid_manager.grid_size.x):
				var occupant := battle.grid_manager.get_unit_at(destination) as BattleUnit
				if occupant == null or occupant.team_id != team_id:
					return {"unit": unit, "slot": slot, "destination": destination}
	return {}


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append("FAIL: %s" % description)