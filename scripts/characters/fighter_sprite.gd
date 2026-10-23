class_name FighterSprite
extends Node3D

## Shows a FighterModel as a pixel-art sprite: the model is rendered at low
## resolution in its own small world and drawn on the board as a camera-facing
## quad with nearest filtering, a dark outline, a reduced palette, scanlines and
## a rim light in the team colour. UnitMovement drives it through walking,
## pose() and release().

const FRAME_SIZE := Vector2i(120, 168)
## World height of the sprite quad on the board.
const DISPLAY_HEIGHT: float = 2.05
## The low-res model animates at this rate, like hand-drawn sprite frames.
const FRAMES_PER_SECOND: float = 18.0

const POSE_ANIMATIONS := {
	"cast": &"Spell_Simple_Shoot",
	"channel": &"Spell_Simple_Shoot",
	"wind_up": &"Punch_Enter",
	"punch": &"Punch_Cross",
	"aim": &"Pistol_Aim_Neutral",
	"shoot": &"Pistol_Shoot",
	"cheer": &"Dance",
	"hit": &"Hit_Chest",
	"death": &"Death01",
}

const SPRITE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform sampler2D frame : source_color, filter_nearest;
uniform vec2 frame_size = vec2(120.0, 168.0);
uniform vec4 outline_color : source_color = vec4(0.02, 0.05, 0.03, 1.0);
uniform vec4 rim_color : source_color = vec4(0.43, 0.9, 0.35, 1.0);
uniform float levels = 7.0;
uniform float opacity = 1.0;
uniform float hologram = 0.0;

void vertex() {
	// Face the camera like a sprite, keep the node's scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 texel = 1.0 / frame_size;
	vec2 uv = (floor(UV * frame_size) + 0.5) * texel;
	vec4 color = texture(frame, uv);
	float neighbours = 0.0;
	neighbours = max(neighbours, texture(frame, uv + vec2(texel.x, 0.0)).a);
	neighbours = max(neighbours, texture(frame, uv - vec2(texel.x, 0.0)).a);
	neighbours = max(neighbours, texture(frame, uv + vec2(0.0, texel.y)).a);
	neighbours = max(neighbours, texture(frame, uv - vec2(0.0, texel.y)).a);
	if (color.a < 0.5) {
		if (neighbours < 0.5) {
			discard;
		}
		ALBEDO = outline_color.rgb;
		ALPHA = opacity;
	} else {
		vec3 rgb = floor(color.rgb * levels + 0.5) / levels;
		// Rim: pixels next to the silhouette edge pick up the green glow.
		float edge = 1.0 - min(min(texture(frame, uv + vec2(texel.x * 2.0, 0.0)).a, texture(frame, uv - vec2(texel.x * 2.0, 0.0)).a), texture(frame, uv + vec2(0.0, texel.y * 2.0)).a);
		rgb = mix(rgb, rim_color.rgb, edge * 0.45);
		float row = mod(floor(UV.y * frame_size.y), 2.0);
		rgb *= 1.0 - row * 0.12;
		if (hologram > 0.0) {
			float luma = dot(rgb, vec3(0.3, 0.59, 0.11));
			rgb = mix(rgb, rim_color.rgb * (0.35 + luma * 1.4), hologram);
			float band = step(0.82, fract(UV.y * 9.0 - TIME * 0.6));
			rgb += rim_color.rgb * band * 0.25 * hologram;
		}
		ALBEDO = rgb;
		ALPHA = opacity * (1.0 - hologram * 0.25);
	}
}
"""

static var _shader: Shader

var walking: bool = false:
	set(value):
		walking = value
		_update_locomotion()
## Rotation of the figure relative to the viewer (0 = facing the camera).
var turn: float = 0.0
var model: FighterModel
var viewport: SubViewport
var display: MeshInstance3D
var _model_pivot: Node3D
var _posing: bool = false
var _frame_time: float = 0.0
var _seated: bool = false


## show_display = false renders only into the viewport texture (menu previews).
func build(look: Dictionary, rim_color: Color, hologram: float = 0.0, show_display: bool = true) -> void:
	viewport = SubViewport.new()
	viewport.name = "Frame"
	viewport.size = FRAME_SIZE
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)

	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8a94a8")
	environment.ambient_light_energy = 0.55
	world.environment = environment
	viewport.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, 30.0, 0.0)
	key.light_energy = 1.25
	viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15.0, 160.0, 0.0)
	rim.light_color = rim_color
	rim.light_energy = 2.2
	viewport.add_child(rim)

	_model_pivot = Node3D.new()
	viewport.add_child(_model_pivot)
	model = FighterModel.new()
	model.name = "Model"
	_model_pivot.add_child(model)
	model.build(look)
	_seated = "pram" in look.get("gear", [])

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# Big characters (monsters) get a wider shot and a taller sprite.
	var size_factor := maxf(1.0, float(look.get("scale", 1.0)))
	camera.size = 2.6 * size_factor
	camera.position = Vector3(0.0, 1.25 * size_factor, 4.0)
	camera.rotation_degrees.x = -8.0
	viewport.add_child(camera)
	camera.current = true

	if not show_display:
		return
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SPRITE_SHADER
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter("frame", viewport.get_texture())
	material.set_shader_parameter("frame_size", Vector2(FRAME_SIZE))
	material.set_shader_parameter("rim_color", rim_color)
	material.set_shader_parameter("hologram", hologram)
	display = MeshInstance3D.new()
	display.name = "Display"
	var quad := QuadMesh.new()
	var height := DISPLAY_HEIGHT * size_factor
	quad.size = Vector2(height * float(FRAME_SIZE.x) / float(FRAME_SIZE.y), height)
	display.mesh = quad
	display.material_override = material
	display.position.y = height * 0.5 - 0.08
	display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(display)


## A second quad showing the same frames, for the wrapped edge copies.
func make_mirror() -> MeshInstance3D:
	var copy := display.duplicate() as MeshInstance3D
	copy.material_override = (display.material_override as ShaderMaterial).duplicate()
	(copy.material_override as ShaderMaterial).set_shader_parameter("opacity", 0.5)
	return copy


func _process(delta: float) -> void:
	if model == null:
		return
	_model_pivot.rotation.y = lerp_angle(_model_pivot.rotation.y, turn, minf(1.0, delta * 12.0))
	_frame_time += delta
	if _frame_time >= 1.0 / FRAMES_PER_SECOND:
		_frame_time = 0.0
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## Plays the animation for a pose and waits for its key moment.
func pose(pose_name: String, _duration: float = 0.2) -> void:
	_posing = true
	var animation: StringName = POSE_ANIMATIONS.get(pose_name, &"Idle")
	var hold := {"wind_up": 0.25, "aim": 0.3, "cast": 0.45, "channel": 0.35, "punch": 0.3}.get(pose_name, 0.4) as float
	model.play(animation, 0.08)
	await get_tree().create_timer(hold).timeout


func release(_duration: float = 0.2) -> void:
	_posing = false
	_update_locomotion()
	await get_tree().create_timer(0.12).timeout


func play_death() -> void:
	_posing = true
	await model.play_once(&"Death01", 0.7)


func _update_locomotion() -> void:
	if model == null or _posing:
		return
	if _seated:
		model.play(&"Sitting_Idle")
	else:
		model.play(&"Jog_Fwd" if walking else &"Idle", 0.15, 1.15 if walking else 1.0)


## Floating pixel crown above a master: the piece that has to be captured.
func add_crown() -> void:
	var image := Image.create(15, 9, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var gold := Color("ffc23a")
	image.fill_rect(Rect2i(1, 6, 13, 3), gold.darkened(0.2))
	image.fill_rect(Rect2i(1, 7, 13, 1), gold.lightened(0.2))
	for spike: int in [1, 7, 13]:
		image.fill_rect(Rect2i(spike - 1, 2, 3, 4), gold)
		image.set_pixel(spike, 1, gold.lightened(0.3))
	image.set_pixel(7, 3, Color("ff3a3a"))
	image.set_pixel(4, 7, Color("6ee65a"))
	image.set_pixel(10, 7, Color("6ee65a"))
	var crown := Sprite3D.new()
	crown.name = "Crown"
	crown.texture = ImageTexture.create_from_image(image)
	crown.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	crown.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	crown.shaded = false
	crown.pixel_size = 0.028
	crown.no_depth_test = true
	crown.render_priority = 10
	var top := (display.mesh as QuadMesh).size.y if display != null else DISPLAY_HEIGHT
	crown.position.y = top - 0.02
	add_child(crown)
	var bob := crown.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	bob.tween_property(crown, "position:y", top + 0.08, 0.8)
	bob.tween_property(crown, "position:y", top - 0.02, 0.8)
