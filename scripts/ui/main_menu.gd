class_name MainMenu
extends Control

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
const AVATAR_COLORS: Array[Color] = [
	Color("55b8d4"), Color("e78b62"), Color("7ca77a"), Color("cfaa55"), Color("a287c2"),
]

var profile_name: String = "Spieler"
var avatar_index: int = 0
## BotAI.Difficulty value chosen for quick play; saved with the profile.
var bot_difficulty: int = 1
var _panel: PanelContainer
var _content: VBoxContainer
var _profile_button: Button
var _resume_available: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_profile()
	_build_shell()
	_show_home()
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()


func open_menu(can_resume: bool) -> void:
	_resume_available = can_resume
	visible = true
	_show_home()


func close_menu() -> void:
	visible = false


func _build_shell() -> void:
	theme = UITheme.theme()
	var backdrop := TextureRect.new()
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color("3a2414"), Color("1a0f08"), Color("070402")])
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill = GradientTexture2D.FILL_RADIAL
	gradient_texture.fill_from = Vector2(0.5, 0.3)
	gradient_texture.fill_to = Vector2(1.1, 1.0)
	backdrop.texture = gradient_texture
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var centerer := CenterContainer.new()
	centerer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centerer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centerer)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(560.0, 640.0)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_panel.add_theme_stylebox_override("panel", _panel_style())
	centerer.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(margin)
	_content = VBoxContainer.new()
	_content.custom_minimum_size.x = 516.0
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 16)
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(_content)
	_profile_button = Button.new()
	_profile_button.anchor_left = 1.0
	_profile_button.anchor_right = 1.0
	_profile_button.offset_left = -210.0
	_profile_button.offset_top = 18.0
	_profile_button.offset_right = -22.0
	_profile_button.offset_bottom = 70.0
	_profile_button.add_theme_font_size_override("font_size", 15)
	_profile_button.pressed.connect(_show_profile)
	add_child(_profile_button)
	add_to_group("interactive_ui")


func _show_home() -> void:
	_clear_content()
	_update_profile_button()
	var logo := _make_label("INFINITY GRID", 44, UITheme.GOLD_LIGHT)
	logo.add_theme_font_override("font", UITheme.decorative_font())
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.outline_label(logo, 10)
	_content.add_child(logo)
	var tagline := _make_label("Eine Arena. Zwei Seiten. Kein Ende.", 18, UITheme.GOLD)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(tagline)
	var subline := _make_label("Dein Meister und vier Schüler warten auf den nächsten Zug.", 14, Color("b9b3cc"))
	subline.add_theme_font_override("font", ThemeDB.fallback_font)
	subline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(subline)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 22.0
	_content.add_child(spacer)
	var session := MatchClient.saved_session()
	if not session.is_empty():
		_add_menu_button(_content, "PARTIE FORTSETZEN", "Deine Online-Partie läuft noch", func() -> void:
			close_menu()
			online_resume_requested.emit(session))
	# "Schnelles Spiel" now means a random online opponent (Multiplayer > Online).
	_add_menu_button(_content, "GEGEN DEN BOT", "Schwierigkeit wählen", _show_difficulty)
	_add_menu_button(_content, "MULTIPLAYER", "Lokal auf einem Gerät oder online", _show_multiplayer)
	_add_menu_button(_content, "SAMMLUNG", "Deine Bewegungskarten", _show_collection)
	_add_menu_button(_content, "SHOP", "Kosmetik und Kartenrücken", _show_online_page.bind("SHOP"))

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	_content.add_child(footer)
	if _resume_available:
		_add_menu_button(footer, "ZUR PARTIE", "", func() -> void: close_menu())
	var quit_button := Button.new()
	quit_button.text = "BEENDEN"
	quit_button.custom_minimum_size = Vector2(110.0, 42.0)
	quit_button.pressed.connect(func() -> void: quit_requested.emit())
	footer.add_child(quit_button)
	if not MatchClient.is_online_available():
		_content.add_child(_make_label("Online-Funktionen benötigen noch einen Spielserver.", 12, UITheme.GOLD))


func _show_difficulty() -> void:
	_clear_content()
	_content.add_child(_make_label("SCHWIERIGKEIT", 26, UITheme.GOLD_LIGHT))
	_content.add_child(_make_label("Wie stark soll der Bot spielen?", 15, Color("b9b3cc")))
	for level: int in range(DIFFICULTY_OPTIONS.size()):
		var option: Dictionary = DIFFICULTY_OPTIONS[level]
		var marker := "  (gewählt)" if level == bot_difficulty else ""
		_add_menu_button(_content, str(option["title"]) + marker, str(option["subtitle"]), _choose_difficulty.bind(level))
	_add_menu_button(_content, "ZURÜCK", "", _show_home)


func _choose_difficulty(level: int) -> void:
	bot_difficulty = level
	_save_profile()
	_start_bot_training()


func _show_multiplayer() -> void:
	_clear_content()
	_content.add_child(_make_label("MULTIPLAYER", 26, UITheme.GOLD_LIGHT))
	_content.add_child(_make_label("Wähle, wie ihr spielen möchtet.", 15, Color("b9b3cc")))
	_add_menu_button(_content, "AUF DIESEM GERÄT", "Abwechselnd mit einer zweiten Person spielen", _start_local_multiplayer)
	_add_menu_button(_content, "IM WLAN SPIELEN", "Zwei Handys, der PC ist Gastgeber", _start_lan_match)
	if MatchClient.is_online_available():
		_add_menu_button(_content, "ONLINE", "Mit einem Raum-Code gegen Freunde", _show_online_play)
	else:
		_add_menu_button(_content, "ONLINE", "Noch nicht verfügbar: Spielserver fehlt", _show_online_page.bind("ONLINE"))
	_add_menu_button(_content, "ZURÜCK", "", _show_home)


func _show_online_play() -> void:
	_clear_content()
	_content.add_child(_make_label("ONLINE", 26, UITheme.GOLD_LIGHT))
	_content.add_child(_make_label("Spiel gegen einen zufälligen Gegner – oder mit einem Raum-Code gegen Freunde.", 15, Color("b9b3cc")))
	_add_menu_button(_content, "SCHNELLES SPIEL", "Zufälliger Gegner, sofort los", func() -> void:
		close_menu()
		online_quick_requested.emit())
	_add_menu_button(_content, "SPIEL ERSTELLEN", "Du bekommst einen Raum-Code", func() -> void:
		close_menu()
		online_create_requested.emit())
	var code_input := LineEdit.new()
	code_input.placeholder_text = "Raum-Code, z. B. 4821"
	code_input.max_length = 4
	code_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	code_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_input.custom_minimum_size.y = 52.0
	code_input.add_theme_font_size_override("font_size", 22)
	_content.add_child(code_input)
	var join := func() -> void:
		var code := code_input.text.strip_edges()
		if code.length() != 4 or not code.is_valid_int():
			code_input.placeholder_text = "Bitte 4 Ziffern eingeben"
			code_input.text = ""
			return
		close_menu()
		online_join_requested.emit(code)
	code_input.text_submitted.connect(func(_text: String) -> void: join.call())
	_add_menu_button(_content, "BEITRETEN", "Mit dem Code deines Gegners", join)
	_add_menu_button(_content, "ZURÜCK", "", _show_multiplayer)


func _start_lan_match() -> void:
	if not MatchClient.is_lan_available():
		_show_lan_help()
		return
	close_menu()
	lan_match_requested.emit()


func _show_lan_help() -> void:
	_clear_content()
	_content.add_child(_make_label("IM WLAN SPIELEN", 26, UITheme.GOLD_LIGHT))
	_content.add_child(_make_label(
		"Starte am PC „WLAN-Spiel starten“ und öffne auf beiden Handys die Adresse, die dort angezeigt wird. Diese Version hier kommt aus dem Internet und kann sich nicht mit deinem PC verbinden.",
		16,
		Color("b9b3cc")
	))
	_add_menu_button(_content, "ZURÜCK", "", _show_multiplayer)


func _show_online_page(mode_name: String) -> void:
	_clear_content()
	_update_profile_button()
	_content.add_child(_make_label(mode_name, 26, UITheme.GOLD_LIGHT))
	_content.add_child(_make_label(
		"Die Online-Verbindung ist noch nicht eingerichtet. Es gibt noch keinen Matchmaking-, Freunde- oder Ranglistenserver.",
		16,
		Color("b9b3cc")
	))
	_content.add_child(_make_label("Dein Profilname und Avatar werden lokal auf diesem Gerät gespeichert.", 14, Color("9a94ad")))
	_add_menu_button(_content, "ZURÜCK", "", _show_home)


func _show_profile() -> void:
	_clear_content()
	_content.add_child(_make_label("SPIELERPROFIL", 26, UITheme.GOLD_LIGHT))
	_content.add_child(_make_label("Name", 14, Color("b9b3cc")))
	var name_input := LineEdit.new()
	name_input.text = profile_name
	name_input.max_length = 20
	name_input.placeholder_text = "Dein Anzeigename"
	_content.add_child(name_input)
	_content.add_child(_make_label("Avatarfarbe", 14, Color("b9b3cc")))
	var color_choices := HBoxContainer.new()
	color_choices.add_theme_constant_override("separation", 8)
	_content.add_child(color_choices)
	for index: int in range(AVATAR_COLORS.size()):
		var color_button := Button.new()
		color_button.text = _avatar_initial()
		color_button.custom_minimum_size = Vector2(46.0, 46.0)
		color_button.modulate = AVATAR_COLORS[index]
		color_button.tooltip_text = "Avatar %d" % (index + 1)
		color_button.pressed.connect(func() -> void:
			avatar_index = index
			for button_index: int in range(color_choices.get_child_count()):
				(color_choices.get_child(button_index) as Button).text = "●" if button_index == avatar_index else ""
		)
		color_choices.add_child(color_button)
		if index == avatar_index:
			color_button.text = "●"

	var save_button := Button.new()
	save_button.text = "PROFIL SPEICHERN"
	save_button.pressed.connect(func() -> void:
		profile_name = name_input.text.strip_edges()
		if profile_name.is_empty():
			profile_name = "Spieler"
		_save_profile()
		_show_home()
	)
	_content.add_child(save_button)
	_add_menu_button(_content, "ZURÜCK", "", _show_home)


func _show_collection() -> void:
	_clear_content()
	var deck := MovementCardScript.create_deck()
	_content.add_child(_make_label("KARTENSAMMLUNG", 26, UITheme.GOLD_LIGHT))
	_content.add_child(_make_label("%d Bewegungskarten. Pro Partie werden 5 zufällig gezogen." % deck.size(), 14, Color("b9b3cc")))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 380.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	var card_width := floorf((_content.custom_minimum_size.x - 40.0) / 3.0)
	for card: MovementCard in deck:
		var view: CardView = CardViewScript.new()
		view.custom_minimum_size = Vector2(card_width, card_width * 1.08)
		view.show_card(card, false, UITheme.TEAM_COLORS[0], false)
		grid.add_child(view)
	_add_menu_button(_content, "ZURÜCK", "", _show_home)


func _start_bot_training() -> void:
	close_menu()
	bot_training_requested.emit()


func _start_local_multiplayer() -> void:
	close_menu()
	local_multiplayer_requested.emit()


func _add_menu_button(parent: Control, title: String, subtitle: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title if subtitle.is_empty() else "%s\n%s" % [title, subtitle]
	button.custom_minimum_size = Vector2(0.0, 56.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(action)
	parent.add_child(button)


func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _clear_content() -> void:
	for child: Node in _content.get_children():
		child.queue_free()


func _avatar_initial() -> String:
	return profile_name.substr(0, 1).to_upper() if not profile_name.is_empty() else "S"


func _load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(PROFILE_PATH) != OK:
		return
	profile_name = str(config.get_value("profile", "name", profile_name))
	avatar_index = clampi(int(config.get_value("profile", "avatar", avatar_index)), 0, AVATAR_COLORS.size() - 1)
	bot_difficulty = clampi(int(config.get_value("profile", "bot_difficulty", bot_difficulty)), 0, DIFFICULTY_OPTIONS.size() - 1)


func _save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("profile", "name", profile_name)
	config.set_value("profile", "avatar", avatar_index)
	config.set_value("profile", "bot_difficulty", bot_difficulty)
	config.save(PROFILE_PATH)


func _apply_layout() -> void:
	if _panel == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x < 720.0:
		_panel.custom_minimum_size = Vector2(maxf(220.0, viewport_size.x - 24.0), maxf(420.0, viewport_size.y - 88.0))
		_content.custom_minimum_size.x = maxf(176.0, viewport_size.x - 68.0)
	else:
		_panel.custom_minimum_size = Vector2(560.0, 640.0)
		_content.custom_minimum_size.x = 516.0
	_profile_button.offset_left = -minf(230.0, viewport_size.x - 32.0)
	_profile_button.offset_right = -18.0
	_profile_button.offset_top = 14.0
	_profile_button.offset_bottom = 64.0


func _update_profile_button() -> void:
	if _profile_button == null:
		return
	_profile_button.text = "%s   %s" % [_avatar_initial(), profile_name]
	_profile_button.modulate = AVATAR_COLORS[avatar_index]


func _panel_style(color: Color = Color(0.07, 0.065, 0.11, 0.94)) -> StyleBox:
	return UITheme.panel_style(color)