class_name MatchReplay
extends Control

const ReplayBoardScript := preload("res://scripts/ui/replay_board.gd")

var _history: Array[Dictionary] = []
var _selected_index: int = 0
var _board: ReplayBoard
var _step_label: Label
var _action_label: Label
var _cards_label: Label
var _timeline: VBoxContainer
var _timeline_scroll: ScrollContainer
var _previous_button: Button
var _next_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := ColorRect.new()
	background.color = Color(0.0, 0.025, 0.04, 0.96)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 14.0
	panel.offset_top = 18.0
	panel.offset_right = -14.0
	panel.offset_bottom = -18.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("08151b")
	panel_style.border_color = TerminalTheme.GREEN
	panel_style.set_border_width_all(2)
	panel_style.set_content_margin_all(10.0)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 5)
	panel.add_child(layout)
	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var title := _make_label("ZUGVERLAUF", 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.modulate = TerminalTheme.GREEN_BRIGHT
	heading.add_child(title)
	var close_button := _make_button("SCHLIESSEN")
	close_button.pressed.connect(close)
	heading.add_child(close_button)
	_step_label = _make_label("", 22)
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(_step_label)
	_action_label = _make_label("", 20)
	_action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(_action_label)
	_board = ReplayBoardScript.new()
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_board)
	_cards_label = _make_label("", 17)
	_cards_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(_cards_label)
	_timeline_scroll = ScrollContainer.new()
	_timeline_scroll.custom_minimum_size.y = 110.0
	_timeline_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timeline_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(_timeline_scroll)
	_timeline = VBoxContainer.new()
	_timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timeline.add_theme_constant_override("separation", 2)
	_timeline_scroll.add_child(_timeline)
	var navigation := HBoxContainer.new()
	navigation.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(navigation)
	_previous_button = _make_button("< ZURUECK")
	_previous_button.pressed.connect(_step.bind(-1))
	navigation.add_child(_previous_button)
	_next_button = _make_button("WEITER >")
	_next_button.pressed.connect(_step.bind(1))
	navigation.add_child(_next_button)


func open(history: Array[Dictionary]) -> void:
	_history.clear()
	for entry: Dictionary in history:
		_history.append(entry.duplicate(true))
	if _history.is_empty():
		return
	_selected_index = _history.size() - 1
	visible = true
	_rebuild_timeline()
	_show_step()
	_next_button.grab_focus()


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _step(amount: int) -> void:
	_selected_index = clampi(_selected_index + amount, 0, _history.size() - 1)
	_show_step()


func _select_step(index: int) -> void:
	_selected_index = index
	_show_step()


func _show_step() -> void:
	if _history.is_empty():
		return
	var entry := _history[_selected_index]
	_board.show_snapshot(entry)
	_step_label.text = "SCHRITT %02d / %02d  ·  RUNDE %02d  ·  P%d AM ZUG" % [
		_selected_index, _history.size() - 1, int(entry.get("round", 1)), int(entry.get("side_to_move", 0)) + 1,
	]
	_action_label.text = _describe_action(entry)
	_cards_label.text = _describe_cards(entry)
	_previous_button.disabled = _selected_index <= 0
	_next_button.disabled = _selected_index >= _history.size() - 1
	var row := _timeline.get_child(_selected_index) as Button
	if row != null:
		row.grab_focus()
		_timeline_scroll.ensure_control_visible(row)


func _rebuild_timeline() -> void:
	for child: Node in _timeline.get_children():
		_timeline.remove_child(child)
		child.queue_free()
	for index: int in range(_history.size()):
		var row := _make_button(_timeline_text(_history[index], index))
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_font_size_override("font_size", 18)
		row.pressed.connect(_select_step.bind(index))
		_timeline.add_child(row)


func _timeline_text(entry: Dictionary, index: int) -> String:
	var action: Dictionary = entry.get("action", {})
	var prefix := "START" if index == 0 else "ZUG %02d" % index
	var actor := "P%d" % (int(action.get("team", 0)) + 1)
	var card := str(action.get("played_card", ""))
	match str(action.get("type", "")):
		"move":
			var source: Vector2i = action.get("from", Vector2i.ZERO)
			var target: Vector2i = action.get("to", Vector2i.ZERO)
			return "%s  ·  %s: %s  (%d,%d) → (%d,%d)" % [
				prefix, actor, card, source.x + 1, source.y + 1, target.x + 1, target.y + 1,
			]
		"pass":
			return "%s  ·  %s passt: %s gegen %s" % [
				prefix, actor, card, str(action.get("received_card", "")),
			]
		"effect":
			var target: Vector2i = action.get("to", Vector2i.ZERO)
			return "%s  ·  %s: %s / %s (%d,%d)" % [
				prefix, actor, card, str(action.get("effect", "Effekt")), target.x + 1, target.y + 1,
			]
		_:
			return "%s  ·  Partie beginnt" % prefix


func _describe_action(entry: Dictionary) -> String:
	var action: Dictionary = entry.get("action", {})
	var team := int(action.get("team", 0)) + 1
	var type := str(action.get("type", "start"))
	if type == "start":
		return "Partie beginnt. Spieler %d ist am Zug." % (int(entry.get("side_to_move", 0)) + 1)
	if type == "pass":
		return "Spieler %d passt: %s geht in die Mitte; aufgenommen wird %s." % [
			team, str(action.get("played_card", "")), str(action.get("received_card", "")),
		]
	var detail := "Spieler %d spielt %s." % [team, str(action.get("played_card", ""))]
	if type == "move":
		var source: Vector2i = action.get("from", Vector2i.ZERO)
		var target: Vector2i = action.get("to", Vector2i.ZERO)
		detail += "  (%d,%d) → (%d,%d)." % [source.x + 1, source.y + 1, target.x + 1, target.y + 1]
		var captured := str(action.get("captured", ""))
		if not captured.is_empty():
			detail += "  %s geschlagen." % captured
		if bool(action.get("temple_win", false)):
			detail += "  KERN hat den URSPRUNG des Gegners betreten."
	elif type == "effect":
		var target: Vector2i = action.get("to", Vector2i.ZERO)
		detail += "  Effekt: %s auf (%d,%d)." % [str(action.get("effect", "")), target.x + 1, target.y + 1]
		if bool(action.get("master_capture", false)):
			detail += "  KERN geschlagen."
	detail += "  Erhält %s aus der Mitte." % str(action.get("received_card", ""))
	return detail


func _describe_cards(entry: Dictionary) -> String:
	var hands: Array = entry.get("hands", [])
	var first := _hand_text(hands, 0)
	var second := _hand_text(hands, 1)
	return "P1: %s     P2: %s     MITTE: %s" % [
		first, second, str(entry.get("pass_card", "")),
	]


func _hand_text(hands: Array, team: int) -> String:
	if team >= hands.size():
		return "—"
	var hand: Array = hands[team]
	return "%s · %s" % [str(hand[0]), str(hand[1])] if hand.size() >= 2 else "—"


func _make_label(text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _make_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(110.0, 42.0)
	button.add_theme_font_size_override("font_size", 18)
	button.add_to_group("interactive_ui")
	return button
