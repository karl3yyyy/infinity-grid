class_name CharacterShowcase
extends Control

## One page per character in the collection. Each page opens with two slanted
## panels flying in from the bottom left and the top right and crashing
## together in the middle: a close-up render of the character in a halftone,
## RGB-split comic look, and a name plate. Below it the character appears as
## the pixel sprite used on the board. Swipe (or the arrows) for the next one.

signal closed
signal chosen(character_id: String, skin_id: String)
## item is a shop id: the locked character or the locked skin shown.
signal buy_requested(item: String)

const STYLE_COLORS := {
	"mage": Color("2ad4ff"),
	"brawler": Color("ff3b3b"),
	"gunner": Color("ffc23a"),
	"sorcerer": Color("6ee65a"),
}
## Stance shown in the close-up, per fighting style.
const SIGNATURE_ANIMATIONS := {
	"mage": &"Spell_Simple_Idle",
	"brawler": &"Sword_Idle",
	"gunner": &"Pistol_Idle",
	"sorcerer": &"Spell_Simple_Idle",
}
const SWIPE_DISTANCE: float = 80.0
const SPLASH_SIZE := Vector2i(300, 380)

const SPLASH_SHADER := """
shader_type canvas_item;

uniform vec4 accent : source_color = vec4(0.16, 0.83, 1.0, 1.0);
uniform float levels = 5.0;
uniform float split = 2.0;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 base = texture(TEXTURE, UV);
	vec4 right = texture(TEXTURE, UV + vec2(px.x * split, 0.0));
	vec4 left = texture(TEXTURE, UV - vec2(px.x * split, 0.0));
	// RGB split: red and blue drift apart like a broken signal.
	vec3 rgb = vec3(right.r, base.g, left.b);
	rgb = floor(rgb * levels + 0.5) / levels;
	float luma = dot(rgb, vec3(0.3, 0.59, 0.11));
	// Halftone dots in the shadows, tinted with the accent colour.
	vec2 cell = fract(UV / (px * 5.0)) - 0.5;
	float dots = step(length(cell), 0.55 * (1.0 - luma));
	rgb = mix(rgb, accent.rgb * 0.45, dots * (1.0 - luma) * 0.6);
	rgb *= 0.88 + 0.12 * step(0.5, fract(UV.y / px.y * 0.5));
	float alpha = max(base.a, max(right.a, left.a));
	COLOR = vec4(rgb, alpha);
}
"""

var index: int = 0
var _selected_id: String = ""
var _slide: Control
var _busy: bool = false
var _drag_start := Vector2.INF
var _counter: Label
var _select_button: Button
var _flash: ColorRect
var _backdrop: Control
var _fighters: Node3D
## Skin shown on the current page ("" = original) and the row choosing it.
var _skin_id: String = ""
var _skin_row: HBoxContainer


func open(start_index: int, selected_id: String) -> void:
	index = clampi(start_index, 0, CharacterRoster.CHARACTERS.size() - 1)
	_selected_id = selected_id
	_skin_id = CharacterRoster.saved_skin(str(CharacterRoster.CHARACTERS[index]["id"]))
	_build_shell()
	_show_slide(0)


func _build_shell() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = TerminalTheme.theme()
	_fighters = Node3D.new()
	_fighters.name = "Fighters"
	add_child(_fighters)
	var background := ColorRect.new()
	background.color = Color("05070a")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_backdrop = SpeedLines.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24.0
	top.offset_right = -24.0
	top.offset_top = 22.0
	top.offset_bottom = 82.0
	add_child(top)
	var back := Button.new()
	back.text = "< ZURÜCK"
	back.add_theme_font_size_override("font_size", 34)
	back.pressed.connect(func() -> void: closed.emit())
	top.add_child(back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_counter = Label.new()
	_counter.add_theme_font_size_override("font_size", 32)
	_counter.add_theme_color_override("font_color", TerminalTheme.GREEN)
	top.add_child(_counter)

	var bottom := HBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 24.0
	bottom.offset_right = -24.0
	bottom.offset_top = -96.0
	bottom.offset_bottom = -26.0
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 18)
	add_child(bottom)
	var previous := _arrow_button("left")
	previous.pressed.connect(step.bind(-1))
	bottom.add_child(previous)
	_select_button = Button.new()
	_select_button.add_theme_font_size_override("font_size", 38)
	_select_button.custom_minimum_size = Vector2(330.0, 64.0)
	_select_button.pressed.connect(_choose)
	bottom.add_child(_select_button)
	var next := _arrow_button("right")
	next.pressed.connect(step.bind(1))
	bottom.add_child(next)

	_skin_row = HBoxContainer.new()
	_skin_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_skin_row.offset_left = 20.0
	_skin_row.offset_right = -20.0
	_skin_row.offset_top = -168.0
	_skin_row.offset_bottom = -112.0
	_skin_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_skin_row.add_theme_constant_override("separation", 10)
	add_child(_skin_row)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)


func _arrow_button(direction: String) -> Button:
	var button := Button.new()
	button.icon = TerminalTheme.arrow_texture(direction, 34)
	button.custom_minimum_size = Vector2(76.0, 64.0)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return button


## Next (1) or previous (-1) character, wrapping around.
func step(direction: int) -> void:
	if _busy:
		return
	index = posmod(index + direction, CharacterRoster.CHARACTERS.size())
	_skin_id = CharacterRoster.saved_skin(str(CharacterRoster.CHARACTERS[index]["id"]))
	_show_slide(direction)


## Shows the page again in another skin.
func show_skin(skin_id: String) -> void:
	if _busy or skin_id == _skin_id:
		return
	_skin_id = skin_id
	_show_slide(0)


func _fill_skin_row(character: Dictionary, accent: Color) -> void:
	for chip: Node in _skin_row.get_children():
		chip.queue_free()
	var options: Array[Dictionary] = [{"id": "", "name": "ORIGINAL"}]
	options.append_array(CharacterSkins.for_character(str(character["id"])))
	for option: Dictionary in options:
		var chip := Button.new()
		var skin_id := str(option["id"])
		var locked := skin_id != "" and not AccountService.owns(CharacterRoster.item_id("skin", skin_id))
		chip.text = str(option["name"])
		chip.add_theme_font_size_override("font_size", 24)
		chip.focus_mode = Control.FOCUS_NONE
		if skin_id == _skin_id:
			chip.add_theme_stylebox_override("normal", TerminalTheme.bar(accent))
			chip.add_theme_color_override("font_color", Color("05070a"))
		elif locked:
			chip.self_modulate = Color(1.0, 1.0, 1.0, 0.5)
		chip.pressed.connect(show_skin.bind(skin_id))
		_skin_row.add_child(chip)


func _show_slide(direction: int) -> void:
	_busy = true
	var old := _slide
	if old != null:
		# The old panels leave the way the swipe goes.
		var leave := old.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		leave.tween_property(old, "position:x", -size.x * float(direction), 0.22)
		leave.tween_property(old, "modulate:a", 0.0, 0.22)
		await leave.finished
		old.queue_free()
		for fighter: Node in _fighters.get_children():
			fighter.queue_free()
	var character: Dictionary = CharacterRoster.CHARACTERS[index]
	var accent: Color = STYLE_COLORS.get(character.get("style", "brawler"), TerminalTheme.GREEN)
	_counter.text = "%02d / %02d" % [index + 1, CharacterRoster.CHARACTERS.size()]
	_update_select_button(character)
	_fill_skin_row(character, accent)
	(_backdrop as SpeedLines).accent = accent
	_backdrop.queue_redraw()
	_slide = _build_slide(CharacterSkins.dress(character, _skin_id), accent)
	add_child(_slide)
	move_child(_slide, _backdrop.get_index() + 1)
	await _intro(_slide, accent)
	_busy = false


func _build_slide(character: Dictionary, accent: Color) -> Control:
	var slide := Control.new()
	slide.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var width := size.x if size.x > 0.0 else 720.0

	# Huge outlined name behind everything.
	var ghost := Label.new()
	ghost.text = str(character["name"])
	ghost.add_theme_font_size_override("font_size", 150)
	ghost.add_theme_color_override("font_color", Color(accent, 0.08))
	ghost.add_theme_color_override("font_outline_color", Color(accent, 0.3))
	ghost.add_theme_constant_override("outline_size", 3)
	ghost.position = Vector2(-40.0, 150.0)
	ghost.rotation = -0.18
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slide.add_child(ghost)

	# Panel A: the close-up, slanted, flies in from the bottom left.
	var splash_panel := SlantedPanel.new()
	splash_panel.name = "Splash"
	splash_panel.accent = accent
	splash_panel.size = Vector2(width - 90.0, 560.0)
	splash_panel.position = Vector2(30.0, 110.0)
	splash_panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	slide.add_child(splash_panel)
	var splash := TextureRect.new()
	splash.texture = _splash_texture(character, accent)
	splash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	splash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	splash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	splash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SPLASH_SHADER
	material.shader = shader
	material.set_shader_parameter("accent", accent)
	splash.material = material
	splash_panel.add_child(splash)

	# Panel B: the name plate, flies in from the top right.
	var plate := SlantedPanel.new()
	plate.name = "Plate"
	plate.accent = accent
	plate.filled = true
	plate.size = Vector2(width * 0.78, 128.0)
	plate.position = Vector2(width - plate.size.x - 18.0, 610.0)
	slide.add_child(plate)
	var name_label := Label.new()
	name_label.text = str(character["name"])
	name_label.add_theme_font_size_override("font_size", 58)
	name_label.add_theme_color_override("font_color", Color("05070a"))
	name_label.position = Vector2(46.0, 6.0)
	plate.add_child(name_label)
	var style: Dictionary = CharacterRoster.STYLES.get(character.get("style", "brawler"), {})
	var style_label := Label.new()
	style_label.text = "// %s" % str(style.get("name", ""))
	style_label.add_theme_font_size_override("font_size", 30)
	style_label.add_theme_color_override("font_color", Color("05070a", 0.75))
	style_label.position = Vector2(50.0, 70.0)
	plate.add_child(style_label)

	# How the character looks on the board, with its story line.
	var info := HBoxContainer.new()
	info.name = "Info"
	info.position = Vector2(30.0, 760.0)
	info.size = Vector2(width - 60.0, 300.0)
	info.add_theme_constant_override("separation", 18)
	slide.add_child(info)
	var ingame := TextureRect.new()
	ingame.texture = _ingame_texture(character, accent)
	ingame.custom_minimum_size = Vector2(FighterSprite.FRAME_SIZE) * 2.0
	ingame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ingame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	ingame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	info.add_child(ingame)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 8)
	info.add_child(text)
	text.add_child(_text("> SO IM SPIEL", 28, accent))
	var skin := CharacterSkins.skin(_skin_id)
	if skin.is_empty():
		text.add_child(_text(str(character["line"]), 26, TerminalTheme.GREEN_BRIGHT))
	else:
		text.add_child(_text("SKIN: %s" % skin["name"], 26, accent.lightened(0.3)))
		text.add_child(_text(str(skin["line"]), 26, TerminalTheme.GREEN_BRIGHT))
	text.add_child(_text("KAMPFSTIL: %s" % str(style.get("name", "")), 26, TerminalTheme.GREEN))
	text.add_child(_text(str(style.get("line", "")), 24, TerminalTheme.GREEN_DIM))
	return slide


func _text(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## Close-up render: waist up, three-quarter view, in the style's stance.
func _splash_texture(character: Dictionary, accent: Color) -> Texture2D:
	var fighter := FighterSprite.new()
	_fighters.add_child(fighter)
	fighter.build(character, accent, 0.0, false)
	fighter.viewport.size = SPLASH_SIZE
	fighter.frames_per_second = 30.0
	fighter.turn = 0.4
	var scale_factor := float(character.get("scale", 1.0))
	if "pram" in character.get("gear", []):
		fighter.camera.rotation_degrees.x = 0.0
		fighter.camera.size = 1.7
		fighter.camera.position = Vector3(0.0, 0.75, 4.0)
	else:
		# Level camera on the chest and head.
		fighter.camera.rotation_degrees.x = 0.0
		fighter.camera.size = 1.15 * scale_factor
		fighter.camera.position = Vector3(0.0, 1.42 * scale_factor, 4.0)
		fighter.model.play(SIGNATURE_ANIMATIONS.get(character.get("style", ""), &"Idle"))
	return fighter.viewport.get_texture()


func _ingame_texture(character: Dictionary, accent: Color) -> Texture2D:
	var fighter := FighterSprite.new()
	_fighters.add_child(fighter)
	fighter.build(character, accent, 0.0, false)
	return fighter.viewport.get_texture()


## Panels fly in from opposite corners, crash in the middle, flash and shake.
func _intro(slide: Control, accent: Color) -> void:
	var splash := slide.get_node("Splash") as Control
	var plate := slide.get_node("Plate") as Control
	var info := slide.get_node("Info") as Control
	var width := maxf(size.x, 720.0)
	var height := maxf(size.y, 1280.0)
	var splash_home := splash.position
	var plate_home := plate.position
	splash.position = splash_home + Vector2(-width, height * 0.6)
	splash.rotation = -0.25
	plate.position = plate_home + Vector2(width, -height * 0.6)
	plate.rotation = 0.25
	info.modulate.a = 0.0
	var fly := create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	fly.tween_property(splash, "position", splash_home, 0.42)
	fly.tween_property(splash, "rotation", 0.0, 0.42)
	fly.tween_property(plate, "position", plate_home, 0.42).set_delay(0.06)
	fly.tween_property(plate, "rotation", 0.0, 0.42).set_delay(0.06)
	await fly.finished
	# Impact.
	_flash.color = Color(accent.lightened(0.6), 0.85)
	var impact := create_tween().set_parallel(true)
	impact.tween_property(_flash, "color:a", 0.0, 0.3)
	for shake: int in range(6):
		var offset := Vector2(randf_range(-14.0, 14.0), randf_range(-10.0, 10.0)) * (1.0 - shake / 6.0)
		impact.tween_property(slide, "position", offset, 0.04).set_delay(shake * 0.04)
	impact.tween_property(slide, "position", Vector2.ZERO, 0.05).set_delay(0.24)
	await impact.finished
	info.scale = Vector2(0.85, 0.85)
	var reveal := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(info, "modulate:a", 1.0, 0.25)
	reveal.tween_property(info, "scale", Vector2.ONE, 0.3)
	await reveal.finished


func _update_select_button(character: Dictionary) -> void:
	var id := str(character["id"])
	var item := _locked_item(id)
	if item != "":
		_select_button.text = ("SKIN · %d CR" if item.begins_with("skin:") else "KAUFEN · %d CR") % CharacterRoster.PRICES[item]
		_select_button.disabled = false
		return
	var active := id == _selected_id and _skin_id == CharacterRoster.saved_skin(id)
	_select_button.text = "AUSGEWÄHLT" if active else "AUSWÄHLEN"
	_select_button.disabled = active


## The shop item standing between the player and this page's look, or "".
func _locked_item(character_id: String) -> String:
	var character_item := CharacterRoster.item_id("character", character_id)
	if not AccountService.owns(character_item):
		return character_item
	if _skin_id != "" and not AccountService.owns(CharacterRoster.item_id("skin", _skin_id)):
		return CharacterRoster.item_id("skin", _skin_id)
	return ""


## Locked looks are not selected here; the menu offers to buy them.
func _choose() -> void:
	var id := str(CharacterRoster.CHARACTERS[index]["id"])
	var item := _locked_item(id)
	if item != "":
		buy_requested.emit(item)
		return
	_selected_id = id
	CharacterRoster.save_skin(id, _skin_id)
	chosen.emit(_selected_id, _skin_id)
	_update_select_button(CharacterRoster.CHARACTERS[index])


func _gui_input(event: InputEvent) -> void:
	var pressed := false
	var released := false
	var at := Vector2.ZERO
	if event is InputEventScreenTouch:
		pressed = event.pressed
		released = not event.pressed
		at = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
		released = not event.pressed
		at = event.position
	if pressed:
		_drag_start = at
	elif released and _drag_start != Vector2.INF:
		var travel := at - _drag_start
		_drag_start = Vector2.INF
		if absf(travel.x) > SWIPE_DISTANCE and absf(travel.x) > absf(travel.y):
			# Swiping to the left brings the next character in from the right.
			step(1 if travel.x < 0.0 else -1)
			accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_right"):
		step(1)
	elif event.is_action_pressed("ui_left"):
		step(-1)
	elif event.is_action_pressed("ui_cancel"):
		closed.emit()
	elif event.is_action_pressed("ui_accept"):
		_choose()
	else:
		return
	get_viewport().set_input_as_handled()


## Parallelogram with a neon edge; with clip_children it masks its content.
class SlantedPanel:
	extends Control

	var accent := Color.WHITE
	var filled := false
	var slant: float = 46.0

	func _draw() -> void:
		var points := PackedVector2Array([
			Vector2(slant, 0.0), Vector2(size.x, 0.0),
			Vector2(size.x - slant, size.y), Vector2(0.0, size.y),
		])
		if filled:
			draw_colored_polygon(points, accent)
		else:
			# Dark backdrop with a glow from below and diagonal speed lines.
			draw_colored_polygon(points, Color("0b0f16"))
			var glow := PackedColorArray([Color(accent, 0.05), Color(accent, 0.05), Color(accent, 0.45), Color(accent, 0.45)])
			draw_polygon(points, glow)
			for line: int in range(14):
				var x := float(line) * size.x / 10.0 - size.x * 0.2
				draw_line(Vector2(x, size.y), Vector2(x + size.y * 0.5, 0.0), Color(accent, 0.07), 6.0)
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, accent.lightened(0.3), 4.0)


## Diagonal accent stripes across the whole screen behind the panels.
class SpeedLines:
	extends Control

	var accent := Color.WHITE

	func _draw() -> void:
		for line: int in range(10):
			var y := float(line) * size.y / 7.0 - size.y * 0.3
			draw_line(Vector2(0.0, y + size.x * 0.6), Vector2(size.x, y), Color(accent, 0.06 + 0.04 * float(line % 3)), 18.0 + 10.0 * float(line % 2))
