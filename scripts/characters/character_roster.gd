class_name CharacterRoster
extends RefCounted

## Everything a player can pick in the collection: the master character (the
## one real person on their side, the piece that must be captured), how the
## students look ("echoes" of the simulation) and the skin of their board half.
## The choice is saved with the local profile.

const PROFILE_PATH := "user://ring_duel_profile.cfg"

const CHARACTERS: Array[Dictionary] = [
	{"id": "prisoner", "name": "DER GEFANGENE", "line": "Wacht jeden Morgen im selben Feld auf.",
		"skin": Color("d39a74"), "hair": "short", "hair_color": Color("4a2f1f"), "clothes": Color("2f3a2c"), "beard": true, "seed": 3},
	{"id": "mira", "name": "MIRA", "line": "Hat den Ausgang schon zweimal gesehen.",
		"skin": Color("eab894"), "hair": "long", "hair_color": Color("a5432a"), "clothes": Color("3c2f4a"), "freckles": true, "mouth": "smile", "eye_color": Color("3c6b3a"), "seed": 5},
	{"id": "opa", "name": "OPA HEINZ", "line": "Spielt seit 1987. Hat nie verloren. Sagt er.",
		"skin": Color("d8a888"), "hair": "bald", "hair_color": Color("cfcac0"), "clothes": Color("5a4a36"), "beard": true, "glasses": "round", "mouth": "frown", "seed": 8},
	{"id": "baby", "name": "BABY NULL", "line": "Wurde im Grid geboren. Kennt nichts anderes.",
		"kind": "baby", "skin": Color("f2c6a6"), "hair": "tuft", "hair_color": Color("d8a85a"), "clothes": Color("6fa6c9"), "mouth": "pacifier", "seed": 11},
	{"id": "skull", "name": "DER SCHÄDEL", "line": "Ist schon lange hier. Zu lange.",
		"kind": "skull", "skin": Color("d8d2c0"), "hair": "none", "clothes": Color("2a2a2a"), "glitch": 0.5, "seed": 13},
	{"id": "greenling", "name": "GRÜNLING", "line": "Ein Fehler im Code, der zurückbeißt.",
		"kind": "creature", "skin": Color("7ea052"), "hair": "mohawk", "hair_color": Color("2b2b2b"), "clothes": Color("4a3a2a"), "mouth": "tusks", "eye_color": Color("d9b23a"), "seed": 17},
	{"id": "agent", "name": "DIE AGENTIN", "line": "Arbeitet für das System. Angeblich.",
		"skin": Color("c98e6c"), "hair": "bob", "hair_color": Color("15151a"), "clothes": Color("1c1c22"), "glasses": "shades", "seed": 19},
	{"id": "punk", "name": "RIK", "line": "Hat die Wand eingetreten. Die Wand war unendlich.",
		"skin": Color("e0ad8c"), "hair": "mohawk", "hair_color": Color("e05aa8"), "clothes": Color("2a2a2a"), "scar": true, "mouth": "smile", "seed": 23},
	{"id": "monk", "name": "BRUDER ODO", "line": "Meditiert, bis die Felder stillstehen.",
		"skin": Color("b9805c"), "hair": "hood", "hair_color": Color("6b4a2c"), "clothes": Color("6b4a2c"), "seed": 29},
	{"id": "doc", "name": "DOC VOSS", "line": "Hat das Grid gebaut. Bereut es.",
		"skin": Color("e8c0a2"), "hair": "messy", "hair_color": Color("e8e6df"), "clothes": Color("d9d6cc"), "glasses": "round", "seed": 31},
	{"id": "beast", "name": "DIE BESTIE", "line": "Niemand weiß, ob sie mal ein Mensch war.",
		"kind": "creature", "skin": Color("8a5a44"), "hair": "curly", "hair_color": Color("4a2a1c"), "clothes": Color("3a2a22"), "horns": true, "mouth": "tusks", "eye_color": Color("e04a2a"), "seed": 37},
	{"id": "kid", "name": "JUNO", "line": "Zu jung für die Arena. Trotzdem hier.",
		"skin": Color("a8704e"), "hair": "curly", "hair_color": Color("1e1612"), "clothes": Color("c9a23a"), "mouth": "smile", "big_eyes": true, "seed": 41},
]

## How students look. They are not people but copies the grid made.
const ECHO_STYLES: Array[Dictionary] = [
	{"id": "echo", "name": "ECHOS", "line": "Verblasste Kopien deines Meisters, ohne Augen."},
	{"id": "hood", "name": "KAPUZEN", "line": "Gesichtslose Wächter mit glühenden Augen."},
	{"id": "drone", "name": "DROHNEN", "line": "Maschinen mit einem wandernden Auge."},
]

## Tint and glow for the tiles of a player's half of the board.
const BOARD_SKINS: Array[Dictionary] = [
	{"id": "wood", "name": "HOLZ", "line": "Das klassische Brett.", "tint": Color(1, 1, 1), "glow": Color(0, 0, 0)},
	{"id": "matrix", "name": "MATRIX", "line": "Schwarz mit grünem Code-Schimmer.", "tint": Color("2d4a2a"), "glow": Color("2fb23a")},
	{"id": "blood", "name": "BLUTROT", "line": "Für Spieler ohne Gnade.", "tint": Color("7a2a26"), "glow": Color("b3261e")},
	{"id": "neon", "name": "NEON", "line": "Blau und pink wie eine Nachtstadt.", "tint": Color("2c3a7a"), "glow": Color("d94ad9")},
	{"id": "gold", "name": "GOLD", "line": "Für Gewinner. Oder Angeber.", "tint": Color("c9a24a"), "glow": Color("ffcf5a")},
	{"id": "void", "name": "LEERE", "line": "Fast nichts. Nur Umrisse im Dunkeln.", "tint": Color("2a2236"), "glow": Color("6a4ab0")},
]


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


## The player's current choice: {"character", "echo", "board"}.
static func load_look() -> Dictionary:
	var config := ConfigFile.new()
	config.load(PROFILE_PATH)
	return {
		"character": str(config.get_value("look", "character", CHARACTERS[0]["id"])),
		"echo": str(config.get_value("look", "echo", ECHO_STYLES[0]["id"])),
		"board": str(config.get_value("look", "board", BOARD_SKINS[0]["id"])),
	}


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
