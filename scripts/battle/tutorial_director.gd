class_name TutorialDirector
extends CanvasLayer

## The tutorial runs inside a real practice match: Doc Voss talks from a speech
## bubble above the board, points at things and waits for the player to pick a
## card, a figure and a target. GridBattleManager calls the hooks below.

const SPEAKER_AVATAR := "character:doc"
const SPEAKER_NAME := "DOC VOSS"
## Hand of the player, hand of the bot, the shared pass card.
const CARD_NAMES: Array = [["Shell", "Crane"], ["Pulse", "Echo"], ["Orbit"]]

const NODE_PING_INTRO: Array[String] = [
	"Bevor die Karten kommen: Der Node Ping entscheidet, wer den Startspieler wählt. Beide tippen geheim auf einen Punkt. Wer näher am Signal liegt, darf wählen; bei Gleichstand tippt ihr noch einmal.",
]
const INTRO: Array[String] = [
	"Oh, ein neuer Knoten. Wie spontan. Ich bin Doc Voss und habe das Grid gebaut. Es sollte ein ruhiges Datennetz werden. Jetzt prügeln sich darin Leute mit Karten. Danke dafür.",
	"Willkommen im Core System. Jede Partie ist die Übernahme einer Datenplattform. Hier siehst du das Brett: 5×5 Felder. Alles heißt bei uns anders, aber es ist derselbe Mist mit Terminal-Stimmung.",
	"Links und rechts hängen über Infinity-Kabel zusammen. Wer links rausläuft, kommt rechts wieder rein. Ja, auch du. Oben und unten ist Schluss. Der Unendlichkeit wollte ich wenigstens eine Wand geben, an der man sich den Kopf stoßen kann.",
	"Jede Seite hat einen KERN, die eine echte Person. Dazu vier Echos, vom Grid kopiert, weil es zu viel Speicherplatz hatte. Wer den gegnerischen KERN schlägt, gewinnt. Die Echos dürfen sterben. Sag es ihnen nicht.",
]
const CARDS: Array[String] = [
	"Frei laufen? Wo kämen wir da hin. Jede Karte erlaubt nur die Sprünge, die darauf leuchten: Die Mitte bist du, die Farbfelder sind die Ziele.",
	"Fünf Karten pro Partie: zwei für dich, zwei für den Gegner, eine Wechselkarte. Fünf. Mehr Strategie bekommst du nicht geschenkt. Los, probier es aus.",
]
## What Doc Voss says after the player's 1st and 2nd move.
const AFTER_MOVE: Array = [
	[
		"Siehst du? Deine Karte liegt jetzt in der Mitte. Der Gegner bekommt genau die, die du gerade gespielt hast, und du seine Wechselkarte. Das Grid vergisst nichts. Außer Passwörter.",
		"Steht auf dem Zielfeld ein Gegner, ist er 'Node Purged'. Dein Zug, dein Verbrechen. Der Bot läuft dir übrigens gleich entgegen. Er ist heute großzügig.",
	],
	[
		"Es gibt vier Sorten Karten: VECTOR läuft einfach los, WAVE weicht seitlich aus, FIELD umzingelt diagonal, OVERCLOCK ist selten und riskant. Entweder Finale oder Peinlichkeit.",
		"Kannst du nicht ziehen, passt du. Wiederholt sich eine Stellung dreimal, ist es Remis. Das Grid nennt es Endlosschleife. Ich nenne es Montag. Jetzt schlag seinen KERN.",
	],
]
## After the match: only what the next match needs; the rest of the menu explains itself.
const OUTRO_WON: String = "Gewonnen. Gegen einen Bot, der dir freiwillig in die Arme gelaufen ist. Aber ich nehme, was ich kriegen kann."
const OUTRO_OTHER: String = "Na ja, das war ein Match. Im Ernst, selbst das war eine Einladung. Beim nächsten Mal klappt es."
const OUTRO: Array[String] = [
	"Das war der Probelauf. Du kennst jetzt die Grundlagen; der Rest vom Menü erklärt sich selbst. Meistens. Viel Glück, Guest Threat. Das Grid sieht zu. Es applaudiert nicht.",
]
const MENU_RECAP: Array[String] = [
	"Das Brett hat 5×5 Felder: links und rechts geht es auf der anderen Seite weiter. Oben und unten ist Schluss. Jede Karte zeigt dir genau, wohin deine Figur ziehen darf.",
	"Du hast zwei Karten; die fünfte Karte liegt in der Mitte. Nach deinem Zug tauschst du die benutzte Karte mit der mittleren. Kein legaler Zug? Dann musst du passen.",
	"Der Node Ping entscheidet, wer den Start wählt: Beide tippen geheim, dann zählt die Nähe zum Signal. Eine Signal Collision bedeutet Gleichstand und einen neuen Versuch. Schlage den gegnerischen KERN, um zu gewinnen. Such dir jetzt im Menü einen Modus aus.",
]

signal _advanced

var battle: GridBattleManager
var _mandatory: bool = true
var _skipped: bool = false
var _moves_done: int = 0
var _panel: PanelContainer
var _portrait: TextureRect
var _body: Label
var _next_button: Button
var _skip_button: Button


## The cards of the practice match, in the order: player's two, bot's two, pass card.
static func cards() -> Array:
	var by_name: Dictionary = {}
	for card: MovementCard in MovementCard.create_deck():
		by_name[card.card_name] = card
	var dealt: Array = []
	for group: Array in CARD_NAMES:
		for card_name: String in group:
			dealt.append(by_name[card_name])
	return dealt


func setup(battle_manager: GridBattleManager, mandatory: bool) -> void:
	battle = battle_manager
	_mandatory = mandatory
	layer = 5
	_build_panel()


func after_intro() -> void:
	await battle.get_tree().create_timer(1.4).timeout
	await _say(INTRO[0])
	await _say(INTRO[1])
	var edges: Array[Vector2i] = []
	for row: int in range(5):
		edges.append(Vector2i(0, row))
		edges.append(Vector2i(4, row))
	battle.grid_manager.show_movement_targets(edges, Vector2i(-1, -1), 0)
	await _say(INTRO[2])
	battle.grid_manager.clear_highlights()
	_glow_masters(true)
	await _say(INTRO[3])
	_glow_masters(false)
	_hide()


func before_node_ping() -> void:
	for line: String in NODE_PING_INTRO:
		await _say(line)
	_hide()


func after_deal() -> void:
	for line: String in CARDS:
		await _say(line)
	_hide()
	_guide_first_turn.call_deferred()


## Called after every move, before the turn passes on.
func after_move(team: int) -> void:
	if team != 0 or _skipped:
		return
	_moves_done += 1
	_hide()
	if _moves_done <= AFTER_MOVE.size():
		for line: String in AFTER_MOVE[_moves_done - 1]:
			await _say(line)
		_hide()


## A new turn of the player: point at a possible capture of the bot's KERN.
func on_player_turn() -> void:
	if _skipped or _moves_done == 0:
		return
	if _can_capture_master():
		_hint("Da ist er, der gegnerische KERN, in Reichweite. Karte wählen, Figur wählen, rotes Feld antippen.")
	else:
		_hint("Zieh weiter nach vorn. Der Bot kommt dir entgegen.")


## The bot walks its KERN toward the player, into the reach of the player's
## cards, and captures nothing unless it has no other move.
func choose_bot_move() -> Dictionary:
	var reach := _player_reach()
	var best: Dictionary = {}
	var best_score := -INF
	var fallback: Dictionary = {}
	for slot: int in range(2):
		var card: MovementCard = battle.hands[1][slot]
		for unit: BattleUnit in battle.enemies:
			if not is_instance_valid(unit) or battle.grid_manager.get_unit_at(unit.grid_position) != unit:
				continue
			for destination: Vector2i in card.destinations(unit.grid_position, 1, battle.grid_manager.grid_size.x):
				var occupant := battle.grid_manager.get_unit_at(destination) as BattleUnit
				if occupant != null and occupant.team_id == 1:
					continue
				var move := {"unit": unit, "slot": slot, "destination": destination}
				if occupant != null:
					fallback = move
					continue
				var score := float(destination.y)
				if unit.is_master:
					score += 50.0
					if destination in reach:
						score += 100.0
				if score > best_score:
					best_score = score
					best = move
	if not best.is_empty():
		return best
	if not fallback.is_empty():
		return fallback
	return {"slot": 0, "pass": true}


func _player_reach() -> Array[Vector2i]:
	var reach: Array[Vector2i] = []
	for unit: BattleUnit in battle.players:
		if not is_instance_valid(unit) or battle.grid_manager.get_unit_at(unit.grid_position) != unit:
			continue
		for card: MovementCard in battle.hands[0]:
			reach.append_array(card.destinations(unit.grid_position, 0, battle.grid_manager.grid_size.x))
	return reach


func _can_capture_master() -> bool:
	var reach := _player_reach()
	for unit: BattleUnit in battle.enemies:
		if is_instance_valid(unit) and unit.is_master and unit.grid_position in reach:
			return true
	return false


## The match is over: a short menu recap follows a tutorial win.
func on_battle_over(winner: int) -> void:
	_hide()
	if _skipped:
		TutorialProgress.mark_done(battle.battle_ui.main_menu.account)
		return
	await battle.get_tree().create_timer(1.8).timeout
	await _say(OUTRO_WON if winner == 0 else OUTRO_OTHER)
	if winner == 0:
		battle.grid_manager.get_parent().visible = false
		battle.battle_ui.result_overlay.visible = false
		battle.battle_ui.main_menu.open_menu(false)
		for line: String in MENU_RECAP:
			await _say(line)
	else:
		for line: String in OUTRO:
			await _say(line)
	_hide()
	TutorialProgress.mark_done(battle.battle_ui.main_menu.account)


func _guide_first_turn() -> void:
	_hint("Tippe unten auf eine deiner zwei Karten.")
	await _until(func() -> bool: return battle.selected_card_slot >= 0)
	if battle.selected_unit == null:
		_hint("Gut. Jetzt tippst du eine deiner blauen Figuren an. Ihre Ziele leuchten.")
		await _until(func() -> bool: return battle.selected_unit != null)
	_hint("Und jetzt ein leuchtendes Feld. Du musst nur noch hinwollen.")


func _until(condition: Callable) -> void:
	while not _skipped and _moves_done == 0 and not condition.call():
		await battle.get_tree().process_frame


func _glow_masters(on: bool) -> void:
	for team: Array[BattleUnit] in [battle.players, battle.enemies]:
		for unit: BattleUnit in team:
			if unit.is_master:
				unit.set_selected(on)


func _say(text_value: String) -> void:
	if _skipped:
		return
	_show(text_value, true)
	await _advanced


func _hint(text_value: String) -> void:
	if not _skipped:
		_show(text_value, false)


func _show(text_value: String, with_button: bool) -> void:
	_panel.visible = true
	_body.text = text_value
	MenuMotion.type_in(_body, minf(0.9, 0.012 * text_value.length()))
	_next_button.visible = with_button
	# In the editor (testing) the tutorial can always be left.
	_skip_button.visible = not _mandatory or OS.has_feature("editor")
	SoundBoard.play("click", -12.0)


func _hide() -> void:
	_panel.visible = false


func _skip() -> void:
	_skipped = true
	_hide()
	_glow_masters(false)
	battle.grid_manager.clear_highlights()
	_advanced.emit()


## The first call starts rendering the portrait and later swaps it for a still
## image, so the finished image is fetched again a moment later.
func _load_portrait() -> void:
	var host := battle.battle_ui.main_menu._previews_root()
	AvatarGallery.picture(SPEAKER_AVATAR, host)
	for frame: int in range(8):
		await get_tree().process_frame
	_portrait.texture = AvatarGallery.picture(SPEAKER_AVATAR, host)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.theme = TerminalTheme.theme()
	_panel.anchor_right = 1.0
	_panel.offset_left = 12.0
	_panel.offset_right = -12.0
	_panel.offset_top = 96.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.02, 0.92)
	style.border_color = TerminalTheme.GREEN
	style.set_border_width_all(2)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_panel.add_child(row)
	var portrait := TextureRect.new()
	_portrait = portrait
	_load_portrait.call_deferred()
	portrait.custom_minimum_size = Vector2(110, 110)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(portrait)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var name_label := Label.new()
	name_label.text = SPEAKER_NAME
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", TerminalTheme.GREEN_DIM)
	column.add_child(name_label)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("font_size", 26)
	_body.add_theme_color_override("font_color", TerminalTheme.GREEN_BRIGHT)
	column.add_child(_body)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	_skip_button = Button.new()
	_skip_button.text = "ÜBERSPRINGEN"
	_skip_button.pressed.connect(_skip)
	buttons.add_child(_skip_button)
	_next_button = Button.new()
	_next_button.text = "WEITER ▶"
	_next_button.add_theme_font_size_override("font_size", 28)
	_next_button.pressed.connect(func() -> void:
		SoundBoard.play("select")
		_advanced.emit())
	buttons.add_child(_next_button)
