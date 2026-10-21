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


func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	if card == null or area.size.x < 24.0 or area.size.y < 24.0:
		return
	var lift := -5.0 if is_selected else 0.0
	var frame := area.grow(-4.0)
	frame.position.y += lift + 2.0
	var radius := int(clampf(frame.size.x * 0.07, 6.0, 14.0))

	# Drop shadow and, when selected, a soft golden aura.
	draw_style_box(_rounded(Color(0, 0, 0, 0.5), radius), Rect2(frame.position + Vector2(0, 6), frame.size))
	if is_selected:
		for step: int in range(4):
			var aura := _rounded(Color(UITheme.GOLD, 0.22 - step * 0.05), radius + step * 3)
			draw_style_box(aura, frame.grow(3.0 + step * 3.0))

	# Gold outer frame, dark stone body.
	var gold := _rounded(UITheme.GOLD if not disabled or dimmed else UITheme.GOLD.darkened(0.25), radius)
	draw_style_box(gold, frame)
	var body_rect := frame.grow(-4.0)
	var body := _rounded(Color("221f31"), radius - 2)
	body.border_color = UITheme.GOLD_DARK
	body.set_border_width_all(1)
	if is_hovered() and not disabled:
		body.bg_color = Color("2d2942")
	draw_style_box(body, body_rect)
	# Team-coloured inner glow along the top edge.
	var top_glow := Rect2(body_rect.position + Vector2(4, 4), Vector2(body_rect.size.x - 8, body_rect.size.y * 0.32))
	draw_style_box(_rounded(Color(accent_color, 0.18), radius - 4), top_glow)

	var inner := body_rect.grow(-8.0)
	var title_size := int(clampf(inner.size.x * 0.12, 11.0, 22.0))
	var title_font := UITheme.title_font()
	var banner_height := float(title_size) + 10.0
	_draw_banner(Rect2(inner.position + Vector2(-2, 0), Vector2(inner.size.x + 4, banner_height)))
	draw_string(
		title_font,
		Vector2(inner.position.x, inner.position.y + banner_height * 0.5 + float(title_size) * 0.36),
		card.card_name.to_upper(),
		HORIZONTAL_ALIGNMENT_CENTER,
		inner.size.x,
		title_size,
		UITheme.GOLD_LIGHT
	)
	var caption_height := 0.0
	if not caption.is_empty():
		caption_height = float(title_size) * 0.85 + 4.0
	var grid_space := Rect2(
		inner.position + Vector2(0.0, banner_height + 6.0),
		Vector2(inner.size.x, inner.size.y - banner_height - 6.0 - caption_height)
	)
	_draw_diagram(grid_space)
	if not caption.is_empty():
		draw_string(
			title_font,
			Vector2(inner.position.x, inner.end.y - 1.0),
			caption,
			HORIZONTAL_ALIGNMENT_CENTER,
			inner.size.x,
			int(float(title_size) * 0.72),
			UITheme.GOLD
		)
	if dimmed:
		draw_style_box(_rounded(Color(0.02, 0.02, 0.06, 0.42), radius), frame)


func _draw_banner(rect: Rect2) -> void:
	var notch := rect.size.y * 0.35
	var ribbon := PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.position + Vector2(rect.size.x - notch, rect.size.y * 0.5),
		rect.position + Vector2(rect.size.x, rect.size.y),
		rect.position + Vector2(0, rect.size.y),
		rect.position + Vector2(notch, rect.size.y * 0.5),
	])
	draw_colored_polygon(ribbon, accent_color.darkened(0.55))
	var outline := ribbon.duplicate()
	outline.append(ribbon[0])
	draw_polyline(outline, UITheme.GOLD_DARK, 1.5, true)


func _draw_diagram(space: Rect2) -> void:
	var cell := floorf(minf(space.size.x, space.size.y) / float(GRID_CELLS))
	if cell < 3.0:
		return
	var grid_size := cell * float(GRID_CELLS)
	var origin := space.position + (space.size - Vector2(grid_size, grid_size)) * 0.5
	draw_rect(Rect2(origin, Vector2(grid_size, grid_size)).grow(2.0), UITheme.GOLD_DARK)
	var targets: Dictionary = {}
	for offset: Vector2i in card.offsets:
		targets[card.diagram_cell(offset, rotated)] = true
	for row: int in range(GRID_CELLS):
		for column: int in range(GRID_CELLS):
			var square := Rect2(origin + Vector2(column, row) * cell, Vector2(cell, cell)).grow(-1.0)
			var coordinate := Vector2i(column, row)
			var checker := (row + column) % 2 == 0
			draw_rect(square, Color("3a3650") if checker else Color("302d44"))
			if coordinate == Vector2i(2, 2):
				_draw_gem(square)
			elif targets.has(coordinate):
				draw_rect(square, accent_color)
				draw_rect(square.grow(-cell * 0.22), accent_color.lightened(0.45))


func _draw_gem(square: Rect2) -> void:
	var center := square.get_center()
	var half := square.size.x * 0.4
	var diamond := PackedVector2Array([
		center + Vector2(0, -half),
		center + Vector2(half, 0),
		center + Vector2(0, half),
		center + Vector2(-half, 0),
	])
	draw_colored_polygon(diamond, UITheme.GOLD)
	var inner := PackedVector2Array([
		center + Vector2(0, -half * 0.5),
		center + Vector2(half * 0.5, 0),
		center + Vector2(0, half * 0.5),
		center + Vector2(-half * 0.5, 0),
	])
	draw_colored_polygon(inner, UITheme.GOLD_LIGHT)


func _rounded(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(maxi(radius, 0))
	style.anti_aliasing = true
	return style
