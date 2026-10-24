class_name CharacterRoster
extends RefCounted

## Everything a player can pick in the collection: the master character (the
## one real person on their side, the piece that must be captured), how the
## students look ("echoes" of the simulation) and the skin of their board half.
## The choice is saved with the local profile.

const PROFILE_PATH := "user://ring_duel_profile.cfg"

## Fighters built by FighterModel: body, skin texture (+ tint), hair, outfit
## colours and cyber gear. The id of the first entry is the default.
const CHARACTERS: Array[Dictionary] = [
	{"id": "shadow", "style": "gunner", "name": "DER SCHATTEN", "line": "Langer Mantel, schwarze Brille. Sieht den Code hinter allem.",
		"body": "male", "skin": "light", "hair": "buzzed", "hair_color": Color("15110e"), "gear": ["coat", "shades"],
		"outfit": {"top": Color("0b0c0e"), "bottom": Color("0b0c0e"), "shoes": Color("050506")}},
	{"id": "wired", "style": "sorcerer", "name": "DER VERKABELTE", "line": "Kahl rasiert, Schläuche im Schädel. Hängt direkt am Grid.",
		"body": "male", "skin": "light", "tint": Color("e3e7ec"), "gear": ["tubes", "implants"], "glow_color": Color("6ee65a"),
		"outfit": {"top": Color("2b2f33"), "bottom": Color("1a1c1f"), "sleeves": "none"}},
	{"id": "nova", "style": "mage", "name": "NOVA", "line": "Neonhaar und Chips unter der Haut. Hackt sich durch jede Wand.",
		"body": "female", "skin": "light", "hair": "long", "hair_color": Color("ff3fa8"), "gear": ["implants"], "glow_color": Color("2ad4ff"),
		"outfit": {"top": Color("1c2f4a"), "bottom": Color("12151c"), "sleeves": "none"}},
	{"id": "brute", "style": "brawler", "name": "DAS MONSTER", "line": "Ein Fehler im Code, der zurückschlägt.",
		"body": "male", "skin": "dark", "tint": Color("9fe07a"), "scale": 1.18, "gear": ["horns", "spikes"], "glow_eyes": true, "glow_color": Color("ff4a1c"),
		"outfit": {"top": Color("2a221c"), "bottom": Color("2a221c"), "sleeves": "none", "skin_only": false}},
	{"id": "baby", "style": "sorcerer", "name": "BABY NULL", "line": "Fliegt im Hightech-Kinderwagen. Steuert ihn selbst.",
		"body": "male", "skin": "light", "hair": "buzzed", "hair_color": Color("e2c27a"), "gear": ["pram"], "glow_color": Color("2ad4ff"), "head_scale": 1.6,
		"outfit": {"top": Color("dfe9f2"), "bottom": Color("dfe9f2")}},
	{"id": "agent", "style": "gunner", "name": "DIE AGENTIN", "line": "Arbeitet für das System. Angeblich.",
		"body": "female", "skin": "dark", "hair": "buns", "hair_color": Color("0f0f12"), "gear": ["shades", "coat"],
		"outfit": {"top": Color("15161a"), "bottom": Color("15161a")}},
	{"id": "mira", "style": "mage", "name": "MIRA", "line": "Hat den Ausgang schon zweimal gesehen.",
		"body": "female", "skin": "light", "hair": "long", "hair_color": Color("a5432a"),
		"outfit": {"top": Color("3c2f4a"), "bottom": Color("1e1a26")}},
	{"id": "opa", "style": "gunner", "name": "OPA HEINZ", "line": "Spielt seit 1987. Hat nie verloren. Sagt er.",
		"body": "male", "skin": "light", "hair": "parted", "beard": true, "hair_color": Color("cfcac0"), "gear": ["round_glasses"],
		"outfit": {"top": Color("6b5a3c"), "bottom": Color("3a3026"), "plain": true}},
	{"id": "punk", "style": "brawler", "name": "RIK", "line": "Hat die Wand eingetreten. Die Wand war unendlich.",
		"body": "male", "skin": "dark", "hair": "buzzed", "hair_color": Color("e05aa8"), "gear": ["implants"], "glow_color": Color("ff2fd0"),
		"outfit": {"top": Color("201a24"), "bottom": Color("101012"), "sleeves": "none"}},
	{"id": "doc", "style": "sorcerer", "name": "DOC VOSS", "line": "Hat das Grid gebaut. Bereut es.",
		"body": "male", "skin": "light", "hair": "parted", "hair_color": Color("e8e6df"), "gear": ["round_glasses", "coat"], "coat_color": Color("d9d6cc"),
		"outfit": {"top": Color("8a9098"), "bottom": Color("2a2c30")}},
	{"id": "monk", "style": "mage", "name": "BRUDER ODO", "line": "Meditiert, bis die Felder stillstehen.",
		"body": "male", "skin": "dark", "glow_eyes": true, "glow_color": Color("ffc23a"), "gear": ["implants"],
		"outfit": {"top": Color("d2691e"), "bottom": Color("8e3b12"), "sleeves": "short", "plain": true}},
	{"id": "evlis", "style": "bazooka", "name": "EVLIS", "line": "Weißer Malteser, eigener Herr. Lacht über alles, raucht Selbstgedrehte. Alle sagen Dawg.",
		"body": "male", "skin": "light", "tint": Color(3.6, 3.5, 3.4), "gear": ["dog", "bazooka", "cigarette"], "glow_color": Color("ff8a3c"), "scale": 0.9, "head_scale": 1.25,
		"outfit": {"top": Color("4c5b3a"), "bottom": Color("f4f0e8"), "shoes": Color("e8e4da"), "sleeves": "none", "plain": true}},
	{"id": "kid", "style": "gunner", "name": "JUNO", "line": "Zu jung für die Arena. Trotzdem hier.",
		"body": "female", "skin": "dark", "hair": "buzzed_f", "hair_color": Color("1e1612"), "scale": 0.86, "head_scale": 1.12, "glow_color": Color("ffc23a"),
		"outfit": {"top": Color("e8b23a"), "bottom": Color("23303e"), "shoes": Color("e8e8e8")}},
]

## Fighting styles: how a side moves and captures (see UnitMovement.perform_move).
const STYLES: Dictionary = {
	"mage": {"name": "MAGIER", "line": "Zauberkreis aufs Ziel, dann Teleport."},
	"brawler": {"name": "SCHLÄGER", "line": "Rennt hin und haut alles kaputt."},
	"gunner": {"name": "SCHÜTZE", "line": "Schießt erst, dann geht er hin."},
	"sorcerer": {"name": "BLITZWIRKER", "line": "Schleudert Blitze und gleitet hinterher."},
	"bazooka": {"name": "BAZOOKA", "line": "Schießt sich selbst zum Feld und Gegner in die Luft."},
}

## How students look. They are not people but copies the grid made.
const ECHO_STYLES: Array[Dictionary] = [
	{"id": "echo", "name": "HOLOGRAMME", "line": "Leuchtende Kopien deines KERNS in Teamfarbe."},
	{"id": "agents", "name": "AGENTEN", "line": "Anzug, Sonnenbrille, kein Gesichtsausdruck."},
	{"id": "cyborgs", "name": "CYBORGS", "line": "Kahle Klone mit Implantaten und Kabeln."},
	{"id": "bodies", "name": "RUMPFE", "line": "Gesichtslose Puppen, frisch aus dem Code gedruckt."},
]

## Panel tint and border glow for the two rows of a player's half.
const BOARD_SKINS: Array[Dictionary] = [
	{"id": "standard", "name": "PLATINE", "line": "Retro-Mainboard in Blau: Leiterbahnen, Chips, Lötpunkte.", "tint": Color(1, 1, 1), "glow": Color("4fb6ff")},
	{"id": "matrix", "name": "CODE", "line": "Grüner Code läuft über deine Felder.", "tint": Color(1, 1, 1), "glow": Color("2fd23a")},
	{"id": "blood", "name": "LAVA", "line": "Schwarzer Fels mit glühenden Rissen.", "tint": Color(1, 1, 1), "glow": Color("ff6a1c")},
	{"id": "neon", "name": "SYNTHWAVE", "line": "Neon-Raster und Sonnenuntergang wie in den 80ern.", "tint": Color(1, 1, 1), "glow": Color("ff2fd0")},
	{"id": "gold", "name": "GOLD", "line": "Goldene Schaltkreise mit Ornamenten. Für Angeber.", "tint": Color(1, 1, 1), "glow": Color("ffc23a")},
	{"id": "void", "name": "LEERE", "line": "Sterne und Nebel. Dein Feld schwebt im All.", "tint": Color(1, 1, 1), "glow": Color("8a6aff")},
]


## Credits each cosmetic costs in the shop; everything not listed is free.
## Must match PRICES in server/online/accounts.js (checked by tests/lan_test.gd).
const PRICES: Dictionary = {
	"character:agent": 300,
	"character:mira": 300,
	"character:opa": 300,
	"character:kid": 300,
	"character:monk": 400,
	"character:doc": 400,
	"character:brute": 500,
	"character:evlis": 500,
	"character:baby": 600,
	"echo:agents": 250,
	"echo:cyborgs": 250,
	"board:blood": 250,
	"board:neon": 250,
	"board:void": 300,
	"board:gold": 500,
	"skin:shadow_white": 250,
	"skin:shadow_red": 350,
	"skin:wired_rust": 250,
	"skin:wired_ice": 250,
	"skin:nova_solar": 250,
	"skin:nova_glitch": 250,
	"skin:brute_magma": 250,
	"skin:brute_frost": 250,
	"skin:baby_gold": 350,
	"skin:baby_rowdy": 250,
	"skin:agent_red": 250,
	"skin:agent_white": 350,
	"skin:mira_night": 250,
	"skin:mira_rose": 250,
	"skin:opa_sunday": 250,
	"skin:opa_hacker": 250,
	"skin:punk_toxic": 250,
	"skin:punk_chrome": 350,
	"skin:doc_toxic": 250,
	"skin:doc_black": 250,
	"skin:monk_shadow": 250,
	"skin:monk_jade": 250,
	"skin:kid_pink": 250,
	"skin:kid_street": 250,
}

static func character(id: String) -> Dictionary:
	return _find(CHARACTERS, id)


static func echo_style(id: String) -> Dictionary:
	return _find(ECHO_STYLES, id)


static func board_skin(id: String) -> Dictionary:
	return _find(BOARD_SKINS, id)


## Random character for the bot or an opponent without a choice.
static func random_character_id(exclude: String = "") -> String:
	var options := CHARACTERS.filter(func(entry: Dictionary) -> bool: return entry["id"] != exclude)
	return str(options.pick_random()["id"])


## The original look or one of the character's skins, at random.
static func random_skin_id(character_id: String) -> String:
	var options: Array[String] = [""]
	for skin: Dictionary in CharacterSkins.for_character(character_id):
		options.append(str(skin["id"]))
	return options.pick_random()


## The player's current choice: {"character", "echo", "board"}.
static func load_look() -> Dictionary:
	var config := ConfigFile.new()
	config.load(PROFILE_PATH)
	var look := {
		"character": str(config.get_value("look", "character", CHARACTERS[0]["id"])),
		"echo": str(config.get_value("look", "echo", ECHO_STYLES[0]["id"])),
		"board": str(config.get_value("look", "board", BOARD_SKINS[0]["id"])),
	}
	# A choice that is not (or no longer) owned falls back to the free default.
	var defaults := {"character": CHARACTERS[0]["id"], "echo": ECHO_STYLES[0]["id"], "board": BOARD_SKINS[0]["id"]}
	for key: String in look:
		if not AccountService.owns("%s:%s" % [key, look[key]]):
			look[key] = defaults[key]
	# Each character remembers its own skin; "" is the original look.
	var skin_id := str(config.get_value("skins", look["character"], ""))
	if skin_id != "" and not AccountService.owns(item_id("skin", skin_id)):
		skin_id = ""
	look["skin"] = skin_id
	return look


## The master character of a look (character + skin) as FighterModel builds it.
static func dressed_character(look: Dictionary) -> Dictionary:
	return CharacterSkins.dress(character(str(look.get("character", ""))), str(look.get("skin", "")))


## The skin last chosen for a character ("" = original), owned or not.
static func saved_skin(character_id: String) -> String:
	var config := ConfigFile.new()
	config.load(PROFILE_PATH)
	return str(config.get_value("skins", character_id, ""))


static func save_skin(character_id: String, skin_id: String) -> void:
	var config := ConfigFile.new()
	config.load(PROFILE_PATH)
	config.set_value("skins", character_id, skin_id)
	config.save(PROFILE_PATH)


## Wears a cosmetic right after buying it; a skin also picks its character.
static func equip(item: String) -> void:
	var kind := item.get_slice(":", 0)
	var id := item.get_slice(":", 1)
	if kind == "skin":
		var entry := CharacterSkins.skin(id)
		save_look_value("character", str(entry["character"]))
		save_skin(str(entry["character"]), id)
	else:
		save_look_value(kind, id)


## Shop id of a cosmetic, e.g. "board:gold".
static func item_id(kind: String, id: String) -> String:
	return "%s:%s" % [kind, id]


static func price(kind: String, id: String) -> int:
	return int(PRICES.get(item_id(kind, id), 0))


static func save_look_value(key: String, value: String) -> void:
	var config := ConfigFile.new()
	config.load(PROFILE_PATH)
	config.set_value("look", key, value)
	config.save(PROFILE_PATH)


static func _find(entries: Array[Dictionary], id: String) -> Dictionary:
	for entry: Dictionary in entries:
		if entry["id"] == id:
			return entry
	return entries[0]


## What a student looks like on the board for a given echo style.
static func echo_look(style: String, master: Dictionary, team_color: Color) -> Dictionary:
	match style:
		"agents":
			return {"body": "male", "skin": "light", "hair": "buzzed", "hair_color": Color("1a1612"), "gear": ["shades"],
				"outfit": {"top": Color("101114"), "bottom": Color("101114")}}
		"cyborgs":
			return {"body": "male", "skin": "light", "tint": Color("d8dde3"), "gear": ["tubes", "implants"], "glow_color": team_color,
				"outfit": {"top": team_color.darkened(0.6), "bottom": Color("15171a"), "sleeves": "none"}}
		"bodies":
			return {"body": "male", "skin": "light", "tint": Color("b8bec8"),
				"outfit": {"top": Color("9aa0a8"), "bottom": Color("9aa0a8"), "shoes": Color("9aa0a8")}}
		_:
			var clone := master.duplicate(true)
			clone.erase("scale")
			return clone
