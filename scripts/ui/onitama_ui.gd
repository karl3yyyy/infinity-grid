class_name OnitamaUI
extends CanvasLayer

signal card_selected(team_id: int, slot: int)
signal restart_pressed
signal quit_pressed

var round_label: Label
var instruction_label: Label
var selection_label: Label
var pass_label: Label
var card_buttons: Array = [[], []]
var result_overlay: ColorRect
var result_label: Label
var menu_overlay: ColorRect
var hud_root: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	get_viewport().size_changed.connect(_apply_safe_area)


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
	round_label.text = "ROUND %02d    PLAYER %d TO MOVE" % [round_number, current_player + 1]
	round_label.modulate = Color("8fdff4") if current_player == 0 else Color("ff9b82")


func update_hands(hands: Array, pass_card: MovementCard, current_player: int, selected_slot: int) -> void:
	for team_id: int in range(2):
		for slot: int in range(2):
			var button: Button = card_buttons[team_id][slot]
			var card: MovementCard = hands[team_id][slot]
			button.text = "%s\n%s" % [card.card_name, card.move_summary(team_id)]
			button.tooltip_text = card.move_summary(team_id)
			button.disabled = team_id != current_player
			button.modulate = Color("ffe08a") if team_id == current_player and slot == selected_slot else Color.WHITE
	pass_label.text = "PASS\n%s\n%s" % [pass_card.card_name, pass_card.move_summary(current_player)]


func update_selection(unit: BattleUnit) -> void:
	selection_label.text = "No figure selected" if unit == null else unit.unit_name


func set_instruction(text_value: String) -> void:
	instruction_label.text = text_value


func show_result(text_value: String) -> void:
	menu_overlay.visible = false
	get_tree().paused = false
	result_overlay.visible = true
	result_label.text = text_value


func toggle_menu(force_visible: Variant = null) -> void:
	var next_visible := not menu_overlay.visible if force_visible == null else bool(force_visible)
	menu_overlay.visible = next_visible
	get_tree().paused = next_visible


func is_menu_open() -> bool:
	return menu_overlay != null and menu_overlay.visible


func _build_ui() -> void:
	hud_root = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud_root)

	var top_bar := ColorRect.new()
	top_bar.color = Color(0.025, 0.04, 0.065, 0.92)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 82.0
	hud_root.add_child(top_bar)

	round_label = Label.new()
	round_label.position = Vector2(24.0, 10.0)
	round_label.add_theme_font_size_override("font_size", 23)
	top_bar.add_child(round_label)
	selection_label = Label.new()
	selection_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	selection_label.position = Vector2(-280.0, 13.0)
	selection_label.size = Vector2(250.0, 28.0)
	selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	selection_label.add_theme_font_size_override("font_size", 18)
	top_bar.add_child(selection_label)
	instruction_label = Label.new()
	instruction_label.position = Vector2(24.0, 43.0)
	instruction_label.size = Vector2(900.0, 30.0)
	instruction_label.add_theme_font_size_override("font_size", 15)
	instruction_label.modulate = Color("d0d9e4")
	top_bar.add_child(instruction_label)

	var tray := PanelContainer.new()
	tray.anchor_left = 0.0
	tray.anchor_top = 1.0
	tray.anchor_right = 1.0
	tray.anchor_bottom = 1.0
	tray.offset_top = -158.0
	tray.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.04, 0.065, 0.94)))
	tray.add_to_group("interactive_ui")
	hud_root.add_child(tray)
	var rows := HBoxContainer.new()
	rows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rows.add_theme_constant_override("separation", 12)
	tray.add_child(rows)
	_add_hand(rows, 0, "PLAYER 1", Color("65bce8"))
	_add_pass_card(rows)
	_add_hand(rows, 1, "PLAYER 2", Color("ec806e"))

	result_overlay = ColorRect.new()
	result_overlay.color = Color(0.01, 0.015, 0.025, 0.88)
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
	result_label.add_theme_font_size_override("font_size", 38)
	result_box.add_child(result_label)
	var restart_button := _make_button("PLAY AGAIN", result_box)
	var quit_button := _make_button("QUIT", result_box)
	restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	quit_button.pressed.connect(func() -> void: quit_pressed.emit())

	menu_overlay = ColorRect.new()
	menu_overlay.color = Color(0.01, 0.015, 0.025, 0.91)
	menu_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_overlay.visible = false
	menu_overlay.add_to_group("interactive_ui")
	hud_root.add_child(menu_overlay)
	var menu_box := VBoxContainer.new()
	menu_box.set_anchors_preset(Control.PRESET_CENTER)
	menu_box.position = Vector2(-145.0, -100.0)
	menu_box.size = Vector2(290.0, 200.0)
	menu_box.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_box.add_theme_constant_override("separation", 14)
	menu_overlay.add_child(menu_box)
	var title := Label.new()
	title.text = "RING DUEL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	menu_box.add_child(title)
	var resume_button := _make_button("RESUME", menu_box)
	var restart_menu_button := _make_button("RESTART", menu_box)
	resume_button.pressed.connect(func() -> void: toggle_menu(false))
	restart_menu_button.pressed.connect(func() -> void: restart_pressed.emit())

	_apply_safe_area()


func _add_hand(parent: HBoxContainer, team_id: int, title_text: String, team_color: Color) -> void:
	var hand := VBoxContainer.new()
	hand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand.add_theme_constant_override("separation", 5)
	parent.add_child(hand)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = team_color
	title.add_theme_font_size_override("font_size", 14)
	hand.add_child(title)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 8)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand.add_child(cards)
	for slot: int in range(2):
		var button := _make_button("CARD", cards)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(_emit_card_selected.bind(team_id, slot))
		card_buttons[team_id].append(button)


func _add_pass_card(parent: HBoxContainer) -> void:
	var pass_column := VBoxContainer.new()
	pass_column.custom_minimum_size.x = 190.0
	pass_column.add_theme_constant_override("separation", 5)
	parent.add_child(pass_column)
	var title := Label.new()
	title.text = "SHARED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color("ffe08a")
	title.add_theme_font_size_override("font_size", 14)
	pass_column.add_child(title)
	pass_label = Label.new()
	pass_label.custom_minimum_size = Vector2(190.0, 88.0)
	pass_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pass_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pass_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pass_label.add_theme_font_size_override("font_size", 13)
	pass_label.add_theme_color_override("font_color", Color("ffe08a"))
	pass_column.add_child(pass_label)


func _emit_card_selected(team_id: int, slot: int) -> void:
	card_selected.emit(team_id, slot)


func _make_button(label_text: String, parent: Control) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(120.0, 48.0)
	button.add_theme_font_size_override("font_size", 15)
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