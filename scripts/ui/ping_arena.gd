class_name PingArena
extends Control

## The free square of the Node Ping: no cells, a tap lands exactly where it
## is. Draws the picks, the signal and, at the end, a line from each pick to
## the signal so even a hair's difference is visible.

signal spot_tapped(spot: Vector2)

var accepting: bool = false
var signal_spot: Vector2 = Vector2(-1.0, -1.0)

var _marks: Array[Dictionary] = []
var _signal_bright: bool = false
var _distances: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func clear() -> void:
	_marks.clear()
	signal_spot = Vector2(-1.0, -1.0)
	_distances = false
	queue_redraw()


func add_mark(spot: Vector2, color: Color, text: String) -> void:
	_marks.append({"spot": spot, "color": color, "text": text})
	queue_redraw()


func set_signal_bright(bright: bool) -> void:
	_signal_bright = bright
	queue_redraw()


func show_distances() -> void:
	_signal_bright = false
	_distances = true
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not accepting:
		return
	# Touch arrives as screen touches (the project does not emulate the mouse from touch).
	var position := Vector2(-1.0, -1.0)
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		position = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		position = (event as InputEventMouseButton).position
	if position.x < 0.0:
		return
	accepting = false
	accept_event()
	var spot := position / size
	spot_tapped.emit(Vector2(clampf(spot.x, 0.0, 1.0), clampf(spot.y, 0.0, 1.0)))


func _draw() -> void:
	var font := TerminalTheme.font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(TerminalTheme.GREEN, 0.05))
	draw_rect(Rect2(Vector2.ZERO, size), TerminalTheme.GREEN_DIM, false, 3.0)
	# Corner brackets only; nothing that looks like cells.
	var arm := size.x * 0.06
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var point := corner * size
		var direction := Vector2(1.0 - 2.0 * corner.x, 1.0 - 2.0 * corner.y)
		draw_line(point, point + Vector2(arm * direction.x, 0.0), TerminalTheme.GREEN, 4.0)
		draw_line(point, point + Vector2(0.0, arm * direction.y), TerminalTheme.GREEN, 4.0)
	if signal_spot.x >= 0.0 and _distances:
		for mark: Dictionary in _marks:
			draw_line((mark["spot"] as Vector2) * size, signal_spot * size, Color(mark["color"], 0.8), 3.0)
	for mark: Dictionary in _marks:
		var point := (mark["spot"] as Vector2) * size
		var color := mark["color"] as Color
		draw_circle(point, 18.0, Color(color, 0.35))
		draw_arc(point, 18.0, 0.0, TAU, 32, color, 3.0)
		draw_string(font, point + Vector2(-6.0, 9.0), str(mark["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30, color.lightened(0.5))
	if signal_spot.x >= 0.0:
		var hit := signal_spot * size
		var signal_color := Color.WHITE if _signal_bright else TerminalTheme.GREEN_BRIGHT
		draw_circle(hit, 12.0, signal_color)
		draw_arc(hit, 26.0, 0.0, TAU, 32, signal_color, 3.0)
