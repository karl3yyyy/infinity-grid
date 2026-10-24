class_name MainMenu
extends Control

## Title screen in a retro terminal style: a list of entries with an inverted
## selection bar, driven by arrow keys, mouse or touch.

signal bot_training_requested
signal local_multiplayer_requested
signal lan_match_requested
signal online_create_requested
signal online_join_requested(code: String)
signal online_quick_requested
signal online_resume_requested(session: Dictionary)
signal quit_requested

const MovementCardScript := preload("res://scripts/battle/movement_card.gd")
const CardViewScript := preload("res://scripts/ui/card_view.gd")
const DIFFICULTY_OPTIONS: Array[Dictionary] = [
	{"title": "LEICHT", "subtitle": "Zum Reinkommen – macht auch mal Fehler"},
	{"title": "MITTEL", "subtitle": "Denkt einen Zug voraus"},
	{"title": "SCHWER", "subtitle": "Rechnet mehrere Züge tief"},
]
const PROFILE_PATH := "user://ring_duel_profile.cfg"
const ENTRY_FONT_SIZE: int = 46
const TEXT_FONT_SIZE: int = 26

var profile_name: String = "Spieler"
## Profile picture, an AvatarGallery id.
var avatar_id: String = AvatarGallery.DEFAULT_ID
## BotAI.Difficulty value chosen for quick play; saved with the profile.
var bot_difficulty: int = 1
## The block holding the current page's entries and texts.
var _panel: PanelContainer
var _content: VBoxContainer
var _page_title: Label
var _description: Label
var _profile_button: Button
var _profile_picture: TextureRect
var _resume_available: bool = false
## What Escape / the back key does on the current page.
var _back_action: Callable
## Fighter previews of the current page; they render their own small worlds.
var _previews: Node3D
## The online account (credits, owned cosmetics) and its menu pages.
var account: AccountService
var _shop: ShopPages
var _login: LoginPages


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_profile()
	account = AccountService.new()
	account.name = "Account"
	add_child(account)
	_shop = ShopPages.new(self, account)
	_login = LoginPages.new(self, account)
	account.changed.connect(_update_profile_button)
	# Headless test runs must not open accounts on the live server.
	var is_test_run := DisplayServer.get_name() == "headless" and OS.get_environment("INFINITY_GRID_ONLINE").is_empty()
	if MatchClient.is_online_available() and not is_test_run:
		_connect_account.call_deferred()
	_build_shell()
	_show_home()


func open_menu(can_resume: bool) -> void:
	_resume_available = can_resume
	visible = true
	_show_home()


func close_menu() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if _back_action.is_valid():
			_back_action.call()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		# "▶ key" starts the highlighted entry, like Enter.
		var focused := get_viewport().gui_get_focus_owner() as Button
		if focused != null and is_ancestor_of(focused):
			focused.pressed.emit()
			get_viewport().set_input_as_handled()


func _build_shell() -> void:
	theme = TerminalTheme.theme()
	var background := ColorRect.new()
	background.color = TerminalTheme.BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)
	add_child(_radial_overlay(Color(TerminalTheme.GREEN, 0.07), Color(0, 0, 0, 0), Vector2(0.5, 0.42)))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 26)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var top_bar := HBoxContainer.new()
	column.add_child(top_bar)
	var corner := _make_text("INFINITY GRID 2026", 26)
	corner.autowrap_mode = TextServer.AUTOWRAP_OFF
	top_bar.add_child(corner)
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(top_spacer)
	_profile_button = Button.new()
	_profile_button.add_theme_font_size_override("font_size", 26)
	_profile_button.focus_mode = Control.FOCUS_NONE
	_profile_button.pressed.connect(_show_profile)
	_profile_picture = TextureRect.new()
	_profile_picture.custom_minimum_size = Vector2(40.0, 40.0)
	_profile_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_profile_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_profile_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	top_bar.add_child(_profile_picture)
	top_bar.add_child(_profile_button)

	var push_center := Control.new()
	push_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	push_center.size_flags_stretch_ratio = 0.7
	column.add_child(push_center)
	_page_title = _make_text("", 52)
	_page_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	column.add_child(_page_title)
	column.add_child(_spacer(26.0))

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	column.add_child(_panel)
	var indent := MarginContainer.new()
	indent.add_theme_constant_override("margin_left", 36)
	indent.add_theme_constant_override("margin_right", 12)
	_panel.add_child(indent)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 6)
	indent.add_child(_content)

	var rule_margin := MarginContainer.new()
	rule_margin.add_theme_constant_override("margin_left", 36)
	rule_margin.add_theme_constant_override("margin_right", 90)
	rule_margin.add_theme_constant_override("margin_top", 16)
	column.add_child(rule_margin)
	var rule := ColorRect.new()
	rule.color = TerminalTheme.GREEN
	rule.custom_minimum_size.y = 3.0
	rule_margin.add_child(rule)

	var info := MarginContainer.new()
	info.add_theme_constant_override("margin_left", 48)
	info.add_theme_constant_override("margin_right", 12)
	info.add_theme_constant_override("margin_top", 6)
	column.add_child(info)
	var info_box := VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 2)
	info.add_child(info_box)
	_description = _make_text("", TEXT_FONT_SIZE, TerminalTheme.GREEN_BRIGHT)
	_description.custom_minimum_size.y = 34.0
	info_box.add_child(_description)
	for help: Array in _help_rows():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		for part: String in help:
			if part.begins_with("@"):
				var arrow := TextureRect.new()
				arrow.texture = TerminalTheme.arrow_texture(part.substr(1))
				arrow.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
				row.add_child(arrow)
			else:
				var text := _make_text(part, 28)
				text.autowrap_mode = TextServer.AUTOWRAP_OFF
				row.add_child(text)
		info_box.add_child(row)

	var push_down := Control.new()
	push_down.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(push_down)
	column.add_child(_build_footer())

	var scanlines := TextureRect.new()
	scanlines.texture = TerminalTheme.scanline_texture()
	scanlines.stretch_mode = TextureRect.STRETCH_TILE
	scanlines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scanlines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scanlines)
	add_child(_radial_overlay(Color(0, 0, 0, 0), Color(0, 0, 0, 0.55), Vector2(0.5, 0.5)))
	add_to_group("interactive_ui")


func _build_footer() -> Control:
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_END
	var globe := TerminalDecor.Globe.new()
	globe.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(globe)
	left.add_child(_make_text("KEIN ENDE IN SICHT.", 18))
	footer.add_child(left)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", -10)
	var logo := _make_text("INFINITY", 58, TerminalTheme.GREEN_BRIGHT)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.autowrap_mode = TextServer.AUTOWRAP_OFF
	# VT323 has no bold cut; an outline in the same colour thickens the logo.
	logo.add_theme_color_override("font_outline_color", TerminalTheme.GREEN_BRIGHT)
	logo.add_theme_constant_override("outline_size", 3)
	center.add_child(logo)
	var sub := _make_text("G R I D", 28)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(sub)
	footer.add_child(center)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_END
	var barcode := TerminalDecor.Barcode.new()
	barcode.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_child(barcode)
	var grid_label := _make_text("5×5 · ∞ · 19 KARTEN", 18)
	grid_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(grid_label)
	footer.add_child(right)
	return footer


func _show_home() -> void:
	_set_page("MENU", Callable())
	_update_profile_button()
	var session := MatchClient.saved_session()
	if not session.is_empty():
		_add_menu_button(_content, "PARTIE FORTSETZEN", "Deine Online-Partie läuft noch", func() -> void:
			close_menu()
			online_resume_requested.emit(session))
	if _resume_available:
		_add_menu_button(_content, "ZUR PARTIE", "Zurück ins laufende Spiel", close_menu)
	if MatchClient.is_online_available():
		_add_menu_button(_content, "SCHNELLES ONLINE-SPIEL", "Zufälliger Gegner, ohne Code", func() -> void:
			close_menu()
			online_quick_requested.emit())
	_add_menu_button(_content, "GEGEN DEN BOT", "Schwierigkeit wählen", _show_difficulty)
	_add_menu_button(_content, "MULTIPLAYER", "Ein Gerät, WLAN oder online mit Code", _show_multiplayer)
	_add_menu_button(_content, "SAMMLUNG", "Alle Bewegungskarten ansehen", _show_collection)
	_add_menu_button(_content, "SHOP", "Charaktere, Echos und Spielfelder für Credits", _shop.show_shop)
	_add_menu_button(_content, "BEENDEN", "Spiel schließen", func() -> void: quit_requested.emit())
	_focus_first_entry()


func _show_difficulty() -> void:
	_set_page("BOT", _show_home)
	for level: int in range(DIFFICULTY_OPTIONS.size()):
		var option: Dictionary = DIFFICULTY_OPTIONS[level]
		var marker := " *" if level == bot_difficulty else ""
		_add_menu_button(_content, str(option["title"]) + marker, str(option["subtitle"]), _choose_difficulty.bind(level))
	_add_menu_button(_content, "< ZURÜCK", "Zum Hauptmenü", _show_home)
	_focus_first_entry(bot_difficulty)


func _choose_difficulty(level: int) -> void:
	bot_difficulty = level
	_save_profile()
	_start_bot_training()


func _show_multiplayer() -> void:
	_set_page("MULTIPLAYER", _show_home)
	_add_menu_button(_content, "AUF DIESEM GERÄT", "Abwechselnd mit einer zweiten Person spielen", _start_local_multiplayer)
	_add_menu_button(_content, "IM WLAN SPIELEN", "Zwei Handys, der PC ist Gastgeber", _start_lan_match)
	if MatchClient.is_online_available():
		_add_menu_button(_content, "ONLINE", "Zufälliger Gegner oder Raum-Code", _show_online_play)
	else:
		_add_menu_button(_content, "ONLINE", "Noch nicht verfügbar: Spielserver fehlt", _show_online_page.bind("ONLINE"))
	_add_menu_button(_content, "< ZURÜCK", "Zum Hauptmenü", _show_home)
	_focus_first_entry()


func _show_online_play() -> void:
	_set_page("ONLINE", _show_multiplayer)
	_add_menu_button(_content, "SCHNELLES SPIEL", "Zufälliger Gegner, sofort los", func() -> void:
		close_menu()
		online_quick_requested.emit())
	_add_menu_button(_content, "SPIEL ERSTELLEN", "Du bekommst einen Raum-Code", func() -> void:
		close_menu()
		online_create_requested.emit())
	var code_input := LineEdit.new()
	code_input.placeholder_text = "RAUM-CODE  ____"
	code_input.max_length = 4
	code_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	code_input.custom_minimum_size = Vector2(300.0, 56.0)
	code_input.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	code_input.add_theme_font_size_override("font_size", 36)
	_content.add_child(code_input)
	var join := func() -> void:
		var code := code_input.text.strip_edges()
		if code.length() != 4 or not code.is_valid_int():
			code_input.placeholder_text = "4 ZIFFERN!"
			code_input.text = ""
			return
		close_menu()
		online_join_requested.emit(code)
	code_input.text_submitted.connect(func(_text: String) -> void: join.call())
	_add_menu_button(_content, "BEITRETEN", "Mit dem Code deines Gegners", join)
	_add_menu_button(_content, "< ZURÜCK", "Zu Multiplayer", _show_multiplayer)
	_focus_first_entry()


func _start_lan_match() -> void:
	if not MatchClient.is_lan_available():
		_show_lan_help()
		return
	close_menu()
	lan_match_requested.emit()


func _show_lan_help() -> void:
	_set_page("WLAN", _show_multiplayer)
	_content.add_child(_make_text(
		"Starte am PC „WLAN-Spiel starten“ und öffne auf beiden Handys die Adresse, die dort angezeigt wird. Diese Version kommt aus dem Internet und kann sich nicht mit deinem PC verbinden.",
		TEXT_FONT_SIZE
	))
	_add_menu_button(_content, "< ZURÜCK", "Zu Multiplayer", _show_multiplayer)
	_focus_first_entry()


func _show_online_page(mode_name: String) -> void:
	_set_page(mode_name, _show_home)
	_update_profile_button()
	_content.add_child(_make_text("Noch nicht verfügbar. Dafür fehlt die Verbindung zum Spielserver.", TEXT_FONT_SIZE))
	_content.add_child(_make_text("Dein Profilname wird nur auf diesem Gerät gespeichert.", TEXT_FONT_SIZE, TerminalTheme.GREEN_DIM))
	_add_menu_button(_content, "< ZURÜCK", "Zum Hauptmenü", _show_home)
	_focus_first_entry()


func _show_profile() -> void:
	_set_page("PROFIL", _show_home)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	_content.add_child(head)
	var picture := TextureRect.new()
	picture.texture = AvatarGallery.picture(avatar_id, _previews_root())
	picture.custom_minimum_size = Vector2(112.0, 112.0)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	head.add_child(picture)
	var naming := VBoxContainer.new()
	naming.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(naming)
	naming.add_child(_make_text("NAME", TEXT_FONT_SIZE, TerminalTheme.GREEN_DIM))
	var name_input := LineEdit.new()
	name_input.text = profile_name
	name_input.max_length = 20
	name_input.placeholder_text = "Dein Anzeigename"
	name_input.custom_minimum_size.y = 52.0
	name_input.add_theme_font_size_override("font_size", 32)
	naming.add_child(name_input)
	_add_menu_button(_content, "SPEICHERN", "Namen übernehmen", func() -> void:
		profile_name = name_input.text.strip_edges()
		if profile_name.is_empty():
			profile_name = "Spieler"
		_save_profile()
		account.save_profile(profile_name, avatar_id)
		_show_home()
	)
	_add_menu_button(_content, "PROFILBILD", "Porträts und Symbole – auch in der Sammlung", _show_avatar_picker.bind(_show_profile))
	_shop.add_account_section(_content)
	_login.add_section(_content)
	_add_menu_button(_content, "< ZURÜCK", "Ohne Speichern zurück", _show_home)
	name_input.grab_focus.call_deferred()


## Opens the account on first start, afterwards refreshes it (daily bonus).
func _connect_account() -> void:
	var is_new := not account.has_account()
	await account.connect_account()
	if is_new and account.has_account():
		# A new account takes over the name chosen on this device.
		account.save_profile(profile_name, avatar_id)


## After signing in or out, use the account's name and picture here.
func adopt_account_profile() -> void:
	profile_name = str(account.account.get("name", profile_name))
	avatar_id = AvatarGallery.valid(str(account.account.get("avatar", avatar_id)))
	_save_profile()
	_update_profile_button()


func _show_collection() -> void:
	_set_page("SAMMLUNG", _show_home)
	var look := CharacterRoster.load_look()
	_add_menu_button(_content, "CHARAKTERE", "Dein KERN: %s" % CharacterRoster.dressed_character(look)["name"], _show_character_picker)
	_add_menu_button(_content, "ECHOS", "Deine Schüler: %s" % CharacterRoster.echo_style(look["echo"])["name"], _show_echo_picker)
	_add_menu_button(_content, "SPIELFELD", "Deine Brett-Seite: %s" % CharacterRoster.board_skin(look["board"])["name"], _show_board_picker)
	_add_menu_button(_content, "PROFILBILD", "Dein Bild: %s" % AvatarGallery.entry(avatar_id)["name"], _show_avatar_picker.bind(_show_collection))
	_add_menu_button(_content, "KARTEN", "Alle Bewegungskarten ansehen", _show_card_collection)
	_add_menu_button(_content, "< ZURÜCK", "Zum Hauptmenü", _show_home)
	_focus_first_entry()


## Full-screen showcase, one swipeable page per character.
func _show_character_picker() -> void:
	var selected := str(CharacterRoster.load_look()["character"])
	var start := 0
	for index: int in range(CharacterRoster.CHARACTERS.size()):
		if CharacterRoster.CHARACTERS[index]["id"] == selected:
			start = index
	var showcase := CharacterShowcase.new()
	showcase.name = "CharacterShowcase"
	add_child(showcase)
	showcase.chosen.connect(func(character_id: String, _skin_id: String) -> void: CharacterRoster.save_look_value("character", character_id))
	showcase.buy_requested.connect(func(item: String) -> void:
		showcase.queue_free()
		_shop.confirm_buy(item, _show_character_picker))
	showcase.closed.connect(func() -> void:
		showcase.queue_free()
		_show_collection())
	showcase.open(start, selected)


func _show_echo_picker() -> void:
	_set_page("ECHOS", _show_collection)
	var look := CharacterRoster.load_look()
	var master := CharacterRoster.character(look["character"])
	_content.add_child(_make_text("Deine vier Schüler sind keine Menschen, sondern Kopien, die das Grid erschaffen hat.", 22, TerminalTheme.GREEN_DIM))
	_add_picker_grid("echo", CharacterRoster.ECHO_STYLES, str(look["echo"]), 3,
		func(entry: Dictionary) -> Texture2D:
			return _fighter_preview(CharacterRoster.echo_look(entry["id"], master, OnitamaUI.TEAM_COLORS[0]), OnitamaUI.TEAM_COLORS[0], 0.75 if entry["id"] == "echo" else 0.0),
		func(entry: Dictionary) -> void:
			CharacterRoster.save_look_value("echo", entry["id"])
			_show_echo_picker(), _show_echo_picker)
	_add_menu_button(_content, "< ZURÜCK", "Zur Sammlung", _show_collection)


func _show_board_picker() -> void:
	_set_page("SPIELFELD", _show_collection)
	_content.add_child(_make_text("So sehen die zwei Reihen auf deiner Seite des Bretts aus.", 22, TerminalTheme.GREEN_DIM))
	_add_picker_grid("board", CharacterRoster.BOARD_SKINS, str(CharacterRoster.load_look()["board"]), 3,
		func(entry: Dictionary) -> Texture2D:
			return ImageTexture.create_from_image(_board_preview(entry)),
		func(entry: Dictionary) -> void:
			CharacterRoster.save_look_value("board", entry["id"])
			_show_board_picker(), _show_board_picker)
	_add_menu_button(_content, "< ZURÜCK", "Zur Sammlung", _show_collection)


## Two rows of three real board squares of the skin, glow added on top.
func _board_preview(entry: Dictionary) -> Image:
	var glow: Color = entry["glow"]
	var square := 60
	var image := Image.create(square * 3 + 8, square * 2 + 6, false, Image.FORMAT_RGBA8)
	image.fill(Color("05070a"))
	for row: int in range(2):
		for column: int in range(3):
			var images := BoardSkinPainter.paint(str(entry["id"]), (row + column) % 2 == 0, false, row * 3 + column)
			var albedo: Image = images[0]
			var mask: Image = images[1]
			albedo.clear_mipmaps()
			mask.clear_mipmaps()
			albedo.resize(square, square, Image.INTERPOLATE_BILINEAR)
			mask.resize(square, square, Image.INTERPOLATE_BILINEAR)
			for y: int in range(square):
				for x: int in range(square):
					var lit := mask.get_pixel(x, y).r
					var color := albedo.get_pixel(x, y) + glow * lit * 0.7
					image.set_pixel(4 + column * (square + 1) + x, 3 + row * (square + 1) + y, Color(minf(color.r, 1.0), minf(color.g, 1.0), minf(color.b, 1.0)))
	return image


## Live, animated preview of a fighter (the same pixel renderer as on the board).
func _fighter_preview(look: Dictionary, tint: Color, hologram: float) -> Texture2D:
	var fighter := FighterSprite.new()
	_previews.add_child(fighter)
	fighter.build(look, tint, hologram, false)
	return fighter.viewport.get_texture()


## Grid of pickable options with a preview each; the current choice is
## framed. Focus shows the option's name and line below the list.
## Locked (not yet bought) options show their price and open the buy dialog.
func _add_picker_grid(kind: String, entries: Array[Dictionary], selected_id: String, columns: int, make_texture: Callable, on_pick: Callable, page: Callable) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 560.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	var cell_width := floorf((get_viewport().get_visible_rect().size.x - 150.0) / float(columns))
	var selected_button: Button
	for entry: Dictionary in entries:
		var button := Button.new()
		button.icon = make_texture.call(entry)
		button.expand_icon = true
		button.text = str(entry["name"])
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		var icon_size: Vector2 = button.icon.get_size()
		button.custom_minimum_size = Vector2(cell_width, (cell_width - 20.0) * icon_size.y / maxf(icon_size.x, 1.0) + 34.0)
		button.add_theme_font_size_override("font_size", 22)
		button.focus_mode = Control.FOCUS_ALL
		var chosen: bool = entry["id"] == selected_id
		if chosen:
			var frame := StyleBoxFlat.new()
			frame.bg_color = Color(TerminalTheme.GREEN, 0.12)
			frame.border_color = TerminalTheme.GREEN_BRIGHT
			frame.set_border_width_all(3)
			frame.set_content_margin_all(6.0)
			button.add_theme_stylebox_override("normal", frame)
			selected_button = button
		var style_note := ""
		if entry.has("style"):
			style_note = "[%s] " % CharacterRoster.STYLES[entry["style"]]["name"]
		var line := "%s%s %s– %s" % ["* " if chosen else "", entry["name"], style_note, entry["line"]]
		var item := CharacterRoster.item_id(kind, str(entry["id"]))
		if not AccountService.owns(item):
			button.text = "%s  %d CR" % [entry["name"], CharacterRoster.PRICES[item]]
			button.self_modulate = Color(1.0, 1.0, 1.0, 0.55)
			line = "GESPERRT – %s – für %d Credits im Shop" % [entry["name"], CharacterRoster.PRICES[item]]
			button.pressed.connect(_shop.confirm_buy.bind(item, page))
		else:
			button.pressed.connect(on_pick.bind(entry))
		button.mouse_entered.connect(button.grab_focus)
		button.focus_entered.connect(func() -> void: _description.text = "> " + line)
		grid.add_child(button)
	if selected_button != null:
		selected_button.grab_focus.call_deferred()


func _show_card_collection() -> void:
	_set_page("KARTEN", _show_collection)
	var deck := MovementCardScript.create_deck()
	_content.add_child(_make_text("%d Bewegungskarten. Pro Partie werden 5 zufällig gezogen." % deck.size(), TEXT_FONT_SIZE))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 470.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	var card_width := floorf((get_viewport().get_visible_rect().size.x - 170.0) / 3.0)
	for card: MovementCard in deck:
		var view: CardView = CardViewScript.new()
		view.custom_minimum_size = Vector2(card_width, card_width * 1.08)
		view.show_card(card, false, UITheme.TEAM_COLORS[0], false)
		grid.add_child(view)
	_add_menu_button(_content, "< ZURÜCK", "Zur Sammlung", _show_collection)
	_focus_first_entry()


func _start_bot_training() -> void:
	close_menu()
	bot_training_requested.emit()


func _start_local_multiplayer() -> void:
	close_menu()
	local_multiplayer_requested.emit()


## Clears the list and shows the page name framed like "-------- MENU --------".
func _set_page(title: String, back_action: Callable) -> void:
	_clear_content()
	if _previews == null:
		_previews = Node3D.new()
		_previews.name = "Previews"
		add_child(_previews)
	for preview: Node in _previews.get_children():
		preview.queue_free()
	_back_action = back_action
	_page_title.text = "-------- %s --------" % title
	_description.text = ""


## One menu entry; the subtitle appears below the list while it is selected.
func _add_menu_button(parent: Control, title: String, subtitle: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_size_override("font_size", ENTRY_FONT_SIZE)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_entered.connect(button.grab_focus)
	button.focus_entered.connect(func() -> void: _description.text = "> " + subtitle if not subtitle.is_empty() else "")
	button.pressed.connect(action)
	parent.add_child(button)


func _focus_first_entry(preferred_index: int = 0) -> void:
	var entries: Array[Button] = []
	for child: Node in _content.get_children():
		if child is Button and not child.is_queued_for_deletion():
			entries.append(child)
	if entries.is_empty():
		return
	entries[clampi(preferred_index, 0, entries.size() - 1)].grab_focus.call_deferred()


func _make_text(text_value: String, font_size: int, color: Color = TerminalTheme.GREEN) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	return spacer


func _radial_overlay(inner: Color, outer: Color, center: Vector2) -> TextureRect:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([inner, outer])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = center
	texture.fill_to = Vector2(1.05, 1.0)
	var overlay := TextureRect.new()
	overlay.texture = texture
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return overlay


## Key hints below the list; "@up", "@down" and "@right" are drawn arrows.
func _help_rows() -> Array[Array]:
	if DisplayServer.is_touchscreen_available():
		return [["AUSWAHL :", "ANTIPPEN"], ["ZURÜCK  :", "< ZURÜCK"]]
	return [["AUSWAHL :", "@up", "@down", "TASTE"], ["START   :", "@right", "TASTE"], ["ZURÜCK  :", "ESC"]]


func _clear_content() -> void:
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


func _load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(PROFILE_PATH) != OK:
		return
	profile_name = str(config.get_value("profile", "name", profile_name))
	avatar_id = AvatarGallery.valid(str(config.get_value("profile", "avatar_id", avatar_id)))
	bot_difficulty = clampi(int(config.get_value("profile", "bot_difficulty", bot_difficulty)), 0, DIFFICULTY_OPTIONS.size() - 1)


func _save_profile() -> void:
	# The same file holds the account and the look; keep them.
	var config := ConfigFile.new()
	config.load(PROFILE_PATH)
	config.set_value("profile", "name", profile_name)
	config.set_value("profile", "avatar_id", avatar_id)
	config.set_value("profile", "bot_difficulty", bot_difficulty)
	config.save(PROFILE_PATH)


## Renders portraits that outlive a page (the top bar picture).
func _previews_root() -> Node:
	var root := get_node_or_null("Portraits")
	if root == null:
		root = Node3D.new()
		root.name = "Portraits"
		add_child(root)
	return root


func _show_avatar_picker(back: Callable) -> void:
	AvatarPicker.new(self, back).show()


## Called by the avatar picker.
func choose_avatar(id: String) -> void:
	avatar_id = AvatarGallery.valid(id)
	_save_profile()
	account.save_profile(profile_name, avatar_id)
	_update_profile_button()


func _update_profile_button() -> void:
	if _profile_button == null:
		return
	_profile_button.text = profile_name.to_upper()
	_profile_picture.texture = AvatarGallery.picture(avatar_id, _previews_root())
	if not account.account.is_empty():
		_profile_button.text += "  %d CR" % account.credits()
