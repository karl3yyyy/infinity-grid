class_name OnitamaBattleManager
extends Node

const PlayerUnitScript := preload("res://scripts/units/player_unit.gd")
const EnemyUnitScript := preload("res://scripts/units/enemy_unit.gd")
const MovementCardScript := preload("res://scripts/battle/movement_card.gd")

var grid_manager: GridManager
var camera_controller: CameraController
var turn_manager: TurnManager
var battle_ui: OnitamaUI
var player_controller: PlayerController
var unit_movement: UnitMovement
var units_parent: Node3D

var players: Array[BattleUnit] = []
var enemies: Array[BattleUnit] = []
var hands: Array = [[], []]
var pass_card: MovementCard
var selected_unit: BattleUnit
var selected_card_slot: int = -1
var movement_targets: Array[Vector2i] = []
var current_player: int = 0
var round_number: int = 1
var input_locked: bool = true
var battle_over: bool = false
var bot_opponent_enabled: bool = true


func setup(
	grid: GridManager,
	camera: CameraController,
	turns: TurnManager,
	ui: OnitamaUI,
	player_input: PlayerController,
	movement: UnitMovement,
	unit_container: Node3D
) -> void:
	grid_manager = grid
	camera_controller = camera
	turn_manager = turns
	battle_ui = ui
	battle_ui.set_opponent_bot(bot_opponent_enabled)
	player_controller = player_input
	unit_movement = movement
	units_parent = unit_container
	player_controller.cell_clicked.connect(_on_cell_clicked)
	player_controller.cancel_requested.connect(_on_cancel_requested)
	battle_ui.card_selected.connect(_on_card_selected)
	battle_ui.restart_pressed.connect(_restart_battle)
	battle_ui.quit_pressed.connect(func() -> void: get_tree().quit())
	_deal_cards()
	_spawn_armies()
	call_deferred("_start_battle")


func _deal_cards() -> void:
	var deck := MovementCardScript.create_deck()
	deck.shuffle()
	hands[0] = [deck[0], deck[1]]
	hands[1] = [deck[2], deck[3]]
	pass_card = deck[4]


func _spawn_armies() -> void:
	for team_id: int in range(2):
		var team: Array[BattleUnit] = players if team_id == 0 else enemies
		for column: int in range(5):
			var is_master := column == 2
			var coordinate := Vector2i(column, 4 if team_id == 0 else 0)
			var display_name := "P%d Master" % (team_id + 1) if is_master else "P%d Student" % (team_id + 1)
			var unit: BattleUnit
			if team_id == 0:
				unit = PlayerUnitScript.new()
				unit.setup_player(display_name, coordinate)
			else:
				unit = EnemyUnitScript.new()
				unit.setup_enemy(display_name, coordinate)
				unit.rotation_degrees.y = 180.0
			unit.is_master = is_master
			unit.scale = Vector3.ONE * (1.18 if is_master else 1.0)
			units_parent.add_child(unit)
			unit.position = grid_manager.grid_to_world(coordinate)
			unit.create_wrap_projections(units_parent, float(grid_manager.grid_size.x) * GridManager.CELL_SIZE)
			team.append(unit)
			grid_manager.set_occupant(coordinate, unit)
			unit.died.connect(_on_unit_died)


func _start_battle() -> void:
	input_locked = false
	player_controller.enabled = true
	camera_controller.set_player_view(current_player)
	turn_manager.set_state(TurnManager.BattleState.PLAYER_SELECT_UNIT)
	_refresh_ui()
	battle_ui.set_instruction("Player 1: choose a movement card, then a figure and a highlighted destination.")


func _on_card_selected(team_id: int, slot: int) -> void:
	if input_locked or battle_over or team_id != current_player or slot < 0 or slot >= 2:
		return
	selected_card_slot = slot
	_refresh_targets()
	_refresh_ui()
	if selected_unit == null:
		battle_ui.set_instruction("Select one of your figures to preview this card's moves.")
	elif movement_targets.is_empty():
		battle_ui.set_instruction("That card has no legal move for this figure.")
	else:
		battle_ui.set_instruction("Choose a highlighted destination. The gold edge marks the wraparound.")


func _on_cell_clicked(coordinate: Vector2i) -> void:
	if input_locked or battle_over or not grid_manager.is_inside(coordinate):
		return
	var clicked_unit := grid_manager.get_unit_at(coordinate) as BattleUnit
	if clicked_unit != null and clicked_unit.team_id == current_player:
		_select_unit(clicked_unit)
		return
	if selected_unit != null and selected_card_slot >= 0 and coordinate in movement_targets:
		await _perform_move(coordinate)
	elif selected_card_slot < 0:
		battle_ui.set_instruction("Choose one of your two movement cards first.")
	else:
		battle_ui.set_instruction("That field is not a legal move for the selected card.")


func _select_unit(unit: BattleUnit) -> void:
	if selected_unit != null:
		selected_unit.set_selected(false)
	selected_unit = unit
	selected_unit.set_selected(true)
	_refresh_targets()
	_refresh_ui()
	if selected_card_slot < 0:
		battle_ui.set_instruction("Now choose one of your two movement cards.")
	elif movement_targets.is_empty():
		battle_ui.set_instruction("This figure has no legal destination with that card.")
	else:
		battle_ui.set_instruction("Choose a highlighted destination. Capturing the master wins the game.")


func _refresh_targets() -> void:
	movement_targets.clear()
	if selected_unit == null or selected_card_slot < 0:
		grid_manager.clear_highlights()
		return
	var card: MovementCard = hands[current_player][selected_card_slot]
	for coordinate: Vector2i in card.destinations(selected_unit.grid_position, current_player, grid_manager.grid_size.x):
		var occupant := grid_manager.get_unit_at(coordinate) as BattleUnit
		if occupant == null or occupant.team_id != current_player:
			movement_targets.append(coordinate)
	grid_manager.show_movement_targets(movement_targets, selected_unit.grid_position, current_player)


func _perform_move(destination: Vector2i) -> void:
	input_locked = true
	player_controller.enabled = false
	var moving_unit := selected_unit
	var source := moving_unit.grid_position
	var captured_unit := grid_manager.get_unit_at(destination) as BattleUnit
	var captured_master := captured_unit != null and captured_unit.is_master
	grid_manager.clear_highlights()
	if captured_unit != null:
		captured_unit.apply_damage(captured_unit.current_hp)
		await captured_unit.play_death(moving_unit.global_position)
	var path: Array[Vector2i] = [source, destination]
	await unit_movement.move_unit(moving_unit, path, grid_manager)
	moving_unit.grid_position = destination
	grid_manager.move_occupant(moving_unit, source, destination)
	var used_card: MovementCard = hands[current_player][selected_card_slot]
	hands[current_player][selected_card_slot] = pass_card
	pass_card = used_card
	_deselect_unit()
	if captured_master:
		_finish_battle(current_player)
		return
	_advance_turn()


func _advance_turn() -> void:
	current_player = 1 - current_player
	camera_controller.set_player_view(current_player)
	if current_player == 0:
		round_number += 1
	selected_card_slot = -1
	var bot_turn := bot_opponent_enabled and current_player == 1
	input_locked = bot_turn
	player_controller.enabled = not bot_turn
	turn_manager.set_state(TurnManager.BattleState.PLAYER_SELECT_UNIT)
	_refresh_ui()
	if bot_turn:
		battle_ui.set_instruction("The bot is thinking...")
		call_deferred("_run_bot_turn")
	else:
		battle_ui.set_instruction("Player %d: choose a movement card, then a figure and a highlighted destination." % (current_player + 1))


func _run_bot_turn() -> void:
	await get_tree().create_timer(0.4).timeout
	if battle_over or current_player != 1 or not bot_opponent_enabled:
		return
	var choice := _choose_bot_move()
	if choice.is_empty():
		input_locked = false
		player_controller.enabled = true
		battle_ui.set_instruction("The bot has no legal move. Select a figure to continue.")
		return
	selected_card_slot = int(choice["slot"])
	_select_unit(choice["unit"] as BattleUnit)
	await get_tree().create_timer(0.18).timeout
	if not battle_over and current_player == 1:
		await _perform_move(choice["destination"])


func _choose_bot_move() -> Dictionary:
	var player_master := _find_master(players)
	if player_master == null:
		return {}
	var best_score := -INF
	var best_moves: Array[Dictionary] = []
	for unit: BattleUnit in enemies:
		if unit.is_dead:
			continue
		for slot: int in range(2):
			var card: MovementCard = hands[1][slot]
			for destination: Vector2i in card.destinations(unit.grid_position, 1, grid_manager.grid_size.x):
				var target := grid_manager.get_unit_at(destination) as BattleUnit
				if target != null and target.team_id == 1:
					continue
				var old_distance := grid_manager.manhattan_distance(unit.grid_position, player_master.grid_position)
				var new_distance := grid_manager.manhattan_distance(destination, player_master.grid_position)
				var score := float(old_distance - new_distance) * 20.0 + randf()
				if target == player_master:
					score += 10000.0
				elif target != null:
					score += 250.0
				if score > best_score:
					best_score = score
					best_moves.clear()
					best_moves.append({"unit": unit, "slot": slot, "destination": destination})
				elif is_equal_approx(score, best_score):
					best_moves.append({"unit": unit, "slot": slot, "destination": destination})
	return best_moves.pick_random() if not best_moves.is_empty() else {}


func _find_master(team: Array[BattleUnit]) -> BattleUnit:
	for unit: BattleUnit in team:
		if unit.is_master and not unit.is_dead:
			return unit
	return null


func _deselect_unit() -> void:
	if selected_unit != null:
		selected_unit.set_selected(false)
	selected_unit = null
	movement_targets.clear()
	grid_manager.clear_highlights()


func _on_unit_died(unit: BattleUnit) -> void:
	grid_manager.remove_occupant(unit.grid_position, unit)


func _finish_battle(winner: int) -> void:
	battle_over = true
	input_locked = true
	player_controller.enabled = false
	turn_manager.set_state(TurnManager.BattleState.VICTORY if winner == 0 else TurnManager.BattleState.DEFEAT)
	battle_ui.show_result("PLAYER %d WINS" % (winner + 1))


func _refresh_ui() -> void:
	battle_ui.update_header(current_player, round_number)
	battle_ui.update_hands(hands, pass_card, current_player, selected_card_slot)
	battle_ui.update_selection(selected_unit)


func _on_cancel_requested() -> void:
	if input_locked or battle_over:
		return
	if selected_unit != null:
		_deselect_unit()
		_refresh_ui()
		battle_ui.set_instruction("Selection cleared. Choose a card and figure.")
	else:
		battle_ui.toggle_menu(true)


func _restart_battle() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()