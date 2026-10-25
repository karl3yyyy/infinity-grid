class_name CameraController
extends Camera3D

var focus_point: Vector3 = Vector3.ZERO
var target_focus: Vector3 = Vector3.ZERO
var distance: float = 11.5
var target_distance: float = 11.5
var yaw: float = 0.0
var target_yaw: float = 0.0
var pitch: float = deg_to_rad(54.0)
## The view the match starts in; turning and zooming stay close to it.
var base_yaw: float = 0.0
var base_distance: float = 11.5
const MAX_YAW_OFFSET: float = 0.75
const ZOOM_IN_FACTOR: float = 0.7
const ZOOM_OUT_FACTOR: float = 1.2
## Board edge length in cells and whether its left/right copies show (the 4-player board is 9 and closed).
var board_cells: int = 5
var board_wraps: bool = true
var board_margin_cells: float = 0.0
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
	if Input.is_action_pressed("camera_rotate_left"):
		target_yaw -= delta * 1.35
	if Input.is_action_pressed("camera_rotate_right"):
		target_yaw += delta * 1.35
	_clamp_view()
	_update_camera(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_distance -= base_distance * 0.08
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_distance += base_distance * 0.08
		_clamp_view()


func _clamp_view() -> void:
	target_yaw = wrapf(target_yaw, -PI, PI)
	target_distance = clampf(target_distance, base_distance * ZOOM_IN_FACTOR, base_distance * ZOOM_OUT_FACTOR)


func focus_on(world_position: Vector3) -> void:
	target_focus = Vector3(world_position.x, 0.0, world_position.z)


func set_player_view(team_id: int) -> void:
	target_focus = Vector3.ZERO
	base_yaw = 0.0 if team_id == 0 else PI
	target_yaw = base_yaw


## margin_cells: extra room around the board (cards lying beside it).
func set_board(cells: int, wraps: bool, margin_cells: float = 0.0) -> void:
	board_cells = cells
	board_wraps = wraps
	board_margin_cells = margin_cells
	_update_framing()


## Four seats around a square board: 0 bottom, 1 left, 2 top, 3 right.
func set_seat_view(seat: int) -> void:
	target_focus = Vector3.ZERO
	base_yaw = [0.0, -PI * 0.5, PI, PI * 0.5][clampi(seat, 0, 3)]
	target_yaw = base_yaw


func set_board_insets(top_pixels: float, bottom_pixels: float) -> void:
	board_insets = Vector2(maxf(0.0, top_pixels), maxf(0.0, bottom_pixels))
	_update_framing()


func shake(strength: float, duration: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_time = maxf(_shake_time, duration)


func zoom_by_gesture(distance_delta: float) -> void:
	target_distance -= distance_delta * 0.018
	_clamp_view()


func rotate_by_gesture(angle_delta: float) -> void:
	target_yaw += angle_delta
	_clamp_view()


func rotate_by_drag(horizontal_pixels: float) -> void:
	target_yaw -= horizontal_pixels * 0.006
	_clamp_view()


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
	var repeated_side_cells := (0.3 if aspect_ratio < 0.8 else 1.5) if board_wraps else 0.0
	var total_board_width := (float(board_cells) + repeated_side_cells * 2.0 + board_margin_cells * 2.0) * 1.4
	var free_height := maxf(viewport_size.y * 0.3, viewport_size.y - board_insets.x - board_insets.y)
	var width_fit := total_board_width / aspect_ratio
	var height_fit := (BOARD_VISUAL_DEPTH + float(board_cells - 5 + board_margin_cells * 1.5) * 1.4) * viewport_size.y / free_height
	target_distance = maxf(7.4, maxf(width_fit, height_fit))
	base_distance = target_distance
	distance = target_distance
	_apply_inset_offset()


## Shifts the orthographic view so the board sits centred between the trays.
func _apply_inset_offset() -> void:
	var viewport_height := get_viewport().get_visible_rect().size.y
	if viewport_height <= 0.0:
		return
	var pixel_shift := (board_insets.x - board_insets.y) * 0.5
	v_offset = pixel_shift * size / viewport_height
