class_name BattleUI
extends CanvasLayer

signal attack_pressed
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
var wait_button: Button
var cancel_button: Button
var end_turn_button: Button
var result_overlay: ColorRect
var result_label: Label


func _ready() -> void:
	_build_ui()


func update_header(round_number: int, phase: String) -> void:
	round_label.text = "ROUND %02d" % round_number
	phase_label.text = phase


func set_instruction(text_value: String) -> void:
	instruction_label.text = text_value


func update_unit(unit: BattleUnit) -> void:
	if unit == null:
		unit_info.text = "No unit selected\n\nLeft-click a blue swordsman."
		return
	unit_info.text = (
		"%s\nHP  %d / %d\nATK  %d    DEF  %d\nMOVE  %d    RANGE  %d\nMoved: %s    Attacked: %s"
		% [
			unit.unit_name, unit.current_hp, unit.max_hp,
			unit.attack_power, unit.defense, unit.movement_range, unit.attack_range,
			"Yes" if unit.has_moved else "No",
			"Yes" if unit.has_attacked else "No",
		]
	)


func set_actions(can_attack: bool, can_wait: bool, can_cancel: bool, can_end_turn: bool = true) -> void:
	attack_button.disabled = not can_attack
	wait_button.disabled = not can_wait
	cancel_button.disabled = not can_cancel
	end_turn_button.disabled = not can_end_turn


func show_result(victory: bool) -> void:
	result_overlay.visible = true
	result_label.text = "VICTORY" if victory else "DEFEAT"
	result_label.modulate = Color("8ff7a5") if victory else Color("ff7b7b")


func _build_ui() -> void:
	var root := Control.new()
	root.name = "BattleHUD"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top_bar := ColorRect.new()
	top_bar.color = Color(0.025, 0.04, 0.065, 0.90)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 74.0
	root.add_child(top_bar)

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
	root.add_child(info_panel)
	unit_info = Label.new()
	unit_info.position = Vector2(18.0, 15.0)
	unit_info.size = Vector2(290.0, 150.0)
	unit_info.add_theme_font_size_override("font_size", 18)
	unit_info.text = "No unit selected"
	info_panel.add_child(unit_info)

	var action_panel := HBoxContainer.new()
	action_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	action_panel.position = Vector2(-535.0, -74.0)
	action_panel.size = Vector2(515.0, 54.0)
	action_panel.add_theme_constant_override("separation", 8)
	root.add_child(action_panel)
	attack_button = _make_button("ATTACK", action_panel)
	wait_button = _make_button("WAIT", action_panel)
	cancel_button = _make_button("CANCEL", action_panel)
	end_turn_button = _make_button("END TURN", action_panel)
	attack_button.pressed.connect(func() -> void: attack_pressed.emit())
	wait_button.pressed.connect(func() -> void: wait_pressed.emit())
	cancel_button.pressed.connect(func() -> void: cancel_pressed.emit())
	end_turn_button.pressed.connect(func() -> void: end_turn_pressed.emit())

	result_overlay = ColorRect.new()
	result_overlay.color = Color(0.01, 0.015, 0.025, 0.88)
	result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_overlay.visible = false
	root.add_child(result_overlay)
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


func _make_button(label_text: String, parent: Control) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(116.0, 48.0)
	button.add_theme_font_size_override("font_size", 16)
	parent.add_child(button)
	return button
