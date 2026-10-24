class_name CombatEffects
extends RefCounted

## One-shot visual effects for moves and captures: magic circles, teleport
## pillars, bursts, lightning, projectiles and voxel debris. Every effect adds
## its own nodes under `parent` and frees them when done.

static var _circle_texture: ImageTexture


## Rotating rune circle on the floor; fade it out with dismiss().
static func magic_circle(parent: Node, at: Vector3, color: Color) -> Node3D:
	var circle := MeshInstance3D.new()
	circle.name = "MagicCircle"
	var quad := PlaneMesh.new()
	quad.size = Vector2(1.5, 1.5)
	circle.mesh = quad
	circle.material_override = _glow_material(color, 1.0, _rune_texture())
	circle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(circle)
	circle.global_position = at + Vector3(0.0, 0.04, 0.0)
	circle.scale = Vector3.ONE * 0.05
	var grow := circle.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	grow.tween_property(circle, "scale", Vector3.ONE, 0.3)
	var spin := circle.create_tween().set_loops()
	spin.tween_property(circle, "rotation:y", TAU, 2.2).from(0.0)
	return circle


static func dismiss(node: Node3D, duration: float = 0.25) -> void:
	if not is_instance_valid(node):
		return
	var fade := node.create_tween()
	fade.tween_property(node, "scale", Vector3.ONE * 0.01, duration)
	fade.tween_callback(node.queue_free)


## Column of light, used where a figure vanishes or appears.
static func pillar(parent: Node, at: Vector3, color: Color) -> void:
	var beam := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.35
	cylinder.bottom_radius = 0.45
	cylinder.height = 3.0
	beam.mesh = cylinder
	beam.material_override = _glow_material(color, 0.8, _vertical_fade())
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(beam)
	beam.global_position = at + Vector3(0.0, 1.5, 0.0)
	beam.scale = Vector3(0.2, 1.0, 0.2)
	var tween := beam.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(beam, "scale", Vector3(1.0, 1.0, 1.0), 0.12)
	tween.tween_property(beam, "scale", Vector3(0.05, 1.2, 0.05), 0.35)
	tween.tween_callback(beam.queue_free)


## Expanding flash, e.g. where a hit lands.
static func burst(parent: Node, at: Vector3, color: Color, radius: float = 0.9) -> void:
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	flash.mesh = sphere
	var material := _glow_material(color, 0.85, null)
	flash.material_override = material
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flash)
	flash.global_position = at
	flash.scale = Vector3.ONE * 0.1
	var tween := flash.create_tween().set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * radius * 2.0, 0.28).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.3)
	tween.chain().tween_callback(flash.queue_free)


## Jagged bolt from `from` to `to` that flickers briefly.
static func lightning(parent: Node, from: Vector3, to: Vector3, color: Color) -> void:
	var bolt := Node3D.new()
	bolt.name = "Lightning"
	parent.add_child(bolt)
	var material := _glow_material(color.lightened(0.4), 1.0, null)
	var points: Array[Vector3] = [from]
	var segments := 7
	for index: int in range(1, segments):
		var t := float(index) / float(segments)
		var jitter := Vector3(randf_range(-0.25, 0.25), randf_range(-0.2, 0.2), randf_range(-0.25, 0.25))
		points.append(from.lerp(to, t) + jitter)
	points.append(to)
	for index: int in range(points.size() - 1):
		var a := points[index]
		var b := points[index + 1]
		var piece := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.05, 0.05, a.distance_to(b))
		piece.mesh = box
		piece.material_override = material
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bolt.add_child(piece)
		piece.global_position = (a + b) * 0.5
		if a.distance_squared_to(b) > 0.0001:
			piece.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	var flicker := bolt.create_tween()
	for _blink: int in range(3):
		flicker.tween_property(bolt, "visible", false, 0.05)
		flicker.tween_property(bolt, "visible", true, 0.05)
	flicker.tween_property(material, "albedo_color:a", 0.0, 0.15)
	flicker.tween_callback(bolt.queue_free)


## Glowing shot that travels from `from` to `to`; awaits its arrival.
static func projectile(parent: Node, from: Vector3, to: Vector3, color: Color) -> void:
	var shot := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.12, 0.32)
	shot.mesh = box
	shot.material_override = _glow_material(color.lightened(0.3), 1.0, null)
	shot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(shot)
	shot.global_position = from
	if from.distance_squared_to(to) > 0.0001:
		shot.look_at(to, Vector3.UP)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 1.5
	shot.add_child(light)
	var travel := shot.create_tween()
	travel.tween_property(shot, "global_position", to, clampf(from.distance_to(to) / 16.0, 0.08, 0.4))
	await travel.finished
	shot.queue_free()


## The figure breaks into cubes that fly away and fall.
static func shatter(parent: Node, origin: Vector3, direction: Vector3, colors: Array[Color], accent: Color) -> void:
	burst(parent, origin, accent, 0.6)
	for index: int in range(28):
		var cube := MeshInstance3D.new()
		var box := BoxMesh.new()
		var side := randf_range(0.06, 0.13)
		box.size = Vector3.ONE * side
		cube.mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = colors[index % colors.size()]
		material.emission_enabled = index % 5 == 0
		material.emission = accent
		cube.material_override = material
		parent.add_child(cube)
		var start := origin + Vector3(randf_range(-0.25, 0.25), randf_range(-0.6, 0.5), randf_range(-0.25, 0.25))
		cube.global_position = start
		var velocity := (direction * randf_range(1.0, 2.6) + Vector3(randf_range(-1.6, 1.6), randf_range(1.6, 3.4), randf_range(-1.6, 1.6)))
		var spin := Vector3(randf_range(-9.0, 9.0), randf_range(-9.0, 9.0), randf_range(-9.0, 9.0))
		var tween := cube.create_tween()
		tween.tween_method(func(t: float) -> void:
			cube.global_position = start + velocity * t + Vector3(0.0, -6.0 * t * t, 0.0)
			cube.rotation = spin * t
			cube.scale = Vector3.ONE * clampf(1.4 - t * 1.4, 0.0, 1.0), 0.0, 1.0, randf_range(0.7, 1.0))
		tween.tween_callback(cube.queue_free)


static func _glow_material(color: Color, alpha: float, texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(color, alpha)
	material.albedo_texture = texture
	return material


## Two rings with rune ticks between them.
static func _rune_texture() -> ImageTexture:
	if _circle_texture != null:
		return _circle_texture
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(size, size) * 0.5
	for y: int in range(size):
		for x: int in range(size):
			var offset := Vector2(x + 0.5, y + 0.5) - center
			var distance := offset.length()
			var angle := offset.angle()
			var lit := 0.0
			if absf(distance - 60.0) < 1.6 or absf(distance - 46.0) < 1.2:
				lit = 1.0
			elif distance > 48.0 and distance < 58.0 and fmod(angle * 12.0 / PI + 24.0, 2.0) < 0.35:
				lit = 0.9
			elif absf(distance - 30.0) < 1.0 and fmod(angle * 3.0 / PI + 6.0, 2.0) < 1.2:
				lit = 0.7
			if lit > 0.0:
				image.set_pixel(x, y, Color(1, 1, 1, lit))
	_circle_texture = ImageTexture.create_from_image(image)
	return _circle_texture


static func _vertical_fade() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 1.0)
	texture.fill_to = Vector2(0.5, 0.0)
	return texture


## Fat rocket from `from` to `to` with a puff of smoke every step; awaits its arrival.
static func rocket(parent: Node, from: Vector3, to: Vector3, color: Color) -> void:
	var shot := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.16, 0.16, 0.5)
	shot.mesh = box
	shot.material_override = _glow_material(color.lightened(0.35), 1.0, null)
	shot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(shot)
	shot.global_position = from
	if from.distance_squared_to(to) > 0.0001:
		shot.look_at(to, Vector3.UP)
	var duration := clampf(from.distance_to(to) / 12.0, 0.15, 0.5)
	var travel := shot.create_tween()
	travel.tween_property(shot, "global_position", to, duration)
	var smoke := shot.create_tween().set_loops(6)
	smoke.tween_interval(duration / 6.0)
	smoke.tween_callback(func() -> void: burst(parent, shot.global_position, Color(0.8, 0.8, 0.8), 0.28))
	await travel.finished
	shot.queue_free()
