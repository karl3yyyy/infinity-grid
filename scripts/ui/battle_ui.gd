class_name BattleUI
extends CanvasLayer

signal attack_pressed
signal heal_pressed
signal wait_pressed
signal cancel_pressed
signal end_turn_pressed
signal restart_pressed
signal quit_pressed

var phase_label: Label
var round_label: Label
var instruction_label: Label
var unit_info: Label
var attack_button: Button
var heal_button: Button
var wait_button: Button
var cancel_button: Button
var end_turn_button: Button
var result_overlay: ColorRect
var result_label: Label
var menu_overlay: ColorRect
var mute_button: Button
var hud_root: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		cancel_pressed.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			_toggle_fullscreen()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_M:
			_toggle_mute()
			get_viewport().set_input_as_handled()


func update_header(round_number: int, phase: String) -> void:
	round_label.text = "ROUND %02d" % round_number
	phase_label.text = phase


func set_instruction(text_value: String) -> void:
	instruction_label.text = text_value


func update_unit(unit: BattleUnit) -> void:
	if unit == null:
		unit_info.text = "No unit selected\n\nSelect a blue unit."
		attack_button.text = "ATTACK"
		return
	attack_button.text = "HOLY BOLT" if unit.unit_class_id == UnitClassData.UnitClass.PRIEST else "ATTACK"
	unit_info.text = (
		"%s — %s\nHP  %d / %d\nATK  %d    DEF  %d\nMOVE  %d    RANGE  %d–%d\nMoved: %s    Acted: %s"
		% [
			unit.unit_name, unit.class_display_name, unit.current_hp, unit.max_hp,
			unit.attack_power, unit.defense, unit.movement_range, unit.attack_min_range, unit.attack_range,
			"Yes" if unit.has_moved else "No",
			"Yes" if unit.has_attacked else "No",
		]
	)


func set_actions(
	can_attack: bool,
	can_wait: bool,
	can_cancel: bool,
	can_end_turn: bool = true,
	can_heal: bool = false
) -> void:
	attack_button.disabled = not can_attack
	heal_button.disabled = not can_heal
	wait_button.disabled = not can_wait
	cancel_button.disabled = not can_cancel
	end_turn_button.disabled = not can_end_turn


func show_result(victory: bool) -> void:
	if menu_overlay.visible:
		toggle_menu(false)
	result_overlay.visible = true
	result_label.text = "VICTORY" if victory else "DEFEAT"
	result_label.modulate = Color("8ff7a5") if victory else Color("ff7b7b")


func toggle_menu(force_visible: Variant = null) -> void:
	var next_visible := not menu_overlay.visible if force_visible == null else bool(force_visible)
	menu_overlay.visible = next_visible
	get_tree().paused = next_visible


func is_menu_open() -> bool:
	return menu_overlay != null and menu_overlay.visible


func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN
	)


func _toggle_mute() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, not AudioServer.is_bus_mute(bus))
	mute_button.text = "UNMUTE" if AudioServer.is_bus_mute(bus) else "MUTE"


func _apply_safe_area(root: Control) -> void:
	if OS.get_name() not in ["Android", "iOS"]:
		root.offset_left = 0.0
		root.offset_top = 0.0
		root.offset_right = 0.0
		root.offset_bottom = 0.0
		return
	var window_size := DisplayServer.window_get_size()
	var safe_area := DisplayServer.get_display_safe_area()
	if safe_area.size.x <= 0 or safe_area.size.y <= 0 or window_size.x <= 0 or window_size.y <= 0:
		return
	var logical_size := get_viewport().get_visible_rect().size
	var logical_scale := logical_size / Vector2(window_size)
	root.offset_left = float(safe_area.position.x) * logical_scale.x
	root.offset_top = float(safe_area.position.y) * logical_scale.y
	root.offset_right = -float(window_size.x - safe_area.end.x) * logical_scale.x
	root.offset_bottom = -float(window_size.y - safe_area.end.y) * logical_scale.y


func _on_viewport_size_changed() -> void:
	if hud_root != null:
		_apply_safe_area(hud_root)


func _build_ui() -> void:
	hud_root = Control.new()
	hud_root.name = "BattleHUD"
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud_root)
	call_deferred("_apply_safe_area", hud_root)

	var top_bar := ColorRect.new()
	top_bar.color = Color(0.025, 0.04, 0.065, 0.90)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 74.0
	hud_root.add_child(top_bar)

	round_label = Label.new()
	round_label.position = Vector2(28.0, 12.0)
	round_label.add_theme_font_size_override("font_size", 18)
	top_bar.add_child(round_label)
	phase_label = Label.new()
	phase_label.position = Vector2(28.0, 36.0)
	phase_label.add_theme_font_size_override("font_size", 25)
	phase_label.modulate = Color("8fdff4")
	top_bar.add_child(phase_label)
	instruction_label = Label.new()
	instruction_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	instruction_label.position = Vector2(-620.0, 19.0)
	instruction_label.size = Vector2(590.0, 45.0)
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	instruction_label.add_theme_font_size_override("font_size", 17)
	instruction_label.modulate = Color("d0d9e4")
	top_bar.add_child(instruction_label)

	var info_panel := ColorRect.new()
	info_panel.color = Color(0.025, 0.04, 0.065, 0.90)
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	info_panel.position = Vector2(20.0, -198.0)
	info_panel.size = Vector2(322.0, 176.0)
	hud_root.add_child(info_panel)
	unit_info = Label.new()
	unit_info.position = Vector2(18.0, 15.0)
	unit_info.size = Vector2(290.0, 150.0)
	unit_info.add_theme_font_size_override("font_size", 18)
	unit_info.text = "No unit selected"
	info_panel.add_child(unit_info)

	var action_panel := HBoxContainer.new()
	action_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	action_panel.position = Vector2(-646.0, -78.0)
	action_panel.size = Vector2(626.0, 58.0)
	action_panel.add_theme_constant_override("separation", 8)
	hud_root.add_child(action_panel)
	attack_button = _make_button("ATTACK", action_panel)
	heal_button = _make_button("HEAL", action_panel)
	wait_button = _make_button("WAIT", action_panel)
	cancel_button = _make_button("CANCEL", action_panel)
	end_turn_button = _make_button("END TURN", action_panel)
	attack_button.pressed.connect(func() -> void: attack_pressed.emit())
	heal_button.pressed.connect(func() -> void: heal_pressed.emit())
	wait_button.pressed.connect(func() -> void: wait_pressed.emit())
	cancel_button.pressed.connect(func() -> void: cancel_pressed.emit())
	end_turn_button.pressed.connect(func() -> void: end_turn_pressed.emit())

	result_overlay = ColorRect.new()
	result_overlay.color = Color(0.01, 0.015, 0.025, 0.88)
	result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_overlay.visible = false
	result_overlay.add_to_group("interactive_ui")
	hud_root.add_child(result_overlay)
	var result_box := VBoxContainer.new()
	result_box.set_anchors_preset(Control.PRESET_CENTER)
	result_box.position = Vector2(-170.0, -95.0)
	result_box.size = Vector2(340.0, 190.0)
	result_box.alignment = BoxContainer.ALIGNMENT_CENTER
	result_box.add_theme_constant_override("separation", 14)
	result_overlay.add_child(result_box)
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 58)
	result_box.add_child(result_label)
	var restart_button := _make_button("RESTART BATTLE", result_box)
	var quit_button := _make_button("QUIT", result_box)
	restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	quit_button.pressed.connect(func() -> void: quit_pressed.emit())

	menu_overlay = ColorRect.new()
	menu_overlay.name = "PauseMenu"
	menu_overlay.color = Color(0.01, 0.015, 0.025, 0.91)
	menu_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_overlay.visible = false
	menu_overlay.add_to_group("interactive_ui")
	hud_root.add_child(menu_overlay)
	var menu_box := VBoxContainer.new()
	menu_box.set_anchors_preset(Control.PRESET_CENTER)
	menu_box.position = Vector2(-150.0, -145.0)
	menu_box.size = Vector2(300.0, 290.0)
	menu_box.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_box.add_theme_constant_override("separation", 12)
	menu_overlay.add_child(menu_box)
	var menu_title := Label.new()
	menu_title.text = "TACTICAL SLASH"
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title.add_theme_font_size_override("font_size", 31)
	menu_box.add_child(menu_title)
	var resume_button := _make_button("RESUME", menu_box)
	var fullscreen_button := _make_button("FULLSCREEN", menu_box)
	mute_button = _make_button("MUTE", menu_box)
	var menu_quit_button := _make_button("QUIT", menu_box)
	resume_button.pressed.connect(func() -> void: toggle_menu(false))
	fullscreen_button.pressed.connect(_toggle_fullscreen)
	mute_button.pressed.connect(_toggle_mute)
	menu_quit_button.pressed.connect(func() -> void:
		get_tree().paused = false
		quit_pressed.emit()
	)


func _make_button(label_text: String, parent: Control) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(116.0, 52.0)
	button.add_theme_font_size_override("font_size", 16)
	button.add_to_group("interactive_ui")
	parent.add_child(button)
	return button
