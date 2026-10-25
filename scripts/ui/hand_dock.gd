class_name HandDock
extends RefCounted

## Where the card rows of a match sit. Portrait: the opponent's row in the top
## tray, the own row in the bottom tray. Landscape: opponent (and the extra
## hands of four-player mode) in a tray on the left, own cards on the right,
## so the board keeps the full height. Only moves nodes and sizes the places.

const OPPONENT_CARD_SCALE: float = 0.92

var left_tray: PanelContainer
var right_tray: PanelContainer
var landscape: bool = false

var _ui: GridBattleUI
var _top_box: Control
var _bottom_box: Control
var _left_box: VBoxContainer
var _right_box: VBoxContainer
var _placed_landscape: int = -1


func _init(ui: GridBattleUI, top_box: Control, bottom_box: Control) -> void:
	_ui = ui
	_top_box = top_box
	_bottom_box = bottom_box
	left_tray = _make_side_tray(true)
	right_tray = _make_side_tray(false)
	_left_box = left_tray.get_child(0)
	_right_box = right_tray.get_child(0)


func _make_side_tray(on_left: bool) -> PanelContainer:
	var tray := _ui._make_tray()
	tray.visible = false
	tray.anchor_left = 0.0 if on_left else 1.0
	tray.anchor_right = tray.anchor_left
	tray.anchor_top = 0.0
	tray.anchor_bottom = 1.0
	_ui.hud_column.add_child(tray)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	tray.add_child(box)
	return tray


## Moves rows if the mode changed and sizes the card places for the viewport.
func apply(is_landscape: bool, viewport_size: Vector2, column_width: float) -> void:
	landscape = is_landscape
	if _placed_landscape != int(landscape):
		_placed_landscape = int(landscape)
		_place_nodes()
	left_tray.visible = landscape
	right_tray.visible = landscape
	if landscape:
		_size_landscape(viewport_size)
	else:
		_size_portrait(column_width, viewport_size)


func _place_nodes() -> void:
	var opponent_title := _ui.hand_titles[1]
	var own_title := _ui.hand_titles[0]
	var opponent_row := _ui.hand_rows[1]
	var own_row := _ui.hand_rows[0]
	for node: Node in [opponent_title, own_title, opponent_row, own_row]:
		if node != null and node.get_parent() != null:
			node.get_parent().remove_child(node)
	for position: int in range(2):
		_order_row(position)
	if landscape:
		_left_box.add_child(opponent_title)
		_left_box.add_child(opponent_row)
		_right_box.add_child(own_title)
		_right_box.add_child(own_row)
	else:
		_top_box.add_child(opponent_row)
		_top_box.add_child(opponent_title)
		_bottom_box.add_child(own_title)
		_bottom_box.add_child(own_row)


## Side by side the opponent's row mirrors the order, stacked it reads top to bottom.
func _order_row(position: int) -> void:
	var row: BoxContainer = _ui.hand_rows[position]
	row.vertical = landscape
	var places: Array = _ui.hand_anchors[position]
	var next_place: Control = _ui.next_anchors[position]
	var ordered: Array = [places[0], places[1], next_place]
	if position == 1 and not landscape:
		ordered = [next_place, places[1], places[0]]
	for child: Node in row.get_children():
		row.remove_child(child)
	for place: Node in ordered:
		row.add_child(place)


func _size_portrait(column_width: float, viewport_size: Vector2) -> void:
	# Two hand cards plus a slightly smaller next card share one row.
	var usable := column_width - 24.0 - 20.0
	var card_width := clampf(usable / 3.25, 96.0, 240.0)
	var card_height := clampf(card_width * 1.12, 110.0, minf(290.0, viewport_size.y * 0.19))
	_size_places(card_width, card_height)


func _size_landscape(viewport_size: Vector2) -> void:
	var card_height := clampf(viewport_size.y * 0.19, 110.0, 240.0)
	var card_width := card_height / 1.12
	_size_places(card_width, card_height)
	left_tray.offset_left = 0.0
	left_tray.offset_right = left_tray.get_combined_minimum_size().x
	right_tray.offset_right = 0.0
	right_tray.offset_left = -right_tray.get_combined_minimum_size().x


## Top and bottom edge of the side trays: below the header, above the instruction.
func set_side_limits(top: float, bottom: float) -> void:
	for tray: PanelContainer in [left_tray, right_tray]:
		tray.offset_top = top
		tray.offset_bottom = bottom


func _size_places(card_width: float, card_height: float) -> void:
	for position: int in range(2):
		var factor := 1.0 if position == 0 else OPPONENT_CARD_SCALE
		for place: Control in _ui.hand_anchors[position]:
			place.custom_minimum_size = Vector2(card_width, card_height) * factor
		_ui.next_anchors[position].custom_minimum_size = Vector2(card_width * 0.8, card_height * 0.86) * factor
