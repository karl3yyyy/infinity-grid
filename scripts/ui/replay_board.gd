class_name ReplayBoard
extends Control

const BOARD_SIZE: int = 5
const TEAM_COLORS: Array[Color] = [Color("3fa9ff"), Color("ff5a3c")]
const CELL_COLORS: Array[Color] = [Color("15252c"), Color("1c3038")]

var _snapshot: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(230.0, 230.0)


func show_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot
	queue_redraw()


func _draw() -> void:
	if _snapshot.is_empty():
		return
	var side := minf(size.x, size.y)
	var board_origin := (size - Vector2.ONE * side) * 0.5
	var cell_size := side / float(BOARD_SIZE)
	var tiles: Array = _snapshot.get("tiles", [])
	for row: int in range(BOARD_SIZE):
		for column: int in range(BOARD_SIZE):
			var index := row * BOARD_SIZE + column
			var square := Rect2(board_origin + Vector2(column, row) * cell_size, Vector2.ONE * cell_size)
			var tile_state := int(tiles[index]) if index < tiles.size() else 0
			var color := CELL_COLORS[(row + column) % CELL_COLORS.size()]
			if tile_state == 1:
				color = Color("744b21")
			elif tile_state == 2:
				color = Color("39191d")
			draw_rect(square, color)
			if tile_state == 1:
				draw_circle(square.get_center(), cell_size * 0.1, Color("ffc23a"))
			draw_rect(square, Color("73919b", 0.7), false, 1.0)
	_draw_last_move(board_origin, cell_size)
	for piece_value: Variant in _snapshot.get("pieces", []):
		var piece: Dictionary = piece_value
		var cell: Vector2i = piece.get("cell", Vector2i(-1, -1))
		if cell.x < 0 or cell.y < 0 or cell.x >= BOARD_SIZE or cell.y >= BOARD_SIZE:
			continue
		var center := board_origin + (Vector2(cell) + Vector2.ONE * 0.5) * cell_size
		var team := clampi(int(piece.get("team", 0)), 0, TEAM_COLORS.size() - 1)
		draw_circle(center, cell_size * 0.31, Color(TEAM_COLORS[team], 0.28))
		draw_circle(center, cell_size * 0.23, TEAM_COLORS[team])
		draw_string(
			TerminalTheme.font(), center + Vector2(-cell_size * 0.17, cell_size * 0.095),
			"K" if bool(piece.get("master", false)) else "E",
			HORIZONTAL_ALIGNMENT_CENTER, cell_size * 0.34, maxi(12, int(cell_size * 0.33)), Color.WHITE
		)


func _draw_last_move(board_origin: Vector2, cell_size: float) -> void:
	var action: Dictionary = _snapshot.get("action", {})
	var action_type := str(action.get("type", ""))
	if action_type not in ["move", "effect"]:
		return
	var coordinates: Array[String] = ["to"] if action_type == "effect" else ["from", "to"]
	for coordinate_name: String in coordinates:
		var coordinate: Vector2i = action.get(coordinate_name, Vector2i(-1, -1))
		if coordinate.x < 0 or coordinate.y < 0 or coordinate.x >= BOARD_SIZE or coordinate.y >= BOARD_SIZE:
			continue
		var square := Rect2(board_origin + Vector2(coordinate) * cell_size, Vector2.ONE * cell_size)
		var color := Color("ffc23a") if coordinate_name == "to" else Color("effff6")
		draw_rect(square.grow(-2.0), color, false, 3.0)
