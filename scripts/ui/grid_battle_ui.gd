class_name GridBattleUI
extends CanvasLayer

signal card_selected(team_id: int, slot: int)
signal history_requested
signal bot_training_requested
signal tutorial_requested
signal local_multiplayer_requested
signal chaos_requested(options: Dictionary)
signal ffa_requested(humans: int, shifting_tiles: bool, card_effects: bool)
signal group_create_requested(settings: Dictionary, max_players: int)
signal group_join_requested(code: String)
signal group_watch_requested(code: String, watch_key: String)
signal group_resume_requested(session: Dictionary)
signal lan_match_requested
signal online_create_requested(invite_username: String)
signal online_ranked_requested(ticket: String)
signal online_join_requested(code: String)
signal online_watch_requested(code: String, watch_key: String)
signal online_quick_requested
signal online_resume_requested(session: Dictionary)
signal restart_pressed
signal effect_requested
## Same mode again from the start (pause menu, result screen).
signal new_match_pressed
signal quit_pressed
signal board_insets_changed(top_pixels: float, bottom_pixels: float)
signal emote_picked(emote_id: String)

const MainMenuScript := preload("res://scripts/ui/main_menu.gd")
const MatchReplayScript := preload("res://scripts/ui/match_replay.gd")
const PASS_CARD_COLOR := Color("c9a648")
const TEAM_COLORS: Array[Color] = [Color("3fa9ff"), Color("ff5a3c")]
const MAX_COLUMN_WIDTH: float = 760.0
## Opponent cards are drawn smaller, like a hand seen across the table.
const OPPONENT_CARD_SCALE: float = 0.92

var round_label: Label
var instruction_label: Label
var selection_label: Label
## Empty places that reserve room for the 3D cards (see CardStage).
## hand_anchors[position][slot]; position 0 = bottom (viewer), 1 = top (opponent).
var hand_anchors: Array = [[], []]
## Pass-card place per position; the card rests where the side about to move sits.
var next_anchors: Array[Control] = [null, null]
## Row holding a position's two cards and its pass card.
var hand_rows: Array[BoxContainer] = [null, null]
var card_stage: CardStage
var hand_titles: Array[Label] = []
var opponent_is_bot: bool = false
## Opponent plays on another phone; only the viewer's own hand is clickable.
var opponent_is_remote: bool = false
var opponent_label: String = "BOT"
var viewer_team: int = 0
var result_overlay: ColorRect
var result_label: Label
var _header_text: String = ""
var _header_color: Color = Color.WHITE
var _timer_seconds: int = -1
var _clock_row: HBoxContainer
var _own_clock: Label
var _opponent_clock: Label
var result_detail: Label
## Added under the headline, e.g. the XP of this match.
var result_extra: String = ""
var menu_overlay: ColorRect
var hud_root: Control
var hud_column: Control
var top_tray: PanelContainer
var bottom_tray: PanelContainer
var menu_button: Button
var history_button: Button
var result_history_button: Button
var emote_button: Button
var emote_wheel: EmoteWheel
## Optional button under the instruction, e.g. "play the bot instead".
var side_action_button: Button
var _side_action: Callable
## Second button for two-way choices (who starts after the Node Ping).
var side_choice_button: Button
var effect_button: Button
var capture_warning_label: Label
var core_threat_label: Label
var _side_choice: Callable
var _pause_box: VBoxContainer
var _rules_box: VBoxContainer
var _new_match_button: Button
var _main_menu_button: Button
var main_menu: MainMenu
var match_replay: MatchReplay


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_build_main_menu()
	get_viewport().size_changed.connect(_apply_safe_area)
	get_viewport().size_changed.connect(_apply_responsive_layout)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if match_replay != null and match_replay.visible:
			match_replay.close()
		else:
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
	_header_text = "RUNDE %02d  •  %s" % [round_number, mover]
	round_label.text = _header_text
	round_label.modulate = TerminalTheme.GREEN_BRIGHT if current_player == viewer_team else TEAM_COLORS[current_player].lightened(0.35)
	_header_color = round_label.modulate
	set_turn_timer(_timer_seconds)


## A header the caller words itself (four-player mode).
func set_header_text(text_value: String, color: Color) -> void:
	_header_text = text_value
	_header_color = color
	set_turn_timer(_timer_seconds)


## Seconds left for the player's move, shown after the turn text (-1: no clock).
## The last five seconds turn red.
func set_turn_timer(seconds_left: int) -> void:
	_timer_seconds = seconds_left
	if seconds_left < 0:
		round_label.text = _header_text
		round_label.modulate = _header_color
		return
	round_label.text = "%s  •  %d s" % [_header_text, seconds_left]
	round_label.modulate = Color("ff6a55") if seconds_left <= 5 else _header_color
	if seconds_left <= 5 and seconds_left > 0:
		SoundBoard.play("click", -6.0)


## Ranked chess clock, own bank and the opponent's (-1 hides it). The running
## bank is bright, the last ten seconds red.
func set_chess_clock(own_seconds: int, opponent_seconds: int, own_running: bool) -> void:
	_clock_row.visible = own_seconds >= 0
	if own_seconds < 0:
		return
	_show_clock(_own_clock, "DU", own_seconds, own_running)
	_show_clock(_opponent_clock, "GEGNER", opponent_seconds, not own_running)
	var running := own_seconds if own_running else opponent_seconds
	if own_running and running <= 10 and running > 0:
		SoundBoard.play("click", -6.0)


func _show_clock(label: Label, owner_name: String, seconds: int, running: bool) -> void:
	label.text = "%s %s%d:%02d" % [owner_name, "> " if running else "", floori(seconds / 60.0), seconds % 60]
	if seconds <= 10:
		label.modulate = Color("ff6a55")
	else:
		label.modulate = TerminalTheme.GREEN_BRIGHT if running else TerminalTheme.GREEN_DIM


func _add_clock_row(parent: Control) -> void:
	_clock_row = HBoxContainer.new()
	_clock_row.visible = false
	parent.add_child(_clock_row)
	_own_clock = Label.new()
	_opponent_clock = Label.new()
	for label: Label in [_own_clock, _opponent_clock]:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 30)
		_outline(label)
		_clock_row.add_child(label)
	_opponent_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func update_hands(hands: Array, pass_card: MovementCard, current_player: int, selected_slot: int, viewing_team: int = 0, dim_all: bool = false, show_top: bool = true, selectable_pass_card: bool = false) -> void:
	viewer_team = viewing_team
	var placements: Array = []
	for position: int in range(2 if show_top else 1):
		var team_id := _team_at(position)
		var bot_hand := (opponent_is_bot and team_id == 1) or (opponent_is_remote and position == 1)
		var lift := 1.0 if position == 0 else -1.0
		for slot: int in range(2):
			placements.append({
				"card": hands[team_id][slot], "anchor": hand_anchors[position][slot],
				"team": team_id, "slot": slot, "rotated": position == 1,
				"color": TEAM_COLORS[team_id], "lift_direction": lift,
				"selected": team_id == current_player and slot == selected_slot,
				"dimmed": dim_all or team_id != current_player,
				"interactive": team_id == current_player and not bot_hand and not dim_all,
			})
		if team_id == current_player:
			placements.append({
				"card": pass_card, "anchor": next_anchors[position],
				"team": team_id if selectable_pass_card else -1,
				"slot": 2 if selectable_pass_card else -1, "rotated": position == 1,
				"color": PASS_CARD_COLOR,
				"lift_direction": lift,
				"selected": selectable_pass_card and team_id == current_player and selected_slot == 2,
				"dimmed": false, "interactive": selectable_pass_card and not bot_hand and not dim_all,
			})
		hand_titles[position].text = _team_name(team_id)
		hand_titles[position].modulate = TEAM_COLORS[team_id].lightened(0.3)
	if card_stage != null:
		card_stage.present(placements)


## The 3D cards hang under the camera; the HUD only keeps their places free.
func attach_card_stage(stage: CardStage) -> void:
	card_stage = stage
	card_stage.card_picked.connect(_emit_card_selected)


## Opening scene of a match; returns when the last card has landed.
func play_card_deal() -> void:
	if card_stage != null:
		card_stage.set_skin(CardSkins.current())
		await card_stage.deal()


func ensure_cards_visible() -> void:
	if card_stage != null:
		if card_stage.state == CardStage.State.HIDDEN:
			card_stage.set_skin(CardSkins.current())
		card_stage.show_instantly()


func update_selection(unit: BattleUnit) -> void:
	selection_label.text = "" if unit == null else unit.role_label()


## Chaos card effects: the button next to the cards (hidden while off).
func set_effect_button(visible_value: bool, label_text: String = "") -> void:
	effect_button.visible = visible_value
	effect_button.text = label_text


func set_instruction(text_value: String) -> void:
	instruction_label.text = text_value


func set_capture_warning(enabled: bool) -> void:
	capture_warning_label.visible = enabled


func has_capture_warning() -> bool:
	return capture_warning_label.visible


func set_core_threat_warning(enabled: bool) -> void:
	core_threat_label.visible = enabled


func has_core_threat_warning() -> bool:
	return core_threat_label.visible


func set_match_history(history: Array[Dictionary]) -> void:
	var available := history.size() > 1
	history_button.visible = available
	result_history_button.visible = available


func show_match_history(history: Array[Dictionary]) -> void:
	set_match_history(history)
	if not history.is_empty():
		match_replay.open(history)


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
	side_choice_button.visible = false


## Two buttons side by side; either one closes both.
func show_choice(first_text: String, first: Callable, second_text: String, second: Callable) -> void:
	show_side_action(first_text, first)
	_side_choice = second
	side_choice_button.text = second_text
	side_choice_button.visible = true


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
	# First line is the big headline; the rest is smaller and wraps.
	var parts := text_value.split("\n", true, 1)
	result_label.text = parts[0]
	var detail: Array[String] = []
	if parts.size() > 1:
		detail.append(parts[1])
	if not result_extra.is_empty():
		detail.append(result_extra)
	result_detail.text = "\n".join(detail)
	result_detail.visible = not detail.is_empty()


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
	# Emotes sit outside the menu so they are one tap away during a match.
	emote_button = _make_button("EMOTE", header)
	emote_button.custom_minimum_size = Vector2(128.0, 56.0) * (1.12 if AccessibilitySettings.is_enabled() else 1.0)
	emote_button.add_theme_font_size_override("font_size", AccessibilitySettings.font_size(26))
	emote_button.pressed.connect(func() -> void: emote_wheel.open())
	history_button = _make_button("ZUG", header)
	history_button.custom_minimum_size = Vector2(46.0, 44.0)
	history_button.add_theme_font_size_override("font_size", 18)
	history_button.tooltip_text = "Zugverlauf und Kartenwechsel"
	history_button.visible = false
	history_button.pressed.connect(func() -> void: history_requested.emit())
	menu_button = _make_button("MENÜ", header)
	menu_button.custom_minimum_size = Vector2(52.0, 44.0)
	menu_button.add_theme_font_size_override("font_size", 28)
	menu_button.pressed.connect(func() -> void: toggle_menu(true))
	_add_clock_row(top_box)
	_add_hand_row(top_box, 1)
	_add_hand_title(top_box, 1)
	emote_wheel = EmoteWheel.new()
	emote_wheel.name = "EmoteWheel"
	hud_root.add_child(emote_wheel)
	emote_wheel.picked.connect(func(emote_id: String) -> void: emote_picked.emit(emote_id))

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
	instruction_label.add_theme_font_size_override("font_size", AccessibilitySettings.font_size(26))
	instruction_label.modulate = TerminalTheme.GREEN_BRIGHT
	_outline(instruction_label, 7)
	bottom_box.add_child(instruction_label)
	capture_warning_label = Label.new()
	capture_warning_label.text = "KERN-ALARM  ·  GEWINNZUG LEUCHTET GOLD"
	capture_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	capture_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	capture_warning_label.add_theme_font_size_override("font_size", AccessibilitySettings.font_size(22))
	capture_warning_label.modulate = Color("ffc23a")
	_outline(capture_warning_label, 6)
	capture_warning_label.visible = false
	bottom_box.add_child(capture_warning_label)
	core_threat_label = Label.new()
	core_threat_label.text = "KERN IN GEFAHR  ·  GEGNER KANN IHN SCHLAGEN"
	core_threat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	core_threat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	core_threat_label.add_theme_font_size_override("font_size", AccessibilitySettings.font_size(22))
	core_threat_label.modulate = Color("ff5b56")
	_outline(core_threat_label, 6)
	core_threat_label.visible = false
	bottom_box.add_child(core_threat_label)
	side_action_button = _make_button("", bottom_box)
	side_action_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	side_action_button.visible = false
	side_action_button.pressed.connect(func() -> void:
		hide_side_action()
		if _side_action.is_valid():
			_side_action.call())
	side_choice_button = _make_button("", bottom_box)
	side_choice_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	side_choice_button.visible = false
	side_choice_button.pressed.connect(func() -> void:
		hide_side_action()
		if _side_choice.is_valid():
			_side_choice.call())
	effect_button = _make_button("", bottom_box)
	effect_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	effect_button.visible = false
	effect_button.pressed.connect(func() -> void: effect_requested.emit())
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
	result_box.position = Vector2(-280.0, -200.0)
	result_box.size = Vector2(560.0, 340.0)
	result_box.alignment = BoxContainer.ALIGNMENT_CENTER
	result_box.add_theme_constant_override("separation", 16)
	result_overlay.add_child(result_box)
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 76)
	result_label.modulate = TerminalTheme.GREEN_BRIGHT
	_outline(result_label, 12)
	result_box.add_child(result_label)
	result_detail = Label.new()
	result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_detail.add_theme_font_size_override("font_size", 28)
	result_detail.modulate = TerminalTheme.GREEN
	_outline(result_detail, 8)
	result_box.add_child(result_detail)
	var restart_button := _make_button("NOCHMAL SPIELEN", result_box)
	result_history_button = _make_button("ZUGVERLAUF", result_box)
	var quit_button := _make_button("HAUPTMENÜ", result_box)
	restart_button.pressed.connect(func() -> void: new_match_pressed.emit())
	result_history_button.pressed.connect(func() -> void: history_requested.emit())
	result_history_button.visible = false
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
		"> Jede Seite hat einen KERN (auf dem goldenen Sockel) und vier ECHOS.",
		"> Wähle eine deiner zwei Karten und eine Figur. Die Karte zeigt, wohin sie ziehen darf: weißes Feld = Figur, leuchtende Felder = Ziele.",
		"> Ziehst du auf einen Gegner, ist er geschlagen.",
		"> Die benutzte Karte geht an die Mitte; du bekommst die NÄCHSTE Karte.",
		"> Links und rechts ist das Brett endlos: Wer rechts rausgeht, kommt links wieder rein.",
		"> Kann keine Figur ziehen, gibst du eine Karte ab.",
		"> Schlag den gegnerischen KERN – oder stell irgendeine deiner Figuren auf sein Startfeld – und du gewinnst. Dieselbe Stellung dreimal = Unentschieden.",
	])
	_rules_box.add_child(rules)
	var rules_back := _make_button("< ZURÜCK", _rules_box)
	rules_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rules_back.pressed.connect(_show_rules.bind(false))

	match_replay = MatchReplayScript.new()
	match_replay.name = "MatchReplay"
	hud_root.add_child(match_replay)
	_apply_safe_area()
	_apply_responsive_layout()


func _build_main_menu() -> void:
	main_menu = MainMenuScript.new()
	main_menu.name = "MainMenu"
	add_child(main_menu)
	main_menu.bot_training_requested.connect(func() -> void: bot_training_requested.emit())
	main_menu.tutorial_requested.connect(func() -> void: tutorial_requested.emit())
	main_menu.ffa_requested.connect(func(humans: int, shifting_tiles: bool, card_effects: bool) -> void: ffa_requested.emit(humans, shifting_tiles, card_effects))
	main_menu.chaos_requested.connect(func(options: Dictionary) -> void: chaos_requested.emit(options))
	main_menu.local_multiplayer_requested.connect(func() -> void: local_multiplayer_requested.emit())
	main_menu.lan_match_requested.connect(func() -> void: lan_match_requested.emit())
	main_menu.online_create_requested.connect(func(invite_username: String) -> void: online_create_requested.emit(invite_username))
	main_menu.online_ranked_requested.connect(func(ticket: String) -> void: online_ranked_requested.emit(ticket))
	main_menu.online_join_requested.connect(func(code: String) -> void: online_join_requested.emit(code))
	main_menu.online_watch_requested.connect(func(code: String, watch_key: String) -> void: online_watch_requested.emit(code, watch_key))
	main_menu.online_quick_requested.connect(func() -> void: online_quick_requested.emit())
	main_menu.online_resume_requested.connect(func(session: Dictionary) -> void: online_resume_requested.emit(session))
	main_menu.quit_requested.connect(func() -> void: quit_pressed.emit())
	main_menu.toast_requested.connect(show_toast)
	main_menu.group_create_requested.connect(func(settings: Dictionary, max_players: int) -> void: group_create_requested.emit(settings, max_players))
	main_menu.group_join_requested.connect(func(code: String) -> void: group_join_requested.emit(code))
	main_menu.group_watch_requested.connect(func(code: String, watch_key: String) -> void: group_watch_requested.emit(code, watch_key))
	main_menu.group_resume_requested.connect(func(session: Dictionary) -> void: group_resume_requested.emit(session))


## A short message that slides in at the top, stays a few seconds and fades.
func show_toast(text_value: String) -> void:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.02, 0.06, 0.03, 0.92)
	box.border_color = TerminalTheme.GREEN
	box.set_border_width_all(2)
	box.set_content_margin_all(14.0)
	panel.add_theme_stylebox_override("panel", box)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", TerminalTheme.GREEN_BRIGHT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 420.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 70)
	panel.modulate.a = 0.0
	hud_root.add_child(panel)
	SoundBoard.play("emote")
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)
	tween.tween_interval(4.0)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(panel.queue_free)


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
	var row := BoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	hand_rows[position] = row
	var places: Array = []
	for slot: int in range(2):
		places.append(_make_card_place())
	var next_place := _make_card_place()
	# Opponent row mirrors the order so the next card sits on the same screen side.
	if position == 0:
		row.add_child(places[0])
		row.add_child(places[1])
		row.add_child(next_place)
	else:
		row.add_child(next_place)
		row.add_child(places[1])
		row.add_child(places[0])
	hand_anchors[position] = places
	next_anchors[position] = next_place


func _make_card_place() -> Control:
	var place := Control.new()
	place.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return place


func _emit_card_selected(team_id: int, slot: int) -> void:
	card_selected.emit(team_id, slot)


func _make_button(label_text: String, parent: Control) -> Button:
	var button := Button.new()
	button.text = label_text
	var scale_factor := 1.12 if AccessibilitySettings.is_enabled() else 1.0
	button.custom_minimum_size = Vector2(120.0, 48.0) * scale_factor
	button.add_theme_font_size_override("font_size", AccessibilitySettings.font_size(34))
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
		for place: Control in hand_anchors[position]:
			place.custom_minimum_size = Vector2(card_width, card_height) * factor
		next_anchors[position].custom_minimum_size = Vector2(card_width * 0.8, card_height * 0.86) * factor
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
