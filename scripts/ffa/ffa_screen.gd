class_name FfaScreen
extends Control

## Four-player free-for-all: owns the match flow (humans tap, bots answer after
## a short pause) around FfaRules and shows it with FfaBoardView and CardViews.

signal closed

const BotScript := preload("res://scripts/ffa/ffa_bot.gd")

var rules: FfaRules
var bot_delay: float = 0.6
var _is_human: Array[bool] = [false, false, false, false]
var _shifting_tiles: bool = false
var _humans: int = 1
var _bot: FfaBot
var _selected: Vector2i = Vector2i(-1, -1)
var _slot: int = -1
var _must_pass: bool = false
var _busy: bool = false
var _gone: bool = false
var _notice: String = ""

var _board: FfaBoardView
var _header: Label
var _status: Array[Label] = []
var _instruction: Label
var _hand: Array[CardView] = []
var _pass_view: CardView
var _result_panel: PanelContainer
var _result_label: Label


func _ready() -> void:
	theme = TerminalTheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _exit_tree() -> void:
	_gone = true


## humans: 0 (bots only, for tests), 1, 2 (opposite seats) or 4.
func start(humans: int, shifting_tiles: bool) -> void:
	_humans = humans
	_shifting_tiles = shifting_tiles
	var seats: Array = {0: [], 1: [0], 2: [0, 2], 4: [0, 1, 2, 3]}.get(humans, [0])
	for seat: int in range(FfaRules.PLAYERS):
		_is_human[seat] = seat in seats
	rules = FfaRules.new()
	rules.setup(shifting_tiles)
	_bot = BotScript.new()
	_board.rules = rules
	_result_panel.visible = false
	_notice = ""
	_begin_turn()


func _build() -> void:
	var background := ColorRect.new()
	background.color = TerminalTheme.BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	_header = Label.new()
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_theme_font_size_override("font_size", 30)
	_header.modulate = TerminalTheme.GREEN_BRIGHT
	top.add_child(_header)
	var menu_button := Button.new()
	menu_button.text = "MENÜ"
	menu_button.add_theme_font_size_override("font_size", 30)
	menu_button.pressed.connect(func() -> void: closed.emit())
	top.add_child(menu_button)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 12)
	column.add_child(status_row)
	for seat: int in range(FfaRules.PLAYERS):
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 24)
		status_row.add_child(label)
		_status.append(label)
	_board = FfaBoardView.new()
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.custom_minimum_size = Vector2(300, 300)
	_board.cell_pressed.connect(_on_cell_pressed)
	column.add_child(_board)
	_instruction = Label.new()
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instruction.custom_minimum_size.y = 56.0
	_instruction.add_theme_font_size_override("font_size", 26)
	_instruction.modulate = TerminalTheme.GREEN_BRIGHT
	column.add_child(_instruction)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 10)
	cards.custom_minimum_size.y = 170.0
	column.add_child(cards)
	for slot: int in range(2):
		var view := CardView.new()
		view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		view.pressed.connect(_on_card_pressed.bind(slot))
		cards.add_child(view)
		_hand.append(view)
	_pass_view = CardView.new()
	_pass_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pass_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cards.add_child(_pass_view)
	_build_result_panel()


func _build_result_panel() -> void:
	_result_panel = PanelContainer.new()
	_result_panel.set_anchors_preset(Control.PRESET_CENTER)
	_result_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_result_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_result_panel.visible = false
	add_child(_result_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_result_panel.add_child(box)
	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 44)
	box.add_child(_result_label)
	var again := Button.new()
	again.text = "NOCHMAL"
	again.add_theme_font_size_override("font_size", 34)
	again.pressed.connect(func() -> void: start(_humans, _shifting_tiles))
	box.add_child(again)
	var leave := Button.new()
	leave.text = "MENÜ"
	leave.add_theme_font_size_override("font_size", 34)
	leave.pressed.connect(func() -> void: closed.emit())
	box.add_child(leave)


func _seat_name(seat: int) -> String:
	return ("SPIELER %d" if _is_human[seat] else "BOT %d") % (seat + 1)


func _begin_turn() -> void:
	_selected = Vector2i(-1, -1)
	_slot = -1
	_must_pass = rules.legal_moves(rules.current).is_empty()
	_refresh()
	if _is_human[rules.current]:
		_instruction.text = (_notice + " " if _notice != "" else "") + (
			"Keine Figur kann ziehen. Tippe auf eine Karte, um sie abzugeben." if _must_pass
			else "%s: Wähle eine Karte und eine Figur." % _seat_name(rules.current))
	else:
		_instruction.text = (_notice + " " if _notice != "" else "") + "%s denkt nach ..." % _seat_name(rules.current)
		_run_bot()


func _run_bot() -> void:
	_busy = true
	await get_tree().create_timer(bot_delay).timeout
	if _gone or rules.winner != FfaRules.RUNNING:
		return
	var choice := _bot.choose_move(rules, rules.current)
	if choice.has("pass"):
		rules.pass_turn(int(choice["slot"]))
	else:
		rules.apply_move(choice["from"], int(choice["slot"]), choice["to"])
	_busy = false
	_after_turn()


func _after_turn() -> void:
	var parts: PackedStringArray = []
	for seat: int in rules.last_events["eliminated"]:
		parts.append("%s ist ausgeschieden!" % _seat_name(seat))
	if str(rules.last_events["tiles"]) != "":
		parts.append(str(rules.last_events["tiles"]))
	_notice = " ".join(parts)
	if rules.winner != FfaRules.RUNNING:
		_refresh()
		_show_result()
		return
	_begin_turn()


func _show_result() -> void:
	_result_label.text = "UNENTSCHIEDEN" if rules.winner == FfaRules.DRAW else "%s GEWINNT" % _seat_name(rules.winner)
	_result_panel.visible = true


func _on_card_pressed(slot: int) -> void:
	if _busy or rules.winner != FfaRules.RUNNING or not _is_human[rules.current]:
		return
	if _must_pass:
		rules.pass_turn(slot)
		_after_turn()
		return
	_slot = slot
	_update_targets()
	_refresh()
	_instruction.text = "Tippe jetzt eine deiner Figuren." if _selected.x < 0 else "Tippe auf ein leuchtendes Feld."


func _on_cell_pressed(cell: Vector2i) -> void:
	if _busy or rules.winner != FfaRules.RUNNING or not _is_human[rules.current] or _must_pass:
		return
	var piece: Dictionary = rules.pieces.get(cell, {})
	if not piece.is_empty() and int(piece["owner"]) == rules.current:
		_selected = cell
		_update_targets()
		_refresh()
		_instruction.text = "Wähle jetzt eine Karte." if _slot < 0 else "Tippe auf ein leuchtendes Feld."
		return
	if _selected.x >= 0 and _slot >= 0 and cell in _board.targets:
		rules.apply_move(_selected, _slot, cell)
		_after_turn()
	elif _slot < 0:
		_instruction.text = "Wähle zuerst eine deiner zwei Karten."
	else:
		_instruction.text = "Dieses Feld erlaubt die Karte nicht."


func _update_targets() -> void:
	_board.targets = []
	if _selected.x >= 0 and _slot >= 0:
		_board.targets = rules.targets_for(rules.current, _selected, _slot)


func _refresh() -> void:
	_board.selected = _selected
	if _selected.x < 0 or _slot < 0:
		_board.targets = []
	_board.queue_redraw()
	var seat := rules.current
	var color := FfaBoardView.PLAYER_COLORS[seat]
	_header.text = "RUNDE %02d  •  %s AM ZUG" % [rules.round_number, _seat_name(seat)]
	_header.add_theme_color_override("font_color", color.lightened(0.35))
	for index: int in range(FfaRules.PLAYERS):
		var label := _status[index]
		label.text = "%s %d" % [_seat_name(index).replace("SPIELER ", "S").replace("BOT ", "B"), rules.cells_of(index).size()] if rules.alive[index] else "RAUS"
		label.add_theme_color_override("font_color", FfaBoardView.PLAYER_COLORS[index] if rules.alive[index] else FfaBoardView.RUIN_COLOR)
	for slot: int in range(2):
		var view := _hand[slot]
		view.quarter_turns = seat
		view.dimmed = not _is_human[seat]
		view.show_card(rules.hands[seat][slot], false, color, slot == _slot)
	_pass_view.quarter_turns = seat
	_pass_view.show_card(rules.pass_card, false, Color("ffc23a"), false, "WEITERGABE")
