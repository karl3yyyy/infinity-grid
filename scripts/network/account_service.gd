class_name AccountService
extends Node

## The player's account on the online server: name, avatar, credits and owned
## cosmetics. The server decides all of it (server/online/accounts.js); this
## node only asks and keeps the last answer on the device, so the collection
## still works offline. Without a connection nothing can be bought or earned.

signal changed
## A finished request; `error` is "" on success, else the server's reason or
## "offline".
signal request_finished(action: String, error: String)

const PROFILE_PATH := "user://ring_duel_profile.cfg"
const SECTION := "account"

## Last known account; empty until the server answered once.
var account: Dictionary = {}
var code: String = ""
var busy: bool = false
var _last_error: String = ""


func _ready() -> void:
	var config := ConfigFile.new()
	config.load(PROFILE_PATH)
	code = str(config.get_value(SECTION, "code", ""))
	account = config.get_value(SECTION, "cache", {})


static func api_url() -> String:
	var base := MatchClient.online_server_url()
	if OS.has_feature("web"):
		# The game served by the online server asks its own origin.
		var origin := str(JavaScriptBridge.eval("window.location.origin"))
		if origin.ends_with(".workers.dev") or origin.begins_with("http://127.0.0.1:8787"):
			base = origin
	return base.replace("wss://", "https://").replace("ws://", "http://") + "/api/account"


## True for free items and those the account owns (as last reported).
static func owns(item: String) -> bool:
	if not CharacterRoster.PRICES.has(item):
		return true
	var config := ConfigFile.new()
	config.load(PROFILE_PATH)
	var cache: Dictionary = config.get_value(SECTION, "cache", {})
	return item in cache.get("owned", [])


func credits() -> int:
	return int(account.get("credits", 0))


func has_account() -> bool:
	return not code.is_empty()


## Opens a new account on first use, else refreshes it (and collects the daily bonus).
func connect_account() -> void:
	if has_account():
		await _call("refresh", HTTPClient.METHOD_GET, "", {})
		if _last_error != "no_account":
			return
		# The server does not know this code (any more): start a fresh account.
		code = ""
		account = {}
		await _call("create", HTTPClient.METHOD_POST, "", {})
	else:
		await _call("create", HTTPClient.METHOD_POST, "", {})


## Switches to an account from another device by its code.
func use_code(new_code: String) -> void:
	var previous := code
	code = new_code.strip_edges().to_upper()
	await _call("restore", HTTPClient.METHOD_GET, "", {})
	if account.is_empty() or _last_error != "":
		code = previous
		_store()


func buy(item: String) -> void:
	await _call("buy", HTTPClient.METHOD_POST, "/buy", {"item": item})


func save_profile(profile_name: String, avatar: int) -> void:
	if has_account():
		await _call("profile", HTTPClient.METHOD_POST, "/profile", {"name": profile_name, "avatar": avatar})


func report_bot_win(difficulty: int) -> void:
	if has_account():
		await _call("reward", HTTPClient.METHOD_POST, "/reward", {"difficulty": difficulty})



func _call(action: String, method: int, path: String, body: Dictionary) -> void:
	busy = true
	var request := HTTPRequest.new()
	request.timeout = 10.0
	add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not code.is_empty() and action != "create":
		headers.append("Authorization: Bearer " + code)
	var payload := "" if method == HTTPClient.METHOD_GET else JSON.stringify(body)
	_last_error = "offline"
	if request.request(api_url() + path, headers, method, payload) == OK:
		var response: Array = await request.request_completed
		var status: int = response[1]
		# Not JSON (an old server, a proxy page) counts as offline.
		var parser := JSON.new()
		var answer: Variant = parser.data if parser.parse((response[3] as PackedByteArray).get_string_from_utf8()) == OK else null
		if response[0] == HTTPRequest.RESULT_SUCCESS and answer is Dictionary:
			var data: Dictionary = answer
			_last_error = str(data.get("error", "")) if status >= 400 or data.has("error") else ""
			if data.has("account"):
				account = data["account"]
				if action == "create":
					code = str(data.get("code", ""))
			elif status == 404 or status == 401:
				_last_error = "no_account"
	request.queue_free()
	busy = false
	_store()
	changed.emit()
	request_finished.emit(action, _last_error)


func _store() -> void:
	var config := ConfigFile.new()
	config.load(PROFILE_PATH)
	config.set_value(SECTION, "code", code)
	config.set_value(SECTION, "cache", account)
	config.save(PROFILE_PATH)
