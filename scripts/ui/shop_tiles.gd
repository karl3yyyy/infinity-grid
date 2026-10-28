class_name ShopTiles
extends RefCounted

## Shop building blocks: the credit banner, a wide spotlight offer and portrait
## tiles for the grid. Prices come from the caller; nothing is priced here.

const GOLD := Color("ffc23a")


static func _frame(fill: Color, border: Color, border_width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(0.0)
	return style


static func _style(button: Button, fill: Color, border: Color) -> void:
	button.add_theme_stylebox_override("normal", _frame(fill, border))
	button.add_theme_stylebox_override("hover", _frame(fill.lightened(0.1), TerminalTheme.GREEN_BRIGHT, 3))
	button.add_theme_stylebox_override("focus", _frame(fill.lightened(0.1), TerminalTheme.GREEN_BRIGHT, 3))
	button.add_theme_stylebox_override("pressed", _frame(fill.lightened(0.18), TerminalTheme.GREEN_BRIGHT, 3))


static func _label(text_value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", AccessibilitySettings.font_size(size))
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func _preview(menu: MainMenu, item_id: String, size: Vector2) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = _preview_texture(menu, item_id)
	picture.custom_minimum_size = size
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if item_id.begins_with("character:") or item_id.begins_with("skin:") else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture


## Live (animated) where the item is a figure, a still picture for cards and boards.
static func _preview_texture(menu: MainMenu, item_id: String) -> Texture2D:
	var kind := item_id.get_slice(":", 0)
	var id := item_id.get_slice(":", 1)
	match kind:
		"character":
			return _portrait_texture(AvatarGallery.portrait(item_id, menu._previews, true))
		"skin":
			var owner_id := str(CharacterSkins.skin(id)["character"])
			return _portrait_texture(AvatarGallery.portrait("character:" + owner_id, menu._previews, true, id))
		"echo":
			var master := CharacterRoster.character(str(CharacterRoster.load_look()["character"]))
			return menu._fighter_preview(CharacterRoster.echo_look(id, master, GridBattleUI.TEAM_COLORS[0]), GridBattleUI.TEAM_COLORS[0], 0.75 if id == "echo" else 0.0)
		"cards":
			return ImageTexture.create_from_image(CardSkins.preview_image(CardSkins.skin(id)))
		"board":
			return BoardPreview.make(menu._previews, id)
	return null


static func _portrait_texture(sprite: FighterSprite) -> Texture2D:
	sprite.viewport.size = Vector2i(256, 256)
	return sprite.viewport.get_texture()


static func _wire(menu: MainMenu, button: Button, hint: String, action: Callable) -> void:
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_entered.connect(button.grab_focus)
	button.focus_entered.connect(func() -> void:
		menu._description.text = "> " + hint
		SoundBoard.play("click", -10.0))
	button.pressed.connect(func() -> void: SoundBoard.play("select"))
	button.pressed.connect(action)


static func _inset(button: Button, amount: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, amount)
	button.add_child(margin)
	return margin


## Balance strip at the top of the shop.
static func banner(menu: MainMenu, credits_label: Label, subtitle: String) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _frame(Color("1a2a10"), GOLD))
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	credits_label.add_theme_font_size_override("font_size", AccessibilitySettings.font_size(40))
	credits_label.add_theme_color_override("font_color", GOLD)
	column.add_child(credits_label)
	column.add_child(menu._make_text(subtitle, 20, TerminalTheme.GREEN_DIM))
	menu._content.add_child(panel)


## One wide offer: live preview of the item, tag, name and price.
static func spotlight(menu: MainMenu, parent: Control, item_id: String, tag: String, title: String, line: String, price_text: String, hint: String, action: Callable, featured: bool = true) -> Button:
	var button := Button.new()
	var picture_size := 170.0 if featured else 130.0
	button.custom_minimum_size = Vector2(0.0, picture_size + 20.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style(button, Color("241c08") if featured else Color("0e1810"), GOLD if featured else Color("6b5a2a"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inset(button, 10).add_child(row)
	row.add_child(_preview(menu, item_id, Vector2(picture_size, picture_size)))
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(_label("[ %s ]" % tag, 22, GOLD))
	copy.add_child(_label(title, 34 if featured else 28, TerminalTheme.GREEN_BRIGHT))
	copy.add_child(_label(line, 19, TerminalTheme.GREEN_DIM))
	copy.add_child(_label(price_text, 30, GOLD))
	row.add_child(copy)
	_wire(menu, button, hint, action)
	parent.add_child(button)
	return button


## A grid tile with a live portrait, name and price.
static func tile(menu: MainMenu, parent: Control, item_id: String, title: String, price_text: String, hint: String, action: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0.0, 250.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style(button, Color("0e1810"), Color("2f4a34"))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inset(button, 8).add_child(column)
	column.add_child(_preview(menu, item_id, Vector2(0.0, 150.0)))
	var name_label := _label(title, 26, TerminalTheme.GREEN_BRIGHT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	var price := _label(price_text, 24, GOLD)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(price)
	_wire(menu, button, hint, action)
	parent.add_child(button)
	return button
