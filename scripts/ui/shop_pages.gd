class_name ShopPages
extends RefCounted

## The shop pages: cosmetics for credits, credit packs for real money and the
## buy dialog, drawn into the MainMenu's terminal frame with its page helpers.

const KIND_NAMES := {"character": "Charakter", "skin": "Skin", "echo": "Echos", "board": "Spielfeld", "cards": "Karten"}
const KIND_BADGES := {"character": "KERN", "skin": "SKIN", "echo": "ECHO", "board": "FELD", "cards": "KART"}

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
	ShopTiles.banner(menu, _credits_label(), GridLore.SHOP_LORE)
	var daily := account.shop_daily()
	var weekly := account.shop_weekly()
	if daily.is_empty() and weekly.is_empty():
		menu._content.add_child(menu._make_text("Der Cache ist leer. Das Grid sortiert gerade um, schau gleich nochmal vorbei.", MainMenu.TEXT_FONT_SIZE))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 560.0
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu._content.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if not daily.is_empty():
		list.add_child(_heading("TAGESCACHE"))
		list.add_child(_countdown_label("daily"))
		for item: String in daily:
			_offer(list, item, true)
	if not weekly.is_empty():
		list.add_child(_heading("WOCHEN-DEFRAG"))
		list.add_child(_countdown_label("weekly"))
		for item: String in weekly:
			_offer(list, item, false)
	if not account.packs().is_empty():
		list.add_child(_heading("CREDITS"))
		menu._add_menu_button(list, "CREDITS KAUFEN", "Pakete über Stripe", show_credit_packs)
	var bottom := MenuCards.chip_row(menu)
	MenuCards.chip(menu, bottom, "ZUM ARSENAL", "Gekauftes anlegen und ansehen", menu._show_collection)
	MenuCards.chip(menu, bottom, "< ZURÜCK", "Zum Hauptmenü", menu._show_home)
	menu._focus_first_entry()


## One offer in the shop list: the daily one as a spotlight, weekly ones as cards.
## What the player owns already leads to the collection instead.
func _offer(list: Control, item: String, spotlight: bool) -> void:
	var owned := AccountService.owns(item)
	var price := int(CharacterRoster.PRICES[item])
	var action: Callable = menu._show_collection if owned else confirm_buy.bind(item, show_shop)
	var price_text := "IM BESITZ" if owned else "%d CR" % price
	var hint := "%s%s" % [_entry(item)["line"], "" if owned else _level_hint(item)]
	if spotlight:
		ShopTiles.spotlight(menu, list, item, "NUR HEUTE", item_name(item), str(_entry(item)["line"]), price_text, hint, action)
		return
	var kind := item.get_slice(":", 0)
	var title := str(CharacterSkins.skin(item.get_slice(":", 1)).get("name", "")) if kind == "skin" else item_name(item)
	ShopTiles.spotlight(menu, list, item, str(KIND_NAMES[kind]), title, str(_entry(item)["line"]), price_text, hint, action, false)


## "Noch 2 T 05:13:09" until the daily or weekly offers rotate; ticks while the page is open.
func _countdown_label(kind: String) -> Label:
	var label := menu._make_text("", 22, ShopTiles.GOLD)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var tick := func() -> void:
		var seconds := int(account.shop_seconds_left(kind))
		var days := seconds / 86400
		var clock := "%02d:%02d:%02d" % [(seconds % 86400) / 3600, (seconds % 3600) / 60, seconds % 60]
		label.text = "Noch %s%s" % ["%d T " % days if days > 0 else "", clock]
	tick.call()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(tick)
	label.add_child(timer)
	return label


func show_credit_packs() -> void:
	menu._set_page("CREDITS KAUFEN", show_shop)
	menu._content.add_child(_credits_label())
	var best: Dictionary = {}
	for pack: Dictionary in account.packs():
		if best.is_empty() or float(pack["credits"]) > float(best["credits"]):
			best = pack
	for pack: Dictionary in account.packs():
		var is_best := pack == best and account.packs().size() > 1
		MenuCards.card(menu, "+", "%d CREDITS" % int(pack["credits"]), "Für neue Charaktere, Skins, Echos und Spielfelder." if is_best else "Bezahlen über Stripe",
			"Bezahlen mit Karte & Co. über Stripe", buy_pack.bind(pack), str(pack["label"]), is_best, ShopTiles.GOLD)
	menu._add_menu_button(menu._content, "< ZURÜCK", "Zum Shop", show_shop)
	menu._focus_first_entry()


## " · oder ab Level 25" for items the Access Level unlocks for free.
static func _level_hint(item: String) -> String:
	var needed := AccessLevel.unlock_level(item)
	return "  ·  oder ab Level %d" % needed if needed > 0 else ""


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


## Real-money purchase of a credit pack on Stripe's checkout page. The credits
## arrive when Stripe tells the server, never from the game itself; this page
## stays open meanwhile and picks them up.
func buy_pack(pack: Dictionary) -> void:
	ExternalWindow.reserve("Kasse wird geöffnet …")
	menu._set_page("KASSE", show_shop)
	menu._content.add_child(menu._make_text("+%d CREDITS für %s" % [int(pack["credits"]), str(pack["label"])], 34, TerminalTheme.GREEN_BRIGHT))
	var status := menu._make_text("Kasse wird geöffnet ...", MainMenu.TEXT_FONT_SIZE)
	menu._content.add_child(status)
	menu._content.add_child(menu._make_text("Bezahlt wird bei Stripe, unserem Zahlungsanbieter. Wir sehen deine Zahlungsdaten nie.", 22, TerminalTheme.GREEN_DIM))
	menu._add_menu_button(menu._content, "< ZURÜCK", "Zum Shop", show_shop)
	var before := account.credits()
	var details := await account.start_checkout(str(pack["id"]))
	if details.is_empty():
		ExternalWindow.release()
		status.text = _error_text(account._last_error)
		return
	match ExternalWindow.open(str(details.get("url", ""))):
		"page":
			status.text = "Weiter zu Stripe ..."
			return
		"window":
			status.text = "Bezahle im neuen Fenster. Lass dieses hier offen – die Credits kommen dann von selbst."
		_:
			status.text = "Die Kasse ist im Browser offen. Die Credits kommen hier von selbst an."
	menu._add_menu_button(menu._content, "GUTHABEN PRÜFEN", "Credits jetzt abholen", func() -> void:
		await _wait_for_credits(before, status, 1))
	# Paying takes a while; keep asking the server as long as this page is open.
	await _wait_for_credits(before, status, 150, false)


## Asks the server until the balance rose above `before` or the page closed.
## announce = false keeps the current status text while waiting.
func _wait_for_credits(before: int, status: Label, attempts: int, announce: bool = true) -> void:
	if announce:
		status.text = "Credits werden abgeholt ..."
	for attempt: int in range(attempts):
		if not status.is_inside_tree():
			return
		await account.connect_account()
		# Today's login bonus can arrive with the same answer; it is not the purchase.
		before += int(account.account.get("bonus", 0))
		if account.credits() > before:
			if status.is_inside_tree():
				status.text = "Danke! +%d Credits. Du hast jetzt %d." % [account.credits() - before, account.credits()]
			return
		await menu.get_tree().create_timer(4.0).timeout
	if announce and status.is_inside_tree():
		status.text = "Noch keine Credits da. Das kann eine Minute dauern – schau gleich nochmal ins Profil."


## The credit balance on the profile page (logins are in LoginPages).
func add_account_section(parent: Control) -> void:
	if account.has_account() and not account.account.is_empty():
		parent.add_child(_credits_label())


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
		"cards":
			return CardSkins.skin(id)
	return CharacterRoster.board_skin(id)


func _offline_notice(retry: Callable) -> void:
	menu._content.add_child(menu._make_text("Keine Verbindung zum Server. Das Grid ist gerade im Funkloch. Für Credits und Käufe musst du online sein.", MainMenu.TEXT_FONT_SIZE))
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
		"payments_off":
			return "Echtgeld-Käufe sind gerade ausgeschaltet."
		"not_in_rotation":
			return "Gerade nicht im Cache. Schau täglich vorbei, das Grid sortiert um."
		"payment_failed":
			return "Die Kasse konnte nicht erstellt werden. Versuch es gleich nochmal."
	return "Fehler: %s" % error


## Section title inside the scrolling list. Without wrapping: a wrapping label
## in the scroll list asks for the whole page width and pushes the menu wider.
func _heading(text: String) -> Label:
	var label := menu._make_text("// " + text, 22, TerminalTheme.GREEN_DIM)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


## Credit balance that follows the account; opening it also asks the server
## again, so credits bought or earned elsewhere show up without a restart.
func _credits_label() -> Label:
	var label := menu._make_text("CREDITS: %d" % account.credits(), MainMenu.TEXT_FONT_SIZE, TerminalTheme.GREEN_BRIGHT)
	var update := func() -> void: label.text = "CREDITS: %d" % account.credits()
	account.changed.connect(update)
	# Stop listening when the page goes away.
	label.tree_exiting.connect(func() -> void: account.changed.disconnect(update))
	account.refresh_if_stale()
	return label
