class_name CardDemoBoard
extends Control

signal origin_changed(coordinate: Vector2i)

const BOARD_SIZE: int = 5
const CELL_COLORS: Array[Color] = [Color("14242b"), Color("1b3038")]
const TARGET_COLOR := Color("53c8ff")

var card: MovementCard
var team_id: int = 0
var origin := Vector2i(2, 2)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(220.0, 220.0)
	queue_redraw()


func show_card(new_card: MovementCard, viewing_team: int = 0) -> void:
	card = new_card
	team_id = viewing_team
	queue_redraw()


func set_viewing_team(viewing_team: int) -> void:
	team_id = viewing_team
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var pointer := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pointer = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pointer = event.position
	else:
		return
	var board := _board_rect()
	if not board.has_point(pointer):
		return
	var cell_size := board.size.x / float(BOARD_SIZE)
	origin = Vector2i(
		clampi(floori((pointer.x - board.position.x) / cell_size), 0, BOARD_SIZE - 1),
		clampi(floori((pointer.y - board.position.y) / cell_size), 0, BOARD_SIZE - 1)
	)
	origin_changed.emit(origin)
	queue_redraw()
	accept_event()


func _board_rect() -> Rect2:
	var side := minf(size.x, size.y)
	return Rect2((size - Vector2.ONE * side) * 0.5, Vector2.ONE * side)


func _draw() -> void:
	if card == null:
		return
	var board := _board_rect()
	var cell_size := board.size.x / float(BOARD_SIZE)
	var targets: Array[Vector2i] = card.destinations(origin, team_id, BOARD_SIZE)
	for row: int in range(BOARD_SIZE):
		for column: int in range(BOARD_SIZE):
			var coordinate := Vector2i(column, row)
			var square := Rect2(board.position + Vector2(column, row) * cell_size, Vector2.ONE * cell_size)
			draw_rect(square, CELL_COLORS[(column + row) % CELL_COLORS.size()])
			if coordinate == origin:
				draw_circle(square.get_center(), cell_size * 0.28, Color("effff6"))
				draw_circle(square.get_center(), cell_size * 0.18, Color("10202a"))
				draw_string(TerminalTheme.font(), Vector2(square.position.x, square.end.y - 4.0), "DU",
					HORIZONTAL_ALIGNMENT_CENTER, square.size.x, maxi(10, int(cell_size * 0.24)), Color("effff6"))
			elif coordinate in targets:
				draw_circle(square.get_center(), cell_size * 0.29, Color(TARGET_COLOR, 0.28))
				draw_circle(square.get_center(), cell_size * 0.2, TARGET_COLOR)
				draw_circle(square.get_center(), cell_size * 0.1, Color.WHITE)
			draw_rect(square, Color("73919b"), false, 1.0)
	if origin.x == 0 and Vector2i(BOARD_SIZE - 1, origin.y) in targets:
		_draw_wrap_arrow(board.position + Vector2(0.0, (float(origin.y) + 0.5) * cell_size), true, cell_size)
	elif origin.x == BOARD_SIZE - 1 and Vector2i(0, origin.y) in targets:
		_draw_wrap_arrow(board.position + Vector2(board.size.x, (float(origin.y) + 0.5) * cell_size), false, cell_size)


func _draw_wrap_arrow(edge: Vector2, points_left: bool, cell_size: float) -> void:
	var direction := -1.0 if points_left else 1.0
	draw_line(edge, edge + Vector2(direction * cell_size * 0.32, 0.0), Color("ffc23a"), 3.0)
	draw_circle(edge + Vector2(direction * cell_size * 0.32, 0.0), 3.0, Color("ffc23a"))
