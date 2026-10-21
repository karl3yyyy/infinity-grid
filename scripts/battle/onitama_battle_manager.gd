class_name OnitamaBattleManager
extends Node

const PlayerUnitScript := preload("res://scripts/units/player_unit.gd")
const EnemyUnitScript := preload("res://scripts/units/enemy_unit.gd")
const MovementCardScript := preload("res://scripts/battle/movement_card.gd")
const BotAIScript := preload("res://scripts/battle/bot_ai.gd")

var grid_manager: GridManager
var camera_controller: CameraController
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
var bot_difficulty: int = BotAI.Difficulty.MEDIUM
## Cards dealt for this match (hands + pass); the bot indexes into this list.
var match_cards: Array[MovementCard] = []


func setup(
	grid: GridManager,
	camera: CameraController,
	ui: OnitamaUI,
	player_input: PlayerController,
	movement: UnitMovement,
	unit_container: Node3D
) -> void:
	grid_manager = grid
	camera_controller = camera
	battle_ui = ui
	battle_ui.set_opponent_bot(bot_opponent_enabled)
	battle_ui.board_insets_changed.connect(camera_controller.set_board_insets)
	var insets := battle_ui.get_board_insets()
	camera_controller.set_board_insets(insets.x, insets.y)
	player_controller = player_input
	unit_movement = movement
	units_parent = unit_container
	player_controller.cell_clicked.connect(_on_cell_clicked)
	player_controller.cancel_requested.connect(_on_cancel_requested)
	battle_ui.card_selected.connect(_on_card_selected)
	battle_ui.bot_training_requested.connect(_start_bot_training)
	battle_ui.local_multiplayer_requested.connect(_start_local_multiplayer)
	battle_ui.restart_pressed.connect(_restart_battle)
	battle_ui.quit_pressed.connect(func() -> void: get_tree().quit())
	_deal_cards()
	_spawn_armies()
	call_deferred("_show_title_menu")


func _deal_cards() -> void:
	var deck := MovementCardScript.draw_match_cards(5)
	match_cards = deck.duplicate()
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
			unit.is_master = is_master
			# Figurines face the opposing side, like pieces on a real board.
			unit.rest_yaw = PI if team_id == 0 else 0.0
			unit.rotation.y = unit.rest_yaw
			unit.scale = Vector3.ONE * (1.18 if is_master else 1.0)
			units_parent.add_child(unit)
			unit.position = grid_manager.grid_to_world(coordinate)
			unit.create_wrap_projections(units_parent, float(grid_manager.grid_size.x) * GridManager.CELL_SIZE)
			team.append(unit)
			grid_manager.set_occupant(coordinate, unit)
			unit.died.connect(_on_unit_died)


func _show_title_menu() -> void:
	input_locked = true
	player_controller.enabled = false
	grid_manager.get_parent().visible = false
	battle_ui.main_menu.open_menu(false)
	camera_controller.set_player_view(0)
	_refresh_ui()
	battle_ui.set_instruction("Wähle einen Spielmodus.")


func _start_bot_training() -> void:
	if battle_over:
		return
	battle_ui.main_menu.close_menu()
	grid_manager.get_parent().visible = true
	bot_opponent_enabled = true
	_set_creature_visible(true)
	bot_difficulty = battle_ui.main_menu.bot_difficulty
	battle_ui.set_opponent_bot(true, BotAI.label_for(bot_difficulty))
	input_locked = false
	player_controller.enabled = true
	camera_controller.set_player_view(current_player)
	_refresh_ui()
	battle_ui.set_instruction("Wähle eine Karte und eine Figur, dann ein leuchtendes Feld.")


func _start_local_multiplayer() -> void:
	if battle_over:
		return
	battle_ui.main_menu.close_menu()
	grid_manager.get_parent().visible = true
	bot_opponent_enabled = false
	# The table creature would block the board once the camera turns around.
	_set_creature_visible(false)
	battle_ui.set_opponent_bot(false)
	input_locked = false
	player_controller.enabled = true
	camera_controller.set_player_view(0)
	_refresh_ui()
	battle_ui.set_instruction("Spieler 1 beginnt. Nach jedem Zug das Gerät weitergeben.")


func _on_card_selected(team_id: int, slot: int) -> void:
	if input_locked or battle_over or team_id != current_player or slot < 0 or slot >= 2:
		return
	selected_card_slot = slot
	_refresh_targets()
	_refresh_ui()
	if selected_unit == null:
		battle_ui.set_instruction("Wähle jetzt eine deiner Figuren.")
	elif movement_targets.is_empty():
		battle_ui.set_instruction("Mit dieser Karte kann die Figur nicht ziehen.")
	else:
		battle_ui.set_instruction("Tippe auf ein leuchtendes Feld. Die goldene Kante ist der Übergang.")


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
		battle_ui.set_instruction("Wähle zuerst eine deiner zwei Karten.")
	else:
		battle_ui.set_instruction("Dieses Feld erlaubt die Karte nicht.")


func _select_unit(unit: BattleUnit) -> void:
	if selected_unit != null:
		selected_unit.set_selected(false)
	selected_unit = unit
	selected_unit.set_selected(true)
	_refresh_targets()
	_refresh_ui()
	if selected_card_slot < 0:
		battle_ui.set_instruction("Wähle jetzt eine deiner zwei Karten.")
	elif movement_targets.is_empty():
		battle_ui.set_instruction("Diese Figur hat mit der Karte kein Zielfeld.")
	else:
		battle_ui.set_instruction("Tippe auf ein leuchtendes Feld. Wer den Meister schlägt, gewinnt.")


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
	if not bot_opponent_enabled:
		camera_controller.set_player_view(current_player)
	if current_player == 0:
		round_number += 1
	selected_card_slot = -1
	var bot_turn := bot_opponent_enabled and current_player == 1
	input_locked = bot_turn
	player_controller.enabled = not bot_turn
	_refresh_ui()
	if bot_turn:
		battle_ui.set_instruction("Der Bot denkt nach ...")
		call_deferred("_run_bot_turn")
	else:
		battle_ui.set_instruction("Wähle eine Karte und eine Figur." if bot_opponent_enabled else "Spieler %d: Wähle eine Karte und eine Figur." % (current_player + 1))


func _run_bot_turn() -> void:
	await get_tree().create_timer(0.4).timeout
	if battle_over or current_player != 1 or not bot_opponent_enabled:
		return
	# Let the "thinking" text render before the search blocks the frame.
	await get_tree().process_frame
	var choice := _choose_bot_move()
	if choice.is_empty():
		input_locked = false
		player_controller.enabled = true
		battle_ui.set_instruction("Der Bot kann nicht ziehen. Du bist wieder dran.")
		return
	selected_card_slot = int(choice["slot"])
	_select_unit(choice["unit"] as BattleUnit)
	await get_tree().create_timer(0.18).timeout
	if not battle_over and current_player == 1:
		await _perform_move(choice["destination"])


func _choose_bot_move() -> Dictionary:
	var ai: BotAI = BotAIScript.new(bot_difficulty)
	var result := ai.choose_move(build_ai_state(), 1)
	if result.is_empty():
		return {}
	var unit := grid_manager.get_unit_at(result["from"]) as BattleUnit
	if unit == null:
		return {}
	return {"unit": unit, "slot": int(result["slot"]), "destination": result["to"]}


## Compact copy of the match for BotAI; never shares scene nodes.
func build_ai_state() -> Dictionary:
	var pieces := PackedInt32Array()
	var teams := PackedInt32Array()
	pieces.resize(25)
	teams.resize(25)
	for team: Array[BattleUnit] in [players, enemies]:
		for unit: BattleUnit in team:
			if unit.is_dead:
				continue
			var cell := unit.grid_position.y * 5 + unit.grid_position.x
			pieces[cell] = 2 if unit.is_master else 1
			teams[cell] = unit.team_id
	var cards: Array[MovementCard] = []
	for card: MovementCard in match_cards:
		cards.append(card)
	for card: MovementCard in [hands[0][0], hands[0][1], hands[1][0], hands[1][1], pass_card]:
		if card not in cards:
			cards.append(card)
	return {
		"pieces": pieces,
		"teams": teams,
		"hands": [
			[cards.find(hands[0][0]), cards.find(hands[0][1])],
			[cards.find(hands[1][0]), cards.find(hands[1][1])],
		],
		"pass": cards.find(pass_card),
		"cards": cards,
	}


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
	if bot_opponent_enabled:
		battle_ui.show_result("SIEG!" if winner == 0 else "NIEDERLAGE")
	else:
		battle_ui.show_result("SPIELER %d GEWINNT" % (winner + 1))


func _refresh_ui() -> void:
	battle_ui.update_header(current_player, round_number)
	battle_ui.update_hands(hands, pass_card, current_player, selected_card_slot, _viewer_team())
	battle_ui.update_selection(selected_unit)


func _set_creature_visible(value: bool) -> void:
	var arena := get_parent().get_node_or_null("Arena") as ArenaEnvironment
	if arena != null:
		arena.set_opponent_creature_visible(value)


func _viewer_team() -> int:
	return current_player if not bot_opponent_enabled else 0


func _on_cancel_requested() -> void:
	if input_locked or battle_over:
		return
	if selected_unit != null:
		_deselect_unit()
		_refresh_ui()
		battle_ui.set_instruction("Auswahl aufgehoben. Wähle Karte und Figur.")
	else:
		battle_ui.toggle_menu(true)


func _restart_battle() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()