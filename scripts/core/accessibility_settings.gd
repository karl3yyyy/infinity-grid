class_name AccessibilitySettings
extends RefCounted

const PROFILE_PATH := "user://ring_duel_profile.cfg"
static var _enabled: int = -1


static func is_enabled() -> bool:
	if _enabled < 0:
		var config := ConfigFile.new()
		config.load(PROFILE_PATH)
		_enabled = 1 if bool(config.get_value("profile", "accessibility", false)) else 0
	return _enabled == 1


static func set_enabled(enabled: bool) -> void:
	_enabled = 1 if enabled else 0
	var config := ConfigFile.new()
	config.load(PROFILE_PATH)
	config.set_value("profile", "accessibility", enabled)
	var error := config.save(PROFILE_PATH)
	if error != OK:
		push_error("Could not save accessibility settings: %s" % error_string(error))


static func font_size(base_size: int) -> int:
	return roundi(float(base_size) * (1.18 if is_enabled() else 1.0))


static func reduced_motion() -> bool:
	return is_enabled()
