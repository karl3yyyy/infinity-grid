class_name PlayerController
extends Node

signal cell_clicked(coordinate: Vector2i)
signal cancel_requested

var camera_controller: CameraController
var grid_manager: GridManager
var enabled: bool = true
var mouse_suppressed_until_msec: int = 0
var touch_click_count: int = 0
var cell_click_emission_count: int = 0

const TOUCH_MOUSE_SUPPRESSION_MSEC: int = 650
const TAP_MAX_MSEC: int = 420
const LONG_PRESS_MSEC: int = 620
const DRAG_THRESHOLD: float = 14.0

var _touch_positions: Dictionary = {}
var _touch_starts: Dictionary = {}
var _touch_started_at: Dictionary = {}
var _touch_moved: Dictionary = {}
var _ui_touch_indices: Dictionary = {}
var _long_press_sent: bool = false


func setup(camera: CameraController, grid: GridManager) -> void:
	camera_controller = camera
	grid_manager = grid


func _process(_delta: float) -> void:
	if camera_controller == null or grid_manager == null:
		return
	var coordinate := _mouse_grid_coordinate()
	grid_manager.set_hover(coordinate)
	if _touch_positions.size() == 1 and not _long_press_sent:
		var index: int = _touch_positions.keys()[0]
		var held_msec := Time.get_ticks_msec() - int(_touch_started_at.get(index, Time.get_ticks_msec()))
		if held_msec >= LONG_PRESS_MSEC and not bool(_touch_moved.get(index, false)):
			_long_press_sent = true
			cancel_requested.emit()


func _input(event: InputEvent) -> void:
	if not enabled or camera_controller == null or grid_manager == null:
		return
	if event is InputEventScreenTouch:
		if _handle_screen_touch(event):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag:
		if _handle_screen_drag(event):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		if Time.get_ticks_msec() < mouse_suppressed_until_msec:
			get_viewport().set_input_as_handled()
			return
		var hovered_control := get_viewport().gui_get_hovered_control()
		if hovered_control is Button:
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			var coordinate := _screen_to_grid(event.position)
			if grid_manager.is_inside(coordinate):
				cell_click_emission_count += 1
				cell_clicked.emit(coordinate)
			else:
				cancel_requested.emit()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_requested.emit()
			get_viewport().set_input_as_handled()


func _handle_screen_touch(event: InputEventScreenTouch) -> bool:
	mouse_suppressed_until_msec = Time.get_ticks_msec() + TOUCH_MOUSE_SUPPRESSION_MSEC
	if event.pressed:
		if _is_over_interactive_control(event.position):
			_ui_touch_indices[event.index] = true
			return false
		_touch_positions[event.index] = event.position
		_touch_starts[event.index] = event.position
		_touch_started_at[event.index] = Time.get_ticks_msec()
		_touch_moved[event.index] = false
		_long_press_sent = false
		return true
	if _ui_touch_indices.has(event.index):
		_ui_touch_indices.erase(event.index)
		return false
	var started_at := int(_touch_started_at.get(event.index, Time.get_ticks_msec()))
	var moved := bool(_touch_moved.get(event.index, true))
	var was_single_touch := _touch_positions.size() == 1
	_touch_positions.erase(event.index)
	_touch_starts.erase(event.index)
	_touch_started_at.erase(event.index)
	_touch_moved.erase(event.index)
	if was_single_touch and not moved and not _long_press_sent and Time.get_ticks_msec() - started_at <= TAP_MAX_MSEC:
		var coordinate := _screen_to_grid(event.position)
		if grid_manager.is_inside(coordinate):
			touch_click_count += 1
			cell_click_emission_count += 1
			cell_clicked.emit(coordinate)
		else:
			cancel_requested.emit()
	_long_press_sent = false
	return true


func _handle_screen_drag(event: InputEventScreenDrag) -> bool:
	mouse_suppressed_until_msec = Time.get_ticks_msec() + TOUCH_MOUSE_SUPPRESSION_MSEC
	if _ui_touch_indices.has(event.index):
		return false
	var previous: Vector2 = _touch_positions.get(event.index, event.position - event.relative)
	_touch_positions[event.index] = event.position
	var start: Vector2 = _touch_starts.get(event.index, event.position)
	if event.position.distance_to(start) >= DRAG_THRESHOLD:
		_touch_moved[event.index] = true
	if _touch_positions.size() == 1:
		camera_controller.pan_by_screen_delta(event.relative)
		return true
	if _touch_positions.size() == 2:
		var indices: Array = _touch_positions.keys()
		var first_index: int = indices[0]
		var second_index: int = indices[1]
		var current_a: Vector2 = _touch_positions[first_index]
		var current_b: Vector2 = _touch_positions[second_index]
		var previous_a := current_a
		var previous_b := current_b
		if first_index == event.index:
			previous_a = previous
		else:
			previous_b = previous
		var distance_delta := current_a.distance_to(current_b) - previous_a.distance_to(previous_b)
		camera_controller.zoom_by_gesture(distance_delta)
		var current_angle := (current_b - current_a).angle()
		var previous_angle := (previous_b - previous_a).angle()
		camera_controller.rotate_by_gesture(angle_difference(previous_angle, current_angle))
	return true


func _is_over_interactive_control(screen_position: Vector2) -> bool:
	for node: Node in get_tree().get_nodes_in_group("interactive_ui"):
		var control := node as Control
		if control != null and control.is_visible_in_tree() and control.get_global_rect().has_point(screen_position):
			return true
	return false


func is_mouse_event_suppressed() -> bool:
	return Time.get_ticks_msec() < mouse_suppressed_until_msec


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
