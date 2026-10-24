class_name AccessLevel
extends RefCounted

## "System Access Level" from the design bible: 1 (Guest Threat) to 100 (Root
## Admin). Experience comes from finished online matches and lives on the account (on
## this device while playing as a guest);
## it only changes how the profile looks, never the game.

const MAX_LEVEL: int = 100
## XP per finished match: [win, loss]. Only ranked and normal online count;
## the server uses the same numbers (server/online/accounts.js).
const XP_RANKED: Array[int] = [60, 25]
const XP_ONLINE: Array[int] = [50, 20]

## One title, emblem and colour per ten levels; level 100 is the last one.
const TIERS: Array[Dictionary] = [
	{"title": "GUEST THREAT", "emblem": "[.]", "color": Color("6ee65a")},
	{"title": "SCRIPT KIDDIE", "emblem": "[o]", "color": Color("7fe3ff")},
	{"title": "PACKET SNIFFER", "emblem": "[+]", "color": Color("5fb4ff")},
	{"title": "PORT SCANNER", "emblem": "[x]", "color": Color("b6ff6e")},
	{"title": "SHELL JOCKEY", "emblem": "[#]", "color": Color("ffd36e")},
	{"title": "KERNEL HACKER", "emblem": "[*]", "color": Color("ffb347")},
	{"title": "ROOT SEEKER", "emblem": "[@]", "color": Color("ff8a5c")},
	{"title": "DAEMON HANDLER", "emblem": "[%]", "color": Color("e0a0ff")},
	{"title": "SYSOP", "emblem": "[&]", "color": Color("ff6ad5")},
	{"title": "SUPER USER", "emblem": "[$]", "color": Color("ffe27a")},
	{"title": "ROOT ADMIN", "emblem": "[ROOT]", "color": Color("fff4a8")},
]


## Total XP needed to reach a level.
static func xp_for_level(level: int) -> int:
	var steps := level - 1
	return 30 * steps + 3 * steps * steps


static func total_xp() -> int:
	var account_xp := AccountService.cached_xp()
	return account_xp if account_xp >= 0 else MatchStats.get_count("xp")


static func level_for(xp: int) -> int:
	var level := 1
	while level < MAX_LEVEL and xp >= xp_for_level(level + 1):
		level += 1
	return level


static func tier(level: int) -> Dictionary:
	return TIERS[mini(level / 10, TIERS.size() - 1)]


static func title(level: int) -> String:
	return str(tier(level)["title"])


static func emblem(level: int) -> String:
	return str(tier(level)["emblem"])


static func color(level: int) -> Color:
	return tier(level)["color"]


## 0..1 progress towards the next level (1 at the maximum).
static func progress(xp: int) -> float:
	var level := level_for(xp)
	if level >= MAX_LEVEL:
		return 1.0
	var from := xp_for_level(level)
	return float(xp - from) / float(xp_for_level(level + 1) - from)


## Adds the XP for a finished match and returns the line for the result screen.
static func award(mode: String, won: bool) -> String:
	var table := XP_RANKED if mode == "ranked" else XP_ONLINE
	var amount := table[0] if won else table[1]
	var before_xp := total_xp()
	var before := level_for(before_xp)
	# A signed-in account gets its XP from the server; a guest keeps it here.
	if AccountService.cached_xp() < 0:
		MatchStats.add("xp", amount)
	var after := level_for(before_xp + amount)
	var note := "+%d XP" % amount
	if after > before:
		note += "  ·  LEVEL UP: %02d %s" % [after, title(after)]
		var fresh := unlocked_between(before, after)
		if not fresh.is_empty():
			note += "\nFREIGESCHALTET: " + ", ".join(fresh)
	return note


## Cosmetics that unlock by level instead of credits: about a third of the
## shop, spread from the early to the late levels. Everything else stays a
## purchase. Same item ids as CharacterRoster.PRICES.
const UNLOCKS: Dictionary = {
	"character:agent": 10,
	"character:kid": 25,
	"character:doc": 45,
	"echo:agents": 30,
	"board:blood": 15,
	"board:void": 55,
	"skin:shadow_white": 12,
	"skin:wired_ice": 20,
	"skin:nova_solar": 28,
	"skin:agent_red": 35,
	"skin:mira_night": 40,
	"skin:punk_toxic": 50,
	"skin:monk_jade": 65,
	"skin:brute_frost": 80,
}


## Level that unlocks an item, or 0 if it can only be bought.
static func unlock_level(item: String) -> int:
	return int(UNLOCKS.get(item, 0))


static func is_unlocked(item: String) -> bool:
	var needed := unlock_level(item)
	return needed > 0 and level_for(total_xp()) >= needed


static func item_label(item: String) -> String:
	var id := item.get_slice(":", 1)
	match item.get_slice(":", 0):
		"character":
			return str(CharacterRoster.character(id).get("name", id))
		"skin":
			return str(CharacterSkins.skin(id).get("name", id))
		"echo":
			return str(CharacterRoster.echo_style(id).get("name", id))
		_:
			return str(CharacterRoster.board_skin(id).get("name", id))


## Names of everything that unlocks when going from one level to another.
static func unlocked_between(before: int, after: int) -> Array[String]:
	var names: Array[String] = []
	for item: String in UNLOCKS:
		if int(UNLOCKS[item]) > before and int(UNLOCKS[item]) <= after:
			names.append(item_label(item))
	return names
