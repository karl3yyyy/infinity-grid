class_name FighterModel
extends Node3D

## A rigged human (Quaternius Universal Base Characters, CC0) dressed from a
## character description: skin, hairstyle, beard and procedural cyber gear such
## as a long coat, shades, head tubes, implants, horns or a hover pram. The
## Universal Animation Library (CC0) is retargeted onto it at import, so every
## animation name in ANIMATIONS can be played.

const HUMANS := "res://assets/characters/humans/"
const BODY_SCENES := {
	"male": HUMANS + "Superhero_Male_FullBody.gltf",
	"female": HUMANS + "Superhero_Female_FullBody.gltf",
}
const SKIN_TEXTURES := {
	"male_light": HUMANS + "T_Superhero_Male_Light.png",
	"male_dark": HUMANS + "T_Superhero_Male_Dark.png",
	"female_light": HUMANS + "T_Superhero_Female_Light_BaseColor.png",
	"female_dark": HUMANS + "T_Superhero_Female_Dark_BaseColor.png",
}
const HAIR_SCENES := {
	"buzzed": HUMANS + "Hair_Buzzed.gltf",
	"buzzed_f": HUMANS + "Hair_BuzzedFemale.gltf",
	"long": HUMANS + "Hair_Long.gltf",
	"parted": HUMANS + "Hair_SimpleParted.gltf",
	"buns": HUMANS + "Hair_Buns.gltf",
	"beard": HUMANS + "Hair_Beard.gltf",
}
const ANIMATION_SCENE := HUMANS + "animation_library.glb"

## Vertex colour masks painted from the bind pose: r = top, g = trousers,
## b = shoes, a = how far along the arm (0 shoulder .. 1 wrist).
const OUTFIT_SHADER := """
shader_type spatial;

uniform sampler2D skin_texture : source_color;
uniform vec4 skin_tint : source_color = vec4(1.0);
uniform vec4 top_color : source_color;
uniform vec4 bottom_color : source_color;
uniform vec4 shoe_color : source_color;
uniform vec4 accent_color : source_color;
uniform float sleeves = 1.0;
uniform float covered = 1.0;
// Glowing piping, belt and seams; 0 for plain clothes.
uniform float trim = 1.0;

void fragment() {
	vec3 skin = texture(skin_texture, UV).rgb * skin_tint.rgb;
	float top = COLOR.r * step(COLOR.a, sleeves + 0.001) * covered;
	float bottom = COLOR.g * covered;
	float shoes = COLOR.b * covered;
	float height = UV2.x;
	float side = abs(UV2.y);
	// A faint ripple so large areas read as cloth rather than paint.
	float fold = 0.95 + 0.05 * sin(height * 40.0 + side * 18.0);
	vec3 color = skin;
	color = mix(color, bottom_color.rgb * fold, bottom);
	color = mix(color, top_color.rgb * fold, top);
	color = mix(color, shoe_color.rgb, shoes);
	vec3 glow = vec3(0.0);
	// Belt over the hips with a metal buckle.
	float belt = (1.0 - step(0.028, abs(height - 0.02))) * max(top, bottom) * step(side, 0.2);
	color = mix(color, vec3(0.05, 0.05, 0.06), belt);
	float buckle = belt * (1.0 - step(0.03, side));
	color = mix(color, vec3(0.75, 0.75, 0.8), buckle);
	// Centre zip and piping down the sides of the shirt and trousers.
	float zip = top * (1.0 - step(0.005, side)) * step(0.06, height);
	float piping = top * (1.0 - step(0.006, abs(side - 0.1))) * step(0.08, height) * step(COLOR.a, 0.01);
	float leg_seam = bottom * (1.0 - step(0.008, abs(side - 0.2))) * step(height, -0.32);
	color = mix(color, color * 0.4, zip);
	glow += accent_color.rgb * (piping + leg_seam + buckle * 0.3) * trim;
	// Soles.
	color = mix(color, vec3(0.02), shoes * (1.0 - step(0.012, height + 0.92)));
	ALBEDO = color;
	EMISSION = glow * 1.6;
	ROUGHNESS = mix(0.6, 0.85, max(top, bottom));
	ROUGHNESS = mix(ROUGHNESS, 0.35, max(shoes, buckle));
	METALLIC = max(shoes * 0.3, buckle * 0.8);
}
"""

static var _library: AnimationLibrary
static var _outfit_shader: Shader
static var _outfit_meshes: Dictionary = {}

var animation_player: AnimationPlayer
var skeleton: Skeleton3D
var _current: StringName = &""


## look: one entry of CharacterRoster.CHARACTERS (body, skin, hair, gear...).
func build(look: Dictionary) -> void:
	var body := str(look.get("body", "male"))
	var model := (load(BODY_SCENES.get(body, BODY_SCENES["male"])) as PackedScene).instantiate() as Node3D
	model.name = "Body"
	add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_dress_skin(model, look, body)
	var hair := str(look.get("hair", ""))
	if HAIR_SCENES.has(hair):
		_attach_mesh(HAIR_SCENES[hair], look.get("hair_color", Color("2a1d16")))
	if hair == "long":
		# The library's "long" hair ends at the chin; add the length down the back.
		ClothBuilder.long_hair(skeleton, look.get("hair_color", Color("2a1d16")))
	if look.get("beard", false):
		_attach_mesh(HAIR_SCENES["beard"], look.get("hair_color", Color("2a1d16")))
	if float(look.get("head_scale", 1.0)) != 1.0:
		var modifier := HeadScaleModifier.new()
		modifier.head_scale = float(look.get("head_scale", 1.0))
		skeleton.add_child(modifier)
	for gear: String in look.get("gear", []):
		_add_gear(gear, look)
	scale = Vector3.ONE * float(look.get("scale", 1.0))
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)
	animation_player.root_node = animation_player.get_path_to(model)
	animation_player.add_animation_library("", _animations())
	if "pram" in look.get("gear", []):
		play(&"Sitting_Idle")
	else:
		play(&"Idle")


func play(animation: StringName, blend: float = 0.15, speed: float = 1.0) -> void:
	if animation_player == null or not animation_player.has_animation(animation):
		return
	if _current == animation and animation_player.is_playing():
		return
	_current = animation
	animation_player.play(animation, blend, speed)


## Plays a one-shot animation and waits until it is done (or `limit` seconds).
func play_once(animation: StringName, limit: float = 1.2, speed: float = 1.0) -> void:
	if animation_player == null or not animation_player.has_animation(animation):
		return
	_current = animation
	animation_player.play(animation, 0.1, speed)
	var length := minf(animation_player.get_animation(animation).length / speed, limit)
	await get_tree().create_timer(length).timeout


static func _animations() -> AnimationLibrary:
	if _library != null:
		return _library
	var source := (load(ANIMATION_SCENE) as PackedScene).instantiate()
	var player := source.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	_library = AnimationLibrary.new()
	for name: StringName in player.get_animation_list():
		# The importer already strips "_Loop" from names and sets looping.
		var animation := player.get_animation(name).duplicate() as Animation
		_library.add_animation(name, animation)
	source.free()
	return _library


func _dress_skin(model: Node3D, look: Dictionary, body: String) -> void:
	var skin_key := "%s_%s" % [body, str(look.get("skin", "light"))]
	var texture := load(SKIN_TEXTURES.get(skin_key, SKIN_TEXTURES["male_light"])) as Texture2D
	var tint: Color = look.get("tint", Color.WHITE)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if str(mesh.name).to_lower().begins_with("superhero"):
			# The base bodies only wear underwear; paint an outfit over them.
			mesh.mesh = _outfit_mesh(mesh, body)
			if _outfit_shader == null:
				_outfit_shader = Shader.new()
				_outfit_shader.code = OUTFIT_SHADER
			var material := ShaderMaterial.new()
			material.shader = _outfit_shader
			material.set_shader_parameter("skin_texture", texture)
			material.set_shader_parameter("skin_tint", tint)
			var outfit: Dictionary = look.get("outfit", {})
			material.set_shader_parameter("top_color", outfit.get("top", Color("16181c")))
			material.set_shader_parameter("bottom_color", outfit.get("bottom", Color("101114")))
			material.set_shader_parameter("shoe_color", outfit.get("shoes", Color("08090a")))
			material.set_shader_parameter("accent_color", outfit.get("accent", look.get("glow_color", Color("6ee65a"))))
			material.set_shader_parameter("trim", 0.0 if outfit.get("plain", false) else 1.0)
			material.set_shader_parameter("sleeves", {"long": 1.0, "short": 0.5, "none": 0.0}.get(outfit.get("sleeves", "long"), 1.0))
			material.set_shader_parameter("covered", 0.0 if outfit.get("skin_only", false) else 1.0)
			mesh.material_override = material
		elif mesh.name == "Eyebrows":
			var brows := StandardMaterial3D.new()
			brows.albedo_color = Color(look.get("hair_color", Color("2a1d16"))).darkened(0.2)
			mesh.material_override = brows
		elif mesh.name == "Eyes" and look.get("glow_eyes", false):
			var eyes := StandardMaterial3D.new()
			eyes.albedo_color = look.get("glow_color", Color("6ee65a"))
			eyes.emission_enabled = true
			eyes.emission = look.get("glow_color", Color("6ee65a"))
			eyes.emission_energy_multiplier = 3.0
			mesh.material_override = eyes


## Copy of the body mesh with outfit masks in the vertex colours, worked out
## from bone positions at the bind pose (neck, hips, ankles, wrists).
func _outfit_mesh(instance: MeshInstance3D, body: String) -> Mesh:
	if _outfit_meshes.has(body):
		return _outfit_meshes[body]
	var source := instance.mesh
	# Bone positions in the mesh's own units (the bodies use different scales).
	var unit := absf(_mesh_rest(instance, "Head").y - _mesh_rest(instance, "Neck").y) / maxf(absf(_rest("Head").y - _rest("Neck").y), 0.001)
	var neck_y := _mesh_rest(instance, "Neck").y
	var hips_y := _mesh_rest(instance, "Hips").y - 0.04 * unit
	var ankle_y := _mesh_rest(instance, "LeftFoot").y + 0.045 * unit
	var shoulder_x := absf(_mesh_rest(instance, "LeftUpperArm").x)
	var wrist_x := absf(_mesh_rest(instance, "LeftHand").x) - 0.025 * unit
	var mesh := ArrayMesh.new()
	for surface: int in range(source.get_surface_count()):
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors := PackedColorArray()
		colors.resize(vertices.size())
		# UV2 = (metres above the hips, metres from the centre line) for seams and belts.
		var places := PackedVector2Array()
		places.resize(vertices.size())
		for index: int in range(vertices.size()):
			var v := vertices[index]
			var across := absf(v.x)
			# The shirt reaches up over the shoulders; only the neck stays bare.
			var collar_y := neck_y - 0.035 * unit if across < 0.075 * unit else neck_y + 0.02 * unit
			var top := 1.0 if v.y > hips_y and v.y < collar_y and across < wrist_x else 0.0
			places[index] = Vector2((v.y - hips_y) / unit, v.x / unit)
			var bottom := 1.0 if v.y <= hips_y and v.y > ankle_y else 0.0
			var shoes := 1.0 if v.y <= ankle_y else 0.0
			var arm := clampf((across - shoulder_x) / maxf(wrist_x - shoulder_x, 0.01), 0.0, 1.0)
			colors[index] = Color(top, bottom, shoes, arm)
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV2] = places
		# Custom channels would need their format flags; the outfit shader does not use them.
		for channel: int in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			arrays[channel] = null
		# Keep 8-bone skinning, or the body falls apart (blend shapes are not used).
		var flags: int = source.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	_outfit_meshes[body] = mesh
	return mesh


## Where a bone sits in the mesh's bind space, from the skin's bind poses.
func _mesh_rest(instance: MeshInstance3D, bone: String) -> Vector3:
	var skin := instance.skin
	if skin != null:
		for bind: int in range(skin.get_bind_count()):
			var bind_name := skin.get_bind_name(bind)
			var bone_index := skin.get_bind_bone(bind)
			if bind_name == bone or (bone_index >= 0 and skeleton.get_bone_name(bone_index) == bone):
				return skin.get_bind_pose(bind).affine_inverse().origin
	return _rest(bone)


func _rest(bone: String) -> Vector3:
	return skeleton.get_bone_global_rest(skeleton.find_bone(bone)).origin


## Hair meshes are modelled at the bind pose ("origin at 0"); keep them where
## they were authored relative to the head while the head moves.
func _attach_mesh(path: String, color: Color) -> void:
	var scene := (load(path) as PackedScene).instantiate()
	var attachment := _head_attachment()
	for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var copy := mesh.duplicate() as MeshInstance3D
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.85
		copy.material_override = material
		copy.transform = _head_rest().affine_inverse() * _transform_in(scene, mesh)
		attachment.add_child(copy)
	scene.free()


func _transform_in(root: Node, node: Node3D) -> Transform3D:
	var transform := node.transform
	var parent := node.get_parent()
	while parent != null and parent != root:
		if parent is Node3D:
			transform = (parent as Node3D).transform * transform
		parent = parent.get_parent()
	return transform


func _head_rest() -> Transform3D:
	return skeleton.get_bone_global_rest(skeleton.find_bone("Head"))


func _bone_attachment(bone: String) -> BoneAttachment3D:
	var existing := skeleton.get_node_or_null("Attach_" + bone) as BoneAttachment3D
	if existing != null:
		return existing
	var attachment := BoneAttachment3D.new()
	attachment.name = "Attach_" + bone
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	return attachment


func _head_attachment() -> BoneAttachment3D:
	return _bone_attachment("Head")


# --- Cyber gear -------------------------------------------------------------

func _add_gear(gear: String, look: Dictionary) -> void:
	var glow: Color = look.get("glow_color", Color("6ee65a"))
	match gear:
		"shades":
			_shades()
		"round_glasses":
			_round_glasses()
		"visor":
			_visor(glow)
		"coat":
			_coat(look.get("coat_color", Color("0d0f12")))
		"tubes":
			_tubes(glow)
		"implants":
			_implants(glow)
		"horns":
			_horns()
		"spikes":
			_spikes()
		"pram":
			_pram(glow)


## Head-local frame at bind pose: head bone origin, eye line about 0.09 up,
## face towards +Z of the model (the importer's rest fixer keeps +Z forward).
func _head_point(offset: Vector3) -> Vector3:
	var rest := _head_rest()
	return rest.affine_inverse() * (Vector3(rest.origin.x, rest.origin.y, rest.origin.z) + offset)


func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.position = at
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _flat(color: Color, emission: float = 0.0, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.3 if metallic > 0.0 else 0.6
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material


func _shades() -> void:
	var head := _head_attachment()
	var black := _flat(Color("050607"), 0.0, 0.9)
	_box(head, Vector3(0.19, 0.045, 0.02), _head_point(Vector3(0.0, 0.085, 0.105)), black)
	for side: float in [-1.0, 1.0]:
		_box(head, Vector3(0.012, 0.012, 0.12), _head_point(Vector3(side * 0.095, 0.09, 0.05)), black)


## Glowing band across the eyes, wrapping round to the temples.
func _visor(glow: Color) -> void:
	var head := _head_attachment()
	var light := _flat(glow, 3.0)
	_box(head, Vector3(0.2, 0.035, 0.02), _head_point(Vector3(0.0, 0.085, 0.108)), light)
	for side: float in [-1.0, 1.0]:
		_box(head, Vector3(0.015, 0.03, 0.09), _head_point(Vector3(side * 0.098, 0.085, 0.06)), _flat(Color("15171a"), 0.0, 0.8))


func _round_glasses() -> void:
	var head := _head_attachment()
	var wire := _flat(Color("c9c3b5"), 0.0, 0.8)
	for side: float in [-1.0, 1.0]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.022
		torus.outer_radius = 0.03
		ring.mesh = torus
		ring.rotation_degrees.x = 90.0
		ring.position = _head_point(Vector3(side * 0.04, 0.085, 0.105))
		ring.material_override = wire
		head.add_child(ring)


## Long open coat; skinned, so the skirt swings with the legs.
func _coat(color: Color) -> void:
	ClothBuilder.coat(skeleton, color)


## Cables plugged into the back of a bald head, drooping onto the shoulders.
func _tubes(glow: Color) -> void:
	var head := _head_attachment()
	var rubber := _flat(Color("1b1d20"), 0.0, 0.4)
	var plug := _flat(glow, 2.5)
	for index: int in range(4):
		var side := -1.0 if index % 2 == 0 else 1.0
		var spread := 0.03 + float(index / 2) * 0.05
		var start := Vector3(side * spread, 0.12 - float(index / 2) * 0.05, -0.09)
		var points: Array[Vector3] = [start, start + Vector3(side * 0.04, -0.06, -0.08), start + Vector3(side * 0.08, -0.2, -0.1), start + Vector3(side * 0.12, -0.34, -0.05)]
		for segment: int in range(points.size() - 1):
			var a := _head_point(points[segment])
			var b := _head_point(points[segment + 1])
			var piece := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.016
			cylinder.bottom_radius = 0.016
			cylinder.height = a.distance_to(b)
			cylinder.radial_segments = 6
			piece.mesh = cylinder
			piece.material_override = rubber
			head.add_child(piece)
			# Point the cylinder (local Y) from a to b, in the head's local space.
			var direction := (b - a).normalized()
			var up := Vector3.FORWARD if absf(direction.y) > 0.9 else Vector3.UP
			piece.transform = Transform3D(Basis.looking_at(direction, up), (a + b) * 0.5)
			piece.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
		_box(head, Vector3(0.035, 0.035, 0.03), _head_point(start), plug)


## Glowing lines along the temples and jaw.
func _implants(glow: Color) -> void:
	var head := _head_attachment()
	var light := _flat(glow, 3.0)
	for side: float in [-1.0, 1.0]:
		_box(head, Vector3(0.008, 0.07, 0.008), _head_point(Vector3(side * 0.088, 0.07, 0.06)), light)
		_box(head, Vector3(0.008, 0.008, 0.05), _head_point(Vector3(side * 0.086, 0.035, 0.04)), light)
		_box(head, Vector3(0.012, 0.012, 0.012), _head_point(Vector3(side * 0.05, 0.13, 0.095)), light)


func _horns() -> void:
	var head := _head_attachment()
	var bone := _flat(Color("e6dcc0"), 0.0, 0.1)
	for side: float in [-1.0, 1.0]:
		var horn := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.035
		cone.height = 0.16
		horn.mesh = cone
		horn.material_override = bone
		horn.position = _head_point(Vector3(side * 0.07, 0.2, 0.0))
		horn.rotation_degrees = Vector3(-15.0, 0.0, -side * 30.0)
		head.add_child(horn)


func _spikes() -> void:
	var chest := _bone_attachment("UpperChest")
	var rest := skeleton.get_bone_global_rest(skeleton.find_bone("UpperChest"))
	var bone := _flat(Color("cfc4a6"))
	for index: int in range(5):
		var spike := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.03
		cone.height = 0.12
		spike.mesh = cone
		spike.material_override = bone
		spike.position = rest.affine_inverse() * (rest.origin + Vector3(0.0, 0.1 - index * 0.08, -0.12))
		spike.rotation_degrees.x = -70.0
		chest.add_child(spike)


## Hovering high-tech pram; the (scaled down) baby sits inside.
func _pram(glow: Color) -> void:
	var pram := Node3D.new()
	pram.name = "Pram"
	add_child(pram)
	var shell := _flat(Color("e8ecf0"), 0.0, 0.6)
	var dark := _flat(Color("1a1d22"), 0.0, 0.5)
	var light := _flat(glow, 3.5)
	# Tub.
	var tub := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 0.7
	sphere.is_hemisphere = true
	tub.mesh = sphere
	tub.material_override = shell
	tub.rotation_degrees.x = 180.0
	tub.position = Vector3(0.0, 0.55, 0.0)
	pram.add_child(tub)
	_box(pram, Vector3(1.0, 0.04, 1.05), Vector3(0.0, 0.55, 0.0), dark)
	# Canopy behind the baby.
	var canopy := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 0.5
	dome.height = 0.6
	dome.is_hemisphere = true
	canopy.mesh = dome
	canopy.material_override = dark
	canopy.position = Vector3(0.0, 0.58, -0.25)
	canopy.rotation_degrees.x = -70.0
	pram.add_child(canopy)
	# Glowing thrusters underneath.
	for corner: Vector2 in [Vector2(-0.3, -0.3), Vector2(0.3, -0.3), Vector2(-0.3, 0.3), Vector2(0.3, 0.3)]:
		var thruster := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.09
		cylinder.bottom_radius = 0.06
		cylinder.height = 0.1
		thruster.mesh = cylinder
		thruster.material_override = light
		thruster.position = Vector3(corner.x, 0.22, corner.y)
		pram.add_child(thruster)
	_box(pram, Vector3(0.8, 0.03, 0.05), Vector3(0.0, 0.62, 0.52), light)
	# The baby sits in the tub at a small scale.
	var body := get_node("Body") as Node3D
	# Seated, the hips drop below the rim so only the upper body shows.
	body.scale = Vector3.ONE * 0.48
	body.position = Vector3(0.0, 0.3, -0.05)
	var hover := pram.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	hover.tween_property(pram, "position:y", 0.08, 0.9)
	hover.tween_property(pram, "position:y", 0.0, 0.9)
	var bob := body.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	bob.tween_property(body, "position:y", 0.38, 0.9)
	bob.tween_property(body, "position:y", 0.3, 0.9)
