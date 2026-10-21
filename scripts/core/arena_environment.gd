class_name ArenaEnvironment
extends Node3D

## Purely visual scene around the board: an old wooden table in a candle-lit
## hall and a carved wooden game board with iron-capped rails.
## Nothing here affects game rules.

const BOARD_HALF_DEPTH: float = 3.5
const FRAME_WIDTH: float = 0.55

var _flicker_lights: Array[OmniLight3D] = []
var _time: float = 0.0


func build() -> void:
	_build_world_environment()
	_build_lights()
	_build_table()
	_build_board_frame()
	_build_candles()
	_build_props()
	_build_dust()


func _process(delta: float) -> void:
	_time += delta
	for index: int in range(_flicker_lights.size()):
		var light := _flicker_lights[index]
		var base := float(light.get_meta("base_energy"))
		light.light_energy = base * (0.88 + sin(_time * 9.0 + index * 2.3) * 0.06 + sin(_time * 23.0 + index) * 0.04)


func _build_world_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0b0705")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("6b4a33")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.5
	environment.glow_strength = 0.9
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 1.1
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for level: int in range(7):
		environment.set_glow_level(level, level <= 2)
	environment.fog_enabled = true
	environment.fog_light_color = Color("120b07")
	environment.fog_density = 0.02
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 1.08
	world_environment.environment = environment
	add_child(world_environment)


func _build_lights() -> void:
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.rotation_degrees = Vector3(-60.0, -32.0, 0.0)
	key.light_color = Color("ffd9a8")
	key.light_energy = 1.25
	key.shadow_enabled = true
	key.shadow_opacity = 0.7
	add_child(key)
	var cool := DirectionalLight3D.new()
	cool.name = "MysticFill"
	cool.rotation_degrees = Vector3(-30.0, 160.0, 0.0)
	cool.light_color = Color("7f8cff")
	cool.light_energy = 0.28
	add_child(cool)


func _build_table() -> void:
	var table := MeshInstance3D.new()
	table.name = "Table"
	var top := BoxMesh.new()
	top.size = Vector3(40.0, 0.7, 44.0)
	table.mesh = top
	table.position.y = -0.62
	table.material_override = WoodMaterials.surface("table", 0.16, 0.75)
	add_child(table)
	# Board base: one solid slab of walnut under the tiles.
	var slab := MeshInstance3D.new()
	var slab_mesh := BoxMesh.new()
	slab_mesh.size = Vector3(11.4, 0.24, BOARD_HALF_DEPTH * 2.0 + FRAME_WIDTH * 2.0)
	slab.mesh = slab_mesh
	slab.position.y = -0.2
	slab.material_override = WoodMaterials.surface("frame", 0.5)
	add_child(slab)


func _build_board_frame() -> void:
	var rail_z := BOARD_HALF_DEPTH + FRAME_WIDTH * 0.5
	var oak := WoodMaterials.surface("frame", 0.45, 0.5)
	var brass := WoodMaterials.brass(0.15)
	var studs := WoodMaterials.iron()
	for side: int in [-1, 1]:
		var rail := MeshInstance3D.new()
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(11.4, 0.32, FRAME_WIDTH)
		rail.mesh = rail_mesh
		rail.position = Vector3(0.0, 0.0, float(side) * rail_z)
		rail.material_override = oak
		add_child(rail)
		# Brass inlay line along the inner edge.
		var inlay := MeshInstance3D.new()
		var inlay_mesh := BoxMesh.new()
		inlay_mesh.size = Vector3(11.4, 0.03, 0.06)
		inlay.mesh = inlay_mesh
		inlay.position = Vector3(0.0, 0.165, float(side) * (BOARD_HALF_DEPTH + 0.12))
		inlay.material_override = brass
		add_child(inlay)
		# Carved studs along the rail.
		for index: int in range(7):
			var stud := MeshInstance3D.new()
			var stud_mesh := SphereMesh.new()
			stud_mesh.radius = 0.07
			stud_mesh.height = 0.08
			stud.mesh = stud_mesh
			stud.position = Vector3(-4.2 + index * 1.4, 0.17, float(side) * (rail_z + 0.08))
			stud.material_override = studs
			add_child(stud)
		for end: int in [-1, 1]:
			_brass_corner(Vector3(float(end) * 5.5, 0.0, float(side) * rail_z))


func _brass_corner(at: Vector3) -> void:
	var cap := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.7, 0.4, FRAME_WIDTH + 0.12)
	cap.mesh = mesh
	cap.position = at
	cap.material_override = WoodMaterials.iron()
	add_child(cap)
	var gem := MeshInstance3D.new()
	var gem_mesh := SphereMesh.new()
	gem_mesh.radius = 0.11
	gem_mesh.height = 0.16
	gem.mesh = gem_mesh
	gem.position = at + Vector3(0.0, 0.23, 0.0)
	var gem_material := StandardMaterial3D.new()
	gem_material.albedo_color = Color("ff6a3a")
	gem_material.emission_enabled = true
	gem_material.emission = Color("ff4a1c")
	gem_material.emission_energy_multiplier = 1.6
	gem_material.roughness = 0.1
	gem.material_override = gem_material
	add_child(gem)


func _build_candles() -> void:
	var spots: Array[Vector3] = [
		Vector3(-4.4, 0.0, 5.2), Vector3(-3.7, 0.0, 5.7), Vector3(4.3, 0.0, 5.4),
		Vector3(-4.5, 0.0, -5.4), Vector3(4.2, 0.0, -5.3), Vector3(3.6, 0.0, -5.9),
	]
	var heights: Array[float] = [0.9, 0.55, 0.75, 0.8, 0.95, 0.6]
	for index: int in range(spots.size()):
		var spot := spots[index]
		var height := heights[index]
		var wax := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.13
		cylinder.bottom_radius = 0.15
		cylinder.height = height
		wax.mesh = cylinder
		wax.position = spot + Vector3(0.0, -0.27 + height * 0.5, 0.0)
		var wax_material := StandardMaterial3D.new()
		wax_material.albedo_color = Color("efe2c4")
		wax_material.roughness = 0.6
		wax_material.emission_enabled = true
		wax_material.emission = Color("ff9a4a")
		wax_material.emission_energy_multiplier = 0.12
		wax.material_override = wax_material
		add_child(wax)
		var holder := MeshInstance3D.new()
		var plate := CylinderMesh.new()
		plate.top_radius = 0.24
		plate.bottom_radius = 0.26
		plate.height = 0.05
		holder.mesh = plate
		holder.position = spot + Vector3(0.0, -0.25, 0.0)
		holder.material_override = WoodMaterials.brass()
		add_child(holder)
		var flame_at := spot + Vector3(0.0, -0.22 + height, 0.0)
		_add_flame(flame_at)
		if index % 2 == 0:
			var light := OmniLight3D.new()
			light.position = flame_at + Vector3(0.0, 0.35, 0.0)
			light.light_color = Color("ffa04f")
			light.light_energy = 1.8
			light.set_meta("base_energy", 1.8)
			light.omni_range = 5.5
			light.omni_attenuation = 1.3
			add_child(light)
			_flicker_lights.append(light)


func _build_props() -> void:
	# Coin stacks.
	for stack: Vector3 in [Vector3(3.2, 0.0, 5.0), Vector3(-2.9, 0.0, -5.2)]:
		for index: int in range(5):
			var coin := MeshInstance3D.new()
			var disc := CylinderMesh.new()
			disc.top_radius = 0.2
			disc.bottom_radius = 0.2
			disc.height = 0.05
			coin.mesh = disc
			coin.position = stack + Vector3(randf_range(-0.03, 0.03), -0.24 + index * 0.055, randf_range(-0.03, 0.03))
			coin.material_override = WoodMaterials.brass(0.2)
			add_child(coin)
	# Bone dice.
	for die_spot: Vector3 in [Vector3(2.4, 0.0, 5.7), Vector3(2.85, 0.0, 5.55)]:
		var die := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = Vector3(0.26, 0.26, 0.26)
		die.mesh = cube
		die.position = die_spot + Vector3(0.0, -0.14, 0.0)
		die.rotation_degrees = Vector3(0.0, randf_range(0.0, 90.0), 0.0)
		var bone := StandardMaterial3D.new()
		bone.albedo_color = Color("e8dcc0")
		bone.roughness = 0.5
		die.material_override = bone
		add_child(die)
	# Crystal ball on a brass stand, glowing faintly.
	var stand := MeshInstance3D.new()
	var stand_mesh := CylinderMesh.new()
	stand_mesh.top_radius = 0.18
	stand_mesh.bottom_radius = 0.28
	stand_mesh.height = 0.2
	stand.mesh = stand_mesh
	stand.position = Vector3(-3.0, -0.17, 5.6)
	stand.material_override = WoodMaterials.brass()
	add_child(stand)
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	orb.mesh = sphere
	orb.position = Vector3(-3.0, 0.2, 5.6)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.55, 0.75, 1.0, 0.55)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.emission_enabled = true
	glass.emission = Color("5a8cff")
	glass.emission_energy_multiplier = 1.2
	glass.roughness = 0.05
	glass.metallic = 0.2
	orb.material_override = glass
	add_child(orb)


func _build_dust() -> void:
	var dust := CPUParticles3D.new()
	dust.name = "DustMotes"
	dust.amount = 40
	dust.lifetime = 8.0
	dust.preprocess = 8.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(7.0, 1.5, 8.0)
	dust.position.y = 1.0
	dust.direction = Vector3(0.3, 0.2, 0.0)
	dust.spread = 180.0
	dust.gravity = Vector3(0.0, 0.02, 0.0)
	dust.initial_velocity_min = 0.03
	dust.initial_velocity_max = 0.12
	dust.scale_amount_min = 0.03
	dust.scale_amount_max = 0.06
	dust.mesh = _spark_mesh()
	dust.color_ramp = _fade_gradient(Color(1.0, 0.85, 0.55, 0.0), Color(1.0, 0.8, 0.5, 0.6), Color(1.0, 0.7, 0.4, 0.0))
	add_child(dust)


func _add_flame(at: Vector3) -> void:
	var flame := CPUParticles3D.new()
	flame.amount = 14
	flame.lifetime = 0.55
	flame.position = at
	flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flame.emission_sphere_radius = 0.03
	flame.direction = Vector3.UP
	flame.spread = 8.0
	flame.gravity = Vector3(0.0, 1.2, 0.0)
	flame.initial_velocity_min = 0.15
	flame.initial_velocity_max = 0.35
	flame.scale_amount_min = 0.12
	flame.scale_amount_max = 0.2
	flame.mesh = _spark_mesh()
	flame.color_ramp = _fade_gradient(Color(1.0, 0.95, 0.75, 1.0), Color(1.0, 0.6, 0.2, 0.9), Color(0.8, 0.2, 0.05, 0.0))
	add_child(flame)


func _spark_mesh() -> QuadMesh:
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
	material.albedo_texture = _radial_texture()
	quad.material = material
	return quad


func _fade_gradient(start: Color, middle: Color, end: Color) -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([start, middle, end])
	return gradient


func _radial_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture
