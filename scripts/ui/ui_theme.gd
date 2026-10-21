class_name UITheme
extends RefCounted

## Shared fantasy look for HUD, cards and menus: dark stone, gold trim, Cinzel.

const TITLE_FONT_PATH := "res://assets/fonts/Cinzel.ttf"
const DECORATIVE_FONT_PATH := "res://assets/fonts/CinzelDecorative-Bold.ttf"

const GOLD := Color("e2b75a")
const GOLD_DARK := Color("8a6224")
const GOLD_LIGHT := Color("ffe3a0")
const STONE := Color("1b1a28")
const STONE_LIGHT := Color("2c2a3e")
const INK := Color("f4ead2")
const TEAM_COLORS: Array[Color] = [Color("3fa9ff"), Color("ff5a3c")]

static var _title_font: Font
static var _decorative_font: Font
static var _theme: Theme


static func title_font(weight: int = 700) -> Font:
	if _title_font == null:
		var base := load(TITLE_FONT_PATH) as FontFile
		if base == null:
			return ThemeDB.fallback_font
		var variation := FontVariation.new()
		variation.base_font = base
		var tag := TextServerManager.get_primary_interface().name_to_tag("wght")
		variation.variation_opentype = {tag: weight}
		_title_font = variation
	return _title_font


static func decorative_font() -> Font:
	if _decorative_font == null:
		_decorative_font = load(DECORATIVE_FONT_PATH) as Font
		if _decorative_font == null:
			_decorative_font = title_font()
	return _decorative_font


## Theme for buttons, panels and labels; body text keeps the readable default font.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	var font := title_font()
	_theme.set_font("font", "Button", font)
	_theme.set_font("font", "Label", font)
	_theme.set_font("font", "LineEdit", ThemeDB.fallback_font)
	_theme.set_color("font_color", "Button", INK)
	_theme.set_color("font_hover_color", "Button", GOLD_LIGHT)
	_theme.set_color("font_pressed_color", "Button", GOLD)
	_theme.set_color("font_disabled_color", "Button", Color(INK, 0.4))
	_theme.set_color("font_color", "Label", INK)
	_theme.set_stylebox("normal", "Button", button_style(STONE_LIGHT, GOLD_DARK))
	_theme.set_stylebox("hover", "Button", button_style(Color("3a3652"), GOLD))
	_theme.set_stylebox("pressed", "Button", button_style(Color("15141f"), GOLD_LIGHT))
	_theme.set_stylebox("disabled", "Button", button_style(Color(STONE, 0.7), Color(GOLD_DARK, 0.4)))
	_theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	_theme.set_stylebox("panel", "PanelContainer", panel_style())
	return _theme


static func button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10.0)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style


static func panel_style(fill: Color = Color(0.07, 0.065, 0.11, 0.94)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = GOLD_DARK
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14.0)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 12
	return style


static func outline_label(label: Label, outline_size: int = 6) -> void:
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05, 0.92))
	label.add_theme_constant_override("outline_size", outline_size)
