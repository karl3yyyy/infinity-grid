class_name PixelPortrait
extends RefCounted

## Paints small shaded pixel-art portraits from a character description
## (see CharacterRoster). Light comes from the upper left; every surface is
## quantised to a few tones like hand-placed pixels. A couple of displaced
## scanlines and green code pixels add the "trapped in the grid" glitch.

const WIDTH: int = 32
const HEIGHT: int = 40
## Direction towards the light: upper left, in front of the face.
const LIGHT := Vector3(-0.5, -0.55, 0.68)
const OUTLINE := Color("120d0c")


## Full portrait for a character dictionary.
static func paint(look: Dictionary) -> Image:
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var kind := str(look.get("kind", "human"))
	var skin: Color = look.get("skin", Color("d9a07a"))
	var head := _head_shape(kind)
	_paint_shoulders(image, look.get("clothes", Color("3b4a3a")), kind)
	if kind != "skull":
		_paint_ears(image, head, skin)
	_paint_head(image, head, skin)
	_paint_hair(image, head, str(look.get("hair", "short")), look.get("hair_color", Color("5a3a24")))
	_paint_face(image, head, look, kind)
	if look.get("beard", false):
		_paint_beard(image, head, look.get("hair_color", Color("5a3a24")))
	if look.get("glasses", "") != "":
		_paint_glasses(image, head, str(look["glasses"]))
	if look.get("scar", false):
		_paint_scar(image, head)
	_outline(image)
	_glitch(image, int(look.get("seed", 1)), float(look.get("glitch", 0.25)))
	return image


## A faceless or cloned stand-in for students, tinted in the team colour.
static func paint_echo(style: String, master_look: Dictionary, tint: Color, seed_value: int) -> Image:
	match style:
		"hood":
			return _paint_hood(tint, seed_value)
		"drone":
			return _paint_drone(tint, seed_value)
		_:
			# A washed-out copy of the master without eyes: a program, not a person.
			var clone := master_look.duplicate()
			clone["seed"] = seed_value
			clone["glitch"] = 0.7
			var image := paint(clone)
			_blank_eyes(image, _head_shape(str(master_look.get("kind", "human"))))
			_tint(image, tint, 0.65)
			return image


## Portrait on a dark card with a coloured border. Masters get a thicker gold
## frame and a pixel crown on top so the piece to capture stands out.
static func framed(portrait: Image, border: Color, crowned: bool) -> Image:
	var crown_rows := 9 if crowned else 0
	var thickness := 2 if crowned else 1
	var width := WIDTH + 4
	var height := HEIGHT + 4 + crown_rows
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var card := Rect2i(0, crown_rows, width, HEIGHT + 4)
	image.fill_rect(card, Color("0b0f0b"))
	for offset: int in range(thickness):
		var edge := card.grow(-offset)
		image.fill_rect(Rect2i(edge.position, Vector2i(edge.size.x, 1)), border)
		image.fill_rect(Rect2i(edge.position + Vector2i(0, edge.size.y - 1), Vector2i(edge.size.x, 1)), border.darkened(0.3))
		image.fill_rect(Rect2i(edge.position, Vector2i(1, edge.size.y)), border.lightened(0.1))
		image.fill_rect(Rect2i(edge.position + Vector2i(edge.size.x - 1, 0), Vector2i(1, edge.size.y)), border.darkened(0.3))
	image.blend_rect(portrait, Rect2i(Vector2i.ZERO, portrait.get_size()), Vector2i(2, crown_rows + 2))
	if crowned:
		_paint_crown(image, border, width)
	return image


static func _paint_crown(image: Image, gold: Color, width: int) -> void:
	var left := width / 2 - 8
	# Band.
	for x: int in range(left, left + 16):
		_put_in(image, x, 7, gold.darkened(0.25))
		_put_in(image, x, 6, gold)
	# Three spikes with jewels.
	for spike: int in [0, 7, 14]:
		for step: int in range(5):
			_put_in(image, left + spike, 6 - step, gold.lightened(0.15 if step > 2 else 0.0))
			_put_in(image, left + spike + 1, 6 - step, gold.darkened(0.15))
	_put_in(image, left + 7, 1, Color("ff3a3a"))
	_put_in(image, left + 8, 1, Color("ff3a3a"))
	_put_in(image, left + 3, 5, Color("6ee65a"))
	_put_in(image, left + 11, 5, Color("6ee65a"))


static func _put_in(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
		image.set_pixel(x, y, color)


static func texture(image: Image, scale_factor: int = 1) -> ImageTexture:
	var copy := image.duplicate() as Image
	if scale_factor > 1:
		copy.resize(image.get_width() * scale_factor, image.get_height() * scale_factor, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(copy)


# --- Shapes ---------------------------------------------------------------

## Head ellipse and feature anchors for each body kind.
static func _head_shape(kind: String) -> Dictionary:
	match kind:
		"baby":
			return {"cx": 16.0, "cy": 20.0, "rx": 10.0, "ry": 10.0, "eye_y": 21, "eye_dx": 4, "mouth_y": 26}
		"creature":
			return {"cx": 16.0, "cy": 18.0, "rx": 10.0, "ry": 10.5, "eye_y": 16, "eye_dx": 4, "mouth_y": 24}
		"skull":
			return {"cx": 16.0, "cy": 17.0, "rx": 8.5, "ry": 10.0, "eye_y": 16, "eye_dx": 4, "mouth_y": 24}
		_:
			return {"cx": 16.0, "cy": 17.0, "rx": 8.0, "ry": 10.5, "eye_y": 16, "eye_dx": 3, "mouth_y": 23}


static func _in_ellipse(x: float, y: float, cx: float, cy: float, rx: float, ry: float) -> bool:
	var dx := (x - cx) / rx
	var dy := (y - cy) / ry
	return dx * dx + dy * dy <= 1.0


## Five tones from deep shadow to highlight, picked by a lambert term. Shadows
## drift towards warm purple and highlights towards cream, like painted pixels.
static func _shade(base: Color, normal: Vector3) -> Color:
	var light := clampf(normal.normalized().dot(LIGHT.normalized()), 0.0, 1.0)
	if light > 0.88:
		return base.lightened(0.3).lerp(Color("fff0c8"), 0.18)
	if light > 0.7:
		return base.lightened(0.1)
	if light > 0.48:
		return base
	if light > 0.26:
		return base.darkened(0.24).lerp(Color("5a2a3a"), 0.12)
	return base.darkened(0.48).lerp(Color("2a1428"), 0.2)


static func _sphere_normal(x: float, y: float, cx: float, cy: float, rx: float, ry: float) -> Vector3:
	var nx := (x - cx) / rx
	var ny := (y - cy) / ry
	return Vector3(nx, ny, sqrt(maxf(0.0, 1.0 - nx * nx - ny * ny)))


# --- Body parts -----------------------------------------------------------

static func _paint_shoulders(image: Image, clothes: Color, kind: String) -> void:
	var top := 30 if kind != "baby" else 31
	for y: int in range(top, HEIGHT):
		var half := 6.0 + float(y - top) * 1.6
		for x: int in range(WIDTH):
			var dx := float(x) + 0.5 - 16.0
			if absf(dx) <= half:
				var normal := Vector3(dx / (half + 2.0), -0.4, 0.8)
				image.set_pixel(x, y, _shade(clothes, normal))
	# Neck.
	for y: int in range(top - 4, top + 1):
		for x: int in range(13, 19):
			image.set_pixel(x, y, clothes.darkened(0.55) if y == top else Color("000000", 0.0))


static func _paint_ears(image: Image, head: Dictionary, skin: Color) -> void:
	var y := int(head["eye_y"]) + 1
	for side: float in [-1.0, 1.0]:
		var x := int(head["cx"] + side * (head["rx"] + 0.2))
		for dy: int in range(-2, 2):
			_put(image, x, y + dy, skin.darkened(0.3 if side > 0 else 0.1))


static func _paint_head(image: Image, head: Dictionary, skin: Color) -> void:
	var cx: float = head["cx"]
	var cy: float = head["cy"]
	var rx: float = head["rx"]
	var ry: float = head["ry"]
	for y: int in range(HEIGHT):
		for x: int in range(WIDTH):
			var px := float(x) + 0.5
			var py := float(y) + 0.5
			# Narrow the jaw towards the chin.
			var jaw := 1.0 - clampf((py - cy) / ry, 0.0, 1.0) * 0.28
			if _in_ellipse(px, py, cx, cy, rx * jaw, ry):
				image.set_pixel(x, y, _shade(skin, _sphere_normal(px, py, cx, cy, rx * jaw, ry)))
	# Neck between head and shoulders.
	for y: int in range(int(cy + ry) - 1, 31):
		for x: int in range(13, 19):
			if image.get_pixel(x, y).a == 0.0:
				image.set_pixel(x, y, skin.darkened(0.35 if x > 15 else 0.2))


static func _paint_hair(image: Image, head: Dictionary, style: String, color: Color) -> void:
	var cx: float = head["cx"]
	var cy: float = head["cy"]
	var rx: float = head["rx"]
	var ry: float = head["ry"]
	if style == "bald" or style == "none":
		return
	for y: int in range(HEIGHT):
		for x: int in range(WIDTH):
			var px := float(x) + 0.5
			var py := float(y) + 0.5
			var inside_cap := _in_ellipse(px, py, cx, cy - 1.0, rx + 1.2, ry + 1.0)
			var hair := false
			match style:
				"short":
					hair = inside_cap and py < cy - 4.0 + absf(px - cx) * 0.35
				"buzz":
					hair = inside_cap and py < cy - 5.0
				"long":
					hair = (inside_cap and py < cy - 3.5 + absf(px - cx) * 0.2) \
						or (absf(px - cx) > rx - 1.5 and absf(px - cx) < rx + 2.0 and py > cy - 6.0 and py < cy + ry + 4.0)
				"bob":
					hair = (inside_cap and py < cy - 4.0) \
						or (absf(px - cx) > rx - 1.0 and absf(px - cx) < rx + 2.0 and py > cy - 6.0 and py < cy + 3.0)
				"mohawk":
					hair = absf(px - cx) < 2.2 and py < cy - 3.0 and py > cy - ry - 4.0
				"curly":
					var bump := sin(px * 1.7) * 0.9 + cos(py * 1.9) * 0.6
					hair = _in_ellipse(px, py, cx, cy - 2.0, rx + 2.5 + bump, ry + 1.5 + bump) and py < cy - 2.0 + absf(px - cx) * 0.3
				"messy":
					var spike := absf(sin(px * 2.3)) * 2.0
					hair = _in_ellipse(px, py, cx, cy - 1.0, rx + 2.0, ry + 1.0 + spike) and py < cy - 3.5 + absf(px - cx) * 0.3
				"hood":
					hair = _in_ellipse(px, py, cx, cy, rx + 3.0, ry + 2.5) and not _in_ellipse(px, py, cx, cy + 1.5, rx - 0.5, ry - 1.0)
				"tuft":
					hair = _in_ellipse(px, py, cx - 1.0, cy - ry + 0.5, 2.5, 1.8)
			if hair:
				var normal := _sphere_normal(px, py, cx, cy - 2.0, rx + 3.0, ry + 3.0)
				image.set_pixel(x, y, _shade(color, normal))


static func _paint_face(image: Image, head: Dictionary, look: Dictionary, kind: String) -> void:
	var cx := int(head["cx"])
	var eye_y := int(head["eye_y"])
	var dx := int(head["eye_dx"])
	var skin: Color = look.get("skin", Color("d9a07a"))
	var eye_color: Color = look.get("eye_color", Color("2a3a4a"))
	var brow: Color = Color(look.get("hair_color", Color("5a3a24"))).darkened(0.3)
	if kind == "skull":
		for side: int in [-1, 1]:
			for oy: int in range(-1, 2):
				for ox: int in range(-1, 2):
					_put(image, cx + side * dx + ox - (1 if side > 0 else 0), eye_y + oy, Color("0d0a09"))
			_put(image, cx + side * dx - (1 if side > 0 else 0), eye_y, Color("7dff6a"))
		for x: int in range(cx - 3, cx + 3):
			_put(image, x, int(head["mouth_y"]), Color("0d0a09") if x % 2 == 0 else skin.darkened(0.1))
		_put(image, cx - 1, eye_y + 4, Color("0d0a09"))
		_put(image, cx, eye_y + 4, Color("0d0a09"))
		return
	var big_eyes: bool = look.get("big_eyes", kind == "baby")
	for side: int in [-1, 1]:
		var ex := cx + side * dx - (1 if side > 0 else 0)
		_put(image, ex - 1, eye_y - 2, brow)
		_put(image, ex, eye_y - 2, brow)
		_put(image, ex + 1, eye_y - 2 if kind != "creature" else eye_y - 1, brow)
		if big_eyes:
			for oy: int in range(-1, 1):
				_put(image, ex, eye_y + oy, Color("0f0f14"))
				_put(image, ex + side, eye_y + oy, Color("0f0f14"))
			_put(image, ex, eye_y - 1, Color.WHITE)
		else:
			_put(image, ex - side, eye_y, Color("e8e2d8"))
			_put(image, ex, eye_y, eye_color)
	# Nose: shadow on the far side, highlight on the near side.
	for y: int in range(eye_y + 1, eye_y + 4):
		_put(image, cx + 1, y, skin.darkened(0.3))
	_put(image, cx, eye_y + 3, skin.lightened(0.18))
	_put(image, cx + 1, eye_y + 4, skin.darkened(0.45))
	var mouth_y := int(head["mouth_y"])
	var lip: Color = look.get("lip", skin.darkened(0.5))
	match str(look.get("mouth", "flat")):
		"smile":
			_put(image, cx - 2, mouth_y - 1, lip)
			for x: int in range(cx - 1, cx + 2):
				_put(image, x, mouth_y, lip)
			_put(image, cx + 2, mouth_y - 1, lip)
		"frown":
			_put(image, cx - 2, mouth_y + 1, lip)
			for x: int in range(cx - 1, cx + 2):
				_put(image, x, mouth_y, lip)
			_put(image, cx + 2, mouth_y + 1, lip)
		"pacifier":
			for x: int in range(cx - 2, cx + 2):
				_put(image, x, mouth_y, Color("5fc6e8"))
			_put(image, cx - 1, mouth_y + 1, Color("f1c84b"))
			_put(image, cx, mouth_y + 1, Color("f1c84b"))
		"tusks":
			for x: int in range(cx - 3, cx + 3):
				_put(image, x, mouth_y, lip)
			_put(image, cx - 3, mouth_y - 1, Color("f2ead2"))
			_put(image, cx + 2, mouth_y - 1, Color("f2ead2"))
			_put(image, cx - 3, mouth_y - 2, Color("f2ead2"))
			_put(image, cx + 2, mouth_y - 2, Color("f2ead2"))
		_:
			for x: int in range(cx - 2, cx + 2):
				_put(image, x, mouth_y, lip)
	if look.get("freckles", false):
		for spot: Vector2i in [Vector2i(-4, 2), Vector2i(-3, 3), Vector2i(3, 2), Vector2i(4, 3)]:
			_put(image, cx + spot.x, eye_y + spot.y, skin.darkened(0.28))
	if look.get("horns", false):
		for step: int in range(5):
			_put(image, cx - 8 - step / 2, eye_y - 7 - step, Color("e6dcc0").darkened(step * 0.08))
			_put(image, cx + 7 + step / 2, eye_y - 7 - step, Color("e6dcc0").darkened(0.15 + step * 0.08))


static func _paint_beard(image: Image, head: Dictionary, color: Color) -> void:
	var cx: float = head["cx"]
	var cy: float = head["cy"]
	var mouth_y := int(head["mouth_y"])
	for y: int in range(mouth_y - 2, int(cy + head["ry"]) + 3):
		for x: int in range(WIDTH):
			var px := float(x) + 0.5
			if absf(px - cx) < head["rx"] - 1.0 - maxf(0.0, float(y - mouth_y)) * 0.6 and image.get_pixel(x, y).a > 0.0:
				if y == mouth_y and absf(px - cx) < 2.5:
					continue
				var normal := Vector3((px - cx) / 8.0, 0.3, 0.9)
				image.set_pixel(x, y, _shade(color, normal))


static func _paint_glasses(image: Image, head: Dictionary, kind: String) -> void:
	var cx := int(head["cx"])
	var eye_y := int(head["eye_y"])
	var dx := int(head["eye_dx"])
	var frame := Color("1a1a1a") if kind == "shades" else Color("c9c3b5")
	for side: int in [-1, 1]:
		var ex := cx + side * dx - (1 if side > 0 else 0)
		for ox: int in range(-2, 2):
			_put(image, ex + ox, eye_y - 1, frame)
			if kind == "shades":
				_put(image, ex + ox, eye_y, Color("0b0d10") if ox != -1 else Color("6ee65a"))
			else:
				_put(image, ex + ox, eye_y + 1, frame)
		if kind != "shades":
			_put(image, ex - 2, eye_y, frame)
			_put(image, ex + 1, eye_y, frame)
	_put(image, cx - 1, eye_y - 1, frame)
	_put(image, cx, eye_y - 1, frame)


static func _paint_scar(image: Image, head: Dictionary) -> void:
	var cx := int(head["cx"])
	var eye_y := int(head["eye_y"])
	for step: int in range(6):
		_put(image, cx + 2 + step / 2, eye_y - 3 + step, Color("b4524a"))


static func _paint_hood(tint: Color, seed_value: int) -> Image:
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var cloth := tint.darkened(0.45)
	for y: int in range(HEIGHT):
		for x: int in range(WIDTH):
			var px := float(x) + 0.5
			var py := float(y) + 0.5
			var hood := _in_ellipse(px, py, 16.0, 17.0, 10.0, 12.5) and py < 31.0
			var cape := py >= 26.0 and absf(px - 16.0) < 7.0 + (py - 26.0) * 1.4
			if hood or cape:
				image.set_pixel(x, y, _shade(cloth, _sphere_normal(px, py, 16.0, 22.0, 13.0, 18.0)))
			# Empty face opening with two glowing dots.
			if _in_ellipse(px, py, 16.0, 19.0, 6.0, 7.5):
				image.set_pixel(x, y, Color("050605"))
	_put(image, 13, 19, tint.lightened(0.4))
	_put(image, 18, 19, tint.lightened(0.4))
	_outline(image)
	_glitch(image, seed_value, 0.4)
	return image


static func _paint_drone(tint: Color, seed_value: int) -> Image:
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var metal := Color("6b7178")
	for y: int in range(HEIGHT):
		for x: int in range(WIDTH):
			var px := float(x) + 0.5
			var py := float(y) + 0.5
			if absf(px - 16.0) < 8.0 and py > 8.0 and py < 27.0:
				image.set_pixel(x, y, _shade(metal, Vector3((px - 16.0) / 9.0, (py - 17.0) / 12.0, 0.7)))
			elif py >= 30.0 and absf(px - 16.0) < 6.0 + (py - 30.0) * 1.5:
				image.set_pixel(x, y, _shade(metal.darkened(0.4), Vector3((px - 16.0) / 12.0, -0.3, 0.8)))
	# Visor slit with one roaming eye.
	for x: int in range(10, 22):
		_put(image, x, 16, Color("060707"))
		_put(image, x, 17, Color("060707"))
	var eye := 11 + seed_value % 9
	_put(image, eye, 16, tint.lightened(0.35))
	_put(image, eye + 1, 16, tint.lightened(0.35))
	_put(image, eye, 17, tint)
	_put(image, eye + 1, 17, tint)
	# Antenna.
	for y: int in range(3, 9):
		_put(image, 20, y, metal.darkened(0.3))
	_put(image, 20, 2, tint.lightened(0.3))
	_outline(image)
	_glitch(image, seed_value, 0.3)
	return image


# --- Finishing ------------------------------------------------------------

static func _outline(image: Image) -> void:
	var source := image.duplicate() as Image
	for y: int in range(HEIGHT):
		for x: int in range(WIDTH):
			if source.get_pixel(x, y).a > 0.0:
				continue
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + offset.x
				var ny := y + offset.y
				if nx >= 0 and ny >= 0 and nx < WIDTH and ny < HEIGHT and source.get_pixel(nx, ny).a > 0.0:
					image.set_pixel(x, y, OUTLINE)
					break


## Shifts a few rows sideways and sprinkles green code pixels: the grid shows through.
static func _glitch(image: Image, seed_value: int, amount: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 13
	var rows := int(round(amount * 4.0))
	for _row: int in range(rows):
		var y := rng.randi_range(4, HEIGHT - 6)
		var shift := rng.randi_range(1, 2) * (1 if rng.randf() < 0.5 else -1)
		var line: Array[Color] = []
		for x: int in range(WIDTH):
			line.append(image.get_pixel(x, y))
		for x: int in range(WIDTH):
			var source_x := x - shift
			image.set_pixel(x, y, line[source_x] if source_x >= 0 and source_x < WIDTH else Color(0, 0, 0, 0))
	for _dot: int in range(int(amount * 10.0)):
		var x := rng.randi_range(0, WIDTH - 1)
		var y := rng.randi_range(0, HEIGHT - 1)
		if image.get_pixel(x, y).a > 0.0:
			image.set_pixel(x, y, Color("6ee65a").lerp(image.get_pixel(x, y), 0.35))


static func _blank_eyes(image: Image, head: Dictionary) -> void:
	var cx := int(head["cx"])
	var eye_y := int(head["eye_y"])
	var dx := int(head["eye_dx"])
	for side: int in [-1, 1]:
		var ex := cx + side * dx - (1 if side > 0 else 0)
		for ox: int in range(-1, 2):
			_put(image, ex + ox, eye_y, Color("f4fff0"))


static func _tint(image: Image, tint: Color, strength: float) -> void:
	for y: int in range(HEIGHT):
		for x: int in range(WIDTH):
			var pixel := image.get_pixel(x, y)
			if pixel.a == 0.0 or pixel == OUTLINE:
				continue
			var grey := pixel.get_luminance()
			var toned := Color(tint.r * grey * 1.4, tint.g * grey * 1.4, tint.b * grey * 1.4, pixel.a)
			image.set_pixel(x, y, pixel.lerp(toned, strength))


static func _put(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < WIDTH and y < HEIGHT:
		image.set_pixel(x, y, color)
