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
	var grid := _tile_grid(2)
	for slot: int in range(loadout.size()):
		var emote := EmoteWheel.entry(loadout[slot])
		_add_tile(grid, "%d  %s" % [slot + 1, emote["text"]], "%s – %s" % [SLOT_NAMES[slot], _describe(emote)], show_choices.bind(slot), EmoteWheel.KIND_COLORS[str(emote["kind"])])
	menu._add_menu_button(menu._content, "STANDARD", "Alle Plätze zurücksetzen", func() -> void:
		EmoteWheel.save_loadout(EmoteWheel.DEFAULT_LOADOUT.duplicate())
		show_slots())
	menu._add_menu_button(menu._content, "< ZURÜCK", "Zum Arsenal", menu._show_collection)
	menu._focus_first_entry()


## Every emote as a tile, grouped by kind, three side by side.
func show_choices(slot: int) -> void:
	menu._set_page("PLATZ %d: %s" % [slot + 1, SLOT_NAMES[slot]], show_slots)
	var current := EmoteWheel.load_loadout()[slot]
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 620.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu._content.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	var selected: Button
	for kind: String in EmoteWheel.KIND_NAMES:
		list.add_child(menu._make_text("-- %s --" % EmoteWheel.KIND_NAMES[kind], MainMenu.TEXT_FONT_SIZE, EmoteWheel.KIND_COLORS[kind]))
		var grid := _tile_grid(3, list)
		for emote: Dictionary in EmoteWheel.CATALOGUE:
			if emote["kind"] == kind:
				var mark := "* " if emote["id"] == current else ""
				var tile := _add_tile(grid, mark + str(emote["text"]), _describe(emote), _choose.bind(slot, str(emote["id"])), EmoteWheel.KIND_COLORS[kind])
				if emote["id"] == current:
					selected = tile
	menu._add_menu_button(menu._content, "< ZURÜCK", "Zu den Plätzen", show_slots)
	if selected != null:
		selected.grab_focus.call_deferred()


func _tile_grid(columns: int, parent: Control = null) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	(parent if parent != null else menu._content).add_child(grid)
	return grid


func _add_tile(grid: GridContainer, title: String, subtitle: String, action: Callable, color: Color) -> Button:
	menu._add_menu_button(grid, title, subtitle, action)
	var tile := grid.get_child(grid.get_child_count() - 1) as Button
	tile.alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.custom_minimum_size = Vector2(0.0, 84.0)
	tile.clip_text = true
	tile.add_theme_color_override("font_color", color)
	return tile


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
