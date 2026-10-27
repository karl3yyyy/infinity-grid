class_name MenuMotion
extends RefCounted

## Movement for the terminal menu: falling code behind everything, a scan bar
## sweeping down, page titles typing themselves and entries flickering in one
## after another.

const ENTRY_DELAY: float = 0.045


## Title text types out like a terminal command.
static func type_in(label: Label, duration: float = 0.35) -> void:
	if AccessibilitySettings.reduced_motion():
		label.visible_ratio = 1.0
		return
	label.visible_ratio = 0.0
	label.create_tween().tween_property(label, "visible_ratio", 1.0, duration)


## An entry fades and stretches in, staggered by its position in the list.
## Containers own position and size but not scale, so the motion uses scale.
static func enter(control: Control, order: int) -> void:
	if AccessibilitySettings.reduced_motion():
		control.modulate.a = 1.0
		control.scale = Vector2.ONE
		return
	control.modulate.a = 0.0
	control.scale = Vector2(0.92, 1.0)
	var tween := control.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, 0.22).set_delay(order * ENTRY_DELAY)
	tween.tween_property(control, "scale", Vector2.ONE, 0.28).set_delay(order * ENTRY_DELAY)
	# A short flicker, like a phosphor screen catching the line.
	tween.chain().tween_property(control, "modulate:a", 0.55, 0.04)
	tween.chain().tween_property(control, "modulate:a", 1.0, 0.06)


## Columns of falling characters, dim, behind the menu.
class CodeRain:
	extends Control

	const GLYPHS := "01ABCDEF<>/\\#$%&*+=?"
	const COLUMN_WIDTH: float = 22.0
	const FONT_SIZE: int = 22

	var _heads: PackedFloat32Array = []
	var _speeds: PackedFloat32Array = []
	var _lengths: PackedInt32Array = []
	var _seed: int = 0
	var _redraw_wait: float = 0.0
	var _font: Font

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = TerminalTheme.font()
		resized.connect(_layout)
		_layout()

	func _layout() -> void:
		var columns := maxi(1, int(size.x / COLUMN_WIDTH))
		_heads.resize(columns)
		_speeds.resize(columns)
		_lengths.resize(columns)
		for column: int in range(columns):
			_heads[column] = randf_range(-size.y, size.y)
			_speeds[column] = randf_range(40.0, 140.0)
			_lengths[column] = randi_range(6, 18)

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		for column: int in range(_heads.size()):
			_heads[column] += _speeds[column] * delta
			if _heads[column] - _lengths[column] * FONT_SIZE > size.y:
				_heads[column] = randf_range(-200.0, 0.0)
				_speeds[column] = randf_range(40.0, 140.0)
		# Characters change a few times a second; drawing every frame is not needed.
		_redraw_wait -= delta
		if _redraw_wait <= 0.0:
			_redraw_wait = 1.0 / 20.0
			_seed += 1
			queue_redraw()

	func _draw() -> void:
		for column: int in range(_heads.size()):
			var x := column * COLUMN_WIDTH + 4.0
			for step: int in range(_lengths[column]):
				var y := _heads[column] - step * FONT_SIZE
				if y < 0.0 or y > size.y + FONT_SIZE:
					continue
				var glyph := GLYPHS[(column * 7 + step * 13 + _seed / (3 + column % 4)) % GLYPHS.length()]
				var fade := 1.0 - float(step) / float(_lengths[column])
				var color := TerminalTheme.GREEN_BRIGHT if step == 0 else TerminalTheme.GREEN
				draw_string(_font, Vector2(x, y), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(color, 0.16 * fade + (0.1 if step == 0 else 0.0)))


## A soft bright band sweeping down the screen every few seconds.
class ScanBar:
	extends ColorRect

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		color = Color(TerminalTheme.GREEN, 0.05)
		_sweep()

	func _sweep() -> void:
		var parent_height := (get_parent() as Control).size.y if get_parent() is Control else 1280.0
		size = Vector2((get_parent() as Control).size.x if get_parent() is Control else 720.0, 70.0)
		position = Vector2(0.0, -80.0)
		var tween := create_tween()
		tween.tween_property(self, "position:y", parent_height + 10.0, 2.6).set_trans(Tween.TRANS_SINE)
		tween.tween_interval(randf_range(3.0, 6.0))
		tween.tween_callback(_sweep)
