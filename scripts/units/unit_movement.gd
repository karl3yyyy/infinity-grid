class_name UnitMovement
extends Node

signal movement_started(unit: BattleUnit)
signal movement_finished(unit: BattleUnit)


func move_unit(unit: BattleUnit, path: Array[Vector2i], grid: GridManager) -> void:
	if path.size() <= 1 or unit.is_dead:
		return
	movement_started.emit(unit)
	unit.play_walk()
	for index: int in range(1, path.size()):
		var source: Vector2i = path[index - 1]
		var destination: Vector2i = path[index]
		var target_position: Vector3 = grid.grid_to_world(path[index])
		if _crosses_wrap(source, destination, grid):
			await _move_across_wrap(unit, source, destination, target_position, grid)
		else:
			unit.face_world_position(target_position)
			var tween := unit.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(unit, "position", target_position, 0.22)
			await tween.finished
			unit.position = target_position
	unit.play_idle()
	var turn_back := unit.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	turn_back.tween_property(unit, "rotation:y", unit.rest_yaw, 0.18)
	await turn_back.finished
	movement_finished.emit(unit)


func _move_across_wrap(
	unit: BattleUnit,
	source: Vector2i,
	destination: Vector2i,
	target_position: Vector3,
	grid: GridManager
) -> void:
	var direction := -1.0 if destination.x > source.x else 1.0
	var offset := Vector3(direction * grid.CELL_SIZE * 0.52, 0.0, 0.0)
	var source_edge := unit.position + offset
	var destination_edge := target_position - offset
	var resting_scale := unit.scale
	unit.face_world_position(source_edge)
	var exit_tween := unit.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	exit_tween.set_parallel(true)
	exit_tween.tween_property(unit, "position", source_edge, 0.13)
	exit_tween.tween_property(unit, "scale", resting_scale * 0.55, 0.13)
	await exit_tween.finished
	unit.position = destination_edge
	var enter_tween := unit.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	enter_tween.set_parallel(true)
	enter_tween.tween_property(unit, "position", target_position, 0.15)
	enter_tween.tween_property(unit, "scale", resting_scale, 0.15)
	await enter_tween.finished
	unit.position = target_position
	unit.scale = resting_scale


## A move whose column distance is more than half the board goes over the edge.
func _crosses_wrap(source: Vector2i, destination: Vector2i, grid: GridManager) -> bool:
	return absi(source.x - destination.x) * 2 > grid.grid_size.x


## Moves a piece in its character's fighting style; a captured piece is
## destroyed on the way. Styles (see CharacterRoster.STYLES):
##   mage     - raises a hand, a rune circle appears, then teleports there
##   brawler  - runs up and punches the target apart, then steps in
##   gunner   - aims and shoots, then walks over
##   sorcerer - throws lightning, then dashes over
func perform_move(unit: BattleUnit, victim: BattleUnit, source: Vector2i, destination: Vector2i, grid: GridManager, style: String, accent: Color) -> void:
	var path: Array[Vector2i] = [source, destination]
	if unit.rig == null:
		if victim != null:
			await victim.play_death(unit.global_position)
		await move_unit(unit, path, grid)
		return
	movement_started.emit(unit)
	var target_position := grid.grid_to_world(destination)
	# Across the edge the target is the visible copy right next to the attacker.
	var aim := target_position
	if _crosses_wrap(source, destination, grid):
		var board_width := float(grid.grid_size.x) * GridManager.CELL_SIZE
		aim.x += board_width if destination.x < source.x else -board_width
	var effects_parent := unit.get_parent()
	unit.facing_locked = true
	unit.face_world_position(aim)
	match style:
		"mage":
			await _mage(unit, victim, aim, target_position, effects_parent, accent)
		"brawler":
			await _brawler(unit, victim, source, destination, aim, target_position, grid, effects_parent, accent)
		"gunner":
			if victim != null:
				await unit.rig.pose("aim", 0.2)
				unit.rig.pose("shoot")
				await CombatEffects.projectile(effects_parent, _hand_position(unit), aim + Vector3(0.0, 0.8, 0.0), accent)
				CombatEffects.burst(effects_parent, aim + Vector3(0.0, 0.8, 0.0), accent, 0.5)
				await victim.shatter(unit.global_position, accent)
				await unit.rig.release(0.15)
			await _walk(unit, source, destination, target_position, grid)
		_:
			if victim != null:
				await unit.rig.pose("channel", 0.22)
				CombatEffects.lightning(effects_parent, _hand_position(unit), aim + Vector3(0.0, 0.7, 0.0), accent)
				CombatEffects.burst(effects_parent, aim + Vector3(0.0, 0.7, 0.0), accent.lightened(0.4), 0.55)
				await victim.shatter(unit.global_position, accent)
				await unit.rig.release(0.15)
			await _dash(unit, source, destination, target_position, grid, effects_parent, accent)
	unit.position = target_position
	unit.facing_locked = false
	var turn_back := unit.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	turn_back.tween_property(unit, "rotation:y", unit.rest_yaw, 0.18)
	await turn_back.finished
	movement_finished.emit(unit)


func _mage(unit: BattleUnit, victim: BattleUnit, aim: Vector3, target_position: Vector3, parent: Node, accent: Color) -> void:
	await unit.rig.pose("cast", 0.22)
	var circle := CombatEffects.magic_circle(parent, aim, accent)
	await get_tree().create_timer(0.35).timeout
	if victim != null:
		CombatEffects.burst(parent, aim + Vector3(0.0, 0.6, 0.0), accent, 0.8)
		await victim.shatter(unit.global_position, accent)
	# Vanish in a column of light and reappear on the circle.
	CombatEffects.pillar(parent, unit.global_position, accent)
	var vanish := unit.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	vanish.tween_property(unit.visual_root, "scale", Vector3(0.05, 1.7, 0.05), 0.16)
	await vanish.finished
	unit.position = target_position
	CombatEffects.pillar(parent, target_position, accent)
	var appear := unit.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	appear.tween_property(unit.visual_root, "scale", Vector3.ONE, 0.22)
	CombatEffects.dismiss(circle)
	await appear.finished
	await unit.rig.release(0.2)


func _brawler(unit: BattleUnit, victim: BattleUnit, source: Vector2i, destination: Vector2i, aim: Vector3, target_position: Vector3, grid: GridManager, parent: Node, accent: Color) -> void:
	if victim == null:
		await _walk(unit, source, destination, target_position, grid)
		return
	# Run up, stopping just in front of the target.
	unit.play_walk()
	var start := unit.position
	var approach := start.lerp(aim, 1.0 - 0.75 / maxf(start.distance_to(aim), 0.8))
	var run := unit.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	run.tween_property(unit, "position", approach, clampf(start.distance_to(approach) * 0.22, 0.12, 0.45))
	await run.finished
	unit.play_idle()
	await unit.rig.pose("wind_up", 0.14)
	await unit.rig.pose("punch", 0.07)
	CombatEffects.burst(parent, aim + Vector3(0.0, 0.8, 0.0), Color(1.0, 0.95, 0.8), 0.45)
	await victim.shatter(unit.global_position, accent)
	await unit.rig.release(0.12)
	if _crosses_wrap(source, destination, grid):
		unit.play_walk()
		await _move_across_wrap(unit, source, destination, target_position, grid)
		unit.play_idle()
	else:
		await _walk_to(unit, target_position)


func _walk(unit: BattleUnit, source: Vector2i, destination: Vector2i, target_position: Vector3, grid: GridManager) -> void:
	if _crosses_wrap(source, destination, grid):
		unit.play_walk()
		await _move_across_wrap(unit, source, destination, target_position, grid)
		unit.play_idle()
	else:
		await _walk_to(unit, target_position)


func _walk_to(unit: BattleUnit, target_position: Vector3) -> void:
	unit.play_walk()
	var walk := unit.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	walk.tween_property(unit, "position", target_position, clampf(unit.position.distance_to(target_position) * 0.24, 0.15, 0.6))
	await walk.finished
	unit.play_idle()


func _dash(unit: BattleUnit, source: Vector2i, destination: Vector2i, target_position: Vector3, grid: GridManager, parent: Node, accent: Color) -> void:
	if _crosses_wrap(source, destination, grid):
		await _move_across_wrap(unit, source, destination, target_position, grid)
		return
	CombatEffects.burst(parent, unit.global_position + Vector3(0.0, 0.6, 0.0), accent, 0.35)
	var dash := unit.create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)
	dash.tween_property(unit, "position", target_position, 0.2)
	await dash.finished


## Roughly where the raised right hand is, for shots and bolts.
func _hand_position(unit: BattleUnit) -> Vector3:
	var forward := unit.global_transform.basis.z.normalized()
	var right := unit.global_transform.basis.x.normalized()
	return unit.global_position + forward * 0.45 - right * 0.3 + Vector3(0.0, 1.0 * unit.scale.y, 0.0)
