class_name FriendsPages
extends RefCounted

## The friends tab: add players by username, answer requests, see who is
## online and their rank, challenge a friend (a room whose code goes to them
## as an invitation) and accept invitations. Refreshes itself while open.

const REFRESH_SECONDS: float = 10.0

var menu: MainMenu
var account: AccountService
## Last answer of the server: {username, friends, incoming, outgoing, invites}.
var overview: Dictionary = {}


func _init(owner_menu: MainMenu, owner_account: AccountService) -> void:
	menu = owner_menu
	account = owner_account


## Short summary for the home entry, e.g. "2 online · 1 Anfrage".
func summary() -> String:
	if overview.is_empty():
		return "Freunde hinzufügen, herausfordern, Einladungen"
	var online := (overview.get("friends", []) as Array).filter(func(person: Dictionary) -> bool: return person.get("online", false)).size()
	var waiting := (overview.get("incoming", []) as Array).size() + (overview.get("invites", []) as Array).size()
	return "%d online%s" % [online, ("  ·  %d neu" % waiting) if waiting > 0 else ""]


func show_friends() -> void:
	menu._set_page("FREUNDE", menu._show_home)
	if account.username().is_empty():
		menu._content.add_child(menu._make_text("Freunde gibt es mit Konto und festem Benutzernamen. Melde dich im Profil an.", MainMenu.TEXT_FONT_SIZE))
		menu._add_menu_button(menu._content, "ZUM PROFIL", "Anmelden und Namen wählen", menu._show_profile)
		menu._add_menu_button(menu._content, "< ZURÜCK", "Zum Hauptmenü", menu._show_home)
		menu._focus_first_entry()
		return
	menu._content.add_child(menu._make_text("DU: " + account.username(), MainMenu.TEXT_FONT_SIZE, TerminalTheme.GREEN_BRIGHT))
	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 10)
	menu._content.add_child(add_row)
	var field := LineEdit.new()
	field.placeholder_text = "Benutzername"
	field.max_length = 16
	field.custom_minimum_size = Vector2(320.0, 52.0)
	field.add_theme_font_size_override("font_size", 30)
	add_row.add_child(field)
	var status := menu._make_text("", 22, TerminalTheme.GREEN_BRIGHT)
	var add := func() -> void:
		if field.text.strip_edges().is_empty():
			return
		await _act("add", {"username": field.text.strip_edges()}, status)
		field.text = ""
	field.text_submitted.connect(func(_text: String) -> void: add.call())
	menu._add_menu_button(add_row, "+ HINZU", "Freundschaftsanfrage schicken", add)
	menu._content.add_child(status)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 470.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.name = "FriendList"
	scroll.add_child(list)
	menu._content.add_child(scroll)
	menu._add_menu_button(menu._content, "< ZURÜCK", "Zum Hauptmenü", menu._show_home)
	_fill(list, status)
	await _refresh(list, status)
	# Keep the list current while the page is open.
	while list.is_inside_tree():
		await menu.get_tree().create_timer(REFRESH_SECONDS).timeout
		if list.is_inside_tree():
			await _refresh(list, status)


func _refresh(list: VBoxContainer, status: Label) -> void:
	var answer := await account.friends()
	if not answer.is_empty():
		overview = answer
	if list.is_inside_tree():
		_fill(list, status)


func _fill(list: VBoxContainer, status: Label) -> void:
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for invite: Dictionary in overview.get("invites", []):
		_heading(list, "EINLADUNG")
		var who := str(invite["username"])
		menu._add_menu_button(list, "> %s  RAUM %s" % [who, str(invite["code"])], "Annehmen und sofort spielen", func() -> void:
			await account.friends("dismiss", {"username": who})
			menu.close_menu()
			menu.online_join_requested.emit(str(invite["code"])))
	var incoming: Array = overview.get("incoming", [])
	if not incoming.is_empty():
		_heading(list, "ANFRAGEN")
	for person: Dictionary in incoming:
		var who := str(person["username"])
		menu._add_menu_button(list, "+ " + who, "Annehmen", _act.bind("accept", {"username": who}, status, list))
		menu._add_menu_button(list, "  ablehnen", "Anfrage von %s ablehnen" % who, _act.bind("remove", {"username": who}, status, list))
	var friends: Array = overview.get("friends", [])
	_heading(list, "FREUNDE (%d)" % friends.size())
	if friends.is_empty():
		list.add_child(menu._make_text("Noch keine Freunde. Füg oben jemanden über den Benutzernamen hinzu.", 22, TerminalTheme.GREEN_DIM))
	for person: Dictionary in friends:
		var who := str(person["username"])
		var dot := "*" if person.get("online", false) else "-"
		menu._add_menu_button(list, "%s %s" % [dot, who], "%s · %d  –  antippen zum Herausfordern" % [str(person.get("rank", "")), int(person.get("rating", 1000))], _show_friend.bind(person))
	var outgoing: Array = overview.get("outgoing", [])
	if not outgoing.is_empty():
		_heading(list, "GESENDET")
	for person: Dictionary in outgoing:
		list.add_child(menu._make_text("  %s – wartet" % str(person["username"]), 22, TerminalTheme.GREEN_DIM))


func _show_friend(person: Dictionary) -> void:
	var who := str(person["username"])
	menu._set_page(who, show_friends)
	menu._content.add_child(menu._make_text("%s  ·  %d PUNKTE" % [str(person.get("rank", "")), int(person.get("rating", 1000))], MainMenu.TEXT_FONT_SIZE, TerminalTheme.GREEN_BRIGHT))
	menu._content.add_child(menu._make_text("online" if person.get("online", false) else "gerade nicht online", 22, TerminalTheme.GREEN_DIM))
	menu._add_menu_button(menu._content, "HERAUSFORDERN", "Raum erstellen; %s bekommt eine Einladung" % who, func() -> void:
		menu.close_menu()
		menu.online_create_requested.emit(who))
	menu._add_menu_button(menu._content, "ENTFERNEN", "Aus deiner Freundesliste nehmen", func() -> void:
		await account.friends("remove", {"username": who})
		show_friends())
	menu._add_menu_button(menu._content, "< ZURÜCK", "Zu FREUNDE", show_friends)
	menu._focus_first_entry()


func _act(action: String, body: Dictionary, status: Label, list: VBoxContainer = null) -> void:
	status.text = "..."
	var answer := await account.friends(action, body)
	if answer.is_empty():
		status.text = _error_text(account._last_error)
		return
	overview = answer
	status.text = "Anfrage geschickt." if action == "add" else ""
	var target := list if list != null else menu._content.find_child("FriendList", true, false) as VBoxContainer
	if target != null and target.is_inside_tree():
		_fill(target, status)


func _heading(list: VBoxContainer, text: String) -> void:
	var label := menu._make_text("// " + text, 22, TerminalTheme.GREEN_DIM)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	list.add_child(label)


func _error_text(error: String) -> String:
	match error:
		"unknown_user":
			return "Diesen Benutzernamen gibt es nicht."
		"self":
			return "Das bist du selbst."
		"already_friends":
			return "Ihr seid schon befreundet."
		"too_many":
			return "Deine Freundesliste ist voll."
		"offline":
			return "Keine Verbindung zum Server."
	return "Fehler: %s" % error
