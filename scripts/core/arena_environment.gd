class_name ArenaEnvironment
extends Node3D

## Purely visual "moon temple" arena around the board: dusk lighting, a stone
## dais floating over a misty abyss, braziers, pillars, crystals and embers.
## Nothing here affects game rules.

const DAIS_RADIUS: float = 7.6
const BOARD_HALF: float = 3.5

var _crystals: Array[Node3D] = []
var _rune_material: StandardMaterial3D
var _time: float = 0.0


func build() -> void:
	_build_world_environment()
	_build_lights()
	_build_dais()
	_build_abyss()
	_build_board_frame()
	_build_rune_ring()
	_build_obelisks()
	_build_braziers()
	_build_crystals()
	_build_embers()


func _process(delta: float) -> void:
	_time += delta
	for index: int in range(_crystals.size()):
		var crystal := _crystals[index]
		var phase := float(index) * 1.7
		crystal.position.y = float(crystal.get_meta("base_y")) + sin(_time * 1.4 + phase) * 0.12
		crystal.rotation.y += delta * 0.6
	if _rune_material != null:
		_rune_material.emission_energy_multiplier = 0.9 + sin(_time * 1.8) * 0.35


func _build_world_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("0c0f26")
	sky_material.sky_horizon_color = Color("5a2f4f")
	sky_material.ground_bottom_color = Color("05060f")
	sky_material.ground_horizon_color = Color("2b1a35")
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	environment.sky = sky
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("070914")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("47507a")
	environment.ambient_light_energy = 0.32
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.95
	environment.glow_enabled = true
	environment.glow_intensity = 0.45
	environment.glow_strength = 0.9
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 1.15
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	# Only tight glow levels: wide levels turn small flames into big blurry blobs.
	for level: int in range(7):
		environment.set_glow_level(level, level <= 2)
	environment.fog_enabled = true
	environment.fog_light_color = Color("141228")
	environment.fog_density = 0.004
	environment.fog_height = -1.2
	environment.fog_height_density = 0.35
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.12
	environment.adjustment_saturation = 1.05
	world_environment.environment = environment
	add_child(world_environment)


func _build_lights() -> void:
	var moon := DirectionalLight3D.new()
	moon.name = "MoonLight"
	moon.rotation_degrees = Vector3(-62.0, -28.0, 0.0)
	moon.light_color = Color("d4dcff")
	moon.light_energy = 0.8
	moon.shadow_enabled = true
	moon.shadow_opacity = 0.75
	add_child(moon)
	var rim := DirectionalLight3D.new()
	rim.name = "WarmRim"
	rim.rotation_degrees = Vector3(-24.0, 150.0, 0.0)
	rim.light_color = Color("ff9a52")
	rim.light_energy = 0.4
	add_child(rim)


func _build_dais() -> void:
	# Three stacked octagonal tiers read as a carved temple platform.
	var tiers: Array[Dictionary] = [
		{"radius": DAIS_RADIUS, "height": 0.5, "y": -0.37, "color": Color("2c2a3b")},
		{"radius": DAIS_RADIUS + 0.7, "height": 0.6, "y": -0.9, "color": Color("221f2e")},
		{"radius": DAIS_RADIUS + 1.3, "height": 1.6, "y": -1.95, "color": Color("181622")},
	]
	for tier: Dictionary in tiers:
		var mesh_instance := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.radial_segments = 8
		cylinder.rings = 1
		cylinder.top_radius = float(tier["radius"])
		cylinder.bottom_radius = float(tier["radius"]) * 0.97
		cylinder.height = float(tier["height"])
		mesh_instance.mesh = cylinder
		mesh_instance.position.y = float(tier["y"])
		mesh_instance.rotation_degrees.y = 22.5
		mesh_instance.material_override = _stone_material(tier["color"])
		add_child(mesh_instance)
	# Gold inlay along the top edge of the dais.
	var trim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = DAIS_RADIUS - 0.08
	torus.outer_radius = DAIS_RADIUS + 0.04
	torus.rings = 8
	torus.ring_segments = 8
	trim.mesh = torus
	trim.position.y = -0.12
	trim.rotation_degrees.y = 22.5
	trim.material_override = _gold_material(0.6)
	add_child(trim)


func _build_abyss() -> void:
	var abyss := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120.0, 120.0)
	abyss.mesh = plane
	abyss.position.y = -7.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("0b0d1f")
	material.emission_enabled = true
	material.emission = Color("1b1440")
	material.emission_energy_multiplier = 0.6
	material.roughness = 1.0
	abyss.material_override = material
	add_child(abyss)
	# Soft glowing mist discs under the platform give the abyss depth.
	for layer: int in range(3):
		var mist := MeshInstance3D.new()
		var disc := PlaneMesh.new()
		disc.size = Vector2(26.0 - layer * 5.0, 26.0 - layer * 5.0)
		mist.mesh = disc
		mist.position.y = -3.0 - layer * 1.2
		var mist_material := StandardMaterial3D.new()
		mist_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mist_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mist_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mist_material.albedo_texture = _radial_texture(Color(0.45, 0.32, 0.9, 0.55))
		mist.material_override = mist_material
		mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mist)


func _build_board_frame() -> void:
	# Dark stone border with a gold rim around the 5x5 field (wrap sides stay open).
	var frame_depth := BOARD_HALF + 0.2
	for side: int in [-1, 1]:
		var border := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(10.6, 0.22, 0.32)
		border.mesh = box
		border.position = Vector3(0.0, -0.03, float(side) * frame_depth)
		border.material_override = _stone_material(Color("3a3548"))
		add_child(border)
		var rim := MeshInstance3D.new()
		var rim_box := BoxMesh.new()
		rim_box.size = Vector3(10.6, 0.05, 0.07)
		rim.mesh = rim_box
		rim.position = Vector3(0.0, 0.1, float(side) * (frame_depth - 0.12))
		rim.material_override = _gold_material(1.0)
		add_child(rim)


func _build_rune_ring() -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 6.55
	torus.outer_radius = 6.68
	torus.rings = 6
	torus.ring_segments = 64
	ring.mesh = torus
	ring.position.y = -0.1
	_rune_material = StandardMaterial3D.new()
	_rune_material.albedo_color = Color("6fd6ff")
	_rune_material.emission_enabled = true
	_rune_material.emission = Color("4cc7ff")
	_rune_material.emission_energy_multiplier = 1.4
	_rune_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = _rune_material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	# Rune stones sitting on the ring.
	for index: int in range(12):
		var angle := TAU * float(index) / 12.0
		var stone := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.28, 0.32, 0.12)
		stone.mesh = prism
		stone.position = Vector3(cos(angle) * 6.6, 0.05, sin(angle) * 6.6)
		stone.rotation.y = -angle + PI * 0.5
		stone.material_override = _rune_material
		add_child(stone)


## Dark obelisks with gold caps on the far corners of the dais.
func _build_obelisks() -> void:
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var spot := Vector3(corner.x * 4.3, 0.0, corner.y * 6.3)
		var body := MeshInstance3D.new()
		var column := CylinderMesh.new()
		column.radial_segments = 4
		column.top_radius = 0.16
		column.bottom_radius = 0.34
		column.height = 1.5
		body.mesh = column
		body.position = spot + Vector3(0.0, 0.75, 0.0)
		body.rotation_degrees.y = 45.0
		body.material_override = _stone_material(Color("2a2838"))
		add_child(body)
		var cap := MeshInstance3D.new()
		var pyramid := CylinderMesh.new()
		pyramid.radial_segments = 4
		pyramid.top_radius = 0.0
		pyramid.bottom_radius = 0.2
		pyramid.height = 0.3
		cap.mesh = pyramid
		cap.position = spot + Vector3(0.0, 1.65, 0.0)
		cap.rotation_degrees.y = 45.0
		cap.material_override = _gold_material(0.8)
		add_child(cap)


func _build_braziers() -> void:
	for spot: Vector3 in [Vector3(-2.1, 0.0, 5.9), Vector3(2.1, 0.0, 5.9), Vector3(-2.1, 0.0, -5.9), Vector3(2.1, 0.0, -5.9)]:
		var bowl := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.42
		cylinder.bottom_radius = 0.18
		cylinder.height = 0.32
		bowl.mesh = cylinder
		bowl.position = spot + Vector3(0.0, 0.52, 0.0)
		bowl.material_override = _gold_material(0.25)
		add_child(bowl)
		var stand := MeshInstance3D.new()
		var stand_mesh := CylinderMesh.new()
		stand_mesh.top_radius = 0.08
		stand_mesh.bottom_radius = 0.2
		stand_mesh.height = 0.45
		stand.mesh = stand_mesh
		stand.position = spot + Vector3(0.0, 0.18, 0.0)
		stand.material_override = _stone_material(Color("2a2638"))
		add_child(stand)
		_add_flame(spot + Vector3(0.0, 0.7, 0.0), Color("ff8a3c"), 1.0)
		var light := OmniLight3D.new()
		light.position = spot + Vector3(0.0, 1.2, 0.0)
		light.light_color = Color("ff9a4a")
		light.light_energy = 1.6
		light.omni_range = 4.8
		light.omni_attenuation = 1.4
		add_child(light)


func _build_crystals() -> void:
	# Floating arcane crystals beside the wraparound edges.
	for spot: Vector3 in [Vector3(-4.2, 1.6, -4.7), Vector3(4.2, 1.6, -4.7), Vector3(-4.2, 0.9, 4.7), Vector3(4.2, 0.9, 4.7)]:
		var crystal := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.38, 0.9, 0.38)
		crystal.mesh = prism
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.45, 0.85, 1.0, 0.85)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.emission_enabled = true
		material.emission = Color("3fb8ff")
		material.emission_energy_multiplier = 1.6
		material.metallic = 0.3
		material.roughness = 0.1
		crystal.material_override = material
		crystal.position = spot
		crystal.set_meta("base_y", spot.y)
		add_child(crystal)
		_crystals.append(crystal)
		var lower := crystal.duplicate() as MeshInstance3D
		lower.rotation_degrees.x = 180.0
		lower.position = Vector3(0.0, -0.9, 0.0)
		crystal.add_child(lower)
		var glow := OmniLight3D.new()
		glow.light_color = Color("58c8ff")
		glow.light_energy = 1.2
		glow.omni_range = 3.0
		crystal.add_child(glow)


func _build_embers() -> void:
	var embers := CPUParticles3D.new()
	embers.name = "Embers"
	embers.amount = 45
	embers.lifetime = 6.0
	embers.preprocess = 6.0
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	embers.emission_box_extents = Vector3(9.0, 0.5, 10.0)
	embers.position.y = -1.5
	embers.direction = Vector3(0.0, 1.0, 0.0)
	embers.spread = 25.0
	embers.gravity = Vector3(0.0, 0.25, 0.0)
	embers.initial_velocity_min = 0.25
	embers.initial_velocity_max = 0.7
	embers.scale_amount_min = 0.06
	embers.scale_amount_max = 0.12
	embers.mesh = _spark_mesh(Color("ffb35c"))
	embers.color_ramp = _fade_gradient(Color(1.0, 0.75, 0.4, 0.0), Color(1.0, 0.6, 0.25, 1.0), Color(1.0, 0.3, 0.1, 0.0))
	add_child(embers)


func _add_flame(at: Vector3, color: Color, size_scale: float) -> void:
	var flame := CPUParticles3D.new()
	flame.amount = 20
	flame.lifetime = 0.7
	flame.position = at
	flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flame.emission_sphere_radius = 0.12 * size_scale
	flame.direction = Vector3.UP
	flame.spread = 12.0
	flame.gravity = Vector3(0.0, 1.6, 0.0)
	flame.initial_velocity_min = 0.3
	flame.initial_velocity_max = 0.8
	flame.scale_amount_min = 0.3 * size_scale
	flame.scale_amount_max = 0.5 * size_scale
	flame.mesh = _spark_mesh(color)
	flame.color_ramp = _fade_gradient(Color(1.0, 0.95, 0.7, 1.0), Color(1.0, 0.55, 0.15, 0.9), Color(0.8, 0.15, 0.05, 0.0))
	add_child(flame)


func _spark_mesh(color: Color) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# Without this, particle billboards ignore scale_amount and render 1 m wide.
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.albedo_color = color
	material.albedo_texture = _radial_texture(Color.WHITE)
	quad.material = material
	return quad


func _fade_gradient(start: Color, middle: Color, end: Color) -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([start, middle, end])
	return gradient


func _radial_texture(color: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([color, Color(color.r, color.g, color.b, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture


func _stone_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	material.metallic = 0.05
	return material


func _gold_material(glow: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("d9a640")
	material.metallic = 0.85
	material.roughness = 0.3
	material.emission_enabled = glow > 0.0
	material.emission = Color("b5781e")
	material.emission_energy_multiplier = glow
	return material
