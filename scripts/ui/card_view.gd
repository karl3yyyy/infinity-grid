class_name CardView
extends Button

## Movement card: the card name and a 5x5 diagram where the
## centre square is the moving figure and coloured squares are its targets.

const GRID_CELLS: int = 5

var card: MovementCard
## True when the card belongs to the side facing the camera from the far end;
## its diagram is rotated 180° so targets match the board on screen.
var rotated: bool = false
var accent_color: Color = Color("65bce8")
var is_selected: bool = false
var caption: String = ""
var dimmed: bool = false
## The 3D card raises the targets as light pillars; the flat face keeps a dim pad.
var pillar_mode: bool = false


func _init() -> void:
	text = ""
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	var empty := StyleBoxEmpty.new()
	for style_name: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(style_name, empty)
	add_to_group("interactive_ui")
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func show_card(new_card: MovementCard, is_rotated: bool, color: Color, selected: bool, card_caption: String = "") -> void:
	card = new_card
	rotated = is_rotated
	accent_color = color
	is_selected = selected
	caption = card_caption
	tooltip_text = "%s  ·  %s" % [card.card_name, card.category()] if card != null else ""
	queue_redraw()


const PANEL := Color(0.02, 0.035, 0.05, 0.92)
const AMBER := Color("ffc23a")


## Layout shared by the flat draw and the 3D pillars, so both agree on the grid.
static func layout_for(area: Rect2, lift: float, next_card: bool) -> Dictionary:
	var frame := area.grow(-5.0)
	frame.position.y += lift + 2.0
	var cut := clampf(frame.size.x * 0.09, 6.0, 16.0)
	var inner := frame.grow(-cut * 0.9)
	var title_size := int(clampf(inner.size.x * 0.2, 16.0, 36.0))
	var title_height := float(title_size) * 0.9
	var rule_y := inner.position.y + title_height + 3.0
	var tag_size := int(float(title_size) * 0.55)
	var tag_baseline := rule_y + float(tag_size) + 1.0
	rule_y += float(tag_size) + 2.0
	var caption_height := float(title_size) * 0.75 + 2.0 if next_card else 0.0
	var grid_space := Rect2(
		Vector2(inner.position.x, rule_y + 5.0),
		Vector2(inner.size.x, inner.end.y - rule_y - 5.0 - caption_height)
	)
	return {
		"frame": frame, "cut": cut, "inner": inner, "title_size": title_size,
		"title_height": title_height, "tag_size": tag_size, "tag_baseline": tag_baseline,
		"rule_y": rule_y, "grid_space": grid_space,
	}


## Top-left corner and cell size of the 5x5 move diagram inside a card of this size.
static func diagram_geometry(card_size: Vector2) -> Dictionary:
	var space: Rect2 = layout_for(Rect2(Vector2.ZERO, card_size), 0.0, false)["grid_space"]
	var cell := floorf(minf(space.size.x, space.size.y) / float(GRID_CELLS))
	var grid_size := cell * float(GRID_CELLS)
	return {"origin": space.position + (space.size - Vector2(grid_size, grid_size)) * 0.5, "cell": cell}


## Holographic data card: dark glass with cut corners, a neon border in the
## team colour, the name in terminal type and the move pattern as lit cells.
func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	if card == null or area.size.x < 24.0 or area.size.y < 24.0:
		return
	var lift := -6.0 if is_selected else 0.0
	var next_card := caption != ""
	var layout := layout_for(area, lift, next_card)
	var frame: Rect2 = layout["frame"]
	var cut: float = layout["cut"]
	var inner: Rect2 = layout["inner"]
	var title_size: int = layout["title_size"]
	var title_height: float = layout["title_height"]
	var color := AMBER if next_card else accent_color
	var outline := _cut_corners(frame, cut)

	if is_selected:
		for step: int in range(4):
			draw_polyline(_closed(_cut_corners(frame.grow(2.0 + step * 2.5), cut + step)), Color(color, 0.32 - step * 0.07), 3.0, true)
	draw_colored_polygon(outline, PANEL)
	# Faint scanlines across the glass.
	var y := frame.position.y + 2.0
	while y < frame.end.y - 2.0:
		draw_line(Vector2(frame.position.x + 3.0, y), Vector2(frame.end.x - 3.0, y), Color(color, 0.05), 1.0)
		y += 4.0
	draw_polyline(_closed(outline), color.lightened(0.15) if is_selected else color, 2.5 if is_selected else 1.8, true)

	var font := TerminalTheme.font()
	draw_string(font, Vector2(inner.position.x, inner.position.y + title_height * 0.8), card.card_name.to_upper(),
		HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, title_size, color.lightened(0.35))
	var rule_y: float = layout["rule_y"] - float(layout["tag_size"]) - 2.0
	draw_line(Vector2(inner.position.x, rule_y), Vector2(inner.end.x, rule_y), Color(color, 0.6), 1.0)
	draw_string(font, Vector2(inner.position.x, layout["tag_baseline"]), card.category(),
		HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, int(layout["tag_size"]), card.category_color())
	_draw_diagram(layout["grid_space"], color)
	if next_card:
		draw_string(font, Vector2(inner.position.x, inner.end.y), "> " + caption,
			HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, int(float(title_size) * 0.7), Color(color, 0.85))
	if dimmed:
		draw_colored_polygon(outline, Color(0.0, 0.0, 0.0, 0.45))


func _cut_corners(rect: Rect2, cut: float) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position + Vector2(cut, 0.0),
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.end.x, rect.end.y - cut),
		rect.end - Vector2(cut, 0.0),
		Vector2(rect.position.x, rect.end.y),
		rect.position + Vector2(0.0, cut),
	])


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var closed := points.duplicate()
	closed.append(points[0])
	return closed


## Move pattern: dim grid, the figure as a white cell, targets as lit cells.
func _draw_diagram(space: Rect2, color: Color) -> void:
	var cell := floorf(minf(space.size.x, space.size.y) / float(GRID_CELLS))
	if cell < 3.0:
		return
	var grid_size := cell * float(GRID_CELLS)
	var origin := space.position + (space.size - Vector2(grid_size, grid_size)) * 0.5
	var targets: Dictionary = {}
	for offset: Vector2i in card.offsets:
		targets[card.diagram_cell(offset, rotated)] = true
	for row: int in range(GRID_CELLS):
		for column: int in range(GRID_CELLS):
			var square := Rect2(origin + Vector2(column, row) * cell, Vector2(cell, cell))
			var coordinate := Vector2i(column, row)
			if coordinate == Vector2i(2, 2):
				draw_rect(square.grow(-2.0), Color("e8fff4"))
				draw_rect(square.grow(-cell * 0.32), Color("0a1018"))
			elif targets.has(coordinate) and pillar_mode:
				draw_rect(square.grow(-1.0), Color(color, 0.3))
				draw_rect(square.grow(-2.5), Color(color, 0.22))
			elif targets.has(coordinate):
				draw_rect(square.grow(-1.0), Color(color, 0.25))
				draw_rect(square.grow(-2.5), Color(color, 0.95))
				draw_rect(square.grow(-cell * 0.34), Color(1, 1, 1, 0.35))
			else:
				draw_rect(square.grow(-cell * 0.46), Color(color, 0.18))
	for index: int in range(GRID_CELLS + 1):
		var offset := float(index) * cell
		var line_color := Color(color, 0.5 if index == 0 or index == GRID_CELLS else 0.18)
		draw_line(origin + Vector2(offset, 0), origin + Vector2(offset, grid_size), line_color, 1.0)
		draw_line(origin + Vector2(0, offset), origin + Vector2(grid_size, offset), line_color, 1.0)
