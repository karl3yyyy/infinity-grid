class_name BattleManager
extends Node

const PlayerUnitScript := preload("res://scripts/units/player_unit.gd")
const EnemyUnitScript := preload("res://scripts/units/enemy_unit.gd")

var grid_manager: GridManager
var turn_manager: TurnManager
var battle_ui: BattleUI
var camera_controller: CameraController
var player_controller: PlayerController
var enemy_controller: EnemyController
var unit_movement: UnitMovement
var attack_action: AttackAction
var units_parent: Node3D

var players: Array[BattleUnit] = []
var enemies: Array[BattleUnit] = []
var selected_unit: BattleUnit = null
var reachable_cells: Array[Vector2i] = []
var attack_target_mode: bool = false
var input_locked: bool = true
var battle_over: bool = false


func setup(
	grid: GridManager,
	turns: TurnManager,
	ui: BattleUI,
	camera: CameraController,
	player_input: PlayerController,
	enemy_ai: EnemyController,
	movement: UnitMovement,
	attack: AttackAction,
	unit_container: Node3D
) -> void:
	grid_manager = grid
	turn_manager = turns
	battle_ui = ui
	camera_controller = camera
	player_controller = player_input
	enemy_controller = enemy_ai
	unit_movement = movement
	attack_action = attack
	units_parent = unit_container
	_connect_signals()
	_spawn_armies()
	call_deferred("_start_battle")


func _connect_signals() -> void:
	player_controller.cell_clicked.connect(_on_cell_clicked)
	player_controller.cancel_requested.connect(_on_cancel_pressed)
	battle_ui.attack_pressed.connect(_on_attack_pressed)
	battle_ui.wait_pressed.connect(_on_wait_pressed)
	battle_ui.cancel_pressed.connect(_on_cancel_pressed)
	battle_ui.end_turn_pressed.connect(_on_end_turn_pressed)
	battle_ui.restart_pressed.connect(_restart_battle)
	battle_ui.quit_pressed.connect(func() -> void: get_tree().quit())
	enemy_controller.enemy_activated.connect(_on_enemy_activated)
	enemy_controller.enemy_turn_finished.connect(_on_enemy_turn_finished)
	turn_manager.state_changed.connect(_on_state_changed)
	turn_manager.round_changed.connect(func(_round: int) -> void: _refresh_header())
	attack_action.damage_applied.connect(_on_damage_applied)


func _spawn_armies() -> void:
	var player_starts: Array[Vector2i] = [Vector2i(1, 8), Vector2i(3, 8), Vector2i(5, 8)]
	var enemy_starts: Array[Vector2i] = [Vector2i(8, 1), Vector2i(6, 1), Vector2i(4, 1)]
	for index: int in range(3):
		var player: BattleUnit = PlayerUnitScript.new()
		player.setup_player("Swordsman %s" % char(65 + index), player_starts[index])
		units_parent.add_child(player)
		player.position = grid_manager.grid_to_world(player.grid_position)
		_register_unit(player, players)
		var enemy: BattleUnit = EnemyUnitScript.new()
		enemy.setup_enemy("Raider %d" % (index + 1), enemy_starts[index])
		units_parent.add_child(enemy)
		enemy.position = grid_manager.grid_to_world(enemy.grid_position)
		enemy.rotation_degrees.y = 180.0
		_register_unit(enemy, enemies)


func _register_unit(unit: BattleUnit, team: Array[BattleUnit]) -> void:
	team.append(unit)
	grid_manager.set_occupant(unit.grid_position, unit)
	unit.died.connect(_on_unit_died)
	unit.health_changed.connect(func(changed_unit: BattleUnit) -> void:
		if changed_unit == selected_unit:
			battle_ui.update_unit(changed_unit)
	)


func _start_battle() -> void:
	turn_manager.set_state(TurnManager.BattleState.BATTLE_START)
	await get_tree().create_timer(0.35).timeout
	_begin_player_turn(false)


func _begin_player_turn(increment_round: bool) -> void:
	if battle_over:
		return
	for unit: BattleUnit in players:
		if not unit.is_dead:
			unit.begin_turn()
	_deselect_unit()
	turn_manager.start_player_round(increment_round)
	turn_manager.set_state(TurnManager.BattleState.PLAYER_SELECT_UNIT)
	input_locked = false
	player_controller.enabled = true
	battle_ui.set_actions(false, false, false, true)
	battle_ui.set_instruction("Select a blue swordsman • WASD/Arrows pan • Q/E rotate • Wheel zoom")
	_refresh_header()


func _begin_enemy_turn() -> void:
	if battle_over:
		return
	input_locked = true
	player_controller.enabled = false
	_deselect_unit()
	for unit: BattleUnit in enemies:
		if not unit.is_dead:
			unit.begin_turn()
	turn_manager.set_state(TurnManager.BattleState.ENEMY_TURN_START)
	battle_ui.set_actions(false, false, false, false)
	battle_ui.set_instruction("Enemy squad is acting…")
	await get_tree().create_timer(0.42).timeout
	turn_manager.set_state(TurnManager.BattleState.ENEMY_ACTING)
	await enemy_controller.run_turn(enemies, players)


func _on_cell_clicked(coordinate: Vector2i) -> void:
	if input_locked or battle_over or turn_manager.state >= TurnManager.BattleState.ENEMY_TURN_START:
		return
	var clicked_node: Node = grid_manager.get_unit_at(coordinate)
	var clicked_unit: BattleUnit = clicked_node as BattleUnit
	if selected_unit == null:
		if clicked_unit != null and clicked_unit.team_id == 0 and clicked_unit.can_act():
			_select_unit(clicked_unit)
		return
	if clicked_unit != null and clicked_unit.team_id == 0:
		if clicked_unit.can_act():
			_select_unit(clicked_unit)
		return
	if clicked_unit != null and clicked_unit.team_id != selected_unit.team_id:
		if attack_action.can_attack(selected_unit, clicked_unit, grid_manager):
			await _perform_player_attack(clicked_unit)
		return
	if attack_target_mode:
		battle_ui.set_instruction("Choose a red enemy on an adjacent highlighted tile, or right-click to cancel.")
		return
	if not selected_unit.has_moved and coordinate in reachable_cells and clicked_unit == null:
		await _perform_player_move(coordinate)


func _select_unit(unit: BattleUnit) -> void:
	if selected_unit != null:
		selected_unit.set_selected(false)
	selected_unit = unit
	selected_unit.set_selected(true)
	attack_target_mode = false
	camera_controller.focus_on(unit.global_position)
	battle_ui.update_unit(unit)
	if not unit.has_moved:
		reachable_cells = grid_manager.get_reachable(unit.grid_position, unit.movement_range, unit)
		grid_manager.show_reachable(reachable_cells, unit.grid_position)
		turn_manager.set_state(TurnManager.BattleState.PLAYER_SELECT_MOVE)
		battle_ui.set_instruction("Choose a blue tile to move, or attack an adjacent red enemy.")
	else:
		reachable_cells.clear()
		grid_manager.clear_highlights()
		turn_manager.set_state(TurnManager.BattleState.PLAYER_SELECT_ACTION)
		battle_ui.set_instruction("Choose ATTACK or WAIT.")
	_refresh_action_buttons()


func _perform_player_move(destination: Vector2i) -> void:
	var path := grid_manager.find_path(selected_unit.grid_position, destination, selected_unit)
	if path.size() <= 1 or path.size() - 1 > selected_unit.movement_range:
		return
	input_locked = true
	player_controller.enabled = false
	turn_manager.set_state(TurnManager.BattleState.UNIT_MOVING)
	grid_manager.clear_highlights()
	battle_ui.set_actions(false, false, false, false)
	var original_coordinate := selected_unit.grid_position
	await unit_movement.move_unit(selected_unit, path, grid_manager)
	selected_unit.grid_position = destination
	grid_manager.move_occupant(selected_unit, original_coordinate, destination)
	selected_unit.has_moved = true
	input_locked = false
	player_controller.enabled = true
	turn_manager.set_state(TurnManager.BattleState.PLAYER_SELECT_ACTION)
	battle_ui.update_unit(selected_unit)
	battle_ui.set_instruction("Movement complete. ATTACK an adjacent enemy or WAIT.")
	_refresh_action_buttons()


func _on_attack_pressed() -> void:
	if input_locked or selected_unit == null or selected_unit.has_attacked:
		return
	var targets := _adjacent_enemy_coordinates(selected_unit)
	if targets.is_empty():
		return
	attack_target_mode = true
	turn_manager.set_state(TurnManager.BattleState.PLAYER_SELECT_TARGET)
	grid_manager.show_attackable(targets, selected_unit.grid_position)
	battle_ui.set_instruction("Select an adjacent red enemy to slash. Damage lands at blade impact.")
	battle_ui.set_actions(false, true, true, true)


func _perform_player_attack(target: BattleUnit) -> void:
	input_locked = true
	player_controller.enabled = false
	attack_target_mode = false
	turn_manager.set_state(TurnManager.BattleState.UNIT_ATTACKING)
	grid_manager.clear_highlights()
	battle_ui.set_actions(false, false, false, false)
	await attack_action.execute(selected_unit, target, grid_manager)
	if battle_over:
		return
	battle_ui.update_unit(selected_unit)
	input_locked = false
	player_controller.enabled = true
	if selected_unit.has_moved and selected_unit.has_attacked:
		selected_unit.set_exhausted(true)
		_deselect_unit()
		turn_manager.set_state(TurnManager.BattleState.PLAYER_SELECT_UNIT)
		battle_ui.set_instruction("Select another blue swordsman, or end the turn.")
	else:
		_select_unit(selected_unit)
	_check_auto_end_player_turn()


func _on_wait_pressed() -> void:
	if input_locked or selected_unit == null:
		return
	selected_unit.finish_action()
	_deselect_unit()
	turn_manager.set_state(TurnManager.BattleState.PLAYER_SELECT_UNIT)
	battle_ui.set_instruction("Unit is waiting. Select another swordsman, or end the turn.")
	_check_auto_end_player_turn()


func _on_cancel_pressed() -> void:
	if input_locked or selected_unit == null:
		return
	if attack_target_mode:
		attack_target_mode = false
		_select_unit(selected_unit)
	elif not selected_unit.has_moved:
		_deselect_unit()
		turn_manager.set_state(TurnManager.BattleState.PLAYER_SELECT_UNIT)
		battle_ui.set_instruction("Selection cancelled. Choose a blue swordsman.")


func _on_end_turn_pressed() -> void:
	if input_locked or battle_over:
		return
	_begin_enemy_turn()


func _on_enemy_activated(enemy: BattleUnit) -> void:
	if battle_over:
		return
	battle_ui.update_unit(enemy)
	battle_ui.set_instruction("%s is choosing an action…" % enemy.unit_name)


func _on_enemy_turn_finished() -> void:
	if not battle_over:
		_begin_player_turn(true)


func _on_unit_died(unit: BattleUnit) -> void:
	grid_manager.remove_occupant(unit.grid_position, unit)
	if unit == selected_unit:
		selected_unit = null
	_check_battle_result()


func _on_damage_applied(_attacker: BattleUnit, target: BattleUnit, _damage: int) -> void:
	if target == selected_unit:
		battle_ui.update_unit(target)


func _check_battle_result() -> void:
	turn_manager.set_state(TurnManager.BattleState.CHECK_BATTLE_RESULT)
	var players_alive := players.any(func(unit: BattleUnit) -> bool: return not unit.is_dead)
	var enemies_alive := enemies.any(func(unit: BattleUnit) -> bool: return not unit.is_dead)
	if not enemies_alive:
		_finish_battle(true)
	elif not players_alive:
		_finish_battle(false)


func _finish_battle(victory: bool) -> void:
	battle_over = true
	input_locked = true
	player_controller.enabled = false
	grid_manager.clear_highlights()
	turn_manager.set_state(TurnManager.BattleState.VICTORY if victory else TurnManager.BattleState.DEFEAT)
	battle_ui.update_header(turn_manager.round_number, "BATTLE COMPLETE")
	battle_ui.show_result(victory)


func _deselect_unit() -> void:
	if selected_unit != null:
		selected_unit.set_selected(false)
	selected_unit = null
	attack_target_mode = false
	reachable_cells.clear()
	if grid_manager != null:
		grid_manager.clear_highlights()
	if battle_ui != null:
		battle_ui.update_unit(null)
		battle_ui.set_actions(false, false, false, not input_locked)


func _adjacent_enemy_coordinates(unit: BattleUnit) -> Array[Vector2i]:
	var coordinates: Array[Vector2i] = []
	for coordinate: Vector2i in grid_manager.get_neighbors(unit.grid_position):
		var node: Node = grid_manager.get_unit_at(coordinate)
		var target: BattleUnit = node as BattleUnit
		if target != null and not target.is_dead and target.team_id != unit.team_id:
			coordinates.append(coordinate)
	return coordinates


func _refresh_action_buttons() -> void:
	if selected_unit == null:
		battle_ui.set_actions(false, false, false, true)
		return
	var has_target := not _adjacent_enemy_coordinates(selected_unit).is_empty()
	battle_ui.set_actions(
		not selected_unit.has_attacked and has_target,
		true,
		not selected_unit.has_moved,
		true
	)


func _check_auto_end_player_turn() -> void:
	if players.all(func(unit: BattleUnit) -> bool: return unit.is_dead or not unit.can_act()):
		_begin_enemy_turn()


func _on_state_changed(_state: TurnManager.BattleState) -> void:
	_refresh_header()


func _refresh_header() -> void:
	if battle_ui == null or turn_manager == null:
		return
	var phase := "PLAYER PHASE"
	if turn_manager.state in [TurnManager.BattleState.ENEMY_TURN_START, TurnManager.BattleState.ENEMY_ACTING]:
		phase = "ENEMY PHASE"
	elif turn_manager.state == TurnManager.BattleState.BATTLE_START:
		phase = "DEPLOYMENT"
	battle_ui.update_header(turn_manager.round_number, phase)


func _restart_battle() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

