class_name FriendsPages
extends RefCounted

## The friends tab: add players by username, answer requests, see who is
## online and their rank, challenge a friend (a room whose code goes to them
## as an invitation) and accept invitations. Refreshes itself while open.

const REFRESH_SECONDS: float = 10.0
const WATCH_SECONDS: float = 45.0

var menu: MainMenu
var account: AccountService
## Last answer of the server: {username, friends, incoming, outgoing, invites}.
var overview: Dictionary = {}
## People in the game right now (anyone with the game open), see start_watch().
var online_count: int = 0
var _known_online: Dictionary = {}
var _watched: bool = false


func _init(owner_menu: MainMenu, owner_account: AccountService) -> void:
	menu = owner_menu
	account = owner_account


## Runs for the whole session: tells the server we are here, counts who is in
## the game, applies an invite link and says when a friend comes online.
func start_watch() -> void:
	await menu.get_tree().create_timer(6.0).timeout
	while menu.is_inside_tree():
		await _watch_once()
		await menu.get_tree().create_timer(WATCH_SECONDS).timeout


func _watch_once() -> void:
	if account.busy or not account.has_account() or account.account.is_empty():
		return
	var count := await account.presence()
	if count >= 0:
		online_count = count
	if account.username().is_empty() or account.busy:
		return
	await _apply_pending_invite()
	if account.busy:
		return
	var answer := await account.friends()
	if answer.is_empty():
		return
	overview = answer
	var now_online: Dictionary = {}
	for person: Dictionary in answer.get("friends", []):
		if person.get("online", false):
			var who := str(person["username"])
			now_online[who] = true
			if _watched and not _known_online.has(who):
				menu.toast_requested.emit("%s ist jetzt online." % who)
	_known_online = now_online
	_watched = true


## The invite link of someone else brought us here: become friends, both get credits.
func _apply_pending_invite() -> void:
	var config := ConfigFile.new()
	config.load(MainMenu.PROFILE_PATH)
	var inviter := str(config.get_value("profile", "pending_invite", ""))
	if inviter.is_empty():
		return
	var answer := await account.friends("invited", {"username": inviter})
	if account._last_error == "offline":
		return
	config.set_value("profile", "pending_invite", "")
	config.save(MainMenu.PROFILE_PATH)
	if not answer.is_empty() and int(answer.get("bonus", 0)) > 0:
		overview = answer
		menu.toast_requested.emit("Einladung von %s: +%d Credits. Ihr seid jetzt Freunde." % [inviter, int(answer["bonus"])])


## Link that brings a friend into the game; they land on your friends list.
func _invite_link() -> String:
	return "%s/?invite=%s" % [AccountService.api_url().replace("/api/account", ""), account.username()]


func _share_invite(status: Label) -> void:
	var link := _invite_link()
	DisplayServer.clipboard_set(link)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (navigator.share) { navigator.share({title: 'Infinity Grid', text: 'Spiel mit mir Infinity Grid!', url: %s}).catch(function () {}); }" % JSON.stringify(link))
	status.text = "Link kopiert. Wer darüber kommt und sich anmeldet, wird dein Freund – ihr bekommt beide Credits."


## Short summary for the home entry, e.g. "2 online · 1 Anfrage".
func summary() -> String:
	if overview.is_empty():
		return "Menschen, die du freiwillig kennst"
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
	WebTextInput.attach(field, "Benutzername")
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
	menu._add_menu_button(menu._content, "FREUND EINLADEN", "Link kopieren und teilen – beide bekommen Credits", _share_invite.bind(status))
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
	while (is_instance_valid(list) and list.is_inside_tree()):
		await menu.get_tree().create_timer(REFRESH_SECONDS).timeout
		if (is_instance_valid(list) and list.is_inside_tree()):
			await _refresh(list, status)


func _refresh(list: VBoxContainer, status: Label) -> void:
	var answer := await account.friends()
	if not answer.is_empty():
		overview = answer
	if (is_instance_valid(list) and list.is_inside_tree()):
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
		list.add_child(menu._make_text("  %s – wartet auf Annahme" % str(person["username"]), 22, TerminalTheme.GREEN_DIM))


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
	status.text = ""
	if action == "add":
		var who := str(body.get("username", ""))
		var already := (overview.get("friends", []) as Array).any(func(person: Dictionary) -> bool: return str(person["username"]).to_lower() == who.to_lower())
		status.text = "Ihr seid jetzt befreundet." if already else "Anfrage an %s geschickt. Die Person muss sie annehmen." % who
	var target := list if list != null else menu._content.find_child("FriendList", true, false) as VBoxContainer
	if is_instance_valid(target) and target.is_inside_tree():
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
