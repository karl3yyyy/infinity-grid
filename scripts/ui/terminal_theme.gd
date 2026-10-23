class_name TerminalTheme
extends RefCounted

## Retro green-phosphor terminal look for the main menu: VT323 on near-black,
## scanlines and an inverted selection bar.

const FONT_PATH := "res://assets/fonts/VT323-Regular.ttf"

const BACKGROUND := Color("0a0e09")
const GREEN := Color("6ee65a")
const GREEN_BRIGHT := Color("a6ff8f")
const GREEN_DIM := Color("3f8a35")
## Text on the selection bar.
const INK := Color("071006")

static var _font: Font
static var _theme: Theme


static func font() -> Font:
	if _font == null:
		_font = load(FONT_PATH) as Font
		if _font == null:
			_font = ThemeDB.fallback_font
	return _font


static func theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	_theme.default_font = font()
	_theme.default_font_size = 30
	_theme.set_color("font_color", "Label", GREEN)

	# Menu entries: plain green text; hover/focus inverts like a terminal cursor.
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 12.0
	empty.content_margin_right = 12.0
	_theme.set_stylebox("normal", "Button", empty)
	_theme.set_stylebox("disabled", "Button", empty)
	_theme.set_stylebox("hover", "Button", bar(GREEN))
	_theme.set_stylebox("focus", "Button", bar(GREEN))
	_theme.set_stylebox("pressed", "Button", bar(GREEN_BRIGHT))
	_theme.set_stylebox("hover_pressed", "Button", bar(GREEN_BRIGHT))
	_theme.set_color("font_color", "Button", GREEN)
	_theme.set_color("font_hover_color", "Button", INK)
	_theme.set_color("font_focus_color", "Button", INK)
	_theme.set_color("font_pressed_color", "Button", INK)
	_theme.set_color("font_hover_pressed_color", "Button", INK)
	_theme.set_color("font_disabled_color", "Button", GREEN_DIM)

	var field := StyleBoxFlat.new()
	field.bg_color = Color(GREEN, 0.06)
	field.border_color = GREEN
	field.set_border_width_all(2)
	field.set_content_margin_all(10.0)
	_theme.set_stylebox("normal", "LineEdit", field)
	var field_focus := field.duplicate() as StyleBoxFlat
	field_focus.border_color = GREEN_BRIGHT
	field_focus.bg_color = Color(GREEN, 0.12)
	_theme.set_stylebox("focus", "LineEdit", field_focus)
	_theme.set_color("font_color", "LineEdit", GREEN_BRIGHT)
	_theme.set_color("font_placeholder_color", "LineEdit", GREEN_DIM)
	_theme.set_color("caret_color", "LineEdit", GREEN_BRIGHT)
	_theme.set_color("selection_color", "LineEdit", Color(GREEN, 0.35))
	return _theme


## The inverted block behind a selected entry.
static func bar(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	# Slanted right edge, like the highlight in old menu screens.
	box.skew = Vector2(-0.12, 0.0)
	return box


## Filled triangle pointing "up", "down" or "right". VT323 has no arrow glyphs
## and phones have no system font to fall back to, so they are drawn.
static func arrow_texture(direction: String, size: int = 22, color: Color = GREEN) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y: int in range(size):
		for x: int in range(size):
			var u := (float(x) + 0.5) / float(size)
			var v := (float(y) + 0.5) / float(size)
			var inside := false
			match direction:
				"up":
					inside = v >= 0.1 and absf(u - 0.5) <= (v - 0.1) * 0.55
				"down":
					inside = v <= 0.9 and absf(u - 0.5) <= (0.9 - v) * 0.55
				_:
					inside = u <= 0.9 and absf(v - 0.5) <= (0.9 - u) * 0.55
			if inside:
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


## One bright line every few pixels, tiled over the whole screen.
static func scanline_texture() -> ImageTexture:
	var image := Image.create(1, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	image.set_pixel(0, 0, Color(0.6, 1.0, 0.5, 0.035))
	image.set_pixel(0, 2, Color(0, 0, 0, 0.18))
	return ImageTexture.create_from_image(image)
