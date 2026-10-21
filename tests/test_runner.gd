extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const MovementCardScript := preload("res://scripts/battle/movement_card.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var main := MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame

	var grid := main.get_node_or_null("BattleScene/GridManager") as GridManager
	var battle := main.get_node_or_null("BattleManager") as OnitamaBattleManager
	var ui := main.get_node_or_null("BattleUI") as OnitamaUI
	var camera := main.get_node_or_null("CameraController") as CameraController
	_expect(grid != null, "GridManager exists")
	_expect(battle != null, "Onitama battle manager exists")
	_expect(ui != null, "Card-selection UI exists")
	_expect(camera != null and camera.projection == Camera3D.PROJECTION_ORTHOGONAL and camera.pitch < deg_to_rad(70.0), "Board uses an oblique camera behind the active side")
	if ui != null:
		ui._apply_responsive_layout(Vector2(390.0, 844.0))
		_expect(ui.card_layout.columns == 1 and ui.tray.offset_top == -312.0, "Card HUD stacks for portrait mobile screens")
		ui._apply_responsive_layout(Vector2(1280.0, 720.0))
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
	_expect(deck.size() == 5, "Exactly five movement cards exist")
	_expect(Vector2i(2, 1) in deck[0].destinations(Vector2i(2, 2), 0, 5), "Player 1 card moves forward")
	_expect(Vector2i(2, 3) in deck[0].destinations(Vector2i(2, 2), 1, 5), "Player 2 card is mirrored")
	_expect(Vector2i(3, 2) in deck[1].destinations(Vector2i(0, 2), 0, 5), "Card targets wrap horizontally")
	_expect(Vector2i(4, 2) in deck[3].destinations(Vector2i(0, 2), 0, 5), "Player 1 can move from the left edge to the right")
	_expect(Vector2i(4, 2) in deck[3].destinations(Vector2i(0, 2), 1, 5), "Player 2's mirrored card uses the same shared board")
	_expect(deck[0].move_summary(0) == deck[0].move_summary(1), "Both players read identical relative arrows from their own sides")

	if battle != null:
		battle.bot_opponent_enabled = false
		_expect(battle.players.size() == 5 and battle.enemies.size() == 5, "Each player has five figures")
		_expect(battle.players.filter(func(unit: BattleUnit) -> bool: return unit.is_master).size() == 1, "Player 1 has one master")
		_expect(battle.enemies.filter(func(unit: BattleUnit) -> bool: return unit.is_master).size() == 1, "Player 2 has one master")
		_expect(battle.players[0]._wrap_projections.size() == 2, "Each logical figure has only render-only side projections")
		_expect(ui.opponent_is_bot and ui.hand_titles[1].text == "BOT", "Second hand is identified as the bot")
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
			var seam_attacker: BattleUnit = battle.players[0]
			var seam_target: BattleUnit = battle.enemies[0]
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
			var seam_unit: BattleUnit = battle.players[0]
			var seam_start := Vector2i(0, 2)
			var seam_end := Vector2i(4, 2)
			seam_unit.position = grid.grid_to_world(seam_start)
			await battle.unit_movement.move_unit(seam_unit, [seam_start, seam_end], grid)
			_expect(seam_unit.position.is_equal_approx(grid.grid_to_world(seam_end)), "Wrap animation exits one edge and lands on the opposite edge")

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
			_expect(ui.result_overlay.visible and ui.result_label.text == "PLAYER 1 WINS", "Master capture declares the winning player")

	if failures.is_empty():
		print("TEST RESULT: PASS (all core assertions succeeded)")
	else:
		for failure: String in failures:
			push_error(failure)
		print("TEST RESULT: FAIL (%d failures)" % failures.size())
	main.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _find_legal_move(battle: OnitamaBattleManager, team_id: int) -> Dictionary:
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