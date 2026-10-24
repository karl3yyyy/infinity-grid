class_name ProfileStatsView
extends RefCounted

## The profile's statistics as tiles: totals, ranked and online records, the
## System Log counters and the last duels. Reads MatchStats only.


static func build(parent: Control) -> void:
	var ranked_played := MatchStats.get_count("ranked_played")
	var ranked_won := MatchStats.get_count("ranked_won")
	var online_played := MatchStats.get_count("online_played")
	var online_won := MatchStats.get_count("online_won")
	var played := ranked_played + online_played
	var won := ranked_won + online_won
	var fastest := MatchStats.get_count("fastest_win")

	_access_level(parent)
	_row(parent, [
		[str(played), "Duelle", TerminalTheme.GREEN_BRIGHT],
		[MatchStats.percent(won, played), "Siegquote", Color("7fe3ff")],
		[str(won), "Siege", TerminalTheme.GREEN],
	])
	_row(parent, [
		[str(MatchStats.get_count("streak")), "Serie", Color("ffd36e")],
		[str(MatchStats.get_count("best_streak")), "Beste Serie", Color("ffb347")],
		["--" if fastest == 0 else str(fastest), "Schnellster Sieg", Color("ff8a5c")],
	])
	_record(parent, "RANKED", Color("7fe3ff"), ranked_played, ranked_won)
	_record(parent, "SCHNELLES SPIEL", Color("ffb347"), online_played, online_won)

	var lethal := MatchStats.most_lethal_card()
	_log_panel(parent, [
		["Nodes Claimed", str(MatchStats.get_count("nodes_claimed"))],
		["Initiative Accuracy", MatchStats.percent(MatchStats.get_count("ping_wins"), MatchStats.get_count("pings"))],
		["Most Lethal Protocol", lethal.to_upper() if not lethal.is_empty() else "--"],
	])

	parent.add_child(make_text("LETZTE DUELLE", 22, TerminalTheme.GREEN_DIM))
	var recent := MatchStats.recent()
	if recent.is_empty():
		parent.add_child(make_text("Noch keins. Das Grid wartet.", 22, TerminalTheme.GREEN_DIM))
	for entry: Dictionary in recent:
		_duel(parent, entry)


## Level, title and emblem in the tier's colour with a bar to the next level.
static func _access_level(parent: Control) -> void:
	var xp := AccessLevel.total_xp()
	var level := AccessLevel.level_for(xp)
	var tint := AccessLevel.color(level)
	var panel := make_panel()
	var frame := panel.get_theme_stylebox("panel") as StyleBoxFlat
	frame.border_color = tint
	frame.set_border_width_all(3)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_child(make_text("ACCESS LEVEL %02d" % level, 34, tint))
	names.add_child(make_text(AccessLevel.title(level), 24, TerminalTheme.GREEN_BRIGHT))
	head.add_child(names)
	head.add_child(make_text(AccessLevel.emblem(level), 44, tint))
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.value = AccessLevel.progress(xp)
	bar.show_percentage = false
	bar.custom_minimum_size.y = 14.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = tint
	var back := StyleBoxFlat.new()
	back.bg_color = Color(tint, 0.15)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	box.add_child(bar)
	var next_text := "MAX LEVEL" if level >= AccessLevel.MAX_LEVEL else "%d / %d XP bis Level %02d" % [xp - AccessLevel.xp_for_level(level), AccessLevel.xp_for_level(level + 1) - AccessLevel.xp_for_level(level), level + 1]
	box.add_child(make_text(next_text, 18, TerminalTheme.GREEN_DIM))


static func _row(parent: Control, tiles: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	for tile: Array in tiles:
		var panel := make_panel()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(panel)
		var column := VBoxContainer.new()
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(column)
		column.add_child(make_text(str(tile[0]), 42, tile[2], true))
		column.add_child(make_text(str(tile[1]), 18, TerminalTheme.GREEN_DIM, true))


static func _record(parent: Control, title: String, color: Color, played: int, won: int) -> void:
	var panel := make_panel()
	parent.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(make_text(title, 20, color))
	var row := HBoxContainer.new()
	box.add_child(row)
	for cell: Array in [[str(played), "Gespielt"], [str(won), "Gewonnen"], [str(played - won), "Verloren"], [MatchStats.percent(won, played), "Siegquote"]]:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_child(make_text(str(cell[0]), 32, TerminalTheme.GREEN_BRIGHT, true))
		column.add_child(make_text(str(cell[1]), 16, TerminalTheme.GREEN_DIM, true))
		row.add_child(column)


static func _log_panel(parent: Control, rows: Array) -> void:
	var panel := make_panel()
	parent.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(make_text("SYSTEM LOG", 20, TerminalTheme.GREEN_DIM))
	for entry: Array in rows:
		var line := HBoxContainer.new()
		box.add_child(line)
		var name_label := make_text(str(entry[0]), 22, TerminalTheme.GREEN)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		line.add_child(make_text(str(entry[1]), 22, TerminalTheme.GREEN_BRIGHT))


static func _duel(parent: Control, entry: Dictionary) -> void:
	var panel := make_panel()
	parent.add_child(panel)
	var line := HBoxContainer.new()
	panel.add_child(line)
	var won := bool(entry.get("won", false))
	var mode := "Ranked" if str(entry.get("mode", "")) == "ranked" else "Schnelles Spiel"
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(make_text("SIEG" if won else "NIEDERLAGE", 26, TerminalTheme.GREEN_BRIGHT if won else Color("ff6a55")))
	left.add_child(make_text("%s  ·  %d Züge" % [mode, int(entry.get("moves", 0))], 18, TerminalTheme.GREEN_DIM))
	line.add_child(left)
	line.add_child(make_text(_ago(int(entry.get("at", 0))), 18, TerminalTheme.GREEN_DIM))


static func _ago(timestamp: int) -> String:
	var seconds := int(Time.get_unix_time_from_system()) - timestamp
	if seconds < 90:
		return "gerade eben"
	if seconds < 3600:
		return "vor %d Min" % (seconds / 60)
	if seconds < 86400:
		return "vor %d Std" % (seconds / 3600)
	return "vor %d Tagen" % (seconds / 86400)


static func make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(TerminalTheme.GREEN, 0.06)
	box.border_color = TerminalTheme.GREEN_DIM
	box.set_border_width_all(2)
	box.set_content_margin_all(12.0)
	panel.add_theme_stylebox_override("panel", box)
	return panel


static func make_text(value: String, size: int, color: Color, centered: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label
