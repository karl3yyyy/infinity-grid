class_name ScreenLayout
extends RefCounted

## Which way the phone is held, a setting chosen on the Finite Grid page. The
## screen looks the same in both; only the device turns (landscape applies to
## Finite Grid matches only). The choice is stored in the profile file.

const PROFILE_PATH := "user://ring_duel_profile.cfg"
const MODES: Array[String] = ["portrait", "landscape"]
const NAMES: Dictionary = {"portrait": "HOCHFORMAT", "landscape": "QUERFORMAT"}
const HINTS: Dictionary = {
	"portrait": "Handy aufrecht.",
	"landscape": "Handy waagerecht, das Spielfeld sieht aus wie im Hochformat.",
}
const PORTRAIT_WINDOW := Vector2i(450, 800)


static func mode() -> String:
	var config := ConfigFile.new()
	if config.load(PROFILE_PATH) == OK:
		var saved := str(config.get_value("settings", "screen_layout", "portrait"))
		if saved in MODES:
			return saved
	return "portrait"


## Landscape only applies inside a Finite Grid match; every other mode stays portrait.
static var finite_grid_active: bool = false


static func is_landscape() -> bool:
	return finite_grid_active and mode() == "landscape"


static func set_finite_grid_active(active: bool) -> void:
	finite_grid_active = active
	apply_to_window()


static func set_mode(value: String) -> void:
	var config := ConfigFile.new()
	config.load(PROFILE_PATH)
	config.set_value("settings", "screen_layout", value)
	config.save(PROFILE_PATH)


static func next_mode() -> String:
	var next := MODES[(MODES.find(mode()) + 1) % MODES.size()]
	set_mode(next)
	apply_to_window()
	return next


## Turns the phone screen, or resizes the desktop window. The browser decides on its own.
static func apply_to_window() -> void:
	var landscape := is_landscape()
	match OS.get_name():
		"Android", "iOS":
			DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE if landscape else DisplayServer.SCREEN_PORTRAIT)
		"Web":
			pass
		_:
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
				var size := Vector2i(PORTRAIT_WINDOW.y, PORTRAIT_WINDOW.x) if landscape else PORTRAIT_WINDOW
				DisplayServer.window_set_size(size)
