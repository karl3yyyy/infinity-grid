class_name Card3D
extends Node3D

## One movement card as a 3D object. Units are screen pixels (the stage scales
## them), the face is the flat CardView rendered into a SubViewport texture.

const FACE_SUPERSAMPLE: int = 2
const HALO_PADDING: float = 28.0
const FACE_MARGIN: float = 5.0
const MATRIX_GREEN := Color("46ff6e")

var card: MovementCard
var face_size: Vector2 = Vector2.ZERO
## Which hand slot the card sits in; filled in by the stage.
var team_id: int = -1
var slot: int = -1
## Pixel scale the card rests at (hand size, pass size).
var rest_scale: float = 1.0

var _viewport: SubViewport
var _view: CardView
var _quad: MeshInstance3D
var _material: ShaderMaterial
var _selected: float = 0.0
var _hover: float = 0.0
var _selected_target: bool = false
var _hover_target: bool = false
## Free-moving cards (flying, shuffling) are driven by the stage's tweens.
var animated: bool = false
var tilt: Vector2 = Vector2.ZERO
## Set by the stage from the hand layout.
var interactive: bool = false
var anchor: Control
## +1 for the bottom hand, -1 for the top one: which way "towards the board" is.
var lift_direction: float = 1.0
var face_key: String = ""

var _pillar_root: Node3D
var _pillar_holders: Array[Node3D] = []
var _pillar_material: StandardMaterial3D
var _cap_material: StandardMaterial3D
var _team_color: Color = Color.WHITE
var _rotated: bool = false
var _reveal: float = 1.0
var _dimmed: bool = false
var _pillar_cell: float = 20.0
var _glow: Color = MATRIX_GREEN


func _init() -> void:
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.size_2d_override_stretch = true
	add_child(_viewport)
	_view = CardView.new()
	# It lives in a texture, not on screen: no clicks, and it must not block touches.
	_view.remove_from_group("interactive_ui")
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_view)

	_quad = MeshInstance3D.new()
	_quad.mesh = QuadMesh.new()
	_material = CardMatrixShader.make_material()
	_material.set_shader_parameter("face_tex", _viewport.get_texture())
	_material.set_shader_parameter("seed", randf() * 50.0)
	_quad.material_override = _material
	add_child(_quad)

	_pillar_root = Node3D.new()
	add_child(_pillar_root)
	_pillar_material = StandardMaterial3D.new()
	_pillar_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pillar_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pillar_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_pillar_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_pillar_material.no_depth_test = true
	_cap_material = _pillar_material.duplicate()


func set_face_size(new_size: Vector2) -> void:
	if new_size.is_equal_approx(face_size) or new_size.x < 8.0 or new_size.y < 8.0:
		return
	face_size = new_size
	_viewport.size = Vector2i(new_size * float(FACE_SUPERSAMPLE))
	_viewport.size_2d_override = Vector2i(new_size)
	_view.size = new_size
	var padded := new_size + Vector2.ONE * HALO_PADDING * 2.0
	(_quad.mesh as QuadMesh).size = padded
	_material.set_shader_parameter("card_size", new_size)
	_material.set_shader_parameter("pad", HALO_PADDING)
	_material.set_shader_parameter("margin", FACE_MARGIN)
	_material.set_shader_parameter("cut", clampf((new_size.x - FACE_MARGIN * 2.0) * 0.09, 6.0, 16.0))
	_redraw_face()
	_rebuild_pillars()


func show_card(new_card: MovementCard, rotated: bool, color: Color) -> void:
	card = new_card
	_view.show_card(new_card, rotated, color, false)
	_material.set_shader_parameter("team_color", color)
	_team_color = color
	_rotated = rotated
	_redraw_face()
	_rebuild_pillars()


## Colours and back pattern of a CardSkins entry.
func apply_skin(skin: Dictionary) -> void:
	_glow = skin["glow"]
	_material.set_shader_parameter("glow_color", skin["glow"])
	_material.set_shader_parameter("rain_color", skin["rain"])
	_material.set_shader_parameter("base_color", skin["base"])
	_material.set_shader_parameter("back_mode", int(skin["mode"]))
	_material.set_shader_parameter("rain_speed", float(skin["speed"]))


func set_dimmed(value: bool) -> void:
	_dimmed = value
	_material.set_shader_parameter("dim", 1.0 if value else 0.0)


func set_selected(value: bool) -> void:
	_selected_target = value


func set_hovered(value: bool) -> void:
	_hover_target = value


func is_selected() -> bool:
	return _selected_target


func set_appear(value: float) -> void:
	_material.set_shader_parameter("appear", value)


func set_reveal(value: float) -> void:
	_reveal = value
	_material.set_shader_parameter("reveal", value)


func set_flash(value: float) -> void:
	_material.set_shader_parameter("flash", value)


func get_flash() -> float:
	return float(_material.get_shader_parameter("flash"))


## Rectangle of the card face in its own pixel space.
func face_half_extent() -> Vector2:
	return face_size * 0.5 - Vector2.ONE * FACE_MARGIN


func _process(delta: float) -> void:
	var weight := 1.0 - exp(-delta * 12.0)
	_selected = lerpf(_selected, 1.0 if _selected_target else 0.0, weight)
	_hover = lerpf(_hover, 1.0 if _hover_target else 0.0, weight)
	_material.set_shader_parameter("selected", _selected)
	_material.set_shader_parameter("hover", _hover)
	_update_pillars(Time.get_ticks_msec() / 1000.0)


func _redraw_face() -> void:
	if face_size.x < 8.0:
		return
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## The move targets rise from the card as light pillars (the white one is the
## figure itself); the picked card raises them higher and brighter.
func _rebuild_pillars() -> void:
	for holder: Node3D in _pillar_holders:
		holder.queue_free()
	_pillar_holders.clear()
	if card == null or face_size.x < 8.0:
		return
	var geometry := CardView.diagram_geometry(face_size)
	var origin: Vector2 = geometry["origin"]
	_pillar_cell = float(geometry["cell"])
	var cells: Array[Vector2i] = [Vector2i(2, 2)]
	for offset: Vector2i in card.offsets:
		cells.append(card.diagram_cell(offset, _rotated))
	for coordinate: Vector2i in cells:
		var center := origin + (Vector2(coordinate) + Vector2.ONE * 0.5) * _pillar_cell
		var width := _pillar_cell * (0.3 if coordinate == Vector2i(2, 2) else 0.58)
		var holder := Node3D.new()
		holder.position = Vector3(center.x - face_size.x * 0.5, face_size.y * 0.5 - center.y, 1.0)
		var shaft := MeshInstance3D.new()
		var shaft_mesh := BoxMesh.new()
		shaft_mesh.size = Vector3(width, width, 1.0)
		shaft.mesh = shaft_mesh
		shaft.position.z = 0.5
		shaft.material_override = _pillar_material
		var pivot := Node3D.new()
		pivot.add_child(shaft)
		holder.add_child(pivot)
		var cap := MeshInstance3D.new()
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(width * 1.12, width * 1.12, 2.0)
		cap.mesh = cap_mesh
		cap.material_override = _cap_material
		holder.add_child(cap)
		pivot.scale = Vector3(1.0, 1.0, 0.01)
		_pillar_root.add_child(holder)
		_pillar_holders.append(holder)


func _update_pillars(time: float) -> void:
	var grow := smoothstep(0.75, 1.0, _reveal)
	var height := _pillar_cell * (0.3 + _selected * 0.3) * grow
	for index: int in range(_pillar_holders.size()):
		var taller := 1.0
		var shaft_height := maxf(height * taller, 0.01)
		_pillar_holders[index].get_child(0).scale = Vector3(1.0, 1.0, shaft_height)
		(_pillar_holders[index].get_child(1) as Node3D).position.z = shaft_height
		(_pillar_holders[index].get_child(1) as Node3D).visible = grow > 0.05
	var tint := _team_color.lightened(0.35).lerp(_glow, _selected)
	tint.a = (0.1 if _dimmed else 0.22) + _selected * 0.15
	_pillar_material.albedo_color = Color(tint.r * 1.3, tint.g * 1.3, tint.b * 1.3, tint.a)
	var cap_tint := tint.lightened(0.55)
	cap_tint.a = 0.15 if _dimmed else 0.4
	cap_tint = Color(cap_tint.r * 1.5, cap_tint.g * 1.5, cap_tint.b * 1.5, cap_tint.a)
	_cap_material.albedo_color = cap_tint
