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
	if card == null:
		return
	if area.size.x < 8.0 or area.size.y < 8.0:
		return
	var lift := -4.0 if is_selected else 0.0
	var card_rect := area.grow(-3.0)
	card_rect.position.y += lift + 2.0
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0.0, 0.0, 0.0, 0.35)
	shadow.set_corner_radius_all(10)
	draw_style_box(shadow, Rect2(card_rect.position + Vector2(0.0, 4.0), card_rect.size))

	var body := StyleBoxFlat.new()
	body.bg_color = Color("f1e6cc") if not disabled else Color("d9cfb8")
	body.border_color = Color("f8d66d") if is_selected else accent_color.darkened(0.15)
	body.set_border_width_all(5 if is_selected else 3)
	body.set_corner_radius_all(10)
	if is_hovered() and not disabled:
		body.bg_color = body.bg_color.lightened(0.06)
	draw_style_box(body, card_rect)
	var font := get_theme_default_font()
	var inner := card_rect.grow(-10.0)
	var title_size := int(clampf(inner.size.x * 0.13, 12.0, 24.0))
	var title_height := float(title_size) + 6.0
	draw_string(
		font,
		Vector2(inner.position.x, inner.position.y + float(title_size)),
		card.card_name.to_upper(),
		HORIZONTAL_ALIGNMENT_CENTER,
		inner.size.x,
		title_size,
		Color("2b2a33")
	)
	var caption_height := 0.0
	if not caption.is_empty():
		caption_height = float(title_size) * 0.8 + 4.0
	var grid_space := Rect2(
		inner.position + Vector2(0.0, title_height),
		Vector2(inner.size.x, inner.size.y - title_height - caption_height)
	)
	var cell := floorf(minf(grid_space.size.x, grid_space.size.y) / float(GRID_CELLS))
	if cell < 3.0:
		return
	var grid_size := cell * float(GRID_CELLS)
	var origin := grid_space.position + (grid_space.size - Vector2(grid_size, grid_size)) * 0.5
	var targets: Dictionary = {}
	for offset: Vector2i in card.offsets:
		targets[card.diagram_cell(offset, rotated)] = true
	for row: int in range(GRID_CELLS):
		for column: int in range(GRID_CELLS):
			var square := Rect2(origin + Vector2(column, row) * cell, Vector2(cell, cell)).grow(-1.0)
			var coordinate := Vector2i(column, row)
			var fill := Color("e2d5b8")
			if coordinate == Vector2i(2, 2):
				fill = Color("2b2a33")
			elif targets.has(coordinate):
				fill = accent_color
			draw_rect(square, fill)
	draw_rect(Rect2(origin, Vector2(grid_size, grid_size)), Color("8d806a"), false, 1.5)
	if not caption.is_empty():
		draw_string(
			font,
			Vector2(inner.position.x, inner.end.y - 2.0),
			caption,
			HORIZONTAL_ALIGNMENT_CENTER,
			inner.size.x,
			int(float(title_size) * 0.75),
			Color("6b604d")
		)
	if dimmed:
		var veil := StyleBoxFlat.new()
		veil.bg_color = Color(0.05, 0.07, 0.1, 0.35)
		veil.set_corner_radius_all(10)
		draw_style_box(veil, card_rect)
