class_name LoginPages
extends RefCounted

## Signing in: with Google (in its own window) or e-mail + password, and
## signing out again. Drawn into the MainMenu's terminal frame like the shop.

const GOOGLE_POLL_SECONDS: float = 2.0
const GOOGLE_WAIT_SECONDS: float = 300.0

var menu: MainMenu
var account: AccountService


func _init(owner_menu: MainMenu, owner_account: AccountService) -> void:
	menu = owner_menu
	account = owner_account


## The profile's bottom part: one KONTO panel (credits, sign-in state) and a
## row of small buttons, instead of loose lines and big menu bars.
func add_account_panel(parent: Control, avatar_action: Callable) -> void:
	var online := account.has_account() and not account.account.is_empty()
	var panel := ProfileStatsView.make_panel()
	parent.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(ProfileStatsView.make_text("KONTO", 20, TerminalTheme.GREEN_DIM))
	if online:
		var credits := ProfileStatsView.make_text("%d CR" % account.credits(), 26, TerminalTheme.GREEN_BRIGHT)
		box.add_child(_info_row("Credits", credits))
		var update := func() -> void: credits.text = "%d CR" % account.credits()
		account.changed.connect(update)
		credits.tree_exiting.connect(func() -> void: account.changed.disconnect(update))
		account.refresh_if_stale()
	var state := "Gast – Konto anlegen für Credits auf jedem Gerät"
	if not online:
		state = "Offline – Anmelden geht, sobald du online bist"
	elif not account.email().is_empty():
		state = account.email()
	var state_label := ProfileStatsView.make_text(state, 22, TerminalTheme.GREEN_BRIGHT if online and not account.email().is_empty() else TerminalTheme.GREEN_DIM)
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_info_row("Angemeldet", state_label))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	parent.add_child(actions)
	menu._add_menu_button(actions, "PROFILBILD", "Porträts und Symbole – auch im Arsenal", avatar_action)
	if online:
		if account.email().is_empty():
			menu._add_menu_button(actions, "ANMELDEN", "Mit Google oder E-Mail", show_login)
		else:
			if account.username().is_empty():
				menu._add_menu_button(actions, "NAME WÄHLEN", "Brauchst du für Freunde und Ranked", show_choose_username)
			menu._add_menu_button(actions, "ABMELDEN", "Dieses Gerät vom Konto trennen", _confirm_logout)
	for child: Node in actions.get_children():
		(child as Button).add_theme_font_size_override("font_size", 30)


func _info_row(title: String, value: Control) -> Control:
	var row := HBoxContainer.new()
	var name_label := ProfileStatsView.make_text(title, 22, TerminalTheme.GREEN)
	name_label.custom_minimum_size.x = 170.0
	row.add_child(name_label)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)
	return row


## Status and login buttons for the profile page.
func add_section(parent: Control) -> void:
	if not account.has_account() or account.account.is_empty():
		parent.add_child(menu._make_text("KONTO: offline – Anmelden geht, sobald du online bist.", 22, TerminalTheme.GREEN_DIM))
		return
	if account.email().is_empty():
		parent.add_child(menu._make_text("GAST – melde dich an, dann hast du Credits und Käufe auf jedem Gerät.", 22, TerminalTheme.GREEN_DIM))
		menu._add_menu_button(parent, "ANMELDEN", "Mit Google oder E-Mail", show_login)
	else:
		parent.add_child(menu._make_text("ANGEMELDET: " + account.email(), 22, TerminalTheme.GREEN_BRIGHT))
		if account.username().is_empty():
			menu._add_menu_button(parent, "BENUTZERNAMEN WÄHLEN", "Brauchst du für Freunde und Ranked", show_choose_username)
		menu._add_menu_button(parent, "ABMELDEN", "Dieses Gerät vom Konto trennen", _confirm_logout)


func show_login() -> void:
	menu._set_page("ANMELDEN", menu._show_profile)
	menu._content.add_child(menu._make_text("Neu hier? Beim Registrieren wird dein bisheriger Fortschritt auf diesem Gerät dein Konto.", 22, TerminalTheme.GREEN_DIM))
	menu._add_menu_button(menu._content, "MIT GOOGLE", "Öffnet die Google-Anmeldung in einem neuen Fenster", _google)
	menu._add_menu_button(menu._content, "MIT E-MAIL", "Du hast schon ein Konto", show_email.bind(false))
	menu._add_menu_button(menu._content, "REGISTRIEREN", "Neues Konto mit E-Mail und Passwort", show_email.bind(true))
	menu._content.add_child(menu._make_text("Mit Apple anmelden kommt später.", 22, TerminalTheme.GREEN_DIM))
	menu._add_menu_button(menu._content, "< ZURÜCK", "Zum Profil", menu._show_profile)
	menu._focus_first_entry()


func show_email(register: bool) -> void:
	menu._set_page("REGISTRIEREN" if register else "E-MAIL", show_login)
	menu._content.add_child(menu._make_text("E-MAIL", MainMenu.TEXT_FONT_SIZE, TerminalTheme.GREEN_DIM))
	var address := _field("du@beispiel.de", false)
	menu._content.add_child(menu._make_text("PASSWORT" + (" (mindestens 8 Zeichen)" if register else ""), MainMenu.TEXT_FONT_SIZE, TerminalTheme.GREEN_DIM))
	var password := _field("", true)
	var status := menu._make_text("", MainMenu.TEXT_FONT_SIZE, TerminalTheme.GREEN_BRIGHT)
	if not register:
		menu._content.add_child(menu._make_text("Achtung: Der Gast-Fortschritt auf diesem Gerät wird durch dein Konto ersetzt.", 22, TerminalTheme.GREEN_DIM))
	menu._add_menu_button(menu._content, "KONTO ANLEGEN" if register else "ANMELDEN", "Weiter", func() -> void:
		if password.text.length() < 8:
			status.text = "Das Passwort braucht mindestens 8 Zeichen."
			return
		status.text = "Einen Moment ..."
		if register:
			await account.register(address.text.strip_edges(), password.text)
		else:
			await account.login(address.text.strip_edges(), password.text)
		if account._last_error.is_empty():
			_signed_in()
		elif status.is_inside_tree():
			status.text = _error_text(account._last_error))
	menu._content.add_child(status)
	menu._add_menu_button(menu._content, "< ZURÜCK", "Andere Anmeldung wählen", show_login)


func _google() -> void:
	ExternalWindow.reserve("Google wird geöffnet …")
	menu._set_page("GOOGLE", show_login)
	var status := menu._make_text("Google wird geöffnet ...", MainMenu.TEXT_FONT_SIZE)
	menu._content.add_child(status)
	menu._add_menu_button(menu._content, "< ZURÜCK", "Abbrechen", show_login)
	var start := await account.begin_google()
	if start.is_empty():
		ExternalWindow.release()
		status.text = _error_text(account._last_error)
		return
	var mode := ExternalWindow.open(str(start["url"]))
	if mode == "page":
		return
	status.text = "Melde dich im neuen Fenster bei Google an. Dieses hier bleibt offen und macht danach weiter."
	var waited := 0.0
	while waited < GOOGLE_WAIT_SECONDS and status.is_inside_tree():
		await menu.get_tree().create_timer(GOOGLE_POLL_SECONDS).timeout
		waited += GOOGLE_POLL_SECONDS
		if not status.is_inside_tree():
			return
		if await account.collect_google(str(start["nonce"])):
			_signed_in()
			return
		if account._last_error == "expired":
			break
	if status.is_inside_tree():
		status.text = "Die Anmeldung ist abgelaufen. Versuch es nochmal."


func _signed_in() -> void:
	menu.adopt_account_profile()
	if account.username().is_empty():
		show_choose_username()
	else:
		menu._show_profile()


## Once per account: the name others see, for good.
func show_choose_username() -> void:
	menu._set_page("BENUTZERNAME", menu._show_profile)
	menu._content.add_child(menu._make_text("Wähle deinen Namen im Grid. Freunde finden dich darüber, und er steht in der Rangliste.", MainMenu.TEXT_FONT_SIZE))
	menu._content.add_child(menu._make_text("3 bis 16 Zeichen: Buchstaben, Ziffern, _ . Achtung: Du kannst ihn danach NIE mehr ändern.", 22, TerminalTheme.GREEN_DIM))
	var field := _field("z. B. NeoRunner", false)
	field.max_length = 16
	var status := menu._make_text("", MainMenu.TEXT_FONT_SIZE, TerminalTheme.GREEN_BRIGHT)
	menu._add_menu_button(menu._content, "FESTLEGEN", "Dieser Name gehört dann dir", func() -> void:
		var wanted := field.text.strip_edges()
		if not RegEx.create_from_string("^[A-Za-z0-9_]{3,16}$").search(wanted):
			status.text = "3 bis 16 Zeichen, nur Buchstaben, Ziffern und _."
			return
		status.text = "Prüfe ..."
		await account.choose_username(wanted)
		if account._last_error.is_empty():
			menu.adopt_account_profile()
			menu._show_profile()
		elif status.is_inside_tree():
			status.text = _error_text(account._last_error))
	menu._content.add_child(status)
	menu._add_menu_button(menu._content, "SPÄTER", "Ohne Namen keine Freunde und kein Ranked", menu._show_profile)
	field.grab_focus.call_deferred()


func _confirm_logout() -> void:
	menu._set_page("ABMELDEN", menu._show_profile)
	menu._content.add_child(menu._make_text("Auf diesem Gerät spielst du danach als neuer Gast weiter. Dein Konto bleibt erhalten – melde dich einfach wieder an.", MainMenu.TEXT_FONT_SIZE))
	menu._add_menu_button(menu._content, "JA, ABMELDEN", "Dieses Gerät trennen", func() -> void:
		await account.logout()
		menu.adopt_account_profile()
		menu._show_profile())
	menu._add_menu_button(menu._content, "< ZURÜCK", "Angemeldet bleiben", menu._show_profile)
	menu._focus_first_entry(1)


func _field(placeholder: String, secret: bool) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.secret = secret
	field.max_length = 128 if secret else 254
	field.custom_minimum_size.y = 52.0
	field.add_theme_font_size_override("font_size", 30)
	field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD if secret else LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	menu._content.add_child(field)
	WebTextInput.attach(field, placeholder)
	return field


func _error_text(error: String) -> String:
	match error:
		"bad_email":
			return "Das sieht nicht nach einer E-Mail-Adresse aus."
		"bad_password":
			return "Das Passwort braucht 8 bis 128 Zeichen."
		"email_taken":
			return "Diese E-Mail hat schon ein Konto. Melde dich mit „MIT E-MAIL“ an."
		"wrong_login":
			return "E-Mail oder Passwort stimmt nicht."
		"locked":
			return "Zu viele Versuche. Warte 15 Minuten."
		"username_taken":
			return "Den Namen gibt es schon. Versuch einen anderen."
		"username_set":
			return "Du hast schon einen Namen."
		"bad_username":
			return "3 bis 16 Zeichen, nur Buchstaben, Ziffern und _."
		"google_off":
			return "Google-Anmeldung ist noch nicht eingerichtet."
		"offline":
			return "Keine Verbindung zum Server."
	return "Fehler: %s" % error
