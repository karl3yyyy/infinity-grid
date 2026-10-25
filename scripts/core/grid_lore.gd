class_name GridLore
extends RefCounted

## The Grid's dry sense of humour: short system messages for the menu, the
## ping, the rival and the end of a match. Texts only; nothing here decides
## anything.

## The side pieces next to the KERN: copies the Grid made, background processes.
const SIDE_PIECE: String = "ECHO"
const SIDE_PIECES: String = "ECHOS"

const FINITE_LORE: String = "FEHLER 0xF1N1T3: Das Grid hat plötzlich Ränder. Vier Prozesse wachen in einem endlichen Quadrat auf, ohne Weg hinaus. Der Speicher reicht für genau einen KERN. Das System meldet: Problem gelöst, sobald nur noch einer läuft."

const FINITE_START_LINES: Array[String] = [
	"Vier Prozesse, ein Quadrat, null Ausgänge. Das System nennt es Lastverteilung.",
	"Das Grid ist endlich geworden. Niemand hat gefragt, ob das okay ist.",
	"Die Ränder sind echt. Der Speicher reicht für einen Gewinner. Viel Erfolg.",
]

const FINITE_OUT_LINES: Array[String] = [
	"wurde aus dem endlichen Grid gelöscht. Speicher wieder frei.",
	"ist abgestürzt. Seine Echos laufen als Geister weiter.",
]

const MENU_TAGLINES: Array[String] = [
	"KEIN ENDE IN SICHT.",
	"ES BOOTET. IRGENDWANN.",
	"SYSTEM STABIL. FAST.",
	"HAT SCHON JEMAND NEU GESTARTET?",
	"KNOTEN 7 ANTWORTET NICHT. WIE IMMER.",
	"ALLES UNTER KONTROLLE. VERMUTLICH.",
	"DAS GRID LIEBT DICH. EIN BISSCHEN.",
	"CACHE GELEERT. MOTIVATION NICHT.",
]

const RIVAL_LINES: Array[String] = [
	"Rivalen-Signatur erkannt. Sieht überheblich aus.",
	"Gegner geladen. Der Lüfter dreht schon hoch.",
	"Rival-Protokoll gefunden. Es hat keinen Plan, aber viel Selbstvertrauen.",
	"Gegner online. Zum Glück nur ein paar Millionen Zeilen Code.",
]

const WIN_LINES: Array[String] = [
	"Core überschrieben. Der Gegner bootet gerade in Tränen.",
	"Knoten übernommen. Das Grid applaudiert (leise).",
	"Rival gelöscht. Backup? Gab's nicht.",
	"Sauber. Der KERN des Gegners meldet: Fehler 404, Würde nicht gefunden.",
]

const LOSS_LINES: Array[String] = [
	"Dein KERN wurde gelöscht. Hast du es mal mit Neustart versucht?",
	"Kritischer Fehler: Gegner war besser. Wird nicht wieder vorkommen (doch).",
	"Verbindung zu deinem Ego unterbrochen.",
	"Der Gegner hat dich überschrieben. Der Papierkorb ist voll.",
]

const COLLISION_LINES: Array[String] = [
	"SIGNAL COLLISION! Zwei Hirne, ein Gedanke, null Plan – nochmal.",
	"SIGNAL COLLISION! Das Grid hat die Augenbraue gehoben.",
]


static func finite_start_line() -> String:
	return FINITE_START_LINES.pick_random()


static func finite_out_line() -> String:
	return FINITE_OUT_LINES.pick_random()


static func menu_tagline() -> String:
	return MENU_TAGLINES.pick_random()


static func rival_line() -> String:
	return RIVAL_LINES.pick_random()


static func win_line() -> String:
	return WIN_LINES.pick_random()


static func loss_line() -> String:
	return LOSS_LINES.pick_random()


static func collision_line() -> String:
	return COLLISION_LINES.pick_random()
