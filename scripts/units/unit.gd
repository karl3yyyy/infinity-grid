class_name BattleUnit
extends Node3D

signal died(unit: BattleUnit)


var unit_name: String = "Unit"
var team_id: int = 0
var grid_position: Vector2i = Vector2i.ZERO
var is_master: bool = false
var is_dead: bool = false
## Yaw the figure returns to after moving (faces the opposing side).
var rest_yaw: float = 0.0

## Holds the plinth, the team glow and the fighter (see apply_figure).
var visual_root: Node3D
var selection_ring: MeshInstance3D
var status_label: Label3D

var _team_color: Color = Color("3a8fe7")
var _accent_color: Color = Color("d7ecff")
var _wrap_projections: Array[Dictionary] = []
## The character's pixel-art fighter once applied.
var rig: FighterSprite
## While true the figure faces where the piece points (moving, attacking)
## instead of turning to the viewer.
var facing_locked: bool = false


func configure(
	display_name: String,
	new_team_id: int,
	coordinate: Vector2i,
	team_color: Color,
	accent_color: Color
) -> void:
	unit_name = display_name
	team_id = new_team_id
	grid_position = coordinate
	_team_color = team_color
	_accent_color = accent_color
	name = display_name.replace(" ", "_")


func _ready() -> void:
	_build_model()
	_update_status_label()


func _process(_delta: float) -> void:
	_face_viewer()
	_sync_wrap_projections()


func create_wrap_projections(parent: Node, board_width: float) -> void:
	for side: int in [-1, 1]:
		var projection_root := Node3D.new()
		projection_root.name = "%s_Wrap_%d" % [name, side]
		parent.add_child(projection_root)
		var projection_visual := visual_root.duplicate() as Node3D
		projection_visual.name = "VisualProjection"
		projection_root.add_child(projection_visual)
		_set_projection_transparency(projection_visual, 0.48)
		var projection_ring := selection_ring.duplicate() as MeshInstance3D
		projection_ring.name = "SelectionProjection"
		projection_root.add_child(projection_ring)
		_set_projection_transparency(projection_ring, 0.58)
		var projection_label := status_label.duplicate() as Label3D
		projection_label.name = "StatusProjection"
		projection_root.add_child(projection_label)
		projection_label.modulate.a = 0.52
		_wrap_projections.append({
			"root": projection_root,
			"visual": projection_visual,
			"ring": projection_ring,
			"label": projection_label,
			"offset": float(side) * board_width,
		})
	_sync_wrap_projections()


## Puts the character's fighter (see FighterSprite) on a small glowing plinth. Called whenever the players' looks are known (match
## start, opponent's choice arriving).
func apply_figure(figure: Node3D) -> void:
	var old := visual_root.get_node_or_null("Standee")
	if old != null:
		visual_root.remove_child(old)
		old.queue_free()
	var standee := Node3D.new()
	standee.name = "Standee"
	visual_root.add_child(standee)

	var plinth := MeshInstance3D.new()
	var plinth_mesh := CylinderMesh.new()
	plinth_mesh.radial_segments = 6
	plinth_mesh.rings = 1
	plinth_mesh.top_radius = 0.36
	plinth_mesh.bottom_radius = 0.42
	plinth_mesh.height = 0.12
	plinth.mesh = plinth_mesh
	plinth.position.y = 0.06
	var plinth_material := StandardMaterial3D.new()
	plinth_material.albedo_color = Color("15181a")
	plinth_material.metallic = 0.6
	plinth_material.roughness = 0.35
	plinth_material.emission_enabled = true
	plinth_material.emission = _aura_color()
	plinth_material.emission_energy_multiplier = 0.35
	plinth.material_override = plinth_material
	standee.add_child(plinth)

	figure.position.y = 0.12
	standee.add_child(figure)
	rig = figure as FighterSprite
	if rig == null:
		refresh_projections()


## Fighters face the player so every character shows its face; while a piece
## moves or attacks the model inside the sprite turns where the piece points.
func _face_viewer() -> void:
	if rig == null or is_dead:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	visual_root.rotation.y = 0.0
	rig.turn = wrapf(global_rotation.y - camera.global_rotation.y, -PI, PI) if facing_locked else 0.0


func set_selected(value: bool) -> void:
	selection_ring.visible = value and not is_dead


func play_idle() -> void:
	if rig != null:
		rig.walking = false


func play_walk() -> void:
	if rig != null:
		rig.walking = true


func face_world_position(target_position: Vector3) -> void:
	var flat_target := Vector3(target_position.x, global_position.y, target_position.z)
	if global_position.distance_squared_to(flat_target) > 0.001:
		look_at(flat_target, Vector3.UP, true)


## Removes a captured piece that has no fighter yet (the fighters break apart
## in shatter()).
func play_death(_from_position: Vector3 = Vector3.INF) -> void:
	if is_dead:
		return
	is_dead = true
	_hide_auras()
	selection_ring.visible = false
	visual_root.visible = false
	await get_tree().process_frame
	died.emit(self)


func _hide_auras() -> void:
	var roots: Array[Node] = [visual_root]
	for projection: Dictionary in _wrap_projections:
		roots.append(projection["visual"])
	for root: Node in roots:
		var aura := root.get_node_or_null("TeamAura") as Node3D
		if aura != null:
			aura.visible = false


func _build_model() -> void:
	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)
	selection_ring = MeshInstance3D.new()
	selection_ring.name = "SelectionRing"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.43
	ring.outer_radius = 0.50
	selection_ring.mesh = ring
	selection_ring.position.y = 0.035
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color("ffe56b")
	ring_material.emission_enabled = true
	ring_material.emission = Color("ffe56b")
	ring_material.emission_energy_multiplier = 2.0
	selection_ring.material_override = ring_material
	selection_ring.visible = false
	add_child(selection_ring)
	if is_master:
		var master_base := MeshInstance3D.new()
		master_base.name = "MasterBase"
		var master_base_mesh := CylinderMesh.new()
		master_base_mesh.top_radius = 0.55
		master_base_mesh.bottom_radius = 0.60
		master_base_mesh.height = 0.07
		master_base.mesh = master_base_mesh
		master_base.position.y = 0.04
		var master_material := StandardMaterial3D.new()
		master_material.albedo_color = Color("e6b84f")
		master_material.metallic = 0.58
		master_material.roughness = 0.35
		master_base.material_override = master_material
		add_child(master_base)

	status_label = Label3D.new()
	status_label.name = "StatusLabel"
	status_label.position = Vector3(0.0, 2.05, 0.0)
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status_label.font_size = 30
	status_label.outline_size = 6
	status_label.modulate = _accent_color
	add_child(status_label)

	# Role is shown by the plinth and aura instead of floating text.
	status_label.visible = false
	_build_team_aura()


func _aura_color() -> Color:
	return Color("3fa9ff") if team_id == 0 else Color("ff4f3a")


## Glowing team ring under every figure; masters also get a gold ring.
func _build_team_aura() -> void:
	var aura := Node3D.new()
	aura.name = "TeamAura"
	visual_root.add_child(aura)
	var color := _aura_color()
	var glow := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.25, 1.25)
	glow.mesh = plane
	glow.position.y = 0.03
	var glow_material := StandardMaterial3D.new()
	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 0.75, 1.0])
	gradient.colors = PackedColorArray([Color(color, 0.05), Color(color, 0.25), Color(color, 0.9), Color(color, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	glow_material.albedo_texture = texture
	glow.material_override = glow_material
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura.add_child(glow)
	if not is_master:
		return
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.52
	torus.outer_radius = 0.6
	ring.mesh = torus
	ring.position.y = 0.05
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("e2b04a")
	gold.metallic = 0.9
	gold.roughness = 0.25
	gold.emission_enabled = true
	gold.emission = Color("c98a24")
	gold.emission_energy_multiplier = 1.2
	ring.material_override = gold
	aura.add_child(ring)



func _update_status_label() -> void:
	if status_label != null:
		status_label.text = _role_name()


func _role_name() -> String:
	return "KERN" if is_master else "SCHÜLER"


func _sync_wrap_projections() -> void:
	if _wrap_projections.is_empty() or visual_root == null:
		return
	for index: int in range(_wrap_projections.size()):
		var projection: Dictionary = _wrap_projections[index]
		var projection_root := projection["root"] as Node3D
		projection_root.global_position = global_position + Vector3(float(projection["offset"]), 0.0, 0.0)
		projection_root.global_rotation = global_rotation
		projection_root.scale = scale
		var projection_visual := projection["visual"] as Node3D
		projection_visual.position = visual_root.position
		projection_visual.rotation = visual_root.rotation
		projection_visual.scale = visual_root.scale
		var projection_ring := projection["ring"] as MeshInstance3D
		projection_ring.position = selection_ring.position
		projection_ring.rotation = selection_ring.rotation
		projection_ring.visible = selection_ring.visible
		var projection_label := projection["label"] as Label3D
		projection_label.position = status_label.position
		projection_label.text = status_label.text
		projection_label.modulate = status_label.modulate
		projection_label.modulate.a = 0.52


## The edge projections copy the visual; refresh them after it changed. The
## fighter sprite itself is not copied (it renders its own world); the copies
## show the same frames through a mirror quad.
func refresh_projections() -> void:
	var standee := visual_root.get_node_or_null("Standee")
	if rig != null and standee != null:
		standee.remove_child(rig)
	for index: int in range(_wrap_projections.size()):
		var projection: Dictionary = _wrap_projections[index]
		var old_visual := projection["visual"] as Node3D
		var projection_root := projection["root"] as Node3D
		var fresh := visual_root.duplicate() as Node3D
		fresh.name = "VisualProjection"
		projection_root.remove_child(old_visual)
		old_visual.queue_free()
		projection_root.add_child(fresh)
		_set_projection_transparency(fresh, 0.48)
		projection["visual"] = fresh
		_wrap_projections[index] = projection
		if rig != null:
			var mirror := rig.make_mirror()
			mirror.position = rig.display.position
			fresh.get_node("Standee").add_child(mirror)
	if rig != null and standee != null:
		standee.add_child(rig)


## Breaks the fighter apart into flying pieces (captured pieces).
func shatter(from_position: Vector3, color: Color) -> void:
	if is_dead:
		return
	is_dead = true
	_hide_auras()
	selection_ring.visible = false
	if rig != null:
		# Knocked out first, then the body breaks apart into the grid.
		await rig.play_death()
	var origin := global_position + Vector3(0.0, 0.7, 0.0)
	CombatEffects.shatter(get_parent(), origin, (origin - from_position).normalized(), _figure_colors(color), color)
	visual_root.visible = false
	for projection: Dictionary in _wrap_projections:
		(projection["visual"] as Node3D).visible = false
	await get_tree().create_timer(0.25).timeout
	died.emit(self)


## Debris colours: dark suit pieces, skin and the attacker's glow.
func _figure_colors(glow: Color) -> Array[Color]:
	return [Color("101114"), Color("1c1f24"), Color("c99a7a"), _aura_color(), glow, Color("6ee65a")]


func _set_projection_transparency(node: Node, transparency_amount: float) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.transparency = transparency_amount
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in node.get_children():
		_set_projection_transparency(child, transparency_amount)
