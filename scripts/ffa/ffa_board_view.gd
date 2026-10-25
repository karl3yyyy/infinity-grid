class_name FfaBoardView
extends Control

## Flat board of the four-player mode. Draws what FfaRules says; clicks are
## reported as cells and nothing else.

signal cell_pressed(cell: Vector2i)

const PLAYER_COLORS: Array[Color] = [Color("3a8fe7"), Color("6ee65a"), Color("e75a4a"), Color("ffc23a")]
const RUIN_COLOR := Color("6b7480")
const TILE := Color("14231f")
const TILE_ALT := Color("1a2c27")
const WARNED := Color("ffb02e")
const COLLAPSED := Color("3a0d12")

var rules: FfaRules
var selected: Vector2i = Vector2i(-1, -1)
var targets: Array[Vector2i] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func _square() -> Rect2:
	var side := minf(size.x, size.y)
	return Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))


func cell_at(point: Vector2) -> Vector2i:
	var square := _square()
	var cell_size := square.size.x / float(FfaRules.SIZE)
	var local := (point - square.position) / cell_size
	return Vector2i(floori(local.x), floori(local.y))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var cell := cell_at((event as InputEventMouseButton).position)
		if cell.x >= 0 and cell.y >= 0 and cell.x < FfaRules.SIZE and cell.y < FfaRules.SIZE:
			cell_pressed.emit(cell)
			accept_event()


func _draw() -> void:
	if rules == null:
		return
	var square := _square()
	var cell_size := square.size.x / float(FfaRules.SIZE)
	var font := TerminalTheme.font()
	for y: int in range(FfaRules.SIZE):
		for x: int in range(FfaRules.SIZE):
			var cell := Vector2i(x, y)
			var rect := Rect2(square.position + Vector2(x, y) * cell_size, Vector2(cell_size, cell_size))
			var color := TILE if (x + y) % 2 == 0 else TILE_ALT
			if rules.tiles.collapsed.has(cell):
				color = COLLAPSED
			elif rules.tiles.warned.has(cell):
				color = WARNED.darkened(0.45)
			draw_rect(rect, color)
			draw_rect(rect, Color(1, 1, 1, 0.06), false, 1.0)
			if rules.tiles.warned.has(cell):
				draw_rect(rect.grow(-2.0), WARNED, false, 2.0)
	_draw_start_sides(square, cell_size)
	for cell: Vector2i in rules.pieces.keys():
		_draw_piece(cell, rules.pieces[cell], square.position + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size, cell_size, font)
	for cell: Vector2i in targets:
		var center := square.position + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size
		var capture := rules.pieces.has(cell)
		draw_arc(center, cell_size * 0.4, 0.0, TAU, 24, Color("ff4a3d") if capture else Color("3fb8ff"), 3.0, true)
		if not capture:
			draw_circle(center, cell_size * 0.12, Color("3fb8ff"))
	if selected.x >= 0:
		draw_rect(Rect2(square.position + Vector2(selected) * cell_size, Vector2(cell_size, cell_size)).grow(-1.0), Color("7ff3ff"), false, 3.0)


## Coloured strips mark which edge belongs to whom.
func _draw_start_sides(square: Rect2, cell_size: float) -> void:
	var thickness := maxf(cell_size * 0.12, 3.0)
	for player: int in range(FfaRules.PLAYERS):
		var color := PLAYER_COLORS[player]
		if not rules.alive[player]:
			color = RUIN_COLOR
		var rect: Rect2
		match player:
			0:
				rect = Rect2(square.position + Vector2(cell_size * 2.0, square.size.y - thickness), Vector2(cell_size * 5.0, thickness))
			1:
				rect = Rect2(square.position + Vector2(0.0, cell_size * 2.0), Vector2(thickness, cell_size * 5.0))
			2:
				rect = Rect2(square.position + Vector2(cell_size * 2.0, 0.0), Vector2(cell_size * 5.0, thickness))
			_:
				rect = Rect2(square.position + Vector2(square.size.x - thickness, cell_size * 2.0), Vector2(thickness, cell_size * 5.0))
		draw_rect(rect, color)


func _draw_piece(_cell: Vector2i, piece: Dictionary, center: Vector2, cell_size: float, font: Font) -> void:
	var owner_id := int(piece["owner"])
	var color := RUIN_COLOR if owner_id < 0 else PLAYER_COLORS[owner_id]
	var radius := cell_size * (0.36 if bool(piece["master"]) else 0.28)
	draw_circle(center, radius, color.darkened(0.35))
	draw_circle(center, radius * 0.78, color)
	if bool(piece["master"]):
		draw_arc(center, radius * 1.12, 0.0, TAU, 24, Color("ffffff"), 2.0, true)
		draw_string(font, center + Vector2(-radius, radius * 0.35), "K", HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, int(radius * 1.4), Color("071006"))
