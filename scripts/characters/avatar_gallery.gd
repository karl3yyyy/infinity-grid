class_name AvatarGallery
extends RefCounted

## Profile pictures: a few free grid symbols, painted pixel by pixel, and a
## portrait of every character, available once the character is owned.
## Ids look like "symbol:code" or "character:nova"; the server stores the id.

const DEFAULT_ID := "symbol:code"
const SIZE := 96
## Frame of a portrait render; small, it is only a head.
const PORTRAIT_FRAME := Vector2i(96, 96)

const SYMBOLS: Array[Dictionary] = [
	{"id": "symbol:code", "name": "CODE", "line": "Grüne Zeichen, die nie aufhören zu fallen."},
	{"id": "symbol:eye", "name": "AUGE", "line": "Das System sieht dich. Du siehst zurück."},
	{"id": "symbol:grid", "name": "GRID", "line": "Das Feld, das kein Ende hat."},
	{"id": "symbol:glitch", "name": "GLITCH", "line": "Ein Fehler, der geblieben ist."},
]

static var _symbol_cache: Dictionary = {}
static var _portrait_cache: Dictionary = {}


## Every picture, symbols first: {id, name, line}.
static func entries() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	list.append_array(SYMBOLS)
	for character: Dictionary in CharacterRoster.CHARACTERS:
		list.append({"id": "character:" + str(character["id"]), "name": str(character["name"]), "line": "Porträt – gehört dir mit dem Charakter."})
	return list


static func entry(id: String) -> Dictionary:
	for candidate: Dictionary in entries():
		if candidate["id"] == id:
			return candidate
	return SYMBOLS[0]


## Symbols are free; a portrait needs its character.
static func owns(id: String) -> bool:
	if id.begins_with("character:"):
		return AccountService.owns(id)
	return id.begins_with("symbol:")


## A usable id: unknown or no longer owned pictures fall back to the default.
static func valid(id: String) -> String:
	return id if owns(id) and entry(id)["id"] == id else DEFAULT_ID


## Still picture for menus. Portraits are rendered once in `host`'s tree and
## then kept as plain images.
static func picture(id: String, host: Node) -> Texture2D:
	if id.begins_with("character:"):
		if _portrait_cache.has(id):
			return _portrait_cache[id]
		var live := portrait(id, host, true)
		_snapshot(id, live)
		return live.viewport.get_texture()
	if not _symbol_cache.has(id):
		_symbol_cache[id] = ImageTexture.create_from_image(_paint_symbol(id))
	return _symbol_cache[id]


## Animated portrait (head and shoulders) of a character, rendered live.
static func portrait(id: String, host: Node, keep_frames_low: bool = false) -> FighterSprite:
	var character := CharacterRoster.character(id.get_slice(":", 1))
	var fighter := FighterSprite.new()
	host.add_child(fighter)
	fighter.build(character, Color("6ee65a"), 0.0, false)
	fighter.viewport.size = PORTRAIT_FRAME
	fighter.viewport.transparent_bg = false
	fighter.turn = 0.35
	if keep_frames_low:
		fighter.frames_per_second = 6.0
	var size := float(character.get("scale", 1.0))
	fighter.camera.rotation_degrees.x = 0.0
	if "pram" in character.get("gear", []):
		fighter.camera.size = 0.75
		fighter.camera.position = Vector3(0.0, 1.0, 4.0)
	else:
		fighter.camera.size = 0.62 * size
		fighter.camera.position = Vector3(0.0, 1.55 * size, 4.0)
	_add_backdrop(fighter.viewport)
	return fighter


static func _add_backdrop(viewport: SubViewport) -> void:
	for child: Node in viewport.get_children():
		if child is WorldEnvironment:
			var environment := (child as WorldEnvironment).environment
			environment.background_mode = Environment.BG_COLOR
			environment.background_color = Color("0b1a10")


## Keeps a frame of the live portrait as an image and frees the renderer.
static func _snapshot(id: String, live: FighterSprite) -> void:
	for frame: int in range(4):
		await live.get_tree().process_frame
	if not is_instance_valid(live):
		return
	_portrait_cache[id] = ImageTexture.create_from_image(live.viewport.get_texture().get_image())
	live.queue_free()


static func _paint_symbol(id: String) -> Image:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var random := RandomNumberGenerator.new()
	random.seed = hash(id)
	match id:
		"symbol:eye":
			image.fill(Color("07090f"))
			for y: int in range(SIZE):
				for x: int in range(SIZE):
					var u := (float(x) - SIZE * 0.5) / (SIZE * 0.42)
					var v := (float(y) - SIZE * 0.5) / (SIZE * 0.24)
					# Almond outline, iris and pupil.
					var lid := absf(u * u + v * v * (1.0 + u * u) - 1.0)
					var radius := Vector2(x - SIZE * 0.5, y - SIZE * 0.5).length()
					if lid < 0.12:
						image.set_pixel(x, y, Color("2ad4ff"))
					elif radius < 6.0:
						image.set_pixel(x, y, Color("02040a"))
					elif radius < 15.0:
						image.set_pixel(x, y, Color("2ad4ff").lerp(Color("0a4a6a"), radius / 15.0))
			for ray: int in range(12):
				var angle := TAU * float(ray) / 12.0
				for step: int in range(3):
					var at := Vector2(SIZE * 0.5, SIZE * 0.5) + Vector2.from_angle(angle) * (40.0 + step * 2.0)
					_put(image, at, Color("2ad4ff", 0.6))
		"symbol:grid":
			image.fill(Color("0a0614"))
			var horizon := SIZE * 0.42
			for y: int in range(SIZE):
				for x: int in range(SIZE):
					if y < horizon:
						# Sun with stripes above the horizon.
						var sun := Vector2(x - SIZE * 0.5, y - horizon).length()
						if sun < 26.0 and int(y) % 6 < 4:
							image.set_pixel(x, y, Color("ffb21c").lerp(Color("ff2fd0"), float(y) / horizon))
						continue
					var depth := (float(y) - horizon) / (SIZE - horizon)
					var row := fmod(1.0 / maxf(depth, 0.02), 0.35) < 0.06
					var column := fmod((float(x) - SIZE * 0.5) / maxf(depth, 0.05) + 400.0, 22.0) < 1.6
					if row or column:
						image.set_pixel(x, y, Color("ff2fd0").lerp(Color("2ad4ff"), depth))
		"symbol:glitch":
			image.fill(Color("08080a"))
			for band: int in range(18):
				var y0 := random.randi_range(0, SIZE - 6)
				var height := random.randi_range(2, 7)
				var shift := random.randi_range(-14, 14)
				var color: Color = [Color("ff3b3b"), Color("2ad4ff"), Color("e8e8e8"), Color("6ee65a")][band % 4]
				for y: int in range(y0, mini(y0 + height, SIZE)):
					for x: int in range(maxi(0, 18 + shift), mini(SIZE, 78 + shift)):
						if random.randf() < 0.85:
							image.set_pixel(x, y, Color(color, 0.85))
		_:
			image.fill(Color("030a04"))
			for column: int in range(12):
				var x := column * 8 + 2
				var head := random.randi_range(10, SIZE - 4)
				for y: int in range(0, head, 8):
					var glow := float(y) / float(head)
					for dy: int in range(6):
						for dx: int in range(5):
							if random.randf() < 0.55:
								image.set_pixel(x + dx, y + dy, Color("6ee65a").lerp(Color("103a10"), 1.0 - glow))
				for dy: int in range(6):
					for dx: int in range(5):
						_put(image, Vector2(x + dx, mini(head, SIZE - 6) + dy), Color("d8ffd0"))
	return image


static func _put(image: Image, at: Vector2, color: Color) -> void:
	var x := int(at.x)
	var y := int(at.y)
	if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
		image.set_pixel(x, y, color)
