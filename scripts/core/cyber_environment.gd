class_name CyberEnvironment
extends Node3D

## Purely visual scene around the board: the board floats as a dark metal
## platform in a digital void above an endless neon grid, with data towers on
## the horizon and code raining down. Nothing here affects game rules.

const BOARD_HALF_WIDTH: float = 3.5
const BOARD_HALF_DEPTH: float = 3.5
const CYAN := Color("2ad4ff")
const MAGENTA := Color("ff2fb4")
const CODE_GREEN := Color("6ee65a")
const TEAM_EDGES: Array[Color] = [Color("3fa9ff"), Color("ff5a3c")]

const FLOOR_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 line_color : source_color = vec4(0.16, 0.83, 1.0, 1.0);
uniform vec4 base_color : source_color = vec4(0.01, 0.015, 0.03, 1.0);
uniform float cell = 1.4;
uniform float speed = 0.35;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 coord = world_position.xz / cell + vec2(0.0, TIME * speed);
	vec2 grid = abs(fract(coord - 0.5) - 0.5) / fwidth(coord);
	float line = 1.0 - min(min(grid.x, grid.y), 1.0);
	// Every fifth line is brighter, like a measuring grid.
	vec2 major = abs(fract(coord / 5.0 - 0.5) - 0.5) / fwidth(coord / 5.0);
	float major_line = 1.0 - min(min(major.x, major.y), 1.0);
	float distance_fade = clamp(1.0 - length(world_position.xz) / 70.0, 0.0, 1.0);
	float glow = max(line * 0.55, major_line) * distance_fade;
	ALBEDO = base_color.rgb + line_color.rgb * glow * 1.6;
}
"""

const TOWER_SHADER := """
shader_type spatial;
render_mode unshaded;

uniform vec4 tint : source_color = vec4(0.16, 0.83, 1.0, 1.0);
uniform float seed = 0.0;

void fragment() {
	// Lit windows scroll upwards like data streams.
	vec2 cells = floor(UV * vec2(4.0, 60.0) + vec2(0.0, -TIME * (1.0 + seed)));
	float lit = step(0.72, fract(sin(dot(cells, vec2(12.9898, 78.233)) + seed * 3.1) * 43758.5453));
	float edge = step(0.92, max(UV.x, 1.0 - UV.x));
	vec3 body = vec3(0.012, 0.016, 0.03);
	ALBEDO = body + tint.rgb * (lit * 0.9 + edge * 0.6) * (1.0 - UV.y * 0.6);
}
"""

var _time: float = 0.0
var _pulsing: Array[Dictionary] = []


func build() -> void:
	_build_world_environment()
	_build_lights()
	_build_floor()
	_build_towers()
	_build_code_rain()
	_build_motes()


func _process(delta: float) -> void:
	_time += delta
	for entry: Dictionary in _pulsing:
		var material := entry["material"] as StandardMaterial3D
		material.emission_energy_multiplier = float(entry["base"]) * (0.8 + 0.2 * sin(_time * float(entry["speed"]) + float(entry["phase"])))


func _build_world_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("04050a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("3a4a7a")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.05
	environment.glow_enabled = true
	environment.glow_intensity = 0.9
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.05
	environment.glow_hdr_threshold = 0.9
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for level: int in range(7):
		environment.set_glow_level(level, level >= 1 and level <= 4)
	environment.fog_enabled = true
	environment.fog_light_color = Color("0a1024")
	environment.fog_density = 0.025
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.12
	environment.adjustment_saturation = 1.15
	world_environment.environment = environment
	add_child(world_environment)


func _build_lights() -> void:
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.rotation_degrees = Vector3(-62.0, -28.0, 0.0)
	key.light_color = Color("d6e4ff")
	key.light_energy = 0.9
	key.shadow_enabled = true
	key.shadow_opacity = 0.65
	add_child(key)
	# Neon wash from both sides: cyan on the left, magenta on the right.
	for side: int in [-1, 1]:
		var neon := OmniLight3D.new()
		neon.name = "NeonWash_%d" % side
		neon.position = Vector3(float(side) * 6.0, 2.5, 0.0)
		neon.light_color = CYAN if side < 0 else MAGENTA
		neon.light_energy = 2.2
		neon.omni_range = 11.0
		add_child(neon)


func _build_floor() -> void:
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "NeonGrid"
	var plane := PlaneMesh.new()
	plane.size = Vector2(160.0, 160.0)
	floor_mesh.mesh = plane
	floor_mesh.position.y = -4.0
	var shader := Shader.new()
	shader.code = FLOOR_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	floor_mesh.material_override = material
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor_mesh)


func _neon_strip(at: Vector3, size: Vector3, color: Color, energy: float) -> void:
	var strip := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	strip.mesh = box
	strip.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color.lightened(0.3)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	strip.material_override = material
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(strip)
	_pulsing.append({"material": material, "base": energy, "speed": 1.3 + randf(), "phase": randf() * TAU})


## A ring of glowing data towers far away, fading into the fog.
func _build_towers() -> void:
	var shader := Shader.new()
	shader.code = TOWER_SHADER
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for index: int in range(26):
		var angle := TAU * float(index) / 26.0 + rng.randf_range(-0.08, 0.08)
		var distance := rng.randf_range(22.0, 48.0)
		var height := rng.randf_range(8.0, 30.0)
		var tower := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(rng.randf_range(1.2, 3.0), height, rng.randf_range(1.2, 3.0))
		tower.mesh = box
		tower.position = Vector3(cos(angle) * distance, -4.0 + height * 0.5, sin(angle) * distance)
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("tint", [CYAN, MAGENTA, CODE_GREEN][index % 3])
		material.set_shader_parameter("seed", rng.randf())
		tower.material_override = material
		tower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tower)


## Thin green streaks falling through the void, the grid's code.
func _build_code_rain() -> void:
	var rain := CPUParticles3D.new()
	rain.name = "CodeRain"
	rain.amount = 140
	rain.lifetime = 4.0
	rain.preprocess = 4.0
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(18.0, 0.5, 18.0)
	rain.position = Vector3(0.0, 9.0, 0.0)
	rain.direction = Vector3(0.0, -1.0, 0.0)
	rain.spread = 0.0
	rain.gravity = Vector3.ZERO
	rain.initial_velocity_min = 3.0
	rain.initial_velocity_max = 6.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.9)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.albedo_texture = _streak_texture()
	material.albedo_color = Color(CODE_GREEN, 0.7)
	quad.material = material
	rain.mesh = quad
	add_child(rain)


func _build_motes() -> void:
	var motes := CPUParticles3D.new()
	motes.name = "DataMotes"
	motes.amount = 50
	motes.lifetime = 7.0
	motes.preprocess = 7.0
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(6.0, 2.0, 6.0)
	motes.position = Vector3(0.0, 1.2, 0.0)
	motes.gravity = Vector3(0.0, 0.06, 0.0)
	motes.initial_velocity_min = 0.02
	motes.initial_velocity_max = 0.12
	motes.spread = 180.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = Color(CYAN, 0.8)
	quad.material = material
	motes.mesh = quad
	add_child(motes)


## Bright head fading into a tail, for one falling code streak.
func _streak_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	gradient.colors = PackedColorArray([Color(0.9, 1.0, 0.9, 1.0), Color(0.4, 1.0, 0.4, 0.7), Color(0.2, 0.8, 0.2, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 1.0)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 4
	texture.height = 64
	return texture
