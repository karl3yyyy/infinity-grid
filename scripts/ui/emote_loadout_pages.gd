class_name EmoteLoadoutPages
extends RefCounted

## Sammlung > EMOTE-RAD: shows the eight wheel slots; picking a slot lists
## every emote (dances, lines, stickers) to put there. Saved on the device.

const SLOT_NAMES: Array[String] = ["OBEN", "OBEN RECHTS", "RECHTS", "UNTEN RECHTS", "UNTEN", "UNTEN LINKS", "LINKS", "OBEN LINKS"]

var menu: MainMenu


func _init(owner_menu: MainMenu) -> void:
	menu = owner_menu


func summary() -> String:
	var names: Array[String] = []
	for emote_id: String in EmoteWheel.load_loadout():
		names.append(EmoteWheel.entry(emote_id)["text"])
	return "Dein Rad: " + ", ".join(names)


func show_slots() -> void:
	menu._set_page("EMOTE-RAD", menu._show_collection)
	menu._content.add_child(menu._make_text("Nur dein KERN macht Emotes: TANZ, SPRUCH mit Stimme oder STICKER. Wähle einen Platz im Rad.", MainMenu.TEXT_FONT_SIZE, TerminalTheme.GREEN_DIM))
	var loadout := EmoteWheel.load_loadout()
	for slot: int in range(loadout.size()):
		var emote := EmoteWheel.entry(loadout[slot])
		menu._add_menu_button(menu._content, "%d  %s" % [slot + 1, emote["text"]], "%s – %s" % [SLOT_NAMES[slot], _describe(emote)], show_choices.bind(slot))
	menu._add_menu_button(menu._content, "STANDARD", "Alle Plätze zurücksetzen", func() -> void:
		EmoteWheel.save_loadout(EmoteWheel.DEFAULT_LOADOUT.duplicate())
		show_slots())
	menu._add_menu_button(menu._content, "< ZURÜCK", "Zur Sammlung", menu._show_collection)
	menu._focus_first_entry()


func show_choices(slot: int) -> void:
	menu._set_page("PLATZ %d: %s" % [slot + 1, SLOT_NAMES[slot]], show_slots)
	var current := EmoteWheel.load_loadout()[slot]
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 620.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu._content.add_child(scroll)
	var list := VBoxContainer.new()
	scroll.add_child(list)
	for kind: String in EmoteWheel.KIND_NAMES:
		list.add_child(menu._make_text("-- %s --" % EmoteWheel.KIND_NAMES[kind], MainMenu.TEXT_FONT_SIZE, EmoteWheel.KIND_COLORS[kind]))
		for emote: Dictionary in EmoteWheel.CATALOGUE:
			if emote["kind"] == kind:
				var mark := "* " if emote["id"] == current else ""
				menu._add_menu_button(list, mark + str(emote["text"]), _describe(emote), _choose.bind(slot, str(emote["id"])))
	menu._add_menu_button(menu._content, "< ZURÜCK", "Zu den Plätzen", show_slots)
	for child: Node in list.get_children():
		if child is Button and (child as Button).text.begins_with("* "):
			(child as Button).grab_focus.call_deferred()


func _choose(slot: int, emote_id: String) -> void:
	var loadout := EmoteWheel.load_loadout()
	# An emote sits on one slot only: the old slot gets the replaced emote.
	var previous := loadout.find(emote_id)
	if previous >= 0:
		loadout[previous] = loadout[slot]
	loadout[slot] = emote_id
	EmoteWheel.save_loadout(loadout)
	show_slots()


static func _describe(emote: Dictionary) -> String:
	match str(emote["kind"]):
		"dance":
			return "Tanz: dein KERN legt los"
		"voice":
			return 'Spruch: "%s"' % emote["line"]
	return "Sticker über deinem KERN"
