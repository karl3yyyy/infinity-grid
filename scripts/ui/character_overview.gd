class_name CharacterOverview
extends RefCounted

## Sammlung > CHARAKTERE > ALLE: every character on one page as a grid of portraits.
## Characters not owned yet are dimmed; a tap opens that character's big page.

const COLUMNS: int = 3

var menu: MainMenu
var back: Callable
var open_character: Callable


func _init(owner_menu: MainMenu, back_action: Callable, open_action: Callable) -> void:
	menu = owner_menu
	back = back_action
	open_character = open_action


func show() -> void:
	menu._set_page("ALLE CHARAKTERE", back)
	var selected_id := str(CharacterRoster.load_look()["character"])
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 640.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu._content.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	var cell := floorf((menu.get_viewport().get_visible_rect().size.x - 170.0) / float(COLUMNS))
	var current: Button
	for character: Dictionary in CharacterRoster.CHARACTERS:
		var id := str(character["id"])
		var owned := AvatarGallery.owns("character:" + id)
		var button := Button.new()
		button.icon = AvatarGallery.portrait("character:" + id, menu._previews, true).viewport.get_texture()
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.text = str(character["name"]) if owned else "%s  (GESPERRT)" % character["name"]
		button.custom_minimum_size = Vector2(cell, cell + 34.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 18)
		button.clip_text = true
		if not owned:
			button.self_modulate = Color(1.0, 1.0, 1.0, 0.45)
		if id == selected_id:
			var frame := StyleBoxFlat.new()
			frame.bg_color = Color(TerminalTheme.GREEN, 0.12)
			frame.border_color = TerminalTheme.GREEN_BRIGHT
			frame.set_border_width_all(3)
			frame.set_content_margin_all(6.0)
			button.add_theme_stylebox_override("normal", frame)
			current = button
		button.mouse_entered.connect(button.grab_focus)
		button.focus_entered.connect(func() -> void: menu._description.text = "> %s – %s" % [character["name"], character["line"]])
		button.pressed.connect(func() -> void:
			SoundBoard.play("select")
			open_character.call(id))
		grid.add_child(button)
	menu._add_menu_button(menu._content, "< ZURÜCK", "Zur Sammlung", back)
	if current != null:
		current.grab_focus.call_deferred()
