class_name AvatarPicker
extends RefCounted

## Menu page with every profile picture: symbols and character portraits.
## Portraits of characters not owned yet are shown dimmed and point to the shop.

var menu: MainMenu
var back: Callable


func _init(owner_menu: MainMenu, back_action: Callable) -> void:
	menu = owner_menu
	back = back_action


func show() -> void:
	menu._set_page("PROFILBILD", back)
	menu._content.add_child(menu._make_text("Dein Bild neben deinem Namen. Porträts gibt es zu jedem Charakter, den du besitzt.", 22, TerminalTheme.GREEN_DIM))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 560.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu._content.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	var cell := floorf((menu.get_viewport().get_visible_rect().size.x - 170.0) / 4.0)
	var selected: Button
	for entry: Dictionary in AvatarGallery.entries():
		var id := str(entry["id"])
		var owned := AvatarGallery.owns(id)
		var button := Button.new()
		button.icon = _texture(id)
		button.expand_icon = true
		button.text = str(entry["name"]) if owned else "GESPERRT"
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.custom_minimum_size = Vector2(cell, cell + 28.0)
		button.add_theme_font_size_override("font_size", 18)
		button.clip_text = true
		if not owned:
			button.self_modulate = Color(1.0, 1.0, 1.0, 0.4)
		if id == menu.avatar_id:
			var frame := StyleBoxFlat.new()
			frame.bg_color = Color(TerminalTheme.GREEN, 0.12)
			frame.border_color = TerminalTheme.GREEN_BRIGHT
			frame.set_border_width_all(3)
			frame.set_content_margin_all(6.0)
			button.add_theme_stylebox_override("normal", frame)
			selected = button
		var line := "%s – %s" % [entry["name"], entry["line"]] if owned else "%s – kauf den Charakter im Shop, dann gehört dir das Porträt." % entry["name"]
		button.mouse_entered.connect(button.grab_focus)
		button.focus_entered.connect(func() -> void: menu._description.text = "> " + line)
		button.pressed.connect(func() -> void:
			if owned:
				menu.choose_avatar(id)
				show())
		grid.add_child(button)
	menu._add_menu_button(menu._content, "< ZURÜCK", "Zurück", back)
	if selected != null:
		selected.grab_focus.call_deferred()


## Symbols are images; portraits render live (the page frees them on leaving).
func _texture(id: String) -> Texture2D:
	if id.begins_with("character:"):
		return AvatarGallery.portrait(id, menu._previews).viewport.get_texture()
	return AvatarGallery.picture(id, menu._previews)
