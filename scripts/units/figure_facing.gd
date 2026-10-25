class_name FigureFacing
extends RefCounted

## Which way the standing figures look, a setting. The look is fixed in the
## world: turning the camera does not turn them. Only the player's own figures
## follow the setting.
##   player - towards the player's seat
##   enemy  - towards the opposing side
##   own    - towards their own back line
## Yaw 0 looks along +z (towards team 0's seat), PI along -z (towards team 1's).

const PROFILE_PATH := "user://ring_duel_profile.cfg"
const MODES: Array[String] = ["player", "enemy", "own"]
const NAMES: Dictionary = {"player": "ZUM SPIELER", "enemy": "ZUM GEGNER", "own": "ZUR EIGENEN SEITE"}
const HINTS: Dictionary = {
	"player": "Deine Figuren schauen zu dir.",
	"enemy": "Deine Figuren schauen zum Gegner.",
	"own": "Deine Figuren schauen vom Gegner weg.",
}


static func mode() -> String:
	var config := ConfigFile.new()
	if config.load(PROFILE_PATH) == OK:
		var saved := str(config.get_value("settings", "figure_facing", "player"))
		if saved in MODES:
			return saved
	return "player"


static func set_mode(value: String) -> void:
	var config := ConfigFile.new()
	config.load(PROFILE_PATH)
	config.set_value("settings", "figure_facing", value)
	config.save(PROFILE_PATH)


static func next_mode() -> String:
	var next := MODES[(MODES.find(mode()) + 1) % MODES.size()]
	set_mode(next)
	return next


## World yaw of a resting figure of `team`; `seat` is the team whose seat the camera sits at.
## The setting only applies to the figures of the seat's side; the opposing figures always look towards the seat.
static func yaw_for(team: int, seat: int) -> float:
	if team != seat:
		return 0.0 if seat == 0 else PI
	match mode():
		"enemy":
			return PI if team == 0 else 0.0
		"own":
			return 0.0 if team == 0 else PI
		_:
			return 0.0 if seat == 0 else PI
