class_name CharacterSkins
extends RefCounted

## Alternative appearances per character. A skin only lists what it changes;
## "outfit" is merged key by key into the character's outfit. The original
## look has the empty id "" and is free; every other skin is sold in the shop
## as "skin:<id>" (prices in CharacterRoster.PRICES).

const SKINS: Array[Dictionary] = [
	{"id": "shadow_white", "character": "shadow", "name": "WEISSER HASE", "line": "Folge ihm. Ganz in Weiß.",
		"look": {"hair_color": Color("e8e6e0"), "coat_color": Color("ecebe6"), "outfit": {"top": Color("dcdad4"), "bottom": Color("dcdad4"), "shoes": Color("f2f2f2")}}},
	{"id": "shadow_red", "character": "shadow", "name": "ROTE PILLE", "line": "Er hat geschluckt. Jetzt sieht er alles rot.",
		"look": {"coat_color": Color("5a0c12"), "glow_color": Color("ff2a2a"), "gear": ["coat", "visor"], "outfit": {"top": Color("1a0608"), "bottom": Color("12080a")}}},
	{"id": "wired_rust", "character": "wired", "name": "ROSTKABEL", "line": "Alte Leitungen, heißer Strom.",
		"look": {"skin": "dark", "tint": Color("d9c2b0"), "glow_color": Color("ff8a1c"), "outfit": {"top": Color("5a3218"), "bottom": Color("2a1a10")}}},
	{"id": "wired_ice", "character": "wired", "name": "KÜHLKREISLAUF", "line": "Läuft bei minus vierzig Grad am stabilsten.",
		"look": {"tint": Color("c8e4f2"), "glow_color": Color("7fe6ff"), "outfit": {"top": Color("1b3a4a"), "bottom": Color("0e1c26"), "sleeves": "short"}}},
	{"id": "nova_solar", "character": "nova", "name": "SOLAR", "line": "Lädt sich an Sonnen auf. Echten.",
		"look": {"hair_color": Color("ffb21c"), "glow_color": Color("ff6a1c"), "outfit": {"top": Color("4a1e08"), "bottom": Color("1e0c06")}}},
	{"id": "nova_glitch", "character": "nova", "name": "GLITCH", "line": "Flackert, wenn man zu lange hinsieht.",
		"look": {"hair_color": Color("3fffb0"), "glow_color": Color("3fffb0"), "gear": ["implants", "visor"], "outfit": {"top": Color("0e1a1a"), "bottom": Color("080c0e")}}},
	{"id": "brute_magma", "character": "brute", "name": "MAGMA", "line": "Kocht von innen.",
		"look": {"tint": Color("e0705a"), "glow_color": Color("ffcf3a"), "outfit": {"top": Color("1a0e0a"), "bottom": Color("1a0e0a")}}},
	{"id": "brute_frost", "character": "brute", "name": "FROSTFEHLER", "line": "Ein eingefrorener Prozess. Taut gerade auf.",
		"look": {"tint": Color("a8d8f0"), "glow_color": Color("2ad4ff"), "outfit": {"top": Color("1a2a38"), "bottom": Color("1a2a38")}}},
	{"id": "baby_gold", "character": "baby", "name": "GOLDKIND", "line": "Erbe des Systems. Benimmt sich auch so.",
		"look": {"hair_color": Color("ffd25a"), "glow_color": Color("ffc23a"), "outfit": {"top": Color("e0b040"), "bottom": Color("e0b040")}}},
	{"id": "baby_rowdy", "character": "baby", "name": "RABAUKE", "line": "Sonnenbrille im Kinderwagen. Natürlich.",
		"look": {"hair_color": Color("1a1612"), "glow_color": Color("ff2fd0"), "gear": ["pram", "shades"], "outfit": {"top": Color("1c1c20"), "bottom": Color("1c1c20")}}},
	{"id": "agent_red", "character": "agent", "name": "DOPPELAGENTIN", "line": "Rot steht ihr. Loyalität nicht.",
		"look": {"hair_color": Color("b02a2a"), "coat_color": Color("6a0e18"), "outfit": {"top": Color("1a0a0c"), "bottom": Color("1a0a0c")}}},
	{"id": "agent_white", "character": "agent", "name": "SYSTEMADMIN", "line": "Hat Rootrechte. Auf alles.",
		"look": {"hair_color": Color("e8e6e0"), "coat_color": Color("e6e6ea"), "glow_color": Color("2ad4ff"), "gear": ["visor", "coat"], "outfit": {"top": Color("cfd2d8"), "bottom": Color("cfd2d8")}}},
	{"id": "mira_night", "character": "mira", "name": "NACHTSCHICHT", "line": "Sieht den Ausgang nur im Dunkeln.",
		"look": {"hair_color": Color("1e1a2e"), "glow_color": Color("8a6aff"), "gear": ["implants"], "outfit": {"top": Color("12101c"), "bottom": Color("0c0a12")}}},
	{"id": "mira_rose", "character": "mira", "name": "ROSENQUARZ", "line": "Weich im Look, hart im Zug.",
		"look": {"hair_color": Color("ff8fb0"), "outfit": {"top": Color("6a1e44"), "bottom": Color("2a0e1e")}}},
	{"id": "opa_sunday", "character": "opa", "name": "SONNTAGSANZUG", "line": "Für Turniere zieht er sich ordentlich an.",
		"look": {"outfit": {"top": Color("223454"), "bottom": Color("161e30"), "shoes": Color("2a1a10"), "plain": true}}},
	{"id": "opa_hacker", "character": "opa", "name": "HACKER-OPA", "line": "Hat 1987 das Passwort erraten. Seitdem drin.",
		"look": {"glow_color": Color("6ee65a"), "gear": ["round_glasses", "implants"], "outfit": {"top": Color("101210"), "bottom": Color("0c0e0c"), "plain": false}}},
	{"id": "punk_toxic", "character": "punk", "name": "GIFTGRÜN", "line": "Nicht anfassen. Ernsthaft.",
		"look": {"hair_color": Color("7cff3a"), "glow_color": Color("7cff3a"), "outfit": {"top": Color("102010"), "bottom": Color("0a100a")}}},
	{"id": "punk_chrome", "character": "punk", "name": "CHROM", "line": "Hat die Haut gegen Metall getauscht.",
		"look": {"skin": "light", "tint": Color("b4bcc6"), "hair": "", "glow_color": Color("2ad4ff"), "gear": ["visor", "implants"], "outfit": {"top": Color("2a3038"), "bottom": Color("1a1e24")}}},
	{"id": "doc_toxic", "character": "doc", "name": "LABORUNFALL", "line": "Das Experiment ging schief. Oder richtig.",
		"look": {"hair_color": Color("b8f070"), "coat_color": Color("c8e6a0"), "glow_color": Color("7cff3a"), "glow_eyes": true, "outfit": {"top": Color("4a6a2a"), "bottom": Color("1e2a14")}}},
	{"id": "doc_black", "character": "doc", "name": "SCHWARZKITTEL", "line": "Forscht jetzt für die andere Seite.",
		"look": {"hair_color": Color("1a1a1e"), "coat_color": Color("141518"), "glow_color": Color("ff3b3b"), "outfit": {"top": Color("2a0c10"), "bottom": Color("0c0c0e")}}},
	{"id": "monk_shadow", "character": "monk", "name": "SCHATTENMÖNCH", "line": "Meditiert im Nichts zwischen zwei Feldern.",
		"look": {"glow_color": Color("8a6aff"), "outfit": {"top": Color("1a1826"), "bottom": Color("100e18")}}},
	{"id": "monk_jade", "character": "monk", "name": "JADE", "line": "Ruhig wie Stein, grün wie Code.",
		"look": {"glow_color": Color("6ee65a"), "outfit": {"top": Color("2f8a5a"), "bottom": Color("1a5a3a")}}},
	{"id": "kid_pink", "character": "kid", "name": "BUBBLEGUM", "line": "Platzt dir eine Blase ins Gesicht.",
		"look": {"hair_color": Color("ff5ab0"), "glow_color": Color("ff5ab0"), "outfit": {"top": Color("ff6ab8"), "bottom": Color("3a1a40"), "shoes": Color("ffffff")}}},
	{"id": "kid_street", "character": "kid", "name": "STRASSE", "line": "Sonnenbrille, rote Sneaker, keine Angst.",
		"look": {"gear": ["shades"], "outfit": {"top": Color("2a2a2e"), "bottom": Color("16161a"), "shoes": Color("ff3b3b")}}},
]


## Skins of one character, without the original.
static func for_character(character_id: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for skin: Dictionary in SKINS:
		if skin["character"] == character_id:
			found.append(skin)
	return found


static func skin(skin_id: String) -> Dictionary:
	for entry: Dictionary in SKINS:
		if entry["id"] == skin_id:
			return entry
	return {}


## The character's look with the skin applied; unknown skins leave it unchanged.
static func dress(character: Dictionary, skin_id: String) -> Dictionary:
	var entry := skin(skin_id)
	if entry.is_empty() or entry["character"] != character["id"]:
		return character
	var look := character.duplicate(true)
	for key: String in entry["look"]:
		if key == "outfit":
			var outfit: Dictionary = look.get("outfit", {}).duplicate()
			outfit.merge(entry["look"]["outfit"], true)
			look["outfit"] = outfit
		else:
			look[key] = entry["look"][key]
	return look
