class_name BattleUnit
extends Node3D

signal health_changed(unit: BattleUnit)
signal died(unit: BattleUnit)

var unit_name: String = "Unit"
var team_id: int = 0
var max_hp: int = 12
var current_hp: int = 12
var attack_power: int = 5
var defense: int = 2
var movement_range: int = 4
var attack_range: int = 1
var grid_position: Vector2i = Vector2i.ZERO
var has_moved: bool = false
var has_attacked: bool = false
var is_dead: bool = false
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

var _team_color: Color = Color("3a8fe7")
var _accent_color: Color = Color("d7ecff")
var _materials: Array[StandardMaterial3D] = []
var _base_colors: Array[Color] = []
var _idle_time: float = 0.0


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


func begin_turn() -> void:
	has_moved = false
	has_attacked = false
	set_exhausted(false)


func finish_action() -> void:
	has_moved = true
	has_attacked = true
	set_exhausted(true)


func can_act() -> bool:
	return not is_dead and (not has_moved or not has_attacked)


func set_selected(value: bool) -> void:
	selection_ring.visible = value and not is_dead


func set_exhausted(value: bool) -> void:
	for index: int in range(_materials.size()):
		_materials[index].albedo_color = _base_colors[index] * (0.48 if value else 1.0)


func set_animation_state(state: StringName) -> void:
	animation_state = state
	if state == &"idle":
		visual_root.position = Vector3.ZERO
		left_leg_pivot.rotation = Vector3.ZERO
		right_leg_pivot.rotation = Vector3.ZERO
		off_arm_pivot.rotation = Vector3.ZERO
		sword_arm_pivot.rotation = Vector3.ZERO
		torso_pivot.rotation = Vector3.ZERO
		sword_pivot.rotation = Vector3.ZERO


func face_world_position(target_position: Vector3) -> void:
	var flat_target := Vector3(target_position.x, global_position.y, target_position.z)
	if global_position.distance_squared_to(flat_target) > 0.001:
		look_at(flat_target, Vector3.UP, true)


func apply_damage(amount: int) -> void:
	if is_dead:
		return
	current_hp = maxi(0, current_hp - amount)
	_update_status_label()
	health_changed.emit(self)


func play_hit_reaction(from_position: Vector3) -> void:
	if current_hp <= 0:
		await play_death(from_position)
		return
	set_animation_state(&"hit")
	_flash(Color.WHITE)
	var original_position := position
	var away := (global_position - from_position).normalized()
	away.y = 0.0
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(torso_pivot, "rotation_degrees:x", -20.0, 0.10)
	tween.tween_property(self, "position", original_position + away * 0.16, 0.10)
	await tween.finished
	var recover := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	recover.set_parallel(true)
	recover.tween_property(torso_pivot, "rotation_degrees:x", 0.0, 0.20)
	recover.tween_property(self, "position", original_position, 0.20)
	await recover.finished
	_restore_materials()
	set_animation_state(&"idle")


func play_death(from_position: Vector3) -> void:
	if is_dead:
		return
	is_dead = true
	animation_state = &"death"
	selection_ring.visible = false
	_flash(Color("ffb3b3"))
	var away := (global_position - from_position).normalized()
	var fall_sign: float = -1.0 if away.x + away.z < 0.0 else 1.0
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.set_parallel(true)
	tween.tween_property(visual_root, "rotation_degrees:z", 88.0 * fall_sign, 0.58)
	tween.tween_property(visual_root, "position:y", 0.18, 0.58)
	await tween.finished
	_restore_materials()
	status_label.text = "%s  [DOWN]" % unit_name
	died.emit(self)


func _build_model() -> void:
	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)

	torso_pivot = Node3D.new()
	torso_pivot.name = "TorsoPivot"
	torso_pivot.position.y = 0.95
	visual_root.add_child(torso_pivot)
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.30
	body_mesh.height = 0.88
	_add_mesh(torso_pivot, body_mesh, Vector3.ZERO, _team_color)

	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.24
	head_mesh.height = 0.48
	_add_mesh(torso_pivot, head_mesh, Vector3(0.0, 0.70, 0.0), Color("f2c9a5"))

	left_leg_pivot = _make_limb_pivot("LeftLegPivot", visual_root, Vector3(-0.16, 0.62, 0.0))
	right_leg_pivot = _make_limb_pivot("RightLegPivot", visual_root, Vector3(0.16, 0.62, 0.0))
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

	status_label = Label3D.new()
	status_label.name = "StatusLabel"
	status_label.position = Vector3(0.0, 2.05, 0.0)
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status_label.font_size = 30
	status_label.outline_size = 6
	status_label.modulate = _accent_color
	add_child(status_label)


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
		status_label.text = "%s  %d/%d" % [unit_name, current_hp, max_hp]

