class_name GroupRoomPages
extends RefCounted

## Menu pages for rooms with up to four players (Finite Grid online): open a
## room, join with its five-digit code, the lobby with the friend invitations.
## The match itself runs in FfaBattle once the host presses START.

var menu: MainMenu
var account: AccountService

var _client: GroupClient
var _lobby: Dictionary = {}
var _code: String = ""
var _is_host: bool = false
var _my_seat: int = 0
var _message: String = ""
var _friends: Array = []
var _invited: Array[String] = []
var _in_lobby: bool = false


func _init(owner_menu: MainMenu, owner_account: AccountService) -> void:
	menu = owner_menu
	account = owner_account


## "MIT FREUNDEN": open a room or join one by code.
func show_entry(back: Callable) -> void:
	menu._set_page("MIT FREUNDEN", back)
	menu._content.add_child(menu._make_text("Bis zu 4 Freunde in einem Raum. Wer fehlt, wird durch Bots ersetzt. Alle sehen die gleichen Karten und spielen von ihrer eigenen Seite.", 22, TerminalTheme.GREEN_DIM))
	menu._add_menu_button(menu._content, "RAUM ERÖFFNEN", "Du bekommst einen Code und kannst Freunde einladen", show_create.bind(back))
	menu._add_menu_button(menu._content, "MIT CODE BEITRETEN", "Der Code hat 5 Ziffern", show_join.bind(back))
	menu._add_menu_button(menu._content, "< ZURÜCK", "Zurück", back)
	menu._focus_first_entry()


func show_create(back: Callable) -> void:
	menu._set_page("RAUM ERÖFFNEN", show_entry.bind(back))
	menu._add_menu_button(menu._content, "SPIELER: %d" % menu.group_max, "Höchstens so viele Menschen im Raum. Der Rest sind Bots.", func() -> void:
		menu.group_max = 2 if menu.group_max >= 4 else menu.group_max + 1
		show_create(back))
	menu._add_menu_button(menu._content, "WANDERNDE FELDER  [%s]" % ("AN" if menu.finite_tiles else "AUS"), "Felder brechen weg und kehren zurück", func() -> void:
		menu.finite_tiles = not menu.finite_tiles
		show_create(back))
	menu._add_menu_button(menu._content, "KARTENEFFEKTE  [%s]" % ("AN" if menu.finite_effects else "AUS"), "Jede Karte: Schritt ODER Effekt (Schlag, Stoß, Schild, Tausch)", func() -> void:
		menu.finite_effects = not menu.finite_effects
		show_create(back))
	var layout := ScreenLayout.mode()
	menu._add_menu_button(menu._content, "BILDSCHIRM: %s" % str(ScreenLayout.NAMES[layout]), "%s Gilt nur für dich." % str(ScreenLayout.HINTS[layout]), func() -> void:
		ScreenLayout.next_mode()
		show_create(back))
	menu._add_menu_button(menu._content, "> RAUM ÖFFNEN", "Verbindet mit dem Server", func() -> void:
		menu.group_create_requested.emit({"tiles": menu.finite_tiles, "effects": menu.finite_effects}, menu.group_max))
	menu._add_menu_button(menu._content, "< ZURÜCK", "Zurück", show_entry.bind(back))
	menu._focus_first_entry(4)


func show_join(back: Callable) -> void:
	menu._set_page("MIT CODE BEITRETEN", show_entry.bind(back))
	var code_input := LineEdit.new()
	code_input.placeholder_text = "RAUM-CODE  _____"
	code_input.max_length = 5
	code_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	code_input.custom_minimum_size = Vector2(340.0, 56.0)
	code_input.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	code_input.add_theme_font_size_override("font_size", 36)
	WebTextInput.attach(code_input, "Raum-Code")
	menu._content.add_child(code_input)
	var join := func() -> void:
		var code := code_input.text.strip_edges()
		if not GroupClient.is_group_code(code):
			code_input.placeholder_text = "5 ZIFFERN!"
			code_input.text = ""
			return
		menu.group_join_requested.emit(code)
	code_input.text_submitted.connect(func(_text: String) -> void: join.call())
	menu._add_menu_button(menu._content, "> BEITRETEN", "Zum Raum mit diesem Code", join)
	menu._add_menu_button(menu._content, "< ZURÜCK", "Zurück", show_entry.bind(back))
	menu._focus_first_entry()


## The room is open (or being joined): shows who is in and lets the host start.
func show_lobby(client: GroupClient) -> void:
	_client = client
	_lobby = {}
	_code = ""
	_message = "Verbinde ..."
	_invited.clear()
	_friends.clear()
	_in_lobby = true
	client.joined.connect(_on_joined)
	client.lobby_changed.connect(_on_lobby)
	client.started.connect(func(_info: Dictionary) -> void: _in_lobby = false)
	client.resumed.connect(func(_info: Dictionary) -> void:
		_in_lobby = false
		menu.close_menu())
	client.rejected.connect(_on_rejected)
	client.connection_lost.connect(func() -> void:
		if _in_lobby:
			_leave_lobby_with("Die Verbindung ist abgebrochen."))
	_render()


func _on_joined(info: Dictionary) -> void:
	_code = str(info.get("code", ""))
	_is_host = bool(info.get("host", false))
	_my_seat = int(info.get("seat", 0))
	_message = ""
	_lobby = {"players": [{"seat": _my_seat, "name": menu.profile_name}], "max": int(info.get("max", 4)), "settings": info.get("settings", {})}
	_render()
	if _is_host:
		_load_friends()


func _on_lobby(info: Dictionary) -> void:
	_lobby = info
	_is_host = int(info["players"][0]["seat"]) == _my_seat
	if _in_lobby:
		_render()


func _on_rejected(reason: String) -> void:
	if not _in_lobby:
		return
	var texts := {
		"not_found": "Diesen Raum gibt es nicht (mehr).",
		"full": "Der Raum ist voll.",
		"started": "Das Spiel in diesem Raum läuft schon.",
		"host_left": "Der Gastgeber hat den Raum geschlossen.",
		"code_taken": "Kein freier Raum-Code. Versuch es noch einmal.",
		"match_over": "Die Partie kann nicht mehr fortgesetzt werden.",
	}
	_leave_lobby_with(str(texts.get(reason, "Das hat nicht geklappt (%s)." % reason)))


func _leave_lobby_with(text_value: String) -> void:
	_in_lobby = false
	menu.toast_requested.emit(text_value)
	menu._show_home()


func _render() -> void:
	if not _in_lobby:
		return
	menu._set_page("RAUM", _leave)
	if _code.is_empty():
		menu._content.add_child(menu._make_text(_message, MainMenu.TEXT_FONT_SIZE))
		menu._add_menu_button(menu._content, "< ABBRECHEN", "Zurück", _leave)
		menu._focus_first_entry()
		return
	menu._content.add_child(menu._make_text("RAUM-CODE  %s" % _code, 54, TerminalTheme.GREEN_BRIGHT))
	var settings: Dictionary = _lobby.get("settings", {})
	var players: Array = _lobby.get("players", [])
	menu._content.add_child(menu._make_text("%d von %d Spielern  ·  Wandernde Felder: %s  ·  Karteneffekte: %s" % [players.size(), int(_lobby.get("max", 4)), "AN" if bool(settings.get("tiles", false)) else "AUS", "AN" if bool(settings.get("effects", false)) else "AUS"], 22, TerminalTheme.GREEN_DIM))
	for player: Dictionary in players:
		var seat := int(player["seat"])
		var line := menu._make_text("> %s%s" % [str(player.get("name", "?")).to_upper(), "  (DU)" if seat == _my_seat else ""], MainMenu.TEXT_FONT_SIZE, FfaFloor.SEAT_COLORS[seat].lightened(0.3))
		menu._content.add_child(line)
	if _is_host:
		if players.size() >= 2:
			menu._add_menu_button(menu._content, "> START", "Leere Plätze spielen Bots", func() -> void: _client.start_match())
		else:
			menu._content.add_child(menu._make_text("Warte auf Mitspieler. Schick ihnen den Code oder lade Freunde ein.", 22, TerminalTheme.GREEN_DIM))
		_add_invites()
	else:
		menu._content.add_child(menu._make_text("Warte, bis der Gastgeber startet ...", MainMenu.TEXT_FONT_SIZE))
	menu._add_menu_button(menu._content, "< VERLASSEN", "Den Raum verlassen", _leave)
	menu._focus_first_entry()


func _add_invites() -> void:
	if account.username().is_empty():
		menu._content.add_child(menu._make_text("Mit Konto und Benutzernamen kannst du Freunde direkt einladen.", 22, TerminalTheme.GREEN_DIM))
		return
	for person: Dictionary in _friends:
		var who := str(person["username"])
		var already := who in _invited
		menu._add_menu_button(menu._content, ("%s  eingeladen" if already else "+ %s einladen") % who, "Schickt %s eine Einladung zu diesem Raum" % who, func() -> void:
			if who in _invited:
				return
			_invited.append(who)
			await account.friends("invite", {"username": who, "code": _code})
			_render())


## Friends who are online get a button each.
func _load_friends() -> void:
	if account.username().is_empty():
		return
	var overview := await account.friends()
	_friends = (overview.get("friends", []) as Array).filter(func(person: Dictionary) -> bool: return bool(person.get("online", false)))
	_render()


func _leave() -> void:
	_in_lobby = false
	if _client != null:
		_client.leave()
	menu._show_home()
