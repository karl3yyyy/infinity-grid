class_name UnitMovement
extends Node

signal movement_started(unit: BattleUnit)
signal movement_finished(unit: BattleUnit)


func move_unit(unit: BattleUnit, path: Array[Vector2i], grid: GridManager) -> void:
	if path.size() <= 1 or unit.is_dead:
		return
	movement_started.emit(unit)
	unit.set_animation_state(&"walk")
	for index: int in range(1, path.size()):
		var target_position: Vector3 = grid.grid_to_world(path[index])
		unit.face_world_position(target_position)
		var tween := unit.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(unit, "position", target_position, 0.22)
		await tween.finished
		unit.position = target_position
	unit.set_animation_state(&"idle")
	movement_finished.emit(unit)

