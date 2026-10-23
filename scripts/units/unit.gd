class_name BattleUnit
extends Node3D

signal died(unit: BattleUnit)

const MODEL_PATHS: Dictionary = {
	0: "res://assets/characters/player/player_swordsman.glb",
	1: "res://assets/characters/enemy/enemy_swordsman.glb",
}
const CreatureFigureScript := preload("res://scripts/units/creature_figure.gd")
const ANIMATION_MAP: Dictionary = {
	&"idle": [&"Idle", &"idle", &"Rig|Idle"],
	&"walk": [&"Walking_A", &"Walk", &"walk", &"Rig|Walking_A"],
	&"death": [&"Death_A", &"Death", &"death", &"Rig|Death_A"],
}

var unit_name: String = "Unit"
var team_id: int = 0
var grid_position: Vector2i = Vector2i.ZERO
var is_master: bool = false
var is_dead: bool = false
## Yaw the figure returns to after moving (faces the opposing side).
var rest_yaw: float = 0.0
var animation_state: StringName = &"idle"

var visual_root: Node3D
var torso_pivot: Node3D
var sword_arm_pivot: Node3D
var off_arm_pivot: Node3D
var left_leg_pivot: Node3D
var right_leg_pivot: Node3D
var sword_pivot: Node3D
var selection_ring: MeshInstance3D
var status_label: Label3D
var imported_model: Node3D
var animation_player: AnimationPlayer
var using_licensed_model: bool = false

var _team_color: Color = Color("3a8fe7")
var _accent_color: Color = Color("d7ecff")
var _materials: Array[StandardMaterial3D] = []
var _base_colors: Array[Color] = []
var _idle_time: float = 0.0
var _placeholder_root: Node3D
var _wrap_projections: Array[Dictionary] = []
## Animates the voxel figure once one is applied.
var rig: FigureRig
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


func _process(delta: float) -> void:
	_face_viewer()
	_sync_wrap_projections()
	if is_dead:
		return
	_idle_time += delta
	if animation_state == &"idle":
		visual_root.position.y = sin(_idle_time * 2.2) * 0.025
		sword_pivot.rotation_degrees.z = sin(_idle_time * 1.7) * 2.0
	elif animation_state == &"walk":
		var stride := sin(_idle_time * 12.0)
		left_leg_pivot.rotation_degrees.x = stride * 25.0
		right_leg_pivot.rotation_degrees.x = -stride * 25.0
		sword_arm_pivot.rotation_degrees.x = -stride * 14.0
		off_arm_pivot.rotation_degrees.x = stride * 14.0


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
			"animation_player": _find_animation_player(projection_visual),
			"animation_state": &"",
			"offset": float(side) * board_width,
		})
	_sync_wrap_projections()


## Replaces the creature figurine with a voxel figure (see VoxelFigure) on a
## small glowing plinth. Called whenever the players' looks are known (match
## start, opponent's choice arriving).
func apply_figure(figure: Node3D) -> void:
	var creature := visual_root.get_node_or_null("Creature") as Node3D
	if creature != null:
		creature.visible = false
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
	if rig == null:
		rig = FigureRig.new()
		rig.name = "FigureRig"
		add_child(rig)
	rig.bind(figure)
	_rebuild_projection_visuals()


## Voxel figures turn towards the player so every character shows its face,
## whichever way the piece itself points. The edge projections copy this.
func _face_viewer() -> void:
	if visual_root == null or visual_root.get_node_or_null("Standee") == null or is_dead:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var target := 0.0 if facing_locked else wrapf(camera.global_rotation.y - global_rotation.y, -PI, PI)
	visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target, minf(1.0, get_process_delta_time() * 10.0))


func set_selected(value: bool) -> void:
	selection_ring.visible = value and not is_dead


func set_animation_state(state: StringName) -> void:
	animation_state = state
	_play_imported_animation(state)
	if state == &"idle":
		visual_root.position = Vector3.ZERO
		left_leg_pivot.rotation = Vector3.ZERO
		right_leg_pivot.rotation = Vector3.ZERO
		off_arm_pivot.rotation = Vector3.ZERO
		sword_arm_pivot.rotation = Vector3.ZERO
		torso_pivot.rotation = Vector3.ZERO
		sword_pivot.rotation = Vector3.ZERO


func play_idle() -> void:
	set_animation_state(&"idle")
	if rig != null:
		rig.walking = false


func play_walk() -> void:
	set_animation_state(&"walk")
	if rig != null:
		rig.walking = true


func face_world_position(target_position: Vector3) -> void:
	var flat_target := Vector3(target_position.x, global_position.y, target_position.z)
	if global_position.distance_squared_to(flat_target) > 0.001:
		look_at(flat_target, Vector3.UP, true)


func play_death(from_position: Vector3 = Vector3.INF) -> void:
	if is_dead:
		return
	is_dead = true
	_hide_auras()
	set_animation_state(&"death")
	selection_ring.visible = false
	_flash(Color("ffb3b3"))
	if from_position == Vector3.INF:
		from_position = global_position + Vector3.BACK
	if using_licensed_model:
		await get_tree().create_timer(0.65).timeout
		_restore_materials()
		status_label.text = "%s  [DOWN]" % _role_name()
		died.emit(self)
		return
	var away := (global_position - from_position).normalized()
	var fall_sign: float = -1.0 if away.x + away.z < 0.0 else 1.0
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.set_parallel(true)
	tween.tween_property(visual_root, "rotation_degrees:z", 88.0 * fall_sign, 0.58)
	tween.tween_property(visual_root, "position:y", 0.18, 0.58)
	await tween.finished
	_restore_materials()
	status_label.text = "%s  [DOWN]" % _role_name()
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
	_placeholder_root = Node3D.new()
	_placeholder_root.name = "ProceduralFallback"
	visual_root.add_child(_placeholder_root)

	torso_pivot = Node3D.new()
	torso_pivot.name = "TorsoPivot"
	torso_pivot.position.y = 0.95
	_placeholder_root.add_child(torso_pivot)
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.30
	body_mesh.height = 0.88
	_add_mesh(torso_pivot, body_mesh, Vector3.ZERO, _team_color)

	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.24
	head_mesh.height = 0.48
	_add_mesh(torso_pivot, head_mesh, Vector3(0.0, 0.70, 0.0), Color("f2c9a5"))

	left_leg_pivot = _make_limb_pivot("LeftLegPivot", _placeholder_root, Vector3(-0.16, 0.62, 0.0))
	right_leg_pivot = _make_limb_pivot("RightLegPivot", _placeholder_root, Vector3(0.16, 0.62, 0.0))
	var leg_mesh := BoxMesh.new()
	leg_mesh.size = Vector3(0.18, 0.62, 0.20)
	_add_mesh(left_leg_pivot, leg_mesh, Vector3(0.0, -0.30, 0.0), Color("263746"))
	_add_mesh(right_leg_pivot, leg_mesh, Vector3(0.0, -0.30, 0.0), Color("263746"))

	sword_arm_pivot = _make_limb_pivot("SwordArmPivot", torso_pivot, Vector3(-0.38, 0.27, 0.0))
	off_arm_pivot = _make_limb_pivot("OffArmPivot", torso_pivot, Vector3(0.38, 0.27, 0.0))
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.16, 0.58, 0.17)
	_add_mesh(sword_arm_pivot, arm_mesh, Vector3(0.0, -0.27, 0.0), _accent_color)
	_add_mesh(off_arm_pivot, arm_mesh, Vector3(0.0, -0.27, 0.0), _accent_color)

	sword_pivot = Node3D.new()
	sword_pivot.name = "SwordPivot"
	sword_pivot.position = Vector3(0.0, -0.55, 0.0)
	sword_arm_pivot.add_child(sword_pivot)
	var blade := BoxMesh.new()
	blade.size = Vector3(0.09, 0.92, 0.055)
	_add_mesh(sword_pivot, blade, Vector3(0.0, -0.44, 0.0), Color("dce9f2"), 1.0)
	var guard := BoxMesh.new()
	guard.size = Vector3(0.34, 0.07, 0.09)
	_add_mesh(sword_pivot, guard, Vector3(0.0, 0.02, 0.0), Color("f0b54d"), 0.45)

	var shield := CylinderMesh.new()
	shield.top_radius = 0.27
	shield.bottom_radius = 0.27
	shield.height = 0.08
	var shield_mesh := _add_mesh(off_arm_pivot, shield, Vector3(0.0, -0.33, -0.18), _accent_color, 0.35)
	shield_mesh.rotation_degrees.x = 90.0

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

	# Role is shown by the creature shape and aura instead of floating text.
	status_label.visible = false
	# Mystical creature figurines replace the humanoid models; the procedural
	# placeholder rig stays (hidden) so the existing animation hooks still work.
	using_licensed_model = false
	_placeholder_root.visible = false
	var creature: CreatureFigure = CreatureFigureScript.new()
	creature.name = "Creature"
	creature.configure(team_id, is_master)
	visual_root.add_child(creature)
	for material: StandardMaterial3D in creature.body_materials:
		_materials.append(material)
		_base_colors.append(material.albedo_color)
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



func _load_licensed_model() -> bool:
	var model_path: String = MODEL_PATHS.get(team_id, "")
	if model_path.is_empty() or not ResourceLoader.exists(model_path):
		return false
	var packed := load(model_path) as PackedScene
	if packed == null:
		return false
	imported_model = packed.instantiate() as Node3D
	if imported_model == null:
		return false
	imported_model.name = "LicensedCharacter"
	visual_root.add_child(imported_model)
	animation_player = _find_animation_player(imported_model)
	return true


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _play_imported_animation(state: StringName) -> void:
	if animation_player == null or not ANIMATION_MAP.has(state):
		return
	var candidates: Array = ANIMATION_MAP[state]
	for candidate_value: Variant in candidates:
		var candidate := StringName(candidate_value)
		if animation_player.has_animation(candidate):
			animation_player.play(candidate)
			return


func _make_limb_pivot(node_name: String, parent: Node3D, at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = at
	parent.add_child(pivot)
	return pivot


func _add_mesh(
	parent: Node3D,
	mesh: PrimitiveMesh,
	at: Vector3,
	color: Color,
	metallic: float = 0.08
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.62
	material.metallic = metallic
	instance.material_override = material
	parent.add_child(instance)
	_materials.append(material)
	_base_colors.append(color)
	return instance


func _flash(color: Color) -> void:
	for material: StandardMaterial3D in _materials:
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.75


func _restore_materials() -> void:
	for index: int in range(_materials.size()):
		_materials[index].albedo_color = _base_colors[index]
		_materials[index].emission_enabled = false


func _update_status_label() -> void:
	if status_label != null:
		status_label.text = _role_name()


func _role_name() -> String:
	return "MASTER" if is_master else "STUDENT"


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
		var projected_animation := projection["animation_player"] as AnimationPlayer
		if projected_animation != null and projection["animation_state"] != animation_state:
			for candidate_value: Variant in ANIMATION_MAP.get(animation_state, []):
				var candidate := StringName(candidate_value)
				if projected_animation.has_animation(candidate):
					projected_animation.play(candidate)
					break
			projection["animation_state"] = animation_state
			_wrap_projections[index] = projection


## The edge projections copy the visual; refresh them after it changed.
func _rebuild_projection_visuals() -> void:
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
		projection["animation_player"] = _find_animation_player(fresh)
		_wrap_projections[index] = projection
	if rig != null:
		var mirrors: Array[Node3D] = []
		for projection: Dictionary in _wrap_projections:
			var copy := (projection["visual"] as Node3D).get_node_or_null("Standee/VoxelFigure") as Node3D
			if copy != null:
				mirrors.append(copy)
		rig.set_mirrors(mirrors)


## Shatters the voxel figure into flying cubes (captured pieces).
func shatter(from_position: Vector3, color: Color) -> void:
	if is_dead:
		return
	is_dead = true
	_hide_auras()
	selection_ring.visible = false
	var origin := global_position + Vector3(0.0, 0.7, 0.0)
	CombatEffects.shatter(get_parent(), origin, (origin - from_position).normalized(), _figure_colors(), color)
	visual_root.visible = false
	for projection: Dictionary in _wrap_projections:
		(projection["visual"] as Node3D).visible = false
	await get_tree().create_timer(0.25).timeout
	died.emit(self)


## A few colours sampled from the figure for its debris.
func _figure_colors() -> Array[Color]:
	var colors: Array[Color] = []
	var figure := visual_root.get_node_or_null("Standee/VoxelFigure")
	if figure == null:
		return [_aura_color()]
	for instance: Node in figure.find_children("Voxels", "MeshInstance3D", true, false):
		var mesh := (instance as MeshInstance3D).mesh as ArrayMesh
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		var vertex_colors: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		for index: int in range(0, vertex_colors.size(), maxi(1, vertex_colors.size() / 6)):
			colors.append(vertex_colors[index])
	return colors if not colors.is_empty() else [_aura_color()]


func _set_projection_transparency(node: Node, transparency_amount: float) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.transparency = transparency_amount
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in node.get_children():
		_set_projection_transparency(child, transparency_amount)
