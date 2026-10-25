class_name FfaSeatStrip
extends HBoxContainer

## Finite Grid: the hands of the three other players, in the order they sit
## around the board as seen from the camera (left, opposite, right). Each
## diagram is turned to the way that player's side faces.

const CARD_SIZE := Vector2(74.0, 104.0)

var _labels: Array[Label] = []
var _cards: Array[Array] = []


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 12)
	for _group: int in range(3):
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 2)
		add_child(column)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		column.add_child(label)
		_labels.append(label)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		column.add_child(row)
		var views: Array[CardView] = []
		for _slot: int in range(2):
			var view := CardView.new()
			view.custom_minimum_size = CARD_SIZE
			view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(view)
			views.append(view)
		_cards.append(views)


## names: display name per seat. view: the seat the camera looks from.
func show_seats(rules: FfaRules, names: Array[String], view: int) -> void:
	for group: int in range(3):
		var seat := (view + 1 + group) % FfaRules.PLAYERS
		var color: Color = FfaFloor.SEAT_COLORS[seat]
		var alive := rules.alive[seat]
		_labels[group].text = names[seat] if alive else "%s  RAUS" % names[seat]
		_labels[group].add_theme_color_override("font_color", color.lightened(0.25) if alive else Color("6b7480"))
		for slot: int in range(2):
			var card_view: CardView = _cards[group][slot]
			card_view.quarter_turns = posmod(seat - view, FfaRules.PLAYERS)
			card_view.dimmed = not alive or seat != rules.current
			card_view.show_card(rules.hands[seat][slot], false, color, false)
