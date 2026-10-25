class_name CardSkins
extends RefCounted

## Looks for the 3D cards: colours of the halo and rain plus the pattern on the
## back. `mode` picks the back pattern in card_matrix_shader.gd:
## 0 = falling code, 1 = rising embers, 2 = synthwave grid, 3 = stars.
const SKINS: Array[Dictionary] = [
	{"id": "code", "name": "CODE", "line": "Grüner Code regnet über die Kartenrücken.", "glow": Color("46ff6e"), "rain": Color("1fff60"), "base": Color(0.0, 0.035, 0.02), "mode": 0, "speed": 1.0},
	{"id": "frost", "name": "FROST", "line": "Eisblaue Glitches, schnell und kalt.", "glow": Color("7fe8ff"), "rain": Color("9fe6ff"), "base": Color(0.0, 0.02, 0.04), "mode": 0, "speed": 1.7},
	{"id": "gold", "name": "GOLD", "line": "Goldener Datenregen, gemächlich. Für Angeber.", "glow": Color("ffc23a"), "rain": Color("ffb830"), "base": Color(0.04, 0.03, 0.0), "mode": 0, "speed": 0.65},
	{"id": "lava", "name": "LAVA", "line": "Glut steigt von unten über die Karten auf.", "glow": Color("ff6a1c"), "rain": Color("ff4a10"), "base": Color(0.05, 0.01, 0.0), "mode": 1, "speed": 0.9},
	{"id": "synth", "name": "SYNTHWAVE", "line": "Neon-Raster und Sonnenuntergang wie in den 80ern.", "glow": Color("ff2fd0"), "rain": Color("30e8ff"), "base": Color(0.03, 0.0, 0.05), "mode": 2, "speed": 1.0},
	{"id": "void", "name": "LEERE", "line": "Sterne und Nebel auf der Rückseite.", "glow": Color("8a6aff"), "rain": Color("b8a0ff"), "base": Color(0.01, 0.0, 0.04), "mode": 3, "speed": 1.0},
]


static func skin(id: String) -> Dictionary:
	for entry: Dictionary in SKINS:
		if entry["id"] == id:
			return entry
	return SKINS[0]


## The skin the local player chose in the collection.
static func current() -> Dictionary:
	return skin(str(CharacterRoster.load_look().get("cards", SKINS[0]["id"])))


## Small picture of a card back for the collection menu.
static func preview_image(entry: Dictionary, size: Vector2i = Vector2i(150, 190)) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var base: Color = entry["base"]
	var glow: Color = entry["glow"]
	var rain: Color = entry["rain"]
	var mode: int = entry["mode"]
	image.fill(Color(base.r, base.g, base.b, 1.0).lightened(0.05))
	var random := RandomNumberGenerator.new()
	random.seed = hash(str(entry["id"]))
	match mode:
		0, 1:
			for column: int in range(10):
				var x := 8 + column * 14
				var head := random.randi_range(30, size.y - 20)
				for step: int in range(14):
					var y := head - step * 9 if mode == 0 else size.y - head + step * 9
					if y < 4 or y > size.y - 8:
						continue
					var strength := 1.0 - float(step) / 14.0
					var color := Color(rain.r, rain.g, rain.b, strength).lerp(Color.WHITE, 0.7 if step == 0 else 0.0)
					_fill(image, Rect2i(x, y, 7, 6), color)
		2:
			var horizon := int(size.y * 0.55)
			_fill(image, Rect2i(size.x / 2 - 26, horizon - 52, 52, 52), Color(glow.r, glow.g, glow.b, 0.85))
			for line: int in range(1, 8):
				var y := horizon + int(pow(float(line) / 7.0, 2.0) * float(size.y - horizon - 8))
				_fill(image, Rect2i(4, y, size.x - 8, 2), rain)
			for line: int in range(-6, 7):
				for y: int in range(horizon, size.y - 6, 2):
					var x := int(size.x * 0.5 + float(line) * float(y - horizon) * 0.55)
					if x > 3 and x < size.x - 3:
						image.set_pixel(x, y, Color(rain.r, rain.g, rain.b, 0.8))
		3:
			for star: int in range(70):
				var point := Vector2i(random.randi_range(5, size.x - 6), random.randi_range(5, size.y - 6))
				var bright := random.randf_range(0.3, 1.0)
				_fill(image, Rect2i(point, Vector2i(2, 2) if bright > 0.8 else Vector2i(1, 1)), Color(rain.r, rain.g, rain.b, bright))
	# The infinity sign in the middle, drawn as a lemniscate.
	for step: int in range(360):
		var angle := float(step) / 360.0 * TAU
		var denominator := 1.0 + sin(angle) * sin(angle)
		var point := Vector2(cos(angle), sin(angle) * cos(angle)) / denominator * 52.0 + Vector2(size) * 0.5
		_fill(image, Rect2i(Vector2i(point), Vector2i(3, 3)), glow)
	for x: int in range(size.x):
		for width: int in range(3):
			image.set_pixel(x, width, glow)
			image.set_pixel(x, size.y - 1 - width, glow)
	for y: int in range(size.y):
		for width: int in range(3):
			image.set_pixel(width, y, glow)
			image.set_pixel(size.x - 1 - width, y, glow)
	return image


static func _fill(image: Image, rect: Rect2i, color: Color) -> void:
	for y: int in range(maxi(rect.position.y, 0), mini(rect.end.y, image.get_height())):
		for x: int in range(maxi(rect.position.x, 0), mini(rect.end.x, image.get_width())):
			var existing := image.get_pixel(x, y)
			image.set_pixel(x, y, existing.lerp(Color(color.r, color.g, color.b, 1.0), color.a))
