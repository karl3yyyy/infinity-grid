class_name ArsenalPage
extends RefCounted

## Main menu > ARSENAL: everything the player owns on one page. The equipped
## KERN stands large on top, below it one card per slot opens that picker.

const SLOT_BADGES: Dictionary = {"kern": "[K]", "echo": "[E]", "board": "[F]", "cards": "[D]", "avatar": "[B]", "emotes": "[:)]"}

var menu: MainMenu


func _init(owner_menu: MainMenu) -> void:
	menu = owner_menu


func show() -> void:
	menu._set_page("ARSENAL", menu._show_home)
	var look := CharacterRoster.load_look()
	var character := CharacterRoster.dressed_character(look)
	var top := MenuCards.chip_row(menu)
	MenuCards.chip(menu, top, "< ZURÜCK", "Zum Hauptmenü", menu._show_home)
	menu._content.add_child(menu._make_text("Hier lagert das Grid, was dir gehört. Leg an, was dich ausmacht.", 22, TerminalTheme.GREEN_DIM))
	menu._content.add_child(_hero(character))
	MenuCards.card(menu, SLOT_BADGES["kern"], "KERN", "%s · Skin, Wechsel, alle deine Kerne" % character["name"], "Charakter und Skin wählen", menu._show_character_picker)
	MenuCards.card(menu, SLOT_BADGES["echo"], "ECHOS", CharacterRoster.echo_style(look["echo"])["name"], "Aussehen deiner vier Echos", menu._show_echo_picker)
	MenuCards.card(menu, SLOT_BADGES["board"], "SPIELFELD", CharacterRoster.board_skin(look["board"])["name"], "Deine Plattform auf dem Brett", menu._show_board_picker)
	MenuCards.card(menu, SLOT_BADGES["cards"], "KARTEN", CardSkins.skin(look["cards"])["name"], "Rückseite und Leuchten deiner Karten", menu._show_card_skin_picker)
	MenuCards.card(menu, SLOT_BADGES["avatar"], "PROFILBILD", AvatarGallery.entry(menu.avatar_id)["name"], "Dein Bild in Profil und Freundesliste", menu._show_avatar_picker.bind(menu._show_collection))
	MenuCards.card(menu, SLOT_BADGES["emotes"], "EMOTE-RAD", menu._emotes.summary(), "Sprüche und Gesten im Match", menu._emotes.show_slots)
	var row := MenuCards.chip_row(menu)
	MenuCards.chip(menu, row, "ZUFALLS-LOOK", "Würfelt einen Look aus allem, was dir gehört", _shuffle)
	MenuCards.chip(menu, row, "ZUM SHOP", "Was das Grid heute im Cache hat", menu._shop.show_shop)
	var more := MenuCards.chip_row(menu)
	MenuCards.chip(menu, more, "ALLE KERNE", "Deine Kerne und das, was gerade im Angebot ist", func() -> void: CharacterOverview.new(menu, menu._show_collection, menu._show_character_picker, menu._known_characters()).show())
	MenuCards.chip(menu, more, "KARTENKATALOG", "Alle Bewegungskarten ansehen", menu._show_card_collection)
	menu._focus_first_entry()


## The equipped KERN, live and animated, in a frame pulsing in its style colour.
func _hero(character: Dictionary) -> Control:
	var accent: Color = CharacterShowcase.STYLE_COLORS.get(character.get("style", "brawler"), TerminalTheme.GREEN)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(accent, 0.08)
	frame.border_color = accent
	frame.set_border_width_all(3)
	frame.set_corner_radius_all(4)
	frame.set_content_margin_all(12.0)
	frame.shadow_color = Color(accent, 0.35)
	frame.shadow_size = 14
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var picture := TextureRect.new()
	picture.texture = menu._fighter_preview(character, accent, 0.0)
	picture.custom_minimum_size = Vector2(240.0, 336.0)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	row.add_child(picture)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(copy)
	copy.add_child(menu._make_text("ANGELEGT", 22, TerminalTheme.GREEN_DIM))
	copy.add_child(menu._make_text(str(character["name"]), 48, accent.lightened(0.3)))
	copy.add_child(menu._make_text(str(character.get("line", "")), 22, TerminalTheme.GREEN))
	var pulse := panel.create_tween().set_loops()
	pulse.tween_method(func(value: float) -> void: frame.shadow_size = int(value), 6.0, 20.0, 1.4).set_trans(Tween.TRANS_SINE)
	pulse.tween_method(func(value: float) -> void: frame.shadow_size = int(value), 20.0, 6.0, 1.4).set_trans(Tween.TRANS_SINE)
	return panel


## Picks a random look from owned items only and shows the page again.
func _shuffle() -> void:
	var owned_characters: Array[Dictionary] = []
	for entry: Dictionary in menu._known_characters():
		if AccountService.owns(CharacterRoster.item_id("character", str(entry["id"]))):
			owned_characters.append(entry)
	if not owned_characters.is_empty():
		var picked := str(owned_characters.pick_random()["id"])
		var skins: Array[String] = [""]
		for skin: Dictionary in CharacterSkins.for_character(picked):
			if AccountService.owns(CharacterRoster.item_id("skin", str(skin["id"]))):
				skins.append(str(skin["id"]))
		CharacterRoster.save_look_value("character", picked)
		CharacterRoster.save_skin(picked, skins.pick_random())
	_shuffle_slot("echo", CharacterRoster.ECHO_STYLES)
	_shuffle_slot("board", CharacterRoster.BOARD_SKINS)
	_shuffle_slot("cards", CardSkins.SKINS)
	SoundBoard.play("select")
	show()


func _shuffle_slot(kind: String, entries: Array[Dictionary]) -> void:
	var owned: Array[Dictionary] = entries.filter(func(entry: Dictionary) -> bool: return AccountService.owns(CharacterRoster.item_id(kind, str(entry["id"]))))
	if not owned.is_empty():
		CharacterRoster.save_look_value(kind, str(owned.pick_random()["id"]))
