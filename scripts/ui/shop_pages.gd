class_name ShopPages
extends RefCounted

## The menu pages around the player's account: the shop, the buy dialog and
## the account code for moving to another device. They are drawn into the
## MainMenu's terminal frame with its page helpers.

const KIND_NAMES := {"character": "Charakter", "skin": "Skin", "echo": "Echos", "board": "Spielfeld"}

var menu: MainMenu
var account: AccountService


func _init(owner_menu: MainMenu, owner_account: AccountService) -> void:
	menu = owner_menu
	account = owner_account


func show_shop() -> void:
	menu._set_page("SHOP", menu._show_home)
	if not account.has_account() or account.account.is_empty():
		_offline_notice(show_shop)
		return
	menu._content.add_child(menu._make_text("CREDITS: %d" % account.credits(), MainMenu.TEXT_FONT_SIZE, TerminalTheme.GREEN_BRIGHT))
	menu._content.add_child(menu._make_text("Credits gibt es für Siege gegen den Bot (+10 / +20 / +40, bis zu 15 pro Tag) und jeden Tag +25 Bonus.", 22, TerminalTheme.GREEN_DIM))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 470.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu._content.add_child(scroll)
	var list := VBoxContainer.new()
	scroll.add_child(list)
	var offered := 0
	var heading := ""
	for item: String in CharacterRoster.PRICES:
		if AccountService.owns(item):
			continue
		# Skins are offered once their character is unlocked.
		if item.begins_with("skin:") and not AccountService.owns(CharacterRoster.item_id("character", str(CharacterSkins.skin(item.get_slice(":", 1))["character"]))):
			continue
		offered += 1
		var kind := item.get_slice(":", 0)
		if kind != heading:
			heading = kind
			list.add_child(menu._make_text("// " + str(KIND_NAMES[kind]).to_upper(), 22, TerminalTheme.GREEN_DIM))
		menu._add_menu_button(list, "%s  %d CR" % [item_name(item), CharacterRoster.PRICES[item]],
			"%s – %s" % [KIND_NAMES[item.get_slice(":", 0)], _entry(item)["line"]], confirm_buy.bind(item, show_shop))
	if offered == 0:
		list.add_child(menu._make_text("Du hast schon alles. Respekt.", MainMenu.TEXT_FONT_SIZE))
	menu._add_menu_button(menu._content, "< ZURÜCK", "Zum Hauptmenü", menu._show_home)
	menu._focus_first_entry()


## Asks before spending credits; back_action is where "back" and a finished purchase go.
func confirm_buy(item: String, back_action: Callable) -> void:
	menu._set_page("KAUFEN", back_action)
	if not account.has_account() or account.account.is_empty():
		_offline_notice(confirm_buy.bind(item, back_action))
		return
	var price := int(CharacterRoster.PRICES[item])
	menu._content.add_child(menu._make_text("%s (%s)" % [item_name(item), KIND_NAMES[item.get_slice(":", 0)]], 34, TerminalTheme.GREEN_BRIGHT))
	menu._content.add_child(menu._make_text(str(_entry(item)["line"]), 22, TerminalTheme.GREEN_DIM))
	menu._content.add_child(menu._make_text("Preis: %d Credits   ·   Du hast: %d" % [price, account.credits()], MainMenu.TEXT_FONT_SIZE))
	var status := menu._make_text("", MainMenu.TEXT_FONT_SIZE, TerminalTheme.GREEN_BRIGHT)
	if account.credits() < price:
		status.text = "Dir fehlen noch %d Credits." % (price - account.credits())
	else:
		menu._add_menu_button(menu._content, "JA, KAUFEN", "%d Credits ausgeben" % price, func() -> void:
			status.text = "Kaufe ..."
			await account.buy(item)
			if AccountService.owns(item):
				# Wear it straight away.
				CharacterRoster.equip(item)
				back_action.call()
			else:
				status.text = _error_text(account._last_error))
	menu._content.add_child(status)
	menu._add_menu_button(menu._content, "< ZURÜCK", "Nicht kaufen", back_action)
	menu._focus_first_entry()


## Credits and the account code on the profile page.
func add_account_section(parent: Control) -> void:
	if not account.has_account() or account.account.is_empty():
		parent.add_child(menu._make_text("KONTO: offline – Name und Käufe werden verbunden, sobald du online bist.", 22, TerminalTheme.GREEN_DIM))
		return
	parent.add_child(menu._make_text("CREDITS: %d" % account.credits(), MainMenu.TEXT_FONT_SIZE, TerminalTheme.GREEN_BRIGHT))
	menu._add_menu_button(parent, "KONTO-CODE", "Damit holst du dein Konto auf ein anderes Gerät", show_code)


func show_code() -> void:
	menu._set_page("KONTO", menu._show_profile)
	menu._content.add_child(menu._make_text("DEIN KONTO-CODE", MainMenu.TEXT_FONT_SIZE, TerminalTheme.GREEN_DIM))
	menu._content.add_child(menu._make_text(account.code, 54, TerminalTheme.GREEN_BRIGHT))
	menu._content.add_child(menu._make_text("Schreib ihn dir auf und zeig ihn niemandem: Wer den Code hat, hat dein Konto mit allen Käufen. Auf einem neuen Gerät gibst du ihn unter „CODE EINGEBEN“ ein.", 22, TerminalTheme.GREEN_DIM))
	menu._add_menu_button(menu._content, "CODE EINGEBEN", "Ein Konto von einem anderen Gerät holen", show_restore)
	menu._add_menu_button(menu._content, "< ZURÜCK", "Zum Profil", menu._show_profile)
	menu._focus_first_entry(1)


func show_restore() -> void:
	menu._set_page("CODE EINGEBEN", show_code)
	menu._content.add_child(menu._make_text("Das Konto auf diesem Gerät wird ersetzt. Merk dir vorher seinen Code, wenn du es behalten willst.", 22, TerminalTheme.GREEN_DIM))
	var input := LineEdit.new()
	input.max_length = 14
	input.placeholder_text = "XXXX-XXXX-XXXX"
	input.custom_minimum_size.y = 52.0
	input.add_theme_font_size_override("font_size", 36)
	menu._content.add_child(input)
	var status := menu._make_text("", MainMenu.TEXT_FONT_SIZE, TerminalTheme.GREEN_BRIGHT)
	menu._add_menu_button(menu._content, "KONTO HOLEN", "Mit diesem Code anmelden", func() -> void:
		status.text = "Suche Konto ..."
		await account.use_code(input.text)
		if account._last_error.is_empty():
			menu.adopt_account_profile()
			menu._show_profile()
		else:
			status.text = _error_text(account._last_error))
	menu._content.add_child(status)
	menu._add_menu_button(menu._content, "< ZURÜCK", "Zum Konto-Code", show_code)
	input.grab_focus.call_deferred()


func item_name(item: String) -> String:
	return str(_entry(item)["name"])


func _entry(item: String) -> Dictionary:
	var id := item.get_slice(":", 1)
	match item.get_slice(":", 0):
		"skin":
			var skin := CharacterSkins.skin(id)
			return {"name": "%s · %s" % [CharacterRoster.character(str(skin["character"]))["name"], skin["name"]], "line": skin["line"]}
		"character":
			return CharacterRoster.character(id)
		"echo":
			return CharacterRoster.echo_style(id)
	return CharacterRoster.board_skin(id)


func _offline_notice(retry: Callable) -> void:
	menu._content.add_child(menu._make_text("Keine Verbindung zum Server. Für Credits und Käufe musst du online sein.", MainMenu.TEXT_FONT_SIZE))
	menu._add_menu_button(menu._content, "NOCHMAL VERSUCHEN", "Mit dem Server verbinden", func() -> void:
		await account.connect_account()
		retry.call())
	menu._add_menu_button(menu._content, "< ZURÜCK", "Zum Hauptmenü", menu._show_home)
	menu._focus_first_entry()


func _error_text(error: String) -> String:
	match error:
		"not_enough_credits":
			return "Nicht genug Credits."
		"owned":
			return "Gehört dir schon."
		"needs_character":
			return "Kauf zuerst den Charakter."
		"no_account":
			return "Diesen Code gibt es nicht."
		"offline":
			return "Keine Verbindung zum Server."
	return "Fehler: %s" % error
