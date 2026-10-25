class_name MainMenu
extends Control

## Title screen in a retro terminal style: a list of entries with an inverted
## selection bar, driven by arrow keys, mouse or touch.

signal bot_training_requested
signal local_multiplayer_requested
signal lan_match_requested
## invite_username: "" for a plain room code, else a friend to invite.
signal online_create_requested(invite_username: String)
signal online_ranked_requested(ticket: String)
signal online_join_requested(code: String)
signal online_quick_requested
signal online_resume_requested(session: Dictionary)
signal quit_requested
## A short message for the player, shown over whatever is on screen.
signal toast_requested(text: String)

const MovementCardScript := preload("res://scripts/battle/movement_card.gd")
const CardViewScript := preload("res://scripts/ui/card_view.gd")
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
var _play: PlayPages
var _friends: FriendsPages
var _emotes: EmoteLoadoutPages
## Entries added to the current page, for the staggered entrance.
var _entry_count: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_profile()
	account = AccountService.new()
	account.name = "Account"
	add_child(account)
	_shop = ShopPages.new(self, account)
	_login = LoginPages.new(self, account)
	_play = PlayPages.new(self, account)
	_friends = FriendsPages.new(self, account)
	_emotes = EmoteLoadoutPages.new(self)
	account.changed.connect(_update_profile_button)
	# Headless test runs must not open accounts on the live server.
	var is_test_run := DisplayServer.get_name() == "headless" and OS.get_environment("INFINITY_GRID_ONLINE").is_empty()
	if MatchClient.is_online_available() and not is_test_run:
		_connect_account.call_deferred()
		_capture_invite()
		_friends.start_watch.call_deferred()
		# Friends see us as online while the game keeps checking in.
		var heartbeat := Timer.new()
		heartbeat.wait_time = 90.0
		heartbeat.autostart = true
		heartbeat.timeout.connect(func() -> void: account.refresh_if_stale())
		add_child(heartbeat)
	_build_shell()
	_show_home()


## A friend's invite link (?invite=NAME) is remembered until this player has an
## account with a username; FriendsPages then applies it.
func _capture_invite() -> void:
	if not OS.has_feature("web"):
		return
	var inviter := str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('invite') || ''"))
	if not RegEx.create_from_string("^[A-Za-z0-9_]{3,16}$").search(inviter):
		return
	var config := ConfigFile.new()
	config.load(PROFILE_PATH)
	config.set_value("profile", "pending_invite", inviter)
	config.save(PROFILE_PATH)


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
	var rain := MenuMotion.CodeRain.new()
	rain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(rain)
	add_child(_radial_overlay(Color(TerminalTheme.GREEN, 0.07), Color(0, 0, 0, 0), Vector2(0.5, 0.42)))
	var scan := MenuMotion.ScanBar.new()
	add_child(scan)

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
	left.add_child(_make_text(GridLore.menu_tagline(), 18))
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
	_content.add_child(_make_text(PurgeCycle.banner(), 22, TerminalTheme.GREEN_DIM))
	if _friends.online_count > 0:
		_content.add_child(_make_text("%d IM GRID" % _friends.online_count, 22, TerminalTheme.GREEN_BRIGHT))
	var session := MatchClient.saved_session()
	if not session.is_empty():
		_add_menu_button(_content, "PARTIE FORTSETZEN", "Deine Online-Partie läuft noch", func() -> void:
			close_menu()
			online_resume_requested.emit(session))
	if _resume_available:
		_add_menu_button(_content, "ZUR PARTIE", "Zurück ins laufende Spiel", close_menu)
	_add_menu_button(_content, "SPIELEN", "Ranked, schnelles Spiel, Bot, zu zweit", _play.show_play)
	if MatchClient.is_online_available():
		_add_menu_button(_content, "FREUNDE", _friends.summary(), _friends.show_friends)
	_add_menu_button(_content, "SAMMLUNG", "Charaktere, Skins, Spielfeld, Profilbild, Emotes, Karten", _show_collection)
	_add_menu_button(_content, "SHOP", "Credits gegen Style tauschen. Das Grid nimmt jede Währung.", _shop.show_shop)
	_add_menu_button(_content, "EINSTELLUNGEN", "Lautstärke des Grids. Es flüstert nicht.", _show_settings)
	if not OS.has_feature("web"):
		_add_menu_button(_content, "BEENDEN", "Spiel schließen", func() -> void: quit_requested.emit())
	_focus_first_entry()


func _show_settings() -> void:
	_set_page("EINSTELLUNGEN", _show_home)
	_add_menu_button(_content, "TON: %s" % ("AN" if SoundBoard.is_enabled() else "AUS"), "Musik, Effekte und Sprachansagen", func() -> void:
		SoundBoard.set_enabled(not SoundBoard.is_enabled())
		_show_settings())
	var facing := FigureFacing.mode()
	_add_menu_button(_content, "FIGUREN: %s" % str(FigureFacing.NAMES[facing]), "%s Wirkt ab dem nächsten Spiel." % str(FigureFacing.HINTS[facing]), func() -> void:
		FigureFacing.next_mode()
		_show_settings())
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
	# The name is the account's username and cannot be edited.
	var shown := account.username() if not account.username().is_empty() else "GAST"
	naming.add_child(_make_text(shown, 40, TerminalTheme.GREEN_BRIGHT))
	if not account.account.is_empty():
		naming.add_child(_make_text("%s  ·  %d PUNKTE" % [str(account.account.get("rank", "")), int(account.account.get("rating", 1000))], 22, TerminalTheme.GREEN_DIM))
	ProfileStatsView.build(_content)
	_login.add_account_panel(_content, _show_avatar_picker.bind(_show_profile))
	_add_menu_button(_content, "< ZURÜCK", "Zum Hauptmenü", _show_home)
	_focus_first_entry()


## Opens the account on first start, afterwards refreshes it (daily bonus).
func _connect_account() -> void:
	var is_new := not account.has_account()
	await account.connect_account()
	if not account.account.is_empty():
		adopt_account_profile()
	if is_new and account.has_account():
		# A new account takes over the name chosen on this device.
		account.save_profile(profile_name, avatar_id)


## After signing in or out, use the account's name and picture here.
func adopt_account_profile() -> void:
	profile_name = account.username() if not account.username().is_empty() else "Gast"
	avatar_id = AvatarGallery.valid(str(account.account.get("avatar", avatar_id)))
	_save_profile()
	_update_profile_button()


func _show_collection() -> void:
	_set_page("SAMMLUNG", _show_home)
	var look := CharacterRoster.load_look()
	_add_menu_button(_content, "CHARAKTERE", "Dein KERN: %s" % CharacterRoster.dressed_character(look)["name"], _show_character_picker)
	_add_menu_button(_content, "ECHOS", "Deine Schüler: %s" % CharacterRoster.echo_style(look["echo"])["name"], _show_echo_picker)
	_add_menu_button(_content, "SPIELFELD", "Deine Brett-Seite: %s" % CharacterRoster.board_skin(look["board"])["name"], _show_board_picker)
	_add_menu_button(_content, "KARTENSKINS", "Deine Karten: %s" % CardSkins.skin(look["cards"])["name"], _show_card_skin_picker)
	_add_menu_button(_content, "PROFILBILD", "Dein Bild: %s" % AvatarGallery.entry(avatar_id)["name"], _show_avatar_picker.bind(_show_collection))
	_add_menu_button(_content, "EMOTE-RAD", _emotes.summary(), _emotes.show_slots)
	_add_menu_button(_content, "KARTEN", "Alle Bewegungskarten ansehen", _show_card_collection)
	_add_menu_button(_content, "< ZURÜCK", "Zum Hauptmenü", _show_home)
	_focus_first_entry()


## Full-screen showcase, one swipeable page per character.
func _show_character_picker(start_id: String = "") -> void:
	var selected := str(CharacterRoster.load_look()["character"])
	var opened := start_id if not start_id.is_empty() else selected
	var start := 0
	for index: int in range(CharacterRoster.CHARACTERS.size()):
		if CharacterRoster.CHARACTERS[index]["id"] == opened:
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
	showcase.overview_requested.connect(func() -> void:
		showcase.queue_free()
		CharacterOverview.new(self, _show_collection, _show_character_picker).show())
	showcase.open(start, selected)


func _show_echo_picker() -> void:
	_set_page("ECHOS", _show_collection)
	var look := CharacterRoster.load_look()
	var master := CharacterRoster.character(look["character"])
	_content.add_child(_make_text("Deine vier Schüler sind keine Menschen, sondern Kopien, die das Grid erschaffen hat.", 22, TerminalTheme.GREEN_DIM))
	_add_picker_grid("echo", CharacterRoster.ECHO_STYLES, str(look["echo"]), 3,
		func(entry: Dictionary) -> Texture2D:
			return _fighter_preview(CharacterRoster.echo_look(entry["id"], master, GridBattleUI.TEAM_COLORS[0]), GridBattleUI.TEAM_COLORS[0], 0.75 if entry["id"] == "echo" else 0.0),
		func(entry: Dictionary) -> void:
			CharacterRoster.save_look_value("echo", entry["id"])
			_show_echo_picker(), _show_echo_picker)
	_add_menu_button(_content, "< ZURÜCK", "Zur Sammlung", _show_collection)


func _show_card_skin_picker() -> void:
	_set_page("KARTENSKINS", _show_collection)
	_content.add_child(_make_text("So sehen deine Karten im Spiel aus: Rückseite beim Austeilen, Leuchten bei der Auswahl.", 22, TerminalTheme.GREEN_DIM))
	_add_picker_grid("cards", CardSkins.SKINS, str(CharacterRoster.load_look()["cards"]), 3,
		func(entry: Dictionary) -> Texture2D:
			return ImageTexture.create_from_image(CardSkins.preview_image(entry)),
		func(entry: Dictionary) -> void:
			CharacterRoster.save_look_value("cards", entry["id"])
			_show_card_skin_picker(), _show_card_skin_picker)
	_add_menu_button(_content, "< ZURÜCK", "Zur Sammlung", _show_collection)


func _show_board_picker() -> void:
	_set_page("SPIELFELD", _show_collection)
	_content.add_child(_make_text("So sieht deine Plattform mit den zwei Reihen auf deiner Seite des Bretts aus.", 22, TerminalTheme.GREEN_DIM))
	_add_picker_grid("board", CharacterRoster.BOARD_SKINS, str(CharacterRoster.load_look()["board"]), 1,
		func(entry: Dictionary) -> Texture2D:
			return BoardPreview.make(_previews, str(entry["id"])),
		func(entry: Dictionary) -> void:
			CharacterRoster.save_look_value("board", entry["id"])
			_show_board_picker(), _show_board_picker)
	_add_menu_button(_content, "< ZURÜCK", "Zur Sammlung", _show_collection)


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
			line = "GESPERRT – %s – für %d Credits im Shop%s" % [entry["name"], CharacterRoster.PRICES[item], ShopPages._level_hint(item)]
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
	_content.add_child(_make_text("VECTOR: gerade Sprünge  ·  WAVE: Flanken  ·  FIELD: Umzingeln  ·  OVERCLOCK: riskante Finisher", 20, TerminalTheme.GREEN_DIM))
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
		view.show_card(card, false, GridBattleUI.TEAM_COLORS[0], false)
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
	MenuMotion.type_in(_page_title)
	_entry_count = 0


## One menu entry; the subtitle appears below the list while it is selected.
func _add_menu_button(parent: Control, title: String, subtitle: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_size_override("font_size", ENTRY_FONT_SIZE)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_entered.connect(button.grab_focus)
	button.focus_entered.connect(func() -> void:
		_description.text = "> " + subtitle if not subtitle.is_empty() else ""
		SoundBoard.play("click", -10.0))
	button.pressed.connect(func() -> void: SoundBoard.play("select"))
	button.pressed.connect(action)
	parent.add_child(button)
	MenuMotion.enter(button, _entry_count)
	_entry_count += 1


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
	bot_difficulty = clampi(int(config.get_value("profile", "bot_difficulty", bot_difficulty)), 0, PlayPages.DIFFICULTY_OPTIONS.size() - 1)


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
