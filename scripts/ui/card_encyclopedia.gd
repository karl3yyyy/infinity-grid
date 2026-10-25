class_name CardEncyclopedia
extends VBoxContainer

const CardViewScript := preload("res://scripts/ui/card_view.gd")
const DemoBoardScript := preload("res://scripts/ui/card_demo_board.gd")

var _cards: Array[MovementCard] = []
var _views: Dictionary = {}
var _selected: MovementCard
var _title: Label
var _description: Label
var _origin_label: Label
var _team_button: Button
var _demo_board: CardDemoBoard
var _team_id: int = 0


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	add_child(_make_label("ANTIPPE EINE KARTE; TIPPE IM BRETT AUF EIN STARTFELD."))
	var card_scroll := ScrollContainer.new()
	card_scroll.custom_minimum_size.y = 210.0
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(card_scroll)
	var card_grid := GridContainer.new()
	card_grid.columns = 3
	card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_grid.add_theme_constant_override("h_separation", 6)
	card_grid.add_theme_constant_override("v_separation", 6)
	card_scroll.add_child(card_grid)
	var width := maxf(86.0, (get_viewport_rect().size.x - 100.0) / 3.0)
	for card: MovementCard in _cards:
		var view: CardView = CardViewScript.new()
		view.custom_minimum_size = Vector2(width, width * 1.08)
		view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		view.show_card(card, false, Color("3fa9ff"), false)
		view.pressed.connect(_select_card.bind(card))
		card_grid.add_child(view)
		_views[card.card_name] = view
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 3)
	add_child(detail)
	_title = _make_label("")
	_title.add_theme_font_size_override("font_size", 30)
	_title.modulate = TerminalTheme.GREEN_BRIGHT
	detail.add_child(_title)
	_description = _make_label("")
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.custom_minimum_size.y = 44.0
	detail.add_child(_description)
	var demo_header := HBoxContainer.new()
	detail.add_child(demo_header)
	_origin_label = _make_label("FIGUR: FELD 3, 3")
	_origin_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	demo_header.add_child(_origin_label)
	_team_button = Button.new()
	_team_button.text = "SEITE: 1"
	_team_button.pressed.connect(_toggle_team)
	demo_header.add_child(_team_button)
	_demo_board = DemoBoardScript.new()
	_demo_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_demo_board.custom_minimum_size = Vector2(220.0, 220.0)
	_demo_board.origin_changed.connect(_update_origin_label)
	detail.add_child(_demo_board)
	_select_card(_cards[0] if not _cards.is_empty() else null)


func _init(cards: Array[MovementCard] = []) -> void:
	_cards.assign(cards)


func _select_card(card: MovementCard) -> void:
	if card == null or not is_instance_valid(_title):
		return
	_selected = card
	for name: String in _views:
		var view: CardView = _views[name]
		view.show_card(view.card, false, Color("3fa9ff"), view.card == _selected)
	_title.text = "%s  ·  %s" % [card.card_name.to_upper(), card.category()]
	_description.text = card.description()
	_demo_board.show_card(card, _team_id)


func _toggle_team() -> void:
	_team_id = 1 - _team_id
	_team_button.text = "SEITE: %d" % (_team_id + 1)
	_demo_board.set_viewing_team(_team_id)


func _update_origin_label(coordinate: Vector2i) -> void:
	_origin_label.text = "FIGUR: FELD %d, %d" % [coordinate.x + 1, coordinate.y + 1]


func _make_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 22)
	return label
