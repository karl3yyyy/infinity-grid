class_name MenuCards
extends RefCounted

## Tappable cards and chips for menu pages that offer several choices at once
## (Finite Grid, Chaos lab). Plain list entries stay in MainMenu._add_menu_button.

const WARNING := Color("ffc23a")


static func _frame(fill: Color, border: Color, border_width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(0.0)
	return style


static func _apply_frames(button: Button, active: bool, accent: Color) -> void:
	var fill := Color("143018") if active else Color("0e1810")
	var border := accent if active else Color("2f4a34")
	button.add_theme_stylebox_override("normal", _frame(fill, border))
	button.add_theme_stylebox_override("hover", _frame(fill.lightened(0.08), TerminalTheme.GREEN_BRIGHT, 3))
	button.add_theme_stylebox_override("focus", _frame(fill.lightened(0.08), TerminalTheme.GREEN_BRIGHT, 3))
	button.add_theme_stylebox_override("pressed", _frame(fill.lightened(0.16), TerminalTheme.GREEN_BRIGHT, 3))


## A full-width card: a badge on the left, title and text in the middle and an
## optional status on the right. The whole card is the button.
static func card(menu: MainMenu, badge: String, title: String, text: String, hint: String, action: Callable, status: String = "", active: bool = false, accent: Color = TerminalTheme.GREEN) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0.0, 104.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	_apply_frames(button, active, accent)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var badge_label := _label(badge, 44, accent if active or accent != TerminalTheme.GREEN else TerminalTheme.GREEN_BRIGHT)
	badge_label.custom_minimum_size.x = 92.0
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(badge_label)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(_label(title, 30, TerminalTheme.GREEN_BRIGHT if active else TerminalTheme.GREEN))
	copy.add_child(_label(text, 20, TerminalTheme.GREEN_DIM))
	row.add_child(copy)
	if status != "":
		var status_label := _label(status, 26, accent if active else TerminalTheme.GREEN_DIM)
		status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(status_label)
	_connect(menu, button, hint, action)
	menu._content.add_child(button)
	MenuMotion.enter(button, menu._entry_count)
	menu._entry_count += 1
	return button


## A compact toggle or action, placed in a row next to others.
static func chip(menu: MainMenu, row: Container, text: String, hint: String, action: Callable, active: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 60.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", AccessibilitySettings.font_size(24))
	button.add_theme_color_override("font_color", TerminalTheme.GREEN_BRIGHT if active else TerminalTheme.GREEN)
	button.add_theme_color_override("font_hover_color", TerminalTheme.GREEN_BRIGHT)
	button.add_theme_color_override("font_focus_color", TerminalTheme.GREEN_BRIGHT)
	_apply_frames(button, active, TerminalTheme.GREEN_BRIGHT)
	_connect(menu, button, hint, action)
	row.add_child(button)
	return button


static func chip_row(menu: MainMenu) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	menu._content.add_child(row)
	return row


static func section_title(menu: MainMenu, text: String) -> void:
	menu._content.add_child(menu._make_text("// " + text, 22, TerminalTheme.GREEN_DIM))


static func _connect(menu: MainMenu, button: Button, hint: String, action: Callable) -> void:
	button.mouse_entered.connect(button.grab_focus)
	button.focus_entered.connect(func() -> void:
		menu._description.text = "> " + hint if hint != "" else ""
		SoundBoard.play("click", -10.0))
	button.pressed.connect(func() -> void: SoundBoard.play("select"))
	button.pressed.connect(action)


static func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", AccessibilitySettings.font_size(font_size))
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
