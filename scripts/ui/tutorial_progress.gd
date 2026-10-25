class_name TutorialProgress
extends RefCounted

## Whether the player has played through the tutorial. The mark lives on the
## device and on the account, so signing in on another device skips it.

const PROFILE_SECTION := "profile"


## Done on this device or on the account last reported by the server.
static func is_done() -> bool:
	var config := ConfigFile.new()
	config.load(MainMenu.PROFILE_PATH)
	if bool(config.get_value(PROFILE_SECTION, "tutorial_done", false)):
		return true
	var cache: Dictionary = config.get_value(AccountService.SECTION, "cache", {})
	return bool(cache.get("tutorial_done", false))


static func mark_done(account: AccountService) -> void:
	var first_time := not is_done()
	_store_flag()
	if first_time:
		account.report_tutorial_done()


## Keeps the device and the account in step: an account that did it clears the
## device flag, a device that did it before signing in tells the account.
static func sync_with_account(account: AccountService) -> void:
	if account.account.is_empty():
		return
	if bool(account.account.get("tutorial_done", false)):
		_store_flag()
	elif is_done() and account.has_account():
		account.report_tutorial_done()


static func _store_flag() -> void:
	var config := ConfigFile.new()
	config.load(MainMenu.PROFILE_PATH)
	config.set_value(PROFILE_SECTION, "tutorial_done", true)
	config.save(MainMenu.PROFILE_PATH)
