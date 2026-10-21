class_name CardView
extends Button

## Onitama-style movement card: the card name and a 5x5 diagram where the
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
	tooltip_text = card.card_name if card != null else ""
	queue_redraw()


const INK := Color(0.16, 0.1, 0.06)
const TEAM_INK: Array[Color] = [Color("2c63a0"), Color("a8302a")]
const BANNER: Array[Color] = [Color("1f3b63"), Color("6e1c18")]


func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	if card == null or area.size.x < 24.0 or area.size.y < 24.0:
		return
	var lift := -6.0 if is_selected else 0.0
	var frame := area.grow(-4.0)
	frame.position.y += lift + 2.0
	var border := clampf(frame.size.x * 0.1, 9.0, 24.0)
	var team := 0 if accent_color.b > accent_color.r else 1
	var gold_card := accent_color.r > 0.7 and accent_color.g > 0.55 and accent_color.b < 0.4

	draw_style_box(_rounded(Color(0, 0, 0, 0.55), 10), Rect2(frame.position + Vector2(3, 8), frame.size))
	if is_selected:
		for step: int in range(4):
			draw_style_box(_rounded(Color(1.0, 0.78, 0.35, 0.24 - step * 0.05), 12 + step * 3), frame.grow(3.0 + step * 3.5))

	# Parchment face inside a dark wooden frame with iron corners.
	var parchment := WoodMaterials.tex("ui_parchment.png")
	var face := frame.grow(-border * 0.55)
	if parchment != null:
		draw_texture_rect(parchment, face, false)
	else:
		draw_rect(face, Color("e0c896"))
	var frame_texture := WoodMaterials.tex("ui_card_frame.png")
	if frame_texture != null:
		_draw_nine_patch(frame_texture, frame, 48.0, border * 1.45)

	var inner := frame.grow(-border - 3.0)
	var title_size := int(clampf(inner.size.x * 0.13, 11.0, 24.0))
	var title_font := UITheme.title_font()
	var banner_height := float(title_size) + 12.0
	var banner_color := Color("6b4a12") if gold_card else BANNER[team]
	_draw_banner(Rect2(Vector2(frame.position.x + border * 0.3, inner.position.y), Vector2(frame.size.x - border * 0.6, banner_height)), banner_color)
	draw_string(
		title_font,
		Vector2(inner.position.x, inner.position.y + banner_height * 0.5 + float(title_size) * 0.36),
		card.card_name.to_upper(),
		HORIZONTAL_ALIGNMENT_CENTER,
		inner.size.x,
		title_size,
		Color("f6e7c1")
	)
	var caption_height := 0.0
	if not caption.is_empty():
		caption_height = float(title_size) * 0.85 + 4.0
	var grid_space := Rect2(
		inner.position + Vector2(0.0, banner_height + 6.0),
		Vector2(inner.size.x, inner.size.y - banner_height - 6.0 - caption_height)
	)
	_draw_diagram(grid_space, Color("8a6418") if gold_card else TEAM_INK[team])
	if not caption.is_empty():
		draw_string(title_font, Vector2(inner.position.x, inner.end.y - 1.0), caption,
			HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, int(float(title_size) * 0.72), INK)
	if dimmed:
		draw_style_box(_rounded(Color(0.04, 0.02, 0.01, 0.38), 8), frame)


## Scales a 9-patch texture so its corners keep their shape on any card size.
func _draw_nine_patch(texture: Texture2D, rect: Rect2, source_margin: float, margin: float) -> void:
	var source_size := texture.get_size()
	var xs: Array[float] = [0.0, source_margin, source_size.x - source_margin, source_size.x]
	var ys: Array[float] = [0.0, source_margin, source_size.y - source_margin, source_size.y]
	var dx: Array[float] = [rect.position.x, rect.position.x + margin, rect.end.x - margin, rect.end.x]
	var dy: Array[float] = [rect.position.y, rect.position.y + margin, rect.end.y - margin, rect.end.y]
	for row: int in range(3):
		for column: int in range(3):
			if row == 1 and column == 1:
				continue
			var source := Rect2(xs[column], ys[row], xs[column + 1] - xs[column], ys[row + 1] - ys[row])
			var target := Rect2(dx[column], dy[row], dx[column + 1] - dx[column], dy[row + 1] - dy[row])
			draw_texture_rect_region(texture, target, source)


func _draw_banner(rect: Rect2, color: Color) -> void:
	var notch := rect.size.y * 0.35
	var ribbon := PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.position + Vector2(rect.size.x - notch, rect.size.y * 0.5),
		rect.position + Vector2(rect.size.x, rect.size.y),
		rect.position + Vector2(0, rect.size.y),
		rect.position + Vector2(notch, rect.size.y * 0.5),
	])
	draw_colored_polygon(ribbon, color)
	var shine := PackedVector2Array([
		rect.position + Vector2(notch, 2),
		rect.position + Vector2(rect.size.x - notch, 2),
		rect.position + Vector2(rect.size.x - notch, rect.size.y * 0.42),
		rect.position + Vector2(notch, rect.size.y * 0.42),
	])
	draw_colored_polygon(shine, Color(1, 1, 1, 0.08))
	var outline := ribbon.duplicate()
	outline.append(ribbon[0])
	draw_polyline(outline, Color("c9a050"), 1.5, true)


## Ink drawing on the parchment: grid lines, the figure and its targets.
func _draw_diagram(space: Rect2, ink: Color) -> void:
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
				draw_rect(square.grow(-1.5), Color(INK, 0.9))
				_draw_gem(square)
			elif targets.has(coordinate):
				draw_rect(square.grow(-1.5), Color(ink, 0.88))
				draw_rect(square.grow(-cell * 0.3), Color(1, 1, 1, 0.18))
	for index: int in range(GRID_CELLS + 1):
		var offset := float(index) * cell
		var width := 2.0 if index == 0 or index == GRID_CELLS else 1.0
		draw_line(origin + Vector2(offset, 0), origin + Vector2(offset, grid_size), Color(INK, 0.6), width)
		draw_line(origin + Vector2(0, offset), origin + Vector2(grid_size, offset), Color(INK, 0.6), width)


func _draw_gem(square: Rect2) -> void:
	var center := square.get_center()
	var half := square.size.x * 0.3
	var diamond := PackedVector2Array([
		center + Vector2(0, -half),
		center + Vector2(half, 0),
		center + Vector2(0, half),
		center + Vector2(-half, 0),
	])
	draw_colored_polygon(diamond, UITheme.GOLD)


func _rounded(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(maxi(radius, 0))
	style.anti_aliasing = true
	return style
