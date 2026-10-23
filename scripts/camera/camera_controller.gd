class_name CameraController
extends Camera3D

var focus_point: Vector3 = Vector3.ZERO
var target_focus: Vector3 = Vector3.ZERO
var distance: float = 11.5
var target_distance: float = 11.5
var yaw: float = 0.0
var target_yaw: float = 0.0
var pitch: float = deg_to_rad(54.0)
var pan_speed: float = 7.0
var _shake_time: float = 0.0
var _shake_strength: float = 0.0
## Screen pixels covered by the card trays above and below the board.
var board_insets: Vector2 = Vector2.ZERO
## World units visible vertically for the whole board including figures.
const BOARD_VISUAL_DEPTH: float = 7.6


func _ready() -> void:
	current = true
	projection = PROJECTION_ORTHOGONAL
	fov = 48.0
	near = 0.1
	far = 100.0
	get_viewport().size_changed.connect(_update_framing)
	_update_framing()
	_update_camera(1.0)


func _process(delta: float) -> void:
	var input_vector := Input.get_vector("camera_left", "camera_right", "camera_forward", "camera_back")
	if input_vector.length_squared() > 0.0:
		var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var right := Vector3(forward.z, 0.0, -forward.x)
		target_focus += (right * input_vector.x + forward * input_vector.y) * pan_speed * delta
		target_focus.x = clampf(target_focus.x, -7.5, 7.5)
		target_focus.z = clampf(target_focus.z, -7.5, 7.5)
	if Input.is_action_pressed("camera_rotate_left"):
		target_yaw -= delta * 1.35
	if Input.is_action_pressed("camera_rotate_right"):
		target_yaw += delta * 1.35
	_update_camera(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_distance = maxf(9.0, target_distance - 1.2)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_distance = minf(23.0, target_distance + 1.2)


func focus_on(world_position: Vector3) -> void:
	target_focus = Vector3(world_position.x, 0.0, world_position.z)


func set_player_view(team_id: int) -> void:
	target_focus = Vector3.ZERO
	target_yaw = 0.0 if team_id == 0 else PI


func set_board_insets(top_pixels: float, bottom_pixels: float) -> void:
	board_insets = Vector2(maxf(0.0, top_pixels), maxf(0.0, bottom_pixels))
	_update_framing()


func shake(strength: float, duration: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_time = maxf(_shake_time, duration)


func pan_by_screen_delta(relative: Vector2) -> void:
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(forward.z, 0.0, -forward.x)
	var scale_factor := distance * 0.0018
	target_focus += (-right * relative.x + forward * relative.y) * scale_factor
	target_focus.x = clampf(target_focus.x, -7.5, 7.5)
	target_focus.z = clampf(target_focus.z, -7.5, 7.5)


func zoom_by_gesture(distance_delta: float) -> void:
	target_distance = clampf(target_distance - distance_delta * 0.018, 9.0, 23.0)


func rotate_by_gesture(angle_delta: float) -> void:
	target_yaw += angle_delta


func _update_camera(delta: float) -> void:
	var weight := 1.0 if delta >= 1.0 else 1.0 - exp(-delta * 7.0)
	focus_point = focus_point.lerp(target_focus, weight)
	distance = lerpf(distance, target_distance, weight)
	size = distance
	_apply_inset_offset()
	yaw = lerp_angle(yaw, target_yaw, weight)
	var horizontal_distance := cos(pitch) * distance
	var offset := Vector3(
		sin(yaw) * horizontal_distance,
		sin(pitch) * distance,
		cos(yaw) * horizontal_distance
	)
	var shake_offset := Vector3.ZERO
	if _shake_time > 0.0:
		_shake_time -= delta
		shake_offset = Vector3(randf_range(-1.0, 1.0), randf_range(-0.35, 0.35), randf_range(-1.0, 1.0)) * _shake_strength
	else:
		_shake_strength = 0.0
	global_position = focus_point + offset + shake_offset
	look_at(focus_point + Vector3(0.0, 0.25, 0.0), Vector3.UP)


func _update_framing() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var aspect_ratio := viewport_size.x / viewport_size.y
	# On phones only a sliver of the wrapped copies shows, so the board itself is big.
	var repeated_side_cells := 0.3 if aspect_ratio < 0.8 else 1.5
	var total_board_width := (5.0 + repeated_side_cells * 2.0) * 1.4
	var free_height := maxf(viewport_size.y * 0.3, viewport_size.y - board_insets.x - board_insets.y)
	var width_fit := total_board_width / aspect_ratio
	var height_fit := BOARD_VISUAL_DEPTH * viewport_size.y / free_height
	target_distance = maxf(7.4, maxf(width_fit, height_fit))
	distance = target_distance
	_apply_inset_offset()


## Shifts the orthographic view so the board sits centred between the trays.
func _apply_inset_offset() -> void:
	var viewport_height := get_viewport().get_visible_rect().size.y
	if viewport_height <= 0.0:
		return
	var pixel_shift := (board_insets.x - board_insets.y) * 0.5
	v_offset = pixel_shift * size / viewport_height
