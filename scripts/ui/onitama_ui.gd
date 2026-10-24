class_name OnitamaUI
extends CanvasLayer

signal card_selected(team_id: int, slot: int)
signal bot_training_requested
signal local_multiplayer_requested
signal lan_match_requested
signal online_create_requested(invite_username: String)
signal online_ranked_requested(ticket: String)
signal online_join_requested(code: String)
signal online_quick_requested
signal online_resume_requested(session: Dictionary)
signal restart_pressed
## Same mode again from the start (pause menu, result screen).
signal new_match_pressed
signal quit_pressed
signal board_insets_changed(top_pixels: float, bottom_pixels: float)

const MainMenuScript := preload("res://scripts/ui/main_menu.gd")
const CardViewScript := preload("res://scripts/ui/card_view.gd")
const TEAM_COLORS: Array[Color] = [Color("3fa9ff"), Color("ff5a3c")]
const MAX_COLUMN_WIDTH: float = 760.0
## Opponent cards are drawn smaller, like a hand seen across the table.
const OPPONENT_CARD_SCALE: float = 0.7

var round_label: Label
var instruction_label: Label
var selection_label: Label
## card_views[position][slot]; position 0 = bottom (viewer), 1 = top (opponent).
var card_views: Array = [[], []]
## Next-card slot per position; only the side about to move shows the pass card.
var next_views: Array[CardView] = [null, null]
var hand_titles: Array[Label] = []
var opponent_is_bot: bool = false
## Opponent plays on another phone; only the viewer's own hand is clickable.
var opponent_is_remote: bool = false
var opponent_label: String = "BOT"
var viewer_team: int = 0
var result_overlay: ColorRect
var result_label: Label
var menu_overlay: ColorRect
var hud_root: Control
var hud_column: Control
var top_tray: PanelContainer
var bottom_tray: PanelContainer
var menu_button: Button
## Optional button under the instruction, e.g. "play the bot instead".
var side_action_button: Button
var _side_action: Callable
var _pause_box: VBoxContainer
var _rules_box: VBoxContainer
var _new_match_button: Button
var _main_menu_button: Button
var main_menu: MainMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_build_main_menu()
	get_viewport().size_changed.connect(_apply_safe_area)
	get_viewport().size_changed.connect(_apply_responsive_layout)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_menu()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var mode := DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN
		)
		get_viewport().set_input_as_handled()


func update_header(current_player: int, round_number: int) -> void:
	var mover := "%s AM ZUG" % _team_name(current_player)
	round_label.text = "RUNDE %02d  •  %s" % [round_number, mover]
	round_label.modulate = TerminalTheme.GREEN_BRIGHT if current_player == viewer_team else TEAM_COLORS[current_player].lightened(0.35)


func update_hands(hands: Array, pass_card: MovementCard, current_player: int, selected_slot: int, viewing_team: int = 0) -> void:
	viewer_team = viewing_team
	for position: int in range(2):
		var team_id := _team_at(position)
		var rotated := position == 1
		var bot_hand := (opponent_is_bot and team_id == 1) or (opponent_is_remote and position == 1)
		for slot: int in range(2):
			var view: CardView = card_views[position][slot]
			var card: MovementCard = hands[team_id][slot]
			var selected := team_id == current_player and slot == selected_slot
			view.disabled = team_id != current_player or bot_hand
			view.dimmed = team_id != current_player
			view.show_card(card, rotated, TEAM_COLORS[team_id], selected)
		var next_view: CardView = next_views[position]
		next_view.disabled = true
		next_view.dimmed = false
		if team_id == current_player:
			next_view.show_card(pass_card, rotated, Color("c9a648"), false, "NÄCHSTE")
		else:
			next_view.show_card(null, rotated, Color("c9a648"), false)
		hand_titles[position].text = _team_name(team_id)
		hand_titles[position].modulate = TEAM_COLORS[team_id].lightened(0.3)


func update_selection(unit: BattleUnit) -> void:
	selection_label.text = "" if unit == null else ("KERN" if unit.is_master else "SCHÜLER")


func set_instruction(text_value: String) -> void:
	instruction_label.text = text_value


func set_opponent_bot(enabled: bool, difficulty_label: String = "") -> void:
	opponent_is_bot = enabled
	opponent_label = "BOT" if difficulty_label.is_empty() else "BOT · %s" % difficulty_label
	if hand_titles.size() > 1:
		hand_titles[1].text = _team_name(_team_at(1))


func show_side_action(label_text: String, action: Callable) -> void:
	_side_action = action
	side_action_button.text = label_text
	side_action_button.visible = true


func hide_side_action() -> void:
	side_action_button.visible = false


func set_opponent_remote(enabled: bool) -> void:
	opponent_is_remote = enabled
	if enabled:
		opponent_is_bot = false


func _team_at(position: int) -> int:
	return viewer_team if position == 0 else 1 - viewer_team


func _team_name(team_id: int) -> String:
	if opponent_is_remote:
		return "DU" if team_id == viewer_team else "GEGNER"
	if team_id == 1 and opponent_is_bot:
		return opponent_label
	if opponent_is_bot:
		return "DU"
	return "SPIELER %d" % (team_id + 1)


func show_result(text_value: String) -> void:
	menu_overlay.visible = false
	main_menu.close_menu()
	get_tree().paused = false
	result_overlay.visible = true
	result_label.text = text_value


func toggle_menu(force_visible: Variant = null) -> void:
	var next_visible := not menu_overlay.visible if force_visible == null else bool(force_visible)
	menu_overlay.visible = next_visible
	get_tree().paused = next_visible
	_show_rules(false)
	# Online the match keeps running for the opponent: no restart, leaving gives up.
	_new_match_button.visible = not opponent_is_remote
	_main_menu_button.text = "AUFGEBEN & MENÜ" if opponent_is_remote else "HAUPTMENÜ"


func _show_rules(show: bool) -> void:
	_rules_box.visible = show
	_pause_box.visible = not show


func is_menu_open() -> bool:
	return menu_overlay != null and menu_overlay.visible


func _build_ui() -> void:
	hud_root = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.theme = TerminalTheme.theme()
	add_child(hud_root)
	# Dark vignette frames the candle-lit table like a tavern scene.
	var vignette := TextureRect.new()
	var vignette_gradient := Gradient.new()
	vignette_gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	vignette_gradient.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0.0, 0.01, 0.03, 0.2), Color(0.0, 0.01, 0.03, 0.75)])
	var vignette_texture := GradientTexture2D.new()
	vignette_texture.gradient = vignette_gradient
	vignette_texture.fill = GradientTexture2D.FILL_RADIAL
	vignette_texture.fill_from = Vector2(0.5, 0.5)
	vignette_texture.fill_to = Vector2(1.05, 0.5)
	vignette.texture = vignette_texture
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(vignette)
	hud_column = Control.new()
	hud_column.anchor_left = 0.5
	hud_column.anchor_right = 0.5
	hud_column.anchor_bottom = 1.0
	hud_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(hud_column)

	# Opponent side: header, name and their two cards (rotated towards them).
	top_tray = _make_tray()
	top_tray.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud_column.add_child(top_tray)
	var top_box := VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 4)
	top_tray.add_child(top_box)
	var header := HBoxContainer.new()
	top_box.add_child(header)
	round_label = Label.new()
	round_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	round_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	round_label.add_theme_font_size_override("font_size", 32)
	_outline(round_label)
	header.add_child(round_label)
	selection_label = Label.new()
	selection_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selection_label.add_theme_font_size_override("font_size", 24)
	selection_label.modulate = TerminalTheme.GREEN
	_outline(selection_label)
	header.add_child(selection_label)
	menu_button = _make_button("MENÜ", header)
	menu_button.custom_minimum_size = Vector2(52.0, 44.0)
	menu_button.add_theme_font_size_override("font_size", 28)
	menu_button.pressed.connect(func() -> void: toggle_menu(true))
	_add_hand_row(top_box, 1)
	_add_hand_title(top_box, 1)

	# Viewer side: instruction text and own cards.
	bottom_tray = _make_tray()
	bottom_tray.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_tray.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud_column.add_child(bottom_tray)
	var bottom_box := VBoxContainer.new()
	bottom_box.add_theme_constant_override("separation", 6)
	bottom_tray.add_child(bottom_box)
	instruction_label = Label.new()
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction_label.custom_minimum_size.y = 42.0
	instruction_label.add_theme_font_size_override("font_size", 26)
	instruction_label.modulate = TerminalTheme.GREEN_BRIGHT
	_outline(instruction_label, 7)
	bottom_box.add_child(instruction_label)
	side_action_button = _make_button("", bottom_box)
	side_action_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	side_action_button.visible = false
	side_action_button.pressed.connect(func() -> void:
		side_action_button.visible = false
		if _side_action.is_valid():
			_side_action.call())
	_add_hand_title(bottom_box, 0)
	_add_hand_row(bottom_box, 0)
	# Titles were appended bottom-last; keep index = position.
	hand_titles.reverse()

	result_overlay = ColorRect.new()
	result_overlay.color = Color(0.0, 0.02, 0.04, 0.86)
	result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_overlay.visible = false
	result_overlay.add_to_group("interactive_ui")
	hud_root.add_child(result_overlay)
	var result_box := VBoxContainer.new()
	result_box.set_anchors_preset(Control.PRESET_CENTER)
	result_box.position = Vector2(-190.0, -85.0)
	result_box.size = Vector2(380.0, 170.0)
	result_box.alignment = BoxContainer.ALIGNMENT_CENTER
	result_box.add_theme_constant_override("separation", 16)
	result_overlay.add_child(result_box)
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 76)
	result_label.modulate = TerminalTheme.GREEN_BRIGHT
	_outline(result_label, 12)
	result_box.add_child(result_label)
	var restart_button := _make_button("NOCHMAL SPIELEN", result_box)
	var quit_button := _make_button("HAUPTMENÜ", result_box)
	restart_button.pressed.connect(func() -> void: new_match_pressed.emit())
	quit_button.pressed.connect(func() -> void: restart_pressed.emit())

	menu_overlay = ColorRect.new()
	menu_overlay.color = Color(0.0, 0.02, 0.04, 0.9)
	menu_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_overlay.visible = false
	menu_overlay.add_to_group("interactive_ui")
	hud_root.add_child(menu_overlay)
	var menu_center := CenterContainer.new()
	menu_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_overlay.add_child(menu_center)
	var menu_box := VBoxContainer.new()
	menu_box.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_box.add_theme_constant_override("separation", 18)
	menu_center.add_child(menu_box)
	_pause_box = menu_box
	var title := Label.new()
	title.text = "---- PAUSE ----"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	menu_box.add_child(title)
	var resume_button := _make_button("WEITER", menu_box)
	var rules_button := _make_button("REGELN", menu_box)
	_new_match_button = _make_button("NEUE PARTIE", menu_box)
	_main_menu_button = _make_button("HAUPTMENÜ", menu_box)
	resume_button.pressed.connect(func() -> void: toggle_menu(false))
	rules_button.pressed.connect(_show_rules.bind(true))
	_new_match_button.pressed.connect(func() -> void: new_match_pressed.emit())
	_main_menu_button.pressed.connect(func() -> void: restart_pressed.emit())

	# Short rules, opened from the pause menu.
	_rules_box = VBoxContainer.new()
	_rules_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rules_box.offset_left = 36.0
	_rules_box.offset_right = -36.0
	_rules_box.offset_top = 80.0
	_rules_box.offset_bottom = -60.0
	_rules_box.add_theme_constant_override("separation", 12)
	_rules_box.visible = false
	menu_overlay.add_child(_rules_box)
	var rules_title := Label.new()
	rules_title.text = "---- REGELN ----"
	rules_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rules_title.add_theme_font_size_override("font_size", 44)
	_rules_box.add_child(rules_title)
	var rules := Label.new()
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.add_theme_font_size_override("font_size", 27)
	rules.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rules.text = "\n".join([
		"> Jede Seite hat einen KERN (auf dem goldenen Sockel) und vier SCHÜLER.",
		"> Wähle eine deiner zwei Karten und eine Figur. Die Karte zeigt, wohin sie ziehen darf: weißes Feld = Figur, leuchtende Felder = Ziele.",
		"> Ziehst du auf einen Gegner, ist er geschlagen.",
		"> Die benutzte Karte geht an die Mitte; du bekommst die NÄCHSTE Karte.",
		"> Links und rechts ist das Brett endlos: Wer rechts rausgeht, kommt links wieder rein.",
		"> Kann keine Figur ziehen, gibst du eine Karte ab.",
		"> Schlag den gegnerischen KERN und du gewinnst. Dieselbe Stellung dreimal = Unentschieden.",
	])
	_rules_box.add_child(rules)
	var rules_back := _make_button("< ZURÜCK", _rules_box)
	rules_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rules_back.pressed.connect(_show_rules.bind(false))

	_apply_safe_area()
	_apply_responsive_layout()


func _build_main_menu() -> void:
	main_menu = MainMenuScript.new()
	main_menu.name = "MainMenu"
	add_child(main_menu)
	main_menu.bot_training_requested.connect(func() -> void: bot_training_requested.emit())
	main_menu.local_multiplayer_requested.connect(func() -> void: local_multiplayer_requested.emit())
	main_menu.lan_match_requested.connect(func() -> void: lan_match_requested.emit())
	main_menu.online_create_requested.connect(func(invite_username: String) -> void: online_create_requested.emit(invite_username))
	main_menu.online_ranked_requested.connect(func(ticket: String) -> void: online_ranked_requested.emit(ticket))
	main_menu.online_join_requested.connect(func(code: String) -> void: online_join_requested.emit(code))
	main_menu.online_quick_requested.connect(func() -> void: online_quick_requested.emit())
	main_menu.online_resume_requested.connect(func(session: Dictionary) -> void: online_resume_requested.emit(session))
	main_menu.quit_requested.connect(func() -> void: quit_pressed.emit())


## Transparent tray: the meadow and board stay visible behind the cards.
func _make_tray() -> PanelContainer:
	var panel := PanelContainer.new()
	var clear := StyleBoxEmpty.new()
	clear.set_content_margin_all(12.0)
	panel.add_theme_stylebox_override("panel", clear)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_to_group("interactive_ui")
	return panel


## Dark outline keeps HUD text readable on top of the bright meadow.
func _outline(label: Label, outline_size: int = 6) -> void:
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.06, 0.9))
	label.add_theme_constant_override("outline_size", outline_size)


func _add_hand_title(parent: Control, position: int) -> void:
	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	_outline(title)
	title.text = "DU" if position == 0 else "BOT"
	parent.add_child(title)
	hand_titles.append(title)


func _add_hand_row(parent: Control, position: int) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var views: Array = []
	for slot: int in range(2):
		var view: CardView = CardViewScript.new()
		view.pressed.connect(_on_card_view_pressed.bind(position, slot))
		views.append(view)
	var next_view: CardView = CardViewScript.new()
	next_view.disabled = true
	# Opponent row mirrors the order so the next card sits on the same screen side.
	if position == 0:
		row.add_child(views[0])
		row.add_child(views[1])
		row.add_child(next_view)
	else:
		row.add_child(next_view)
		row.add_child(views[1])
		row.add_child(views[0])
	card_views[position] = views
	next_views[position] = next_view


func _on_card_view_pressed(position: int, slot: int) -> void:
	_emit_card_selected(_team_at(position), slot)


func _emit_card_selected(team_id: int, slot: int) -> void:
	card_selected.emit(team_id, slot)


func _make_button(label_text: String, parent: Control) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(120.0, 48.0)
	button.add_theme_font_size_override("font_size", 34)
	button.add_to_group("interactive_ui")
	parent.add_child(button)
	return button


func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("526879")
	style.set_border_width_all(1)
	style.set_content_margin_all(12.0)
	return style


func _apply_safe_area() -> void:
	if hud_root == null:
		return
	if OS.get_name() not in ["Android", "iOS"]:
		hud_root.offset_left = 0.0
		hud_root.offset_top = 0.0
		hud_root.offset_right = 0.0
		hud_root.offset_bottom = 0.0
		return
	var window_size := DisplayServer.window_get_size()
	var safe_area := DisplayServer.get_display_safe_area()
	if safe_area.size.x <= 0 or safe_area.size.y <= 0 or window_size.x <= 0 or window_size.y <= 0:
		return
	var logical_scale := get_viewport().get_visible_rect().size / Vector2(window_size)
	hud_root.offset_left = float(safe_area.position.x) * logical_scale.x
	hud_root.offset_top = float(safe_area.position.y) * logical_scale.y
	hud_root.offset_right = -float(window_size.x - safe_area.end.x) * logical_scale.x
	hud_root.offset_bottom = -float(window_size.y - safe_area.end.y) * logical_scale.y


func _apply_responsive_layout(viewport_size: Vector2 = Vector2.ZERO) -> void:
	if hud_column == null or top_tray == null or bottom_tray == null:
		return
	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport().get_visible_rect().size
	var column_width := minf(viewport_size.x, MAX_COLUMN_WIDTH)
	hud_column.offset_left = -column_width * 0.5
	hud_column.offset_right = column_width * 0.5
	# Two hand cards plus a slightly smaller next card share one row.
	var usable := column_width - 24.0 - 20.0
	var card_width := clampf(usable / 3.25, 96.0, 240.0)
	var card_height := clampf(card_width * 1.12, 110.0, minf(290.0, viewport_size.y * 0.19))
	for position: int in range(2):
		var factor := 1.0 if position == 0 else OPPONENT_CARD_SCALE
		for view: CardView in card_views[position]:
			view.custom_minimum_size = Vector2(card_width, card_height) * factor
		next_views[position].custom_minimum_size = Vector2(card_width * 0.8, card_height * 0.86) * factor
	top_tray.offset_left = 0.0
	top_tray.offset_right = 0.0
	bottom_tray.offset_left = 0.0
	bottom_tray.offset_right = 0.0
	top_tray.offset_top = 0.0
	top_tray.offset_bottom = top_tray.get_combined_minimum_size().y
	bottom_tray.offset_bottom = 0.0
	bottom_tray.offset_top = -bottom_tray.get_combined_minimum_size().y
	var insets := get_board_insets()
	board_insets_changed.emit(insets.x, insets.y)


func get_board_insets() -> Vector2:
	if top_tray == null:
		return Vector2.ZERO
	return Vector2(top_tray.offset_bottom + hud_root.offset_top, -bottom_tray.offset_top - hud_root.offset_bottom)
