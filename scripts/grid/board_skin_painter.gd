class_name BoardSkinPainter
extends RefCounted

## Paints the textures of one board square for a board skin: an albedo image
## and a glow mask (white = lights up in the skin's glow colour). Every skin
## is a real pattern, not just a colour: a blue retro circuit board, falling
## code, lava cracks, a synthwave grid, gold circuitry or a starfield.

const SIZE: int = 128


## Returns [albedo, glow_mask]. variant gives neighbouring squares different
## layouts; ring marks the masters' home squares and the centre.
static func paint(skin_id: String, light: bool, ring: bool, variant: int) -> Array[Image]:
	var albedo := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var mask := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	mask.fill(Color.BLACK)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(skin_id) + variant * 7919 + (1 if light else 0)
	match skin_id:
		"matrix":
			_code(albedo, mask, rng, light)
		"blood":
			_lava(albedo, mask, rng, light)
		"neon":
			_synthwave(albedo, mask, rng, light)
		"gold":
			_circuit(albedo, mask, rng, light, Color("120e08"), Color("1a1409"), Color("d9a640"), Color("ffe08a"))
			_ornament_corners(albedo, mask, Color("ffe08a"))
		"void":
			_starfield(albedo, mask, rng, light)
		_:
			_circuit(albedo, mask, rng, light, Color("1a4a7e"), Color("143d6a"), Color("4f9ae0"), Color("bfe3ff"))
	if ring:
		_ring(albedo, mask, Color(1, 1, 1, 0.9))
	_frame(albedo, mask)
	albedo.generate_mipmaps()
	mask.generate_mipmaps()
	return [albedo, mask]


# --- Retro circuit board ------------------------------------------------------

## Substrate, copper traces with 45° bends ending in vias, solder pads, a chip
## on some squares and white silkscreen marks.
static func _circuit(albedo: Image, mask: Image, rng: RandomNumberGenerator, light: bool, base_light: Color, base_dark: Color, trace: Color, silk: Color) -> void:
	var base := base_light if light else base_dark
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			# Faint weave of the fibreglass.
			var weave := 0.03 * float((x / 4 + y / 4) % 2)
			albedo.set_pixel(x, y, base.lightened(weave))
	for _trace: int in range(rng.randi_range(5, 8)):
		var point := Vector2i(rng.randi_range(14, SIZE - 15), rng.randi_range(14, SIZE - 15))
		var direction := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][rng.randi_range(0, 3)] as Vector2i
		for _segment: int in range(rng.randi_range(2, 4)):
			var length := rng.randi_range(10, 38)
			for _step: int in range(length):
				point += direction
				if point.x < 8 or point.y < 8 or point.x > SIZE - 9 or point.y > SIZE - 9:
					break
				_dot(albedo, mask, point, 1, trace, 0.55)
			# Turn by 45° or 90°.
			var options: Array[Vector2i] = [Vector2i(direction.y, direction.x), Vector2i(-direction.y, -direction.x), Vector2i(clampi(direction.x + direction.y, -1, 1), clampi(direction.y - direction.x, -1, 1))]
			direction = options[rng.randi_range(0, options.size() - 1)]
			if direction == Vector2i.ZERO:
				direction = Vector2i(1, 0)
		_via(albedo, mask, point, trace)
	for _pad: int in range(rng.randi_range(3, 6)):
		var pad := Vector2i(rng.randi_range(12, SIZE - 20), rng.randi_range(12, SIZE - 20))
		_rect(albedo, mask, Rect2i(pad, Vector2i(6, 4)), silk.darkened(0.15), 0.8)
	if rng.randf() < 0.45:
		var chip := Rect2i(rng.randi_range(30, 60), rng.randi_range(30, 60), rng.randi_range(26, 38), rng.randi_range(18, 30))
		for pin: int in range(chip.position.x + 3, chip.end.x - 2, 5):
			_rect(albedo, mask, Rect2i(pin, chip.position.y - 4, 2, 4), silk, 0.7)
			_rect(albedo, mask, Rect2i(pin, chip.end.y, 2, 4), silk, 0.7)
		albedo.fill_rect(chip, Color("0a1220"))
		albedo.fill_rect(Rect2i(chip.position + Vector2i(2, 2), Vector2i(4, 4)), silk.darkened(0.3))
		for line: int in range(2):
			albedo.fill_rect(Rect2i(chip.position.x + 8, chip.position.y + 6 + line * 5, chip.size.x - 14, 1), silk.darkened(0.4))
	# Silkscreen labels: little white dashes like "R12" or "C3".
	for _label: int in range(rng.randi_range(2, 4)):
		var at := Vector2i(rng.randi_range(10, SIZE - 24), rng.randi_range(10, SIZE - 14))
		for character: int in range(3):
			albedo.fill_rect(Rect2i(at + Vector2i(character * 4, 0), Vector2i(3, 1)), silk)
			albedo.fill_rect(Rect2i(at + Vector2i(character * 4, 2), Vector2i(1, 2)), silk)


static func _via(albedo: Image, mask: Image, center: Vector2i, color: Color) -> void:
	for y: int in range(-3, 4):
		for x: int in range(-3, 4):
			var distance := Vector2(x, y).length()
			if distance <= 3.2 and distance >= 1.4:
				_put(albedo, mask, center + Vector2i(x, y), color.lightened(0.25), 0.9)
			elif distance < 1.4:
				_put(albedo, mask, center + Vector2i(x, y), Color("05080e"), 0.0)


static func _ornament_corners(albedo: Image, mask: Image, color: Color) -> void:
	for corner: Vector2i in [Vector2i(10, 10), Vector2i(SIZE - 11, 10), Vector2i(10, SIZE - 11), Vector2i(SIZE - 11, SIZE - 11)]:
		for offset: int in range(-6, 7):
			_put(albedo, mask, corner + Vector2i(offset, 0), color, 1.0)
			_put(albedo, mask, corner + Vector2i(0, offset), color, 1.0)
		for diagonal: int in range(-3, 4):
			_put(albedo, mask, corner + Vector2i(diagonal, diagonal), color, 1.0)
			_put(albedo, mask, corner + Vector2i(diagonal, -diagonal), color, 1.0)


# --- Falling code -------------------------------------------------------------

static func _code(albedo: Image, mask: Image, rng: RandomNumberGenerator, light: bool) -> void:
	albedo.fill(Color("04160b") if light else Color("021008"))
	for column: int in range(2, SIZE - 6, 7):
		var head := rng.randi_range(0, SIZE)
		var length := rng.randi_range(30, 90)
		for row: int in range(4, SIZE - 6, 8):
			var distance := posmod(head - row, SIZE)
			if distance > length:
				continue
			var brightness := 1.0 - float(distance) / float(length)
			var glyph := rng.randi()
			# 3x5 pixel glyph.
			for bit: int in range(15):
				if glyph & (1 << bit):
					var at := Vector2i(column + bit % 3, row + bit / 3)
					var color := Color("b9ffb0") if distance < 6 else Color("2fd23a").darkened(0.6 - brightness * 0.6)
					_put(albedo, mask, at, color, brightness)


# --- Lava -------------------------------------------------------------------------

## Dark rock split by glowing cracks (edges of random cells).
static func _lava(albedo: Image, mask: Image, rng: RandomNumberGenerator, light: bool) -> void:
	var seeds: Array[Vector2] = []
	for _cell: int in range(9):
		seeds.append(Vector2(rng.randf_range(0.0, SIZE), rng.randf_range(0.0, SIZE)))
	var rock := Color("2a1512") if light else Color("1d0e0c")
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			var point := Vector2(x, y)
			var nearest := INF
			var second := INF
			for seed_point: Vector2 in seeds:
				var distance := point.distance_to(seed_point)
				if distance < nearest:
					second = nearest
					nearest = distance
				elif distance < second:
					second = distance
			var edge := second - nearest
			if edge < 2.2:
				var heat := 1.0 - edge / 2.2
				albedo.set_pixel(x, y, Color("ff6a1c").lerp(Color("ffd25a"), heat * 0.6))
				mask.set_pixel(x, y, Color(heat, heat, heat))
			else:
				var shade := 0.08 * sin(nearest * 0.4)
				albedo.set_pixel(x, y, rock.lightened(shade + 0.04 * float((x * 7 + y * 3) % 5 == 0)))


# --- Synthwave --------------------------------------------------------------------

static func _synthwave(albedo: Image, mask: Image, rng: RandomNumberGenerator, light: bool) -> void:
	var top := Color("2b0f4a") if light else Color("1f0a38")
	var bottom := Color("120624")
	for y: int in range(SIZE):
		var row_color := top.lerp(bottom, float(y) / float(SIZE))
		for x: int in range(SIZE):
			albedo.set_pixel(x, y, row_color)
	for line: int in range(0, SIZE, 16):
		for x: int in range(SIZE):
			_put(albedo, mask, Vector2i(x, line), Color("ff2fd0"), 0.7)
		for y: int in range(SIZE):
			_put(albedo, mask, Vector2i(line, y), Color("ff2fd0"), 0.7)
	# A small sunset disc with stripes on some squares.
	if rng.randf() < 0.35:
		var center := Vector2(rng.randf_range(40.0, 88.0), rng.randf_range(40.0, 88.0))
		for y: int in range(-14, 15):
			for x: int in range(-14, 15):
				if Vector2(x, y).length() <= 14.0 and (y + 14) % 5 < 3:
					_put(albedo, mask, Vector2i(center) + Vector2i(x, y), Color("ffc23a").lerp(Color("ff2fd0"), float(y + 14) / 28.0), 0.8)


# --- Starfield ----------------------------------------------------------------------

static func _starfield(albedo: Image, mask: Image, rng: RandomNumberGenerator, light: bool) -> void:
	var base := Color("0d0a1c") if light else Color("07060f")
	var cloud := Vector2(rng.randf_range(0.0, SIZE), rng.randf_range(0.0, SIZE))
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			var nebula := clampf(1.0 - Vector2(x, y).distance_to(cloud) / 70.0, 0.0, 1.0)
			albedo.set_pixel(x, y, base.lerp(Color("3a1f6a"), nebula * 0.55))
	for _star: int in range(40):
		var at := Vector2i(rng.randi_range(4, SIZE - 5), rng.randi_range(4, SIZE - 5))
		var bright := rng.randf_range(0.3, 1.0)
		_put(albedo, mask, at, Color(0.85, 0.8, 1.0).darkened(1.0 - bright), bright)
		if bright > 0.85:
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				_put(albedo, mask, at + offset, Color("b9a0ff"), 0.5)


# --- Shared ---------------------------------------------------------------------------

## Bright edge and corner brackets that always glow.
static func _frame(albedo: Image, mask: Image) -> void:
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			var edge := mini(mini(x, y), mini(SIZE - 1 - x, SIZE - 1 - y))
			var corner := (x < 18 or x > SIZE - 19) and (y < 18 or y > SIZE - 19)
			if edge <= 1 or (corner and edge <= 4):
				mask.set_pixel(x, y, Color.WHITE)
				albedo.set_pixel(x, y, albedo.get_pixel(x, y).lightened(0.45))


static func _ring(albedo: Image, mask: Image, color: Color) -> void:
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			var distance := Vector2(x - SIZE / 2.0, y - SIZE / 2.0).length()
			if absf(distance - 34.0) < 2.0 or absf(distance - 28.0) < 0.8:
				_put(albedo, mask, Vector2i(x, y), color, 0.9)


static func _dot(albedo: Image, mask: Image, center: Vector2i, radius: int, color: Color, glow: float) -> void:
	for y: int in range(-radius, radius + 1):
		for x: int in range(-radius, radius + 1):
			_put(albedo, mask, center + Vector2i(x, y), color, glow)


static func _rect(albedo: Image, mask: Image, rect: Rect2i, color: Color, glow: float) -> void:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			_put(albedo, mask, Vector2i(x, y), color, glow)


static func _put(albedo: Image, mask: Image, at: Vector2i, color: Color, glow: float) -> void:
	if at.x < 0 or at.y < 0 or at.x >= SIZE or at.y >= SIZE:
		return
	albedo.set_pixel(at.x, at.y, color)
	if glow > 0.0:
		var current := mask.get_pixel(at.x, at.y).r
		var value := maxf(current, glow)
		mask.set_pixel(at.x, at.y, Color(value, value, value))
