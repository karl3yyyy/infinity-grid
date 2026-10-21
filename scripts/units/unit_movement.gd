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
		if absi(source.x - destination.x) > 1:
			await _move_across_wrap(unit, source, destination, target_position, grid)
		else:
			unit.face_world_position(target_position)
			var tween := unit.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(unit, "position", target_position, 0.22)
			await tween.finished
			unit.position = target_position
	unit.play_idle()
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
