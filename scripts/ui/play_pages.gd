class_name PlayPages
extends RefCounted

## Everything under SPIELEN: ranked ("Overclocked Protocols") with the
## leaderboard, quick online play, the bot, room codes for friends and local
## play (one device or Wi-Fi). Drawn into the MainMenu like the other pages.

const DIFFICULTY_OPTIONS: Array[Dictionary] = [
	{"title": "LEICHT", "subtitle": "Zum Reinkommen – macht auch mal Fehler"},
	{"title": "MITTEL", "subtitle": "Denkt einen Zug voraus"},
	{"title": "SCHWER", "subtitle": "Rechnet mehrere Züge tief"},
]

var menu: MainMenu
var account: AccountService


func _init(owner_menu: MainMenu, owner_account: AccountService) -> void:
	menu = owner_menu
	account = owner_account


func show_play() -> void:
	menu._set_page("SPIELEN", menu._show_home)
	var online := MatchClient.is_online_available()
	if online:
		var rank := "%s · %d" % [str(account.account.get("rank", "")), int(account.account.get("rating", 1000))] if not account.username().is_empty() else "Nur mit Benutzername"
		menu._add_menu_button(menu._content, "RANKED", "Overclocked Protocols  ·  " + rank, show_ranked)
		menu._add_menu_button(menu._content, "SCHNELLES SPIEL", "Node Link Search: zufälliger Gegner, zählt nicht", func() -> void:
			menu.close_menu()
			menu.online_quick_requested.emit())
	menu._add_menu_button(menu._content, "GEGEN DEN BOT", "Training, drei Stufen", show_bot)
	if online:
		menu._add_menu_button(menu._content, "MIT CODE", "Raum erstellen oder mit Code beitreten", show_room_code)
	menu._add_menu_button(menu._content, "LOKAL", "Ein Gerät oder WLAN ohne Internet", show_local)
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


func show_room_code() -> void:
	menu._set_page("MIT CODE", show_play)
	menu._add_menu_button(menu._content, "RAUM ERSTELLEN", "Du bekommst einen Code für deinen Gegner", func() -> void:
		menu.close_menu()
		menu.online_create_requested.emit(""))
	var code_input := LineEdit.new()
	code_input.placeholder_text = "RAUM-CODE  ____"
	code_input.max_length = 4
	code_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	code_input.custom_minimum_size = Vector2(300.0, 56.0)
	code_input.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	code_input.add_theme_font_size_override("font_size", 36)
	menu._content.add_child(code_input)
	var join := func() -> void:
		var code := code_input.text.strip_edges()
		if code.length() != 4 or not code.is_valid_int():
			code_input.placeholder_text = "4 ZIFFERN!"
			code_input.text = ""
			return
		menu.close_menu()
		menu.online_join_requested.emit(code)
	code_input.text_submitted.connect(func(_text: String) -> void: join.call())
	menu._add_menu_button(menu._content, "BEITRETEN", "Mit dem Code deines Gegners", join)
	menu._add_menu_button(menu._content, "< ZURÜCK", "Zu SPIELEN", show_play)
	menu._focus_first_entry()


func show_local() -> void:
	menu._set_page("LOKAL", show_play)
	menu._add_menu_button(menu._content, "AUF DIESEM GERÄT", "Abwechselnd mit einer zweiten Person", menu._start_local_multiplayer)
	menu._add_menu_button(menu._content, "IM WLAN", "Zwei Handys, der PC ist Gastgeber", func() -> void:
		if MatchClient.is_lan_available():
			menu.close_menu()
			menu.lan_match_requested.emit()
		else:
			_show_lan_help())
	menu._add_menu_button(menu._content, "< ZURÜCK", "Zu SPIELEN", show_play)
	menu._focus_first_entry()


func _show_lan_help() -> void:
	menu._set_page("WLAN", show_local)
	menu._content.add_child(menu._make_text(
		"Starte am PC „WLAN-Spiel starten“ und öffne auf beiden Handys die Adresse, die dort angezeigt wird. Diese Version kommt aus dem Internet und kann sich nicht mit deinem PC verbinden.",
		MainMenu.TEXT_FONT_SIZE))
	menu._add_menu_button(menu._content, "< ZURÜCK", "Zu LOKAL", show_local)
	menu._focus_first_entry()
