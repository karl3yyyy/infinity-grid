class_name VoxelFigure
extends RefCounted

## Builds 3D voxel figures from the same character descriptions as the pixel
## portraits (CharacterRoster): people made of the grid they are trapped in.
## Coordinates: x right, y up, z towards the figure's front. Only faces next to
## empty space become geometry, coloured per voxel.

const VOXEL: float = 0.07
const GOLD := Color("e2b04a")

## Voxel colours keyed by Vector3i.
var voxels: Dictionary = {}


## The master: the one real person on a side, crowned.
static func build_master(look: Dictionary, team_color: Color) -> Node3D:
	var figure := VoxelFigure.new()
	var head_top := figure._person(look, team_color)
	figure._crown(head_top)
	return figure._to_node(1.0, null)


## A student in one of the echo styles, tinted in the team colour.
static func build_echo(style: String, master_look: Dictionary, team_color: Color, seed_value: int) -> Node3D:
	var figure := VoxelFigure.new()
	match style:
		"hood":
			figure._hooded(team_color)
		"drone":
			figure._drone(team_color, seed_value)
		_:
			figure._person(master_look, team_color, true)
			figure._tint_all(team_color, 0.55)
			figure._glitch(seed_value)
	var glow := StandardMaterial3D.new()
	glow.vertex_color_use_as_albedo = true
	glow.roughness = 0.6
	glow.emission_enabled = true
	glow.emission = team_color
	glow.emission_energy_multiplier = 0.25
	if style == "echo":
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow.albedo_color = Color(1, 1, 1, 0.78)
	return figure._to_node(0.82, glow)


# --- Bodies -----------------------------------------------------------------

## Builds a person and returns the y just above the head (for the crown).
func _person(look: Dictionary, team_color: Color, blank_eyes: bool = false) -> int:
	var kind := str(look.get("kind", "human"))
	var skin: Color = look.get("skin", Color("d9a07a"))
	var clothes: Color = look.get("clothes", Color("3b4a3a"))
	var pants := clothes.darkened(0.35).lerp(Color("23262a"), 0.4)
	var shoes := Color("1a1614")
	var baby := kind == "baby"
	var leg_top := 5 if baby else 9
	var torso_top := leg_top + (6 if baby else 9)
	var half_width := 3 if baby else 4

	# Legs and shoes.
	for side: int in [-1, 1]:
		var x0 := 1 if side > 0 else -3
		for y: int in range(0, leg_top + 1):
			for x: int in range(x0, x0 + 2 + (0 if baby else 1) - (1 if side > 0 and baby else 0)):
				for z: int in range(-1, 2):
					_put(x, y, z, shoes if y <= 1 else pants)
		if not baby:
			_put(x0 + (0 if side < 0 else 1), 0, 2, shoes)
	# Torso with a belt in the team colour.
	for y: int in range(leg_top + 1, torso_top + 1):
		for x: int in range(-half_width, half_width):
			for z: int in range(-2, 2 if not baby else 1):
				var color := clothes
				if y == leg_top + 1:
					color = team_color.darkened(0.15)
				elif z == 1 and x == -1 and y > torso_top - 3 and not baby:
					color = clothes.lightened(0.15)
				_put(x, y, z, color)
	# Arms with hands.
	for side: int in [-1, 1]:
		var x := -half_width - 1 if side < 0 else half_width
		for y: int in range(leg_top + (1 if baby else 2), torso_top + 1):
			for z: int in range(-1, 1):
				_put(x, y, z, skin if y <= leg_top + (2 if baby else 3) else clothes.darkened(0.1))
			if not baby and y > torso_top - 3:
				# Shoulder pads make the silhouette broader at the top.
				_put(x + side, y, 0, clothes.darkened(0.2))
	# Neck.
	for x: int in range(-1, 1):
		for z: int in range(-1, 1):
			_put(x, torso_top + 1, z, skin.darkened(0.15))
	return _head(look, torso_top + 2, blank_eyes)


## Head with face, hair and accessories; returns the y above the head.
func _head(look: Dictionary, base: int, blank_eyes: bool) -> int:
	var kind := str(look.get("kind", "human"))
	var skin: Color = look.get("skin", Color("d9a07a"))
	var hair: Color = look.get("hair_color", Color("5a3a24"))
	var size := 9 if kind in ["baby", "creature"] else 8
	var left := -size / 2
	var right := left + size - 1
	var front := size / 2 - 1
	var back := front - size + 1
	var top := base + size - 1
	# Skull block with softened corners.
	for y: int in range(base, top + 1):
		for x: int in range(left, right + 1):
			for z: int in range(back, front + 1):
				var corner := int(x == left or x == right) + int(z == back or z == front) + int(y == top or y == base)
				if corner >= 2:
					continue
				_put(x, y, z, skin)
	var eye_y := base + (3 if kind == "baby" else 4)
	var mouth_y := base + (1 if kind == "baby" else 1)
	var eye_x := [left + 1, right - 2] if size == 8 else [left + 2, right - 2]

	if kind == "skull":
		for ex: int in eye_x:
			_put(ex, eye_y, front, Color("0d0a09"))
			_put(ex + 1, eye_y, front, Color("0d0a09"))
			_put(ex, eye_y, front - 1, Color("7dff6a"))
		_put(-1, eye_y - 2, front, Color("0d0a09"))
		for x: int in range(left + 2, right - 1):
			_put(x, mouth_y, front, Color("0d0a09") if x % 2 == 0 else skin.lightened(0.1))
		return top + 1

	# Eyes, brows, nose, mouth.
	var eye_white := Color("efe9df")
	var iris: Color = look.get("eye_color", Color("2a3a4a"))
	var big_eyes: bool = look.get("big_eyes", kind == "baby")
	for index: int in range(eye_x.size()):
		var ex: int = eye_x[index]
		if blank_eyes:
			_put(ex, eye_y, front, Color("f4fff0"))
			_put(ex + 1, eye_y, front, Color("f4fff0"))
		elif big_eyes:
			_put(ex, eye_y, front, Color("111116"))
			_put(ex + 1, eye_y, front, Color("111116"))
			_put(ex, eye_y + 1, front, Color("111116"))
			_put(ex + (1 if index == 0 else 0), eye_y + 1, front, Color.WHITE)
		else:
			_put(ex + (1 if index == 0 else 0), eye_y, front, eye_white)
			_put(ex + (0 if index == 0 else 1), eye_y, front, iris)
		_put(ex, eye_y + 1 + (1 if big_eyes else 0), front, hair.darkened(0.3))
		_put(ex + 1, eye_y + 1 + (1 if big_eyes else 0), front, hair.darkened(0.3))
	var nose_x := -1 if size == 8 else 0
	_put(nose_x, eye_y - 1, front + 1, skin.darkened(0.08))
	_put(nose_x, eye_y - 2, front + 1, skin.darkened(0.18))
	var lip: Color = look.get("lip", skin.darkened(0.45))
	var mouth := str(look.get("mouth", "flat"))
	for x: int in range(nose_x - 1, nose_x + 2):
		_put(x, mouth_y + (1 if mouth == "smile" and x != nose_x else 0), front, lip)
	match mouth:
		"pacifier":
			_put(nose_x, mouth_y, front + 1, Color("5fc6e8"))
			_put(nose_x, mouth_y, front + 2, Color("f1c84b"))
		"tusks":
			_put(nose_x - 2, mouth_y + 1, front + 1, Color("f2ead2"))
			_put(nose_x + 2, mouth_y + 1, front + 1, Color("f2ead2"))
			_put(nose_x - 2, mouth_y + 2, front + 1, Color("f2ead2"))
			_put(nose_x + 2, mouth_y + 2, front + 1, Color("f2ead2"))
		"frown":
			_put(nose_x - 2, mouth_y - 1, front, lip)
			_put(nose_x + 2, mouth_y - 1, front, lip)
	# Ears.
	_put(left - 1, eye_y - 1, 0, skin.darkened(0.1))
	_put(right + 1, eye_y - 1, 0, skin.darkened(0.1))
	_put(left - 1, eye_y - 2, 0, skin.darkened(0.2))
	_put(right + 1, eye_y - 2, 0, skin.darkened(0.2))

	if look.get("freckles", false):
		for x: int in [left + 1, left + 2, right - 2, right - 1]:
			_put(x, eye_y - 2, front, skin.darkened(0.25))
	if look.get("beard", false):
		for y: int in range(base - 1, mouth_y + 2):
			for x: int in range(left + 1, right):
				if y == mouth_y and absi(x - nose_x) <= 1:
					continue
				_put(x, y, front, hair.darkened(0.05))
				if y < mouth_y:
					_put(x, y, front - 1, hair.darkened(0.15))
		# Sideburns connect the beard to the hair.
		for y: int in range(base, eye_y - 1):
			_put(left, y, front - 1, hair.darkened(0.1))
			_put(right, y, front - 1, hair.darkened(0.1))
	var glasses := str(look.get("glasses", ""))
	if glasses != "":
		var frame := Color("17181a") if glasses == "shades" else Color("c9c3b5")
		for ex: int in eye_x:
			for x: int in range(ex - 1, ex + 3):
				_put(x, eye_y + 1, front + 1, frame)
				_put(x, eye_y, front + 1, Color("0b0d10") if glasses == "shades" else frame if x in [ex - 1, ex + 2] else Color(0, 0, 0, 0))
		_put(nose_x, eye_y + 1, front + 1, frame)
		if glasses == "shades":
			_put(eye_x[0], eye_y, front + 1, Color("6ee65a"))
	if look.get("scar", false):
		for step: int in range(3):
			_put(right - 2 + step % 2, eye_y + 1 - step, front, Color("b4524a"))
	if look.get("horns", false):
		for step: int in range(4):
			_put(left - step / 2, top + 1 + step, 0, Color("e6dcc0").darkened(step * 0.1))
			_put(right + step / 2, top + 1 + step, 0, Color("e6dcc0").darkened(step * 0.1))

	return _hair(str(look.get("hair", "short")), hair, left, right, back, front, base, top, eye_y)


## Hair shell around the head; returns the y above the hair.
func _hair(style: String, color: Color, left: int, right: int, back: int, front: int, base: int, top: int, eye_y: int) -> int:
	var shade := color.darkened(0.18)
	match style:
		"bald", "none":
			return top + 1
		"tuft":
			_put(-1, top + 1, 0, color)
			_put(0, top + 1, 1, color)
			_put(-1, top + 2, 1, color.lightened(0.1))
			return top + 2
		"mohawk":
			for z: int in range(back + 1, front):
				for y: int in range(top + 1, top + 4 - absi(z) / 2):
					_put(-1, y, z, color)
					_put(0, y, z, shade)
			return top + 4
		"hood":
			for y: int in range(base - 2, top + 2):
				for x: int in range(left - 1, right + 2):
					for z: int in range(back - 1, front + 1):
						var shell := x == left - 1 or x == right + 1 or z == back - 1 or y == top + 1
						if shell and not (z == front and y < top and x > left and x < right):
							_put(x, y, z, color if (x + y) % 3 else shade)
			return top + 2
		_:
			pass
	# Cap over the top and the back of the head.
	var cap_bottom := {"short": eye_y + 2, "buzz": top, "messy": eye_y + 1, "curly": eye_y + 1, "bob": eye_y - 2, "long": eye_y - 1}.get(style, eye_y + 2) as int
	for y: int in range(cap_bottom, top + 2):
		for x: int in range(left - 1, right + 2):
			for z: int in range(back - 1, front + 1):
				var on_shell := x == left - 1 or x == right + 1 or z == back - 1 or y == top + 1
				# Keep the face free below the fringe.
				if z == front and y < top and x > left and x < right:
					continue
				if on_shell:
					_put(x, y, z, color if (x + z + y) % 4 else shade)
	# Back hair falls lower for longer styles.
	var back_bottom := {"long": base - 6, "bob": base, "curly": base + 1}.get(style, eye_y - 1) as int
	for y: int in range(back_bottom, cap_bottom):
		for x: int in range(left - 1, right + 2):
			_put(x, y, back - 1, shade)
			if style == "long" or style == "bob":
				_put(left - 1, y, clampi(x, back, front - 1), color)
				_put(right + 1, y, clampi(x, back, front - 1), color)
	match style:
		"messy", "curly":
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(style) + int(color.r8)
			for _tuft: int in range(16):
				_put(rng.randi_range(left - 1, right + 1), top + 2, rng.randi_range(back - 1, front), color.lightened(0.08))
			return top + 3
	return top + 2


func _crown(y: int) -> void:
	for x: int in range(-3, 3):
		for z: int in range(-3, 3):
			if x in [-3, 2] or z in [-3, 2]:
				_put(x, y, z, GOLD.darkened(0.15))
	for spike: Vector2i in [Vector2i(-3, -3), Vector2i(2, -3), Vector2i(-3, 2), Vector2i(2, 2), Vector2i(-1, 2), Vector2i(-1, -3)]:
		_put(spike.x, y + 1, spike.y, GOLD)
		if spike.x != -1:
			_put(spike.x, y + 2, spike.y, GOLD.lightened(0.2))
	_put(-1, y + 1, 2, Color("ff3a3a"))
	_put(0, y, 2, Color("6ee65a"))


func _hooded(team_color: Color) -> void:
	var cloth := team_color.darkened(0.55)
	# Robe widening towards the floor.
	for y: int in range(0, 19):
		var half := 5 - y / 6
		for x: int in range(-half, half):
			for z: int in range(-half + 1, half - 1):
				_put(x, y, z, cloth if (x + y) % 5 else cloth.darkened(0.2))
	# Hood with an empty, dark face and two glowing eyes.
	for y: int in range(19, 28):
		for x: int in range(-4, 4):
			for z: int in range(-4, 4):
				var shell := x in [-4, 3] or z in [-4, 3] or y == 27
				var opening := z == 3 and x > -3 and x < 2 and y < 26 and y > 19
				if opening:
					_put(x, y, z - 1, Color("050605"))
				elif shell:
					_put(x, y, z, cloth.lightened(0.05))
	_put(-2, 23, 2, team_color.lightened(0.5))
	_put(0, 23, 2, team_color.lightened(0.5))


func _drone(team_color: Color, seed_value: int) -> void:
	var metal := Color("6b7178")
	for side: int in [-1, 1]:
		for y: int in range(0, 8):
			_put(side * 2 - (1 if side < 0 else 0), y, 0, metal.darkened(0.35))
	for y: int in range(8, 17):
		for x: int in range(-4, 4):
			for z: int in range(-2, 2):
				_put(x, y, z, metal.darkened(0.2) if y % 3 == 0 else metal)
	for y: int in range(17, 25):
		for x: int in range(-4, 4):
			for z: int in range(-3, 3):
				_put(x, y, z, metal.lightened(0.1))
	for x: int in range(-4, 4):
		_put(x, 21, 2, Color("060707"))
	var eye := -3 + seed_value % 6
	_put(eye, 21, 2, team_color.lightened(0.4))
	_put(eye + 1, 21, 2, team_color)
	for y: int in range(25, 29):
		_put(2, y, 0, metal.darkened(0.3))
	_put(2, 29, 0, team_color.lightened(0.3))
	_put(-1, 12, 2, team_color)
	_put(0, 12, 2, team_color)


# --- Effects ----------------------------------------------------------------

func _tint_all(tint: Color, strength: float) -> void:
	for key: Vector3i in voxels:
		var color: Color = voxels[key]
		var grey := color.get_luminance()
		voxels[key] = color.lerp(Color(tint.r * grey * 1.5, tint.g * grey * 1.5, tint.b * grey * 1.5), strength)


## A few slices shifted sideways: the copy does not quite hold together.
func _glitch(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 3
	for _slice: int in range(2):
		var y := rng.randi_range(6, 26)
		var shift := 1 if rng.randf() < 0.5 else -1
		var moved: Dictionary = {}
		for key: Vector3i in voxels.keys():
			if key.y == y:
				moved[Vector3i(key.x + shift, key.y, key.z)] = voxels[key]
				voxels.erase(key)
		voxels.merge(moved, true)


# --- Mesh -------------------------------------------------------------------

func _put(x: int, y: int, z: int, color: Color) -> void:
	if color.a <= 0.0:
		return
	voxels[Vector3i(x, y, z)] = color


const FACES := [
	[Vector3i(1, 0, 0), [Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)]],
	[Vector3i(-1, 0, 0), [Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(0, 0, 0)]],
	[Vector3i(0, 1, 0), [Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)]],
	[Vector3i(0, -1, 0), [Vector3(0, 0, 1), Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)]],
	[Vector3i(0, 0, 1), [Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1), Vector3(0, 0, 1)]],
	[Vector3i(0, 0, -1), [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)]],
]


func _to_node(scale_factor: float, material: StandardMaterial3D) -> Node3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for key: Vector3i in voxels:
		var color: Color = voxels[key]
		for face: Array in FACES:
			var direction: Vector3i = face[0]
			if voxels.has(key + direction):
				continue
			var corners: Array = face[1]
			var normal := Vector3(direction)
			var origin := Vector3(key)
			# Godot treats clockwise triangles as front-facing.
			for index: int in [0, 2, 1, 0, 3, 2]:
				tool.set_color(color)
				tool.set_normal(normal)
				tool.add_vertex((origin + corners[index]) * VOXEL)
	var mesh := tool.commit()
	if material == null:
		material = StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.75
	var instance := MeshInstance3D.new()
	instance.name = "Voxels"
	instance.mesh = mesh
	instance.material_override = material
	# Centre the figure on its plinth; voxel x/z run from negative to positive.
	instance.position = Vector3(0.5 * VOXEL, 0.0, 0.5 * VOXEL) * -1.0 * scale_factor
	instance.scale = Vector3.ONE * scale_factor
	var root := Node3D.new()
	root.name = "VoxelFigure"
	root.add_child(instance)
	return root
