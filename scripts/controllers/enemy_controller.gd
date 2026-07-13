class_name EnemyController
extends Node

signal enemy_activated(enemy: BattleUnit)
signal enemy_turn_finished

var grid_manager: GridManager
var movement: UnitMovement
var attack_action: AttackAction
var camera_controller: CameraController


func setup(
	grid: GridManager,
	unit_movement: UnitMovement,
	attack: AttackAction,
	camera: CameraController
) -> void:
	grid_manager = grid
	movement = unit_movement
	attack_action = attack
	camera_controller = camera


func run_turn(enemies: Array[BattleUnit], players: Array[BattleUnit]) -> void:
	for enemy: BattleUnit in enemies:
		if enemy.is_dead:
			continue
		var living_players := players.filter(func(unit: BattleUnit) -> bool: return not unit.is_dead)
		if living_players.is_empty():
			break
		enemy_activated.emit(enemy)
		camera_controller.focus_on(enemy.global_position)
		await get_tree().create_timer(0.32).timeout
		var target := _nearest_target(enemy, living_players)
		if target == null:
			continue
		if grid_manager.manhattan_distance(enemy.grid_position, target.grid_position) > 1:
			await _move_toward_target(enemy, target)
		if not enemy.is_dead and not target.is_dead and attack_action.can_attack(enemy, target, grid_manager):
			await attack_action.execute(enemy, target, grid_manager)
		enemy.finish_action()
		await get_tree().create_timer(0.24).timeout
	enemy_turn_finished.emit()


func _nearest_target(enemy: BattleUnit, players: Array[BattleUnit]) -> BattleUnit:
	var nearest: BattleUnit = null
	var nearest_distance: int = 9999
	for player: BattleUnit in players:
		var distance_value := grid_manager.manhattan_distance(enemy.grid_position, player.grid_position)
		if distance_value < nearest_distance:
			nearest_distance = distance_value
			nearest = player
	return nearest


func _move_toward_target(enemy: BattleUnit, target: BattleUnit) -> void:
	var best_path: Array[Vector2i] = []
	for candidate: Vector2i in grid_manager.get_neighbors(target.grid_position):
		if grid_manager.get_unit_at(candidate) != null:
			continue
		var path := grid_manager.find_path(enemy.grid_position, candidate, enemy)
		if path.size() > 1 and (best_path.is_empty() or path.size() < best_path.size()):
			best_path = path
	if best_path.size() <= 1:
		return
	var last_index: int = mini(enemy.movement_range, best_path.size() - 1)
	var movement_path: Array[Vector2i] = []
	for index: int in range(last_index + 1):
		movement_path.append(best_path[index])
	var old_coordinate := enemy.grid_position
	await movement.move_unit(enemy, movement_path, grid_manager)
	enemy.grid_position = movement_path[-1]
	grid_manager.move_occupant(enemy, old_coordinate, enemy.grid_position)
	enemy.has_moved = true

