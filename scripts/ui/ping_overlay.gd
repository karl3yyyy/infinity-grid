class_name PingOverlay
extends CanvasLayer

## Full-screen terminal panel for the Node Ping, kept apart from the board: it
## slides in before the match, shows a free square to tap, the incoming signal
## and the starter choice, then slides out again. Render and input only; the
## rules stay in PingPhase. Positions are 0..1 across the square.

signal _spot_chosen(spot: Vector2)
signal _choice_made(index: int)

const SLIDE_SECONDS: float = 0.3

var _root: Control
var _panel: PanelContainer
var _info: Label
var _arena: PingArena
var _choice_row: HBoxContainer
var _choice_open: bool = false


func _init() -> void:
	layer = 40


## Builds the panel off screen and slides it up over the whole view.
func open() -> void:
	var view := get_viewport().get_visible_rect().size
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = TerminalTheme.theme()
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.color = Color(TerminalTheme.BACKGROUND, 0.96)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(backdrop)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0, 0, 0, 0)
	frame.border_color = TerminalTheme.GREEN
	frame.set_border_width_all(3)
	frame.set_content_margin_all(20.0)
	_panel.add_theme_stylebox_override("panel", frame)
	_panel.offset_left = 14.0
	_panel.offset_top = 14.0
	_panel.offset_right = -14.0
	_panel.offset_bottom = -14.0
	_root.add_child(_panel)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	_panel.add_child(column)

	var title := _label("NODE PING", 64, TerminalTheme.GREEN_BRIGHT)
	column.add_child(title)
	_info = _label("", 30, TerminalTheme.GREEN)
	_info.custom_minimum_size.y = 130.0
	column.add_child(_info)

	var side := clampf(minf(view.x - 100.0, view.y - 480.0), 280.0, 900.0)
	_arena = PingArena.new()
	_arena.custom_minimum_size = Vector2(side, side)
	_arena.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_arena.spot_tapped.connect(_on_spot_tapped)
	column.add_child(_arena)

	column.add_child(_label("Jeder Pixel zählt: wer näher am Signal liegt, gewinnt.", 24, TerminalTheme.GREEN_DIM))
	_choice_row = HBoxContainer.new()
	_choice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_choice_row.add_theme_constant_override("separation", 24)
	column.add_child(_choice_row)

	_root.position.y = view.y
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_root, "position:y", 0.0, SLIDE_SECONDS)
	MenuMotion.type_in(title, 0.5)
	await tween.finished


func close() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_root, "position:y", -get_viewport().get_visible_rect().size.y, SLIDE_SECONDS)
	await tween.finished
	queue_free()


func set_text(text: String) -> void:
	_info.text = text


## Waits until the player taps somewhere on the free square.
func ask_pick(text: String) -> Vector2:
	set_text(text)
	_arena.clear()
	_arena.accepting = true
	return await _spot_chosen


func mark(spot: Vector2, color: Color, text: String) -> void:
	_arena.add_mark(spot, color, text)


## True once the panel was built (open() was called).
func is_open() -> bool:
	return _root != null


## Shows the picks, then the signal hitting, then who was how far away. Two-player
## matches use the team colours; with `colors` and `labels` any number of picks.
func reveal(picks: Array, signal_spot: Vector2, colors: Array = [], labels: Array = []) -> void:
	_arena.clear()
	for index: int in range(picks.size() if not colors.is_empty() else 2):
		var color: Color = colors[index] if not colors.is_empty() else GridBattleUI.TEAM_COLORS[index]
		_arena.add_mark(picks[index], color, str(labels[index]) if not labels.is_empty() else str(index + 1))
	await get_tree().create_timer(0.4).timeout
	SoundBoard.play("signal")
	_arena.signal_spot = signal_spot
	var flash := create_tween()
	for blink: int in range(3):
		flash.tween_callback(_arena.set_signal_bright.bind(true))
		flash.tween_interval(0.08)
		flash.tween_callback(_arena.set_signal_bright.bind(false))
		flash.tween_interval(0.08)
	flash.tween_callback(_arena.show_distances)
	var shake := create_tween()
	for step: int in range(6):
		shake.tween_property(_panel, "position:x", 8.0 if step % 2 == 0 else -8.0, 0.04)
	shake.tween_property(_panel, "position:x", 0.0, 0.04)
	await flash.finished


## Two buttons; returns 0 or 1. Without an answer the first one counts.
func ask_choice(text: String, first: String, second: String, seconds: float) -> int:
	set_text(text)
	for child: Node in _choice_row.get_children():
		child.queue_free()
	for index: int in range(2):
		var button := Button.new()
		button.text = first if index == 0 else second
		button.custom_minimum_size = Vector2(300.0, 72.0)
		button.add_theme_font_size_override("font_size", 34)
		button.pressed.connect(_finish_choice.bind(index))
		_choice_row.add_child(button)
	_choice_open = true
	get_tree().create_timer(seconds).timeout.connect(_finish_choice.bind(0))
	var index: int = await _choice_made
	for child: Node in _choice_row.get_children():
		child.queue_free()
	return index


func _finish_choice(index: int) -> void:
	if _choice_open:
		_choice_open = false
		_choice_made.emit(index)


func _on_spot_tapped(spot: Vector2) -> void:
	SoundBoard.play("select")
	_spot_chosen.emit(spot)


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
