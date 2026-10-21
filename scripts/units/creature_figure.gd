class_name CreatureFigure
extends Node3D

## Procedural "mystical creature" game piece, carved like a figurine on a plinth.
## Team 0 is the Celestial Order (marble, gold, moonlight), team 1 the Abyssal
## Horde (obsidian, bronze, ember glow). Students and masters differ in shape.
## Front of the figure is local +Z. Animated parts are tagged with metadata so a
## duplicated figure (wrap projections) animates without being rebuilt.

const CELESTIAL_BODY := Color("e8ecf6")
const CELESTIAL_SHADE := Color("9aa8cc")
const CELESTIAL_GLOW := Color("5fd4ff")
const ABYSS_BODY := Color("5c3a44")
const ABYSS_SHADE := Color("8a4040")
const ABYSS_GLOW := Color("ff4a1c")
const GOLD := Color("d9a640")
const BRONZE := Color("8c5a2b")

var team_id: int = 0
var is_master: bool = false
var body_materials: Array[StandardMaterial3D] = []
var _time: float = 0.0
var _animated: Array[Node3D] = []


func configure(new_team_id: int, master: bool) -> void:
	team_id = new_team_id
	is_master = master
	if get_child_count() > 0:
		return
	_build_plinth()
	if team_id == 0 and is_master:
		_build_seraph()
	elif team_id == 0:
		_build_moon_owl()
	elif is_master:
		_build_abyss_lord()
	else:
		_build_imp()


func _ready() -> void:
	_time = randf() * 10.0
	_collect_animated(self)


func _process(delta: float) -> void:
	_time += delta
	for node: Node3D in _animated:
		if node.has_meta("spin"):
			node.rotate_object_local(Vector3.UP, delta * float(node.get_meta("spin")))
		if node.has_meta("bob"):
			var base: Vector3 = node.get_meta("rest")
			node.position = base + Vector3(0.0, sin(_time * 2.0 + float(node.get_meta("bob"))) * 0.05, 0.0)
		if node.has_meta("flap"):
			var rest_rotation: Vector3 = node.get_meta("rest_rotation")
			var amount := float(node.get_meta("flap"))
			node.rotation = rest_rotation + Vector3(0.0, sin(_time * 3.0) * amount, 0.0)
		if node.has_meta("orbit"):
			var radius := float(node.get_meta("orbit"))
			var height := float(node.get_meta("orbit_height"))
			var phase := float(node.get_meta("phase"))
			node.position = Vector3(cos(_time * 1.6 + phase) * radius, height + sin(_time * 3.0 + phase) * 0.05, sin(_time * 1.6 + phase) * radius)
		if node.has_meta("blink"):
			# Short blink every few seconds.
			var cycle := fmod(_time + float(node.get_meta("blink")), 4.0)
			node.scale.y = 0.15 if cycle < 0.12 else 1.0


func _collect_animated(node: Node) -> void:
	for child: Node in node.get_children():
		var spatial := child as Node3D
		if spatial != null:
			if spatial.has_meta("bob") and not spatial.has_meta("rest"):
				spatial.set_meta("rest", spatial.position)
			if spatial.has_meta("flap") and not spatial.has_meta("rest_rotation"):
				spatial.set_meta("rest_rotation", spatial.rotation)
			for key: String in ["spin", "bob", "flap", "orbit", "blink"]:
				if spatial.has_meta(key):
					_animated.append(spatial)
					break
		_collect_animated(child)


# --- Plinth ---------------------------------------------------------------

func _build_plinth() -> void:
	var plinth := CylinderMesh.new()
	plinth.radial_segments = 6
	plinth.rings = 1
	plinth.top_radius = 0.4
	plinth.bottom_radius = 0.45
	plinth.height = 0.14
	var stone := _body(Color("ced2df") if team_id == 0 else Color("3e3036"), 0.5)
	_mesh(self, plinth, Vector3(0, 0.07, 0), stone)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.38
	rim.outer_radius = 0.43
	rim.rings = 6
	rim.ring_segments = 6
	_mesh(self, rim, Vector3(0, 0.14, 0), _metal(GOLD if team_id == 0 else BRONZE))


# --- Celestial Order ------------------------------------------------------

func _build_moon_owl() -> void:
	var body := _body(CELESTIAL_BODY)
	var shade := _body(CELESTIAL_SHADE)
	var root := _group(self, Vector3(0, 0.14, 0))
	root.set_meta("bob", 0.0)
	_mesh(root, _sphere(0.27, 0.66), Vector3(0, 0.4, 0), body)
	_mesh(root, _sphere(0.18, 0.4), Vector3(0, 0.36, 0.12), _body(Color("f6f1e2")))
	var head := _group(root, Vector3(0, 0.82, 0.02))
	_mesh(head, _sphere(0.22, 0.4), Vector3.ZERO, body)
	for side: float in [-1.0, 1.0]:
		var tuft := _mesh(head, _prism(Vector3(0.1, 0.22, 0.06)), Vector3(side * 0.12, 0.2, 0), shade)
		tuft.rotation_degrees.z = -side * 18.0
		_eye(head, Vector3(side * 0.085, 0.03, 0.17), 0.055, CELESTIAL_GLOW)
		var wing := _group(root, Vector3(side * 0.24, 0.45, -0.02))
		wing.rotation_degrees = Vector3(0, side * 12.0, side * 8.0)
		wing.set_meta("flap", 0.08 * side)
		var feather := _mesh(wing, _sphere(0.13, 0.5), Vector3(side * 0.04, -0.02, 0), shade)
		feather.scale = Vector3(0.7, 1.0, 0.45)
	var beak := _mesh(head, _prism(Vector3(0.07, 0.08, 0.06)), Vector3(0, -0.04, 0.21), _metal(GOLD))
	beak.rotation_degrees.x = 180.0
	_halo(root, 1.2, 0.18)


func _build_seraph() -> void:
	var robe := _body(CELESTIAL_BODY)
	var shade := _body(CELESTIAL_SHADE)
	var gold := _metal(GOLD)
	var root := _group(self, Vector3(0, 0.14, 0))
	root.set_meta("bob", 1.0)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.14
	cone.bottom_radius = 0.36
	cone.height = 1.0
	_mesh(root, cone, Vector3(0, 0.5, 0), robe)
	_mesh(root, _sphere(0.2, 0.36), Vector3(0, 1.0, 0.02), gold)
	var belt := TorusMesh.new()
	belt.inner_radius = 0.2
	belt.outer_radius = 0.25
	_mesh(root, belt, Vector3(0, 0.7, 0), gold)
	var head := _group(root, Vector3(0, 1.28, 0.02))
	_mesh(head, _sphere(0.17, 0.36), Vector3.ZERO, shade)
	var hood := _mesh(head, _sphere(0.21, 0.42), Vector3(0, 0.03, -0.04), robe)
	hood.scale = Vector3(1.0, 1.1, 1.0)
	var mask := _mesh(head, _sphere(0.15, 0.3), Vector3(0, 0, 0.1), gold)
	mask.scale = Vector3(1.0, 1.1, 0.5)
	for side: float in [-1.0, 1.0]:
		var slit := BoxMesh.new()
		slit.size = Vector3(0.07, 0.025, 0.02)
		var eye := _mesh(head, slit, Vector3(side * 0.055, 0.02, 0.18), _glow(CELESTIAL_GLOW, 3.0))
		eye.set_meta("blink", side)
		# Two pairs of wings fanned out behind the shoulders.
		for tier: int in range(2):
			var wing := _group(root, Vector3(side * 0.12, 1.02 - tier * 0.12, -0.12))
			wing.rotation_degrees = Vector3(-10.0, side * 20.0, side * (35.0 + tier * 30.0))
			wing.set_meta("flap", 0.06 * side)
			_mesh(wing, _prism(Vector3(0.16, 0.85 - tier * 0.2, 0.035)), Vector3(0, 0.42 - tier * 0.1, 0), robe if tier == 0 else shade)
			_mesh(wing, _prism(Vector3(0.05, 0.6 - tier * 0.15, 0.04)), Vector3(0, 0.33 - tier * 0.08, 0.01), gold)
	var big_halo := TorusMesh.new()
	big_halo.inner_radius = 0.28
	big_halo.outer_radius = 0.32
	var halo := _mesh(root, big_halo, Vector3(0, 1.36, -0.16), _glow(Color("ffd77a"), 2.2))
	halo.rotation_degrees.x = 90.0
	for index: int in range(2):
		var orb := _mesh(root, _sphere(0.055, 0.11), Vector3.ZERO, _glow(CELESTIAL_GLOW, 3.5))
		orb.set_meta("orbit", 0.42)
		orb.set_meta("orbit_height", 0.95)
		orb.set_meta("phase", PI * float(index))


# --- Abyssal Horde --------------------------------------------------------

func _build_imp() -> void:
	var skin := _body(ABYSS_BODY)
	var shade := _body(ABYSS_SHADE)
	var bronze := _metal(BRONZE)
	var root := _group(self, Vector3(0, 0.14, 0))
	root.set_meta("bob", 2.0)
	var torso := _mesh(root, _capsule(0.2, 0.62), Vector3(0, 0.4, 0), skin)
	torso.rotation_degrees.x = 12.0
	var head := _group(root, Vector3(0, 0.78, 0.07))
	_mesh(head, _sphere(0.19, 0.36), Vector3.ZERO, skin)
	var jaw := _mesh(head, _sphere(0.13, 0.2), Vector3(0, -0.08, 0.08), shade)
	jaw.scale = Vector3(1.1, 0.7, 1.0)
	for side: float in [-1.0, 1.0]:
		_eye(head, Vector3(side * 0.075, 0.03, 0.16), 0.045, ABYSS_GLOW)
		_horn(head, Vector3(side * 0.11, 0.12, 0.0), side, 0.32, bronze)
		var wing := _group(root, Vector3(side * 0.15, 0.6, -0.12))
		wing.rotation_degrees = Vector3(-15.0, side * 30.0, side * 55.0)
		wing.set_meta("flap", 0.12 * side)
		_mesh(wing, _prism(Vector3(0.36, 0.5, 0.03)), Vector3(0, 0.22, 0), _body(Color("c0504a")))
		var arm := _mesh(root, _capsule(0.06, 0.32), Vector3(side * 0.2, 0.42, 0.08), skin)
		arm.rotation_degrees = Vector3(-30.0, 0, side * 15.0)
	var tail := _mesh(root, _capsule(0.035, 0.5), Vector3(0, 0.22, -0.26), skin)
	tail.rotation_degrees.x = -55.0
	var spade := _mesh(root, _prism(Vector3(0.12, 0.12, 0.03)), Vector3(0, 0.38, -0.46), _glow(ABYSS_GLOW, 1.5))
	spade.rotation_degrees.x = -55.0


func _build_abyss_lord() -> void:
	var skin := _body(ABYSS_BODY)
	var shade := _body(ABYSS_SHADE)
	var bronze := _metal(BRONZE)
	var root := _group(self, Vector3(0, 0.14, 0))
	root.set_meta("bob", 3.0)
	var cape := CylinderMesh.new()
	cape.top_radius = 0.18
	cape.bottom_radius = 0.4
	cape.height = 0.9
	_mesh(root, cape, Vector3(0, 0.45, -0.03), _body(Color("a03a34")))
	var chest := _mesh(root, _sphere(0.3, 0.55), Vector3(0, 0.92, 0), skin)
	chest.scale = Vector3(1.25, 1.0, 0.9)
	var core := _mesh(root, _sphere(0.08, 0.16), Vector3(0, 0.95, 0.24), _glow(ABYSS_GLOW, 3.0))
	core.set_meta("bob", 0.5)
	for side: float in [-1.0, 1.0]:
		var pauldron := _mesh(root, _sphere(0.15, 0.24), Vector3(side * 0.34, 1.05, 0), bronze)
		pauldron.scale = Vector3(1.0, 0.7, 1.0)
		for spike: int in range(2):
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.045
			cone.height = 0.22
			var spike_mesh := _mesh(root, cone, Vector3(side * (0.32 + spike * 0.08), 1.18, -0.04 + spike * 0.06), bronze)
			spike_mesh.rotation_degrees.z = -side * (20.0 + spike * 25.0)
		var arm := _mesh(root, _capsule(0.08, 0.5), Vector3(side * 0.4, 0.75, 0.04), skin)
		arm.rotation_degrees.z = side * 10.0
		var claw := _mesh(root, _sphere(0.09, 0.14), Vector3(side * 0.43, 0.48, 0.07), shade)
		claw.scale = Vector3(1.0, 1.2, 1.0)
		var wing := _group(root, Vector3(side * 0.18, 1.0, -0.2))
		wing.rotation_degrees = Vector3(-20.0, side * 25.0, side * 50.0)
		wing.set_meta("flap", 0.1 * side)
		_mesh(wing, _prism(Vector3(0.55, 0.9, 0.035)), Vector3(0, 0.4, 0), _body(Color("b0443e")))
		_mesh(wing, _capsule(0.03, 0.95), Vector3(-side * 0.12, 0.45, 0.02), bronze)
	var head := _group(root, Vector3(0, 1.32, 0.04))
	_mesh(head, _sphere(0.18, 0.34), Vector3.ZERO, skin)
	for side: float in [-1.0, 1.0]:
		var eye := _mesh(head, _sphere(0.04, 0.05), Vector3(side * 0.07, 0.02, 0.15), _glow(ABYSS_GLOW, 4.0))
		eye.scale = Vector3(1.5, 0.6, 1.0)
		eye.set_meta("blink", side + 2.0)
		_horn(head, Vector3(side * 0.13, 0.1, -0.02), side, 0.5, bronze)
	# Spiked crown of embers.
	var crown := _group(head, Vector3(0, 0.15, 0))
	crown.set_meta("spin", 0.4)
	for index: int in range(5):
		var angle := TAU * float(index) / 5.0
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.03
		cone.height = 0.14
		_mesh(crown, cone, Vector3(cos(angle) * 0.13, 0.05, sin(angle) * 0.13), _glow(Color("ff8a2c"), 2.5))


# --- Helpers ----------------------------------------------------------------

func _horn(parent: Node3D, at: Vector3, side: float, length: float, material: StandardMaterial3D) -> void:
	# Three tapering segments curve outwards and back like a ram horn.
	var pivot := _group(parent, at)
	var segment_length := length / 3.0
	var current := pivot
	for index: int in range(3):
		var cone := CylinderMesh.new()
		cone.top_radius = 0.045 * (1.0 - float(index + 1) / 3.6)
		cone.bottom_radius = 0.05 * (1.0 - float(index) / 3.6)
		cone.height = segment_length
		var joint := _group(current, Vector3(0, segment_length if index > 0 else 0.0, 0))
		joint.rotation_degrees = Vector3(-18.0, 0, -side * (38.0 if index == 0 else 22.0))
		_mesh(joint, cone, Vector3(0, segment_length * 0.5, 0), material)
		current = joint


func _halo(parent: Node3D, height: float, radius: float) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = radius - 0.025
	ring.outer_radius = radius
	var halo := _mesh(parent, ring, Vector3(0, height, 0), _glow(Color("ffd77a"), 2.0))
	halo.set_meta("spin", 0.8)


func _eye(parent: Node3D, at: Vector3, radius: float, color: Color) -> void:
	var eye := _mesh(parent, _sphere(radius, radius * 2.0), at, _glow(color, 3.5))
	eye.set_meta("blink", at.x * 7.0)


func _group(parent: Node3D, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.position = at
	parent.add_child(node)
	return node


func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _sphere(radius: float, height: float) -> SphereMesh:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = height
	sphere.radial_segments = 16
	sphere.rings = 8
	return sphere


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = maxf(height, radius * 2.0)
	capsule.radial_segments = 12
	capsule.rings = 4
	return capsule


func _prism(size_value: Vector3) -> PrismMesh:
	var prism := PrismMesh.new()
	prism.size = size_value
	return prism


func _body(color: Color, roughness: float = 0.42) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.08
	material.rim_enabled = true
	material.rim = 0.35
	material.rim_tint = 0.4
	# Carved marble look; the tint turns it pale for the Order and blood-red for the Horde.
	var stone := "marble"
	material.albedo_texture = WoodMaterials.tex(stone + "_albedo.jpg")
	material.normal_enabled = true
	material.normal_texture = WoodMaterials.tex(stone + "_normal.jpg")
	material.uv1_triplanar = true
	material.uv1_scale = Vector3(0.7, 0.7, 0.7)
	body_materials.append(material)
	return material


func _metal(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.85
	material.roughness = 0.3
	body_materials.append(material)
	return material


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
