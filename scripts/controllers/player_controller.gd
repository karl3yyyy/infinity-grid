class_name PlayerController
extends Node

signal cell_clicked(coordinate: Vector2i)
signal cancel_requested

var camera_controller: CameraController
var grid_manager: GridManager
var enabled: bool = true


func setup(camera: CameraController, grid: GridManager) -> void:
	camera_controller = camera
	grid_manager = grid


func _process(_delta: float) -> void:
	if camera_controller == null or grid_manager == null:
		return
	var coordinate := _mouse_grid_coordinate()
	grid_manager.set_hover(coordinate)


func _input(event: InputEvent) -> void:
	if not enabled or camera_controller == null or grid_manager == null:
		return
	if event is InputEventMouseButton and event.pressed:
		var hovered_control := get_viewport().gui_get_hovered_control()
		if hovered_control is Button:
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			var coordinate := _screen_to_grid(event.position)
			if grid_manager.is_inside(coordinate):
				cell_clicked.emit(coordinate)
			else:
				cancel_requested.emit()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_requested.emit()
			get_viewport().set_input_as_handled()


func _mouse_grid_coordinate() -> Vector2i:
	return _screen_to_grid(get_viewport().get_mouse_position())


func _screen_to_grid(screen_position: Vector2) -> Vector2i:
	var ray_origin := camera_controller.project_ray_origin(screen_position)
	var ray_direction := camera_controller.project_ray_normal(screen_position)
	if absf(ray_direction.y) < 0.0001:
		return Vector2i(-1, -1)
	var distance_to_plane := -ray_origin.y / ray_direction.y
	if distance_to_plane < 0.0:
		return Vector2i(-1, -1)
	return grid_manager.world_to_grid(ray_origin + ray_direction * distance_to_plane)
