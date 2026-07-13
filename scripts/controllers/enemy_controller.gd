class_name EnemyController
extends Node

signal enemy_activated(enemy: BattleUnit)
signal enemy_turn_finished

const ACTION_TIMEOUT_SECONDS: float = 4.0

var grid_manager: GridManager
var movement: UnitMovement
var attack_action: AttackAction
var ranged_attack_action: RangedAttackAction
var heal_action: HealAction
var camera_controller: CameraController
var _action_serial: int = 0
var _completed_actions: Dictionary = {}


func setup(
	grid: GridManager,
	unit_movement: UnitMovement,
	melee_attack: AttackAction,
	ranged_attack: RangedAttackAction,
	healing: HealAction,
	camera: CameraController
) -> void:
	grid_manager = grid
	movement = unit_movement
	attack_action = melee_attack
	ranged_attack_action = ranged_attack
	heal_action = healing
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
		await get_tree().create_timer(0.22).timeout
		_action_serial += 1
		var serial := _action_serial
		_dispatch_action(serial, enemy, enemies, living_players)
		var deadline := Time.get_ticks_msec() + int(ACTION_TIMEOUT_SECONDS * 1000.0)
		while not _completed_actions.has(serial) and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		if not _completed_actions.has(serial):
			push_warning("Enemy action exceeded the %.1f second safety budget: %s" % [ACTION_TIMEOUT_SECONDS, enemy.unit_name])
		else:
			_completed_actions.erase(serial)
		enemy.finish_action()
		await get_tree().create_timer(0.16).timeout
	enemy_turn_finished.emit()


func _dispatch_action(
	serial: int,
	enemy: BattleUnit,
	allies: Array[BattleUnit],
	players: Array[BattleUnit]
) -> void:
	match enemy.unit_class_id:
		UnitClassData.UnitClass.ARCHER:
			await _run_archer(enemy, players)
		UnitClassData.UnitClass.PRIEST:
			await _run_priest(enemy, allies, players)
		_:
			await _run_swordsman(enemy, players)
	_completed_actions[serial] = true


func _run_swordsman(enemy: BattleUnit, players: Array[BattleUnit]) -> void:
	var target := _nearest_target(enemy, players)
	if target == null:
		return
	if grid_manager.manhattan_distance(enemy.grid_position, target.grid_position) > 1:
		await _move_toward_adjacent(enemy, target)
	if attack_action.can_attack(enemy, target, grid_manager):
		await attack_action.execute(enemy, target, grid_manager)


func _run_archer(enemy: BattleUnit, players: Array[BattleUnit]) -> void:
	var target := _nearest_target(enemy, players)
	if target == null:
		return
	var distance := grid_manager.manhattan_distance(enemy.grid_position, target.grid_position)
	if distance < enemy.attack_min_range or not ranged_attack_action.can_attack(enemy, target, grid_manager):
		await _move_for_range(enemy, target, enemy.attack_min_range, enemy.attack_range, 3)
	var available_targets := players.filter(func(unit: BattleUnit) -> bool:
		return ranged_attack_action.can_attack(enemy, unit, grid_manager)
	)
	if not available_targets.is_empty():
		var ranged_target := _nearest_target(enemy, available_targets)
		await ranged_attack_action.execute(enemy, ranged_target, grid_manager)


func _run_priest(enemy: BattleUnit, allies: Array[BattleUnit], players: Array[BattleUnit]) -> void:
	var wounded := _lowest_health_ratio_ally(enemy, allies)
	if wounded != null and float(wounded.current_hp) / float(wounded.max_hp) < 0.5:
		if not heal_action.can_heal(enemy, wounded, grid_manager):
			await _move_for_range(enemy, wounded, enemy.heal_min_range, enemy.heal_range, 2)
		if heal_action.can_heal(enemy, wounded, grid_manager):
			await heal_action.execute(enemy, wounded, grid_manager)
			return
	var target := _nearest_target(enemy, players)
	if target == null:
		return
	if not ranged_attack_action.can_attack(enemy, target, grid_manager):
		await _move_for_range(enemy, target, enemy.attack_min_range, enemy.attack_range, 3)
	var available_targets := players.filter(func(unit: BattleUnit) -> bool:
		return ranged_attack_action.can_attack(enemy, unit, grid_manager)
	)
	if not available_targets.is_empty():
		var bolt_target := _nearest_target(enemy, available_targets)
		await ranged_attack_action.execute(enemy, bolt_target, grid_manager)


func _lowest_health_ratio_ally(priest: BattleUnit, allies: Array[BattleUnit]) -> BattleUnit:
	var lowest: BattleUnit
	var lowest_ratio: float = 2.0
	for ally: BattleUnit in allies:
		if ally == priest or ally.is_dead or ally.current_hp >= ally.max_hp:
			continue
		var ratio := float(ally.current_hp) / float(ally.max_hp)
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			lowest = ally
	return lowest


func _nearest_target(enemy: BattleUnit, targets: Array[BattleUnit]) -> BattleUnit:
	var nearest: BattleUnit
	var nearest_distance: int = 9999
	for target: BattleUnit in targets:
		var distance_value := grid_manager.manhattan_distance(enemy.grid_position, target.grid_position)
		if distance_value < nearest_distance:
			nearest_distance = distance_value
			nearest = target
	return nearest


func _move_toward_adjacent(enemy: BattleUnit, target: BattleUnit) -> void:
	var best_path: Array[Vector2i] = []
	for candidate: Vector2i in grid_manager.get_neighbors(target.grid_position):
		if grid_manager.get_unit_at(candidate) != null:
			continue
		var path := grid_manager.find_path(enemy.grid_position, candidate, enemy)
		if path.size() > 1 and (best_path.is_empty() or path.size() < best_path.size()):
			best_path = path
	await _move_along_limited_path(enemy, best_path)


func _move_for_range(
	enemy: BattleUnit,
	target: BattleUnit,
	minimum_range: int,
	maximum_range: int,
	preferred_range: int
) -> void:
	var reachable := grid_manager.get_reachable(enemy.grid_position, enemy.movement_range, enemy)
	var best_coordinate := enemy.grid_position
	var best_score: int = -99999
	for candidate: Vector2i in reachable:
		if candidate != enemy.grid_position and grid_manager.get_unit_at(candidate) != null:
			continue
		var score := score_ranged_position(candidate, target.grid_position, minimum_range, maximum_range, preferred_range)
		if score > best_score:
			best_score = score
			best_coordinate = candidate
	if best_coordinate == enemy.grid_position:
		return
	var path := grid_manager.find_path(enemy.grid_position, best_coordinate, enemy)
	await _move_along_limited_path(enemy, path)


func score_ranged_position(
	candidate: Vector2i,
	target: Vector2i,
	minimum_range: int,
	maximum_range: int,
	preferred_range: int
) -> int:
	var distance := grid_manager.manhattan_distance(candidate, target)
	var in_range := distance >= minimum_range and distance <= maximum_range
	var has_sight := grid_manager.has_line_of_sight(candidate, target)
	var score := -absi(distance - preferred_range) * 12
	if in_range:
		score += 80
	if has_sight:
		score += 70
	if distance < minimum_range:
		score -= 50
	return score


func _move_along_limited_path(enemy: BattleUnit, path: Array[Vector2i]) -> void:
	if path.size() <= 1:
		return
	var last_index := mini(enemy.movement_range, path.size() - 1)
	var movement_path: Array[Vector2i] = []
	for index: int in range(last_index + 1):
		movement_path.append(path[index])
	var old_coordinate := enemy.grid_position
	await movement.move_unit(enemy, movement_path, grid_manager)
	enemy.grid_position = movement_path[-1]
	grid_manager.move_occupant(enemy, old_coordinate, enemy.grid_position)
	enemy.has_moved = true
