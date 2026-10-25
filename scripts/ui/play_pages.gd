class_name PlayPages
extends RefCounted

## Everything under SPIELEN: ranked ("Overclocked Protocols") with the
## leaderboard, quick online play, the bot, room codes for friends and local
## play (one device or Wi-Fi). Drawn into the MainMenu like the other pages.

const DIFFICULTY_OPTIONS: Array[Dictionary] = [
	{"title": "LEICHT", "subtitle": "Zum Aufwärmen – macht Fehler und entschuldigt sich nicht"},
	{"title": "MITTEL", "subtitle": "Denkt einen Zug voraus. Mehr schafft der Akku nicht."},
	{"title": "SCHWER", "subtitle": "Rechnet tief. Hat keine Hobbys."},
]

var menu: MainMenu
var account: AccountService
var groups: GroupRoomPages


func _init(owner_menu: MainMenu, owner_account: AccountService) -> void:
	menu = owner_menu
	account = owner_account
	groups = GroupRoomPages.new(owner_menu, owner_account)


func show_play() -> void:
	menu._set_page("SPIELEN", menu._show_home)
	var online := MatchClient.is_online_available()
	if online:
		var rank := "%s · %d" % [str(account.account.get("rank", "")), int(account.account.get("rating", 1000))] if not account.username().is_empty() else "Nur mit Benutzername"
		menu._add_menu_button(menu._content, "RANKED", "Overclocked Protocols  ·  " + rank, show_ranked)
		menu._add_menu_button(menu._content, "SCHNELLES SPIEL", "Node Link Search: zufälliger Gegner, zählt nicht für den Rang", func() -> void:
			menu.close_menu()
			menu.online_quick_requested.emit())
	menu._add_menu_button(menu._content, "GEGEN DEN BOT", "Training, drei Stufen", show_bot)
	menu._add_menu_button(menu._content, "CHAOS", "Labor für neue Regeln: Kern verstecken, Karteneffekte, wandernde Felder", show_chaos)
	menu._add_menu_button(menu._content, "FINITE GRID", "4 Prozesse in einem endlichen Grid. Nur einer bleibt übrig.", show_finite_grid)
	menu._add_menu_button(menu._content, "ZU ZWEIT", "Abwechselnd an einem Gerät", menu._start_local_multiplayer)
	menu._add_menu_button(menu._content, "< ZURÜCK", "Zum Hauptmenü", menu._show_home)
	menu._focus_first_entry()


func show_ranked() -> void:
	menu._set_page("RANKED", show_play)
	if account.username().is_empty():
		menu._content.add_child(menu._make_text("Ranked spielst du mit Konto und festem Benutzernamen. Melde dich im Profil an.", MainMenu.TEXT_FONT_SIZE))
		menu._add_menu_button(menu._content, "ZUM PROFIL", "Anmelden und Namen wählen", menu._show_profile)
		menu._add_menu_button(menu._content, "< ZURÜCK", "Zu SPIELEN", show_play)
		menu._focus_first_entry()
		return
	var data := account.account
	menu._content.add_child(menu._make_text(str(data.get("rank", "")), 54, TerminalTheme.GREEN_BRIGHT))
	menu._content.add_child(menu._make_text("%d PUNKTE  ·  %d SIEGE  ·  %d NIEDERLAGEN" % [int(data.get("rating", 1000)), int(data.get("wins", 0)), int(data.get("losses", 0))], MainMenu.TEXT_FONT_SIZE))
	var cycle: Dictionary = data.get("cycle", {})
	if not cycle.is_empty():
		menu._content.add_child(menu._make_text("PURGE CYCLE %02d: %s" % [int(cycle.get("number", 1)), str(cycle.get("name", "")).to_upper()], MainMenu.TEXT_FONT_SIZE, TerminalTheme.GREEN))
		menu._content.add_child(menu._make_text("Noch %d Tage bis zum System Wipe. Dann vergisst das Grid die Hälfte deiner Punkte." % int(cycle.get("days_left", 0)), 22, TerminalTheme.GREEN_DIM))
		var last: Variant = cycle.get("last")
		if last is Dictionary:
			var paid := int((last as Dictionary).get("reward", 0))
			menu._content.add_child(menu._make_text("Letzter Zyklus: %s  ·  %d Punkte%s" % [str((last as Dictionary).get("rank", "")), int((last as Dictionary).get("rating", 0)), ("  ·  +%d Credits" % paid) if paid > 0 else ""], 22, TerminalTheme.GREEN_DIM))
	if int(data.get("games", 0)) < 5:
		menu._content.add_child(menu._make_text("Kalibrierung: noch %d Partien bis zu deinem ersten Rang." % (5 - int(data.get("games", 0))), 22, TerminalTheme.GREEN_DIM))
	var status := menu._make_text("", MainMenu.TEXT_FONT_SIZE, TerminalTheme.GREEN_BRIGHT)
	menu._add_menu_button(menu._content, "SUCHE STARTEN", "Gegner mit ähnlicher Wertung. Aufgeben zählt als Niederlage.", func() -> void:
		status.text = "Verbinde ..."
		var ticket := await account.ranked_ticket()
		if ticket.is_empty():
			status.text = "Suche nicht möglich (%s)." % account._last_error
			return
		menu.close_menu()
		menu.online_ranked_requested.emit(ticket))
	menu._content.add_child(status)
	menu._add_menu_button(menu._content, "RANGLISTE", "Die besten 50 im Grid", show_leaderboard)
	menu._add_menu_button(menu._content, "< ZURÜCK", "Zu SPIELEN", show_play)
	menu._focus_first_entry()


func show_leaderboard() -> void:
	menu._set_page("RANGLISTE", show_ranked)
	var list := VBoxContainer.new()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 560.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(list)
	menu._content.add_child(scroll)
	list.add_child(menu._make_text("Lade ...", MainMenu.TEXT_FONT_SIZE))
	menu._add_menu_button(menu._content, "< ZURÜCK", "Zu RANKED", show_ranked)
	menu._focus_first_entry()
	var players := await account.leaderboard()
	if not list.is_inside_tree():
		return
	for child: Node in list.get_children():
		child.queue_free()
	if players.is_empty():
		list.add_child(menu._make_text("Noch niemand hat seine Kalibrierung abgeschlossen. Sei der Erste.", MainMenu.TEXT_FONT_SIZE))
	for index: int in range(players.size()):
		var player: Dictionary = players[index]
		var me := str(player.get("name", "")) == account.username()
		var line := menu._make_text("%2d. %-16s %5d  %s" % [index + 1, str(player.get("name", "")), int(player.get("rating", 0)), str(player.get("rank", ""))], 24, TerminalTheme.GREEN_BRIGHT if me else TerminalTheme.GREEN)
		line.autowrap_mode = TextServer.AUTOWRAP_OFF
		list.add_child(line)


const CHAOS_VARIANTS: Array[Dictionary] = [
	{"key": "hidden_king", "title": "VERSTECKTER KERN", "short": "Kern versteckt", "text": "Du bestimmst geheim deinen KERN. Den des Gegners kennst du nicht."},
	{"key": "shifting_tiles", "title": "WANDERNDE FELDER", "short": "Felder wandern", "text": "Felder warnen, brechen weg und kehren zurück."},
	{"key": "card_effects", "title": "KARTENEFFEKTE", "short": "Karteneffekte", "text": "Jede Karte hat einen Effekt: Schritt ODER Effekt."},
]


func _chaos_summary() -> String:
	var active: PackedStringArray = []
	for variant: Dictionary in CHAOS_VARIANTS:
		if bool(menu.chaos_options.get(str(variant["key"]), false)):
			active.append(str(variant["short"]))
	return ", ".join(active)


## The chaos lab: new rules tried out on the living grid. Variants combine freely.
func show_chaos() -> void:
	menu._set_page("CHAOS LABOR", show_play)
	menu._content.add_child(menu._make_text("Neue Regeln, getestet am lebenden Grid. Schalte Varianten an und kombiniere sie.", 22, TerminalTheme.GREEN_DIM))
	var summary := _chaos_summary()
	if summary != "":
		menu._add_menu_button(menu._content, "> START", "Gegen den Bot: " + summary, menu._start_chaos)
	else:
		menu._content.add_child(menu._make_text("Wähle mindestens eine Variante.", MainMenu.TEXT_FONT_SIZE))
	for variant: Dictionary in CHAOS_VARIANTS:
		var key := str(variant["key"])
		var on := bool(menu.chaos_options.get(key, false))
		menu._add_menu_button(menu._content, "%s  [%s]" % [str(variant["title"]), "AN" if on else "AUS"], str(variant["text"]), func() -> void:
			menu.chaos_options[key] = not on
			show_chaos())
	menu._add_menu_button(menu._content, "ALLES AN", "Totales Chaos: alle Varianten zugleich", func() -> void:
		for variant: Dictionary in CHAOS_VARIANTS:
			menu.chaos_options[str(variant["key"])] = true
		show_chaos())
	menu._add_menu_button(menu._content, "ÜBERRASCHUNG", "Das Grid würfelt die Varianten aus", func() -> void:
		var any_on := false
		while not any_on:
			for variant: Dictionary in CHAOS_VARIANTS:
				menu.chaos_options[str(variant["key"])] = randf() < 0.5
				any_on = any_on or bool(menu.chaos_options[str(variant["key"])])
		show_chaos())
	menu._add_menu_button(menu._content, "MIT FREUNDEN", "Online mit bis zu 4 Leuten im Raum", func() -> void: groups.show_entry(show_chaos))
	menu._add_menu_button(menu._content, "< ZURÜCK", "Zu SPIELEN", show_play)
	menu._focus_first_entry()


## Four processes in one finite grid: its own mode next to chaos.
func show_finite_grid() -> void:
	menu._set_page("FINITE GRID", show_play)
	menu._content.add_child(menu._make_text(GridLore.FINITE_LORE, 22, TerminalTheme.GREEN_DIM))
	menu._content.add_child(menu._make_text("Vier Seiten, ein Quadrat. Jeder hat 5 Figuren und 2 Karten. Die gespielte Karte wandert im Uhrzeigersinn weiter. Verlierst du deinen KERN, kämpfst du mit den Echos weiter. Schlägst du den KERN eines anderen, bekommst du deinen KERN zurück (sonst einen verlorenen Echo). Raus ist, wer keine Figur mehr hat.", 22, TerminalTheme.GREEN_DIM))
	menu._add_menu_button(menu._content, "ALLEIN GEGEN 3 BOTS", "Nur einer bleibt übrig", func() -> void: menu._start_ffa(1))
	menu._add_menu_button(menu._content, "ZU ZWEIT + 2 BOTS", "Zwei Menschen an gegenüberliegenden Seiten", func() -> void: menu._start_ffa(2))
	menu._add_menu_button(menu._content, "4 SPIELER AM GERÄT", "Abwechselnd, jeder an seiner Seite", func() -> void: menu._start_ffa(4))
	menu._add_menu_button(menu._content, "WANDERNDE FELDER  [%s]" % ("AN" if menu.finite_tiles else "AUS"), "Felder brechen weg und kehren zurück", func() -> void:
		menu.finite_tiles = not menu.finite_tiles
		show_finite_grid())
	menu._add_menu_button(menu._content, "KARTENEFFEKTE  [%s]" % ("AN" if menu.finite_effects else "AUS"), "Jede Karte: Schritt ODER Effekt (Schlag, Stoß, Schild, Tausch)", func() -> void:
		menu.finite_effects = not menu.finite_effects
		show_finite_grid())
	var layout := ScreenLayout.mode()
	menu._add_menu_button(menu._content, "BILDSCHIRM: %s" % str(ScreenLayout.NAMES[layout]), "%s Gilt für Finite Grid." % str(ScreenLayout.HINTS[layout]), func() -> void:
		ScreenLayout.next_mode()
		show_finite_grid())
	menu._add_menu_button(menu._content, "MIT FREUNDEN", "Online mit bis zu 4 Leuten: Raum-Code oder Einladung", func() -> void: groups.show_entry(show_finite_grid))
	menu._add_menu_button(menu._content, "< ZURÜCK", "Zu SPIELEN", show_play)
	menu._focus_first_entry()


func show_bot() -> void:
	menu._set_page("BOT", show_play)
	for level: int in range(DIFFICULTY_OPTIONS.size()):
		var option: Dictionary = DIFFICULTY_OPTIONS[level]
		var marker := " *" if level == menu.bot_difficulty else ""
		menu._add_menu_button(menu._content, str(option["title"]) + marker, str(option["subtitle"]), func() -> void:
			menu.bot_difficulty = level
			menu._save_profile()
			menu._start_bot_training())
	menu._add_menu_button(menu._content, "< ZURÜCK", "Zu SPIELEN", show_play)
	menu._focus_first_entry(menu.bot_difficulty)
