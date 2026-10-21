class_name MainMenu
extends Control

signal bot_training_requested
signal quit_requested

const MovementCardScript := preload("res://scripts/battle/movement_card.gd")
const PROFILE_PATH := "user://ring_duel_profile.cfg"
const AVATAR_COLORS: Array[Color] = [
	Color("55b8d4"), Color("e78b62"), Color("7ca77a"), Color("cfaa55"), Color("a287c2"),
]

var profile_name: String = "Spieler"
var avatar_index: int = 0
var _panel: PanelContainer
var _content: VBoxContainer
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
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.025, 0.055, 0.075, 0.94)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(margin)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	margin.add_child(_content)
	add_to_group("interactive_ui")


func _show_home() -> void:
	_clear_content()
	var eyebrow := _make_label("RING DUEL  /  ECHOES OF THE MEADOW", 13, Color("e6bd70"))
	_content.add_child(eyebrow)
	_content.add_child(_make_label("Eine Arena. Zwei Seiten. Kein Ende.", 28, Color("f0f4df")))
	_content.add_child(_make_label("Dein Meister und vier Schüler warten auf den nächsten Zug.", 15, Color("afc2b6")))

	var profile_button := Button.new()
	profile_button.text = "%s     %s" % [_avatar_initial(), profile_name]
	profile_button.custom_minimum_size = Vector2(0.0, 48.0)
	profile_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	profile_button.modulate = AVATAR_COLORS[avatar_index]
	profile_button.pressed.connect(func() -> void: _show_profile())
	_content.add_child(profile_button)

	var modes := GridContainer.new()
	modes.columns = 2
	modes.add_theme_constant_override("h_separation", 8)
	modes.add_theme_constant_override("v_separation", 8)
	_content.add_child(modes)
	_add_menu_button(modes, "SCHNELLES SPIEL", "Online-Gegner suchen", _show_online_page.bind("SCHNELLES SPIEL"))
	_add_menu_button(modes, "MEHRSPIELER", "Online-Modi und Einladungen", _show_online_page.bind("MEHRSPIELER"))
	_add_menu_button(modes, "BOT-TRAINING", "Lokale Partie starten", _start_bot_training)
	_add_menu_button(modes, "RANKED", "Wertungskampf online", _show_online_page.bind("RANKED"))
	_add_menu_button(modes, "SAMMLUNG", "Deine Bewegungskarten", _show_collection)
	_add_menu_button(modes, "SHOP", "Kosmetik und Kartenrücken", _show_online_page.bind("SHOP"))
	_add_menu_button(modes, "RANGLISTE", "Globale Platzierungen", _show_online_page.bind("RANGLISTE"))
	_add_menu_button(modes, "FREUNDE", "Freunde und Einladungen", _show_online_page.bind("FREUNDE"))

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
	_content.add_child(_make_label("Online-Modi benötigen noch einen Spielserver.", 12, Color("d9a07c")))


func _show_online_page(mode_name: String) -> void:
	_clear_content()
	_content.add_child(_make_label(mode_name, 26, Color("f0f4df")))
	_content.add_child(_make_label(
		"Die Online-Verbindung ist noch nicht eingerichtet. Es gibt noch keinen Matchmaking-, Freunde- oder Ranglistenserver.",
		16,
		Color("afc2b6")
	))
	_content.add_child(_make_label("Dein Profilname und Avatar werden lokal auf diesem Gerät gespeichert.", 14, Color("8fa69a")))
	_add_menu_button(_content, "BOT-TRAINING STARTEN", "", _start_bot_training)
	_add_menu_button(_content, "ZURÜCK", "", _show_home)


func _show_profile() -> void:
	_clear_content()
	_content.add_child(_make_label("SPIELERPROFIL", 26, Color("f0f4df")))
	_content.add_child(_make_label("Name", 14, Color("afc2b6")))
	var name_input := LineEdit.new()
	name_input.text = profile_name
	name_input.max_length = 20
	name_input.placeholder_text = "Dein Anzeigename"
	_content.add_child(name_input)
	_content.add_child(_make_label("Avatarfarbe", 14, Color("afc2b6")))
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
	_content.add_child(_make_label("KARTENSAMMLUNG", 26, Color("f0f4df")))
	_content.add_child(_make_label("Alle fünf Grundkarten sind freigeschaltet.", 14, Color("afc2b6")))
	for card: MovementCard in MovementCardScript.create_deck():
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", _panel_style(Color("203b39")))
		var row_margin := MarginContainer.new()
		row_margin.add_theme_constant_override("margin_left", 12)
		row_margin.add_theme_constant_override("margin_right", 12)
		row_margin.add_theme_constant_override("margin_top", 8)
		row_margin.add_theme_constant_override("margin_bottom", 8)
		row.add_child(row_margin)
		row_margin.add_child(_make_label("%s     %s" % [card.card_name, card.move_summary()], 16, Color("e5e8cf")))
		_content.add_child(row)
	_add_menu_button(_content, "ZURÜCK", "", _show_home)


func _start_bot_training() -> void:
	close_menu()
	bot_training_requested.emit()


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


func _save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("profile", "name", profile_name)
	config.set_value("profile", "avatar", avatar_index)
	config.save(PROFILE_PATH)


func _apply_layout() -> void:
	if _panel == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x < 720.0:
		_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_panel.offset_left = 12.0
		_panel.offset_top = 12.0
		_panel.offset_right = -12.0
		_panel.offset_bottom = -12.0
	else:
		_panel.set_anchors_preset(Control.PRESET_CENTER)
		_panel.position = Vector2(-330.0, -350.0)
		_panel.size = Vector2(660.0, 700.0)


func _panel_style(color: Color = Color("13272b")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("668676")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12.0)
	return style