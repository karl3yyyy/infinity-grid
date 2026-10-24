class_name MatchStats
extends RefCounted

## The local "System Log": counts kept on this device for the profile page.
## Only the player's own moves and results count (not hot-seat matches).

const PATH := "user://ring_duel_profile.cfg"
const SECTION := "stats"
const RECENT_LIMIT: int = 10


static func add(key: String, amount: int = 1) -> void:
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value(SECTION, key, int(config.get_value(SECTION, key, 0)) + amount)
	config.save(PATH)


static func get_count(key: String) -> int:
	var config := ConfigFile.new()
	config.load(PATH)
	return int(config.get_value(SECTION, key, 0))


## One finished match against the bot ("bot") or a person ("online").
static func record_match(mode: String, won: bool, moves: int) -> void:
	var config := ConfigFile.new()
	config.load(PATH)
	var played := "%s_played" % mode
	config.set_value(SECTION, played, int(config.get_value(SECTION, played, 0)) + 1)
	var streak := 0
	if won:
		var wins := "%s_won" % mode
		config.set_value(SECTION, wins, int(config.get_value(SECTION, wins, 0)) + 1)
		streak = int(config.get_value(SECTION, "streak", 0)) + 1
		config.set_value(SECTION, "best_streak", maxi(streak, int(config.get_value(SECTION, "best_streak", 0))))
		var fastest := int(config.get_value(SECTION, "fastest_win", 0))
		if fastest == 0 or moves < fastest:
			config.set_value(SECTION, "fastest_win", moves)
	config.set_value(SECTION, "streak", streak)
	var recent_list: Array = config.get_value(SECTION, "recent", [])
	recent_list.push_front({"won": won, "mode": mode, "moves": moves, "at": int(Time.get_unix_time_from_system())})
	config.set_value(SECTION, "recent", recent_list.slice(0, RECENT_LIMIT))
	config.save(PATH)


static func recent() -> Array:
	var config := ConfigFile.new()
	config.load(PATH)
	return config.get_value(SECTION, "recent", [])


## Card names with how often they captured / were played, one dictionary each.
static func add_card(kind: String, card_name: String) -> void:
	var config := ConfigFile.new()
	config.load(PATH)
	var counts: Dictionary = config.get_value(SECTION, kind, {})
	counts[card_name] = int(counts.get(card_name, 0)) + 1
	config.set_value(SECTION, kind, counts)
	config.save(PATH)


## The card that captured most (ties and no captures fall back to the most played).
static func most_lethal_card() -> String:
	var config := ConfigFile.new()
	config.load(PATH)
	for kind: String in ["card_captures", "card_plays"]:
		var counts: Dictionary = config.get_value(SECTION, kind, {})
		var best := ""
		for card_name: String in counts:
			if best.is_empty() or int(counts[card_name]) > int(counts[best]):
				best = card_name
		if not best.is_empty():
			return best
	return ""


static func percent(part: int, whole: int) -> String:
	return "--" if whole <= 0 else "%d%%" % roundi(100.0 * part / whole)
