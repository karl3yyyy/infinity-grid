class_name AccountService
extends Node

## The player's account on the online server: name, profile picture, credits,
## owned cosmetics and the e-mail it is signed in with (none for a guest). The server decides all of it (server/online/accounts.js); this
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
## Full answer of the last request (checkout details live here).
var _last_response: Dictionary = {}
## When the server was last asked (Time.get_ticks_msec), for refresh_if_stale().
var _refreshed_at: int = -100000


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


## Login routes (server/online/auth.js) next to the account routes.
static func auth_url() -> String:
	return api_url().replace("/api/account", "/api/auth")


## True for free items, those the account owns (as last reported) and those
## the player's Access Level has unlocked.
static func owns(item: String) -> bool:
	if not CharacterRoster.PRICES.has(item) or AccessLevel.is_unlocked(item):
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


## "" for a guest, else the e-mail address the account is signed in with.
func email() -> String:
	return str(account.get("email", ""))


## Ties this device's guest account to a new e-mail login.
func register(address: String, password: String) -> void:
	await _call("register", HTTPClient.METHOD_POST, "/register", {"email": address, "password": password}, auth_url())


## Switches this device to the account behind an e-mail login.
func login(address: String, password: String) -> void:
	await _call("login", HTTPClient.METHOD_POST, "/login", {"email": address, "password": password}, auth_url())


## Starts a Google sign-in; returns {nonce, url} or {} (see _last_error).
func begin_google() -> Dictionary:
	await _call("google", HTTPClient.METHOD_POST, "/google", {}, auth_url())
	return _last_response if _last_error.is_empty() else {}


## True once the Google sign-in with this nonce finished (the account is switched).
func collect_google(nonce: String) -> bool:
	await _call("collect", HTTPClient.METHOD_GET, "/pending/" + nonce, {}, auth_url())
	return _last_error.is_empty() and _last_response.has("code")


## Forgets the account on this device and starts again as a new guest.
func logout() -> void:
	code = ""
	account = {}
	_store()
	await connect_account()


func buy(item: String) -> void:
	await _call("buy", HTTPClient.METHOD_POST, "/buy", {"item": item})


func save_profile(profile_name: String, avatar: String) -> void:
	if has_account():
		await _call("profile", HTTPClient.METHOD_POST, "/profile", {"name": profile_name, "avatar": avatar})


func report_bot_win(difficulty: int) -> void:
	if has_account():
		await _call("reward", HTTPClient.METHOD_POST, "/reward", {"difficulty": difficulty})



func _call(action: String, method: int, path: String, body: Dictionary, base: String = "") -> void:
	busy = true
	var request := HTTPRequest.new()
	request.timeout = 10.0
	add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not code.is_empty() and action != "create":
		headers.append("Authorization: Bearer " + code)
	var payload := "" if method == HTTPClient.METHOD_GET else JSON.stringify(body)
	_last_error = "offline"
	_last_response = {}
	_refreshed_at = Time.get_ticks_msec()
	if request.request((base if not base.is_empty() else api_url()) + path, headers, method, payload) == OK:
		var response: Array = await request.request_completed
		var status: int = response[1]
		# Not JSON (an old server, a proxy page) counts as offline.
		var parser := JSON.new()
		var answer: Variant = parser.data if parser.parse((response[3] as PackedByteArray).get_string_from_utf8()) == OK else null
		if response[0] == HTTPRequest.RESULT_SUCCESS and answer is Dictionary:
			var data: Dictionary = answer
			_last_error = str(data.get("error", "")) if status >= 400 or data.has("error") else ""
			_last_response = data
			if data.has("account"):
				account = data["account"]
				# New accounts and logins hand this device the account's code.
				if data.has("code"):
					code = str(data["code"])
			elif (status == 404 or status == 401) and _last_error.is_empty():
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


## Credit packs the server sells for real money ([] when payments are off).
func packs() -> Array:
	return account.get("packs", [])


## Starts paying for a credit pack. Returns {session, url} of the Stripe
## Checkout page or {} (then _last_error says why).
func start_checkout(pack_id: String) -> Dictionary:
	var body := {"pack": pack_id}
	if OS.has_feature("web"):
		# The thank-you page links back to this very page.
		body["return_to"] = str(JavaScriptBridge.eval("window.location.origin + window.location.pathname"))
	await _call("checkout", HTTPClient.METHOD_POST, "/checkout", body)
	return _last_response if _last_error.is_empty() else {}


## Asks the server again unless that happened in the last few seconds.
func refresh_if_stale() -> void:
	if busy or not has_account() or Time.get_ticks_msec() - _refreshed_at < 5000:
		return
	await connect_account()


## The permanent username ("" for guests and until chosen).
func username() -> String:
	return str(account.get("username", ""))


## Chooses the username once; it can never change afterwards.
func choose_username(new_name: String) -> void:
	await _call("username", HTTPClient.METHOD_POST, "/username", {"username": new_name})


static func friends_url() -> String:
	return api_url().replace("/api/account", "/api/friends")


static func ranked_url() -> String:
	return api_url().replace("/api/account", "/api/ranked")


## Friends overview {username, friends, incoming, outgoing, invites} or {}.
## action: "" (just ask), "add", "accept", "remove", "invite", "dismiss".
func friends(action: String = "", body: Dictionary = {}) -> Dictionary:
	var method := HTTPClient.METHOD_GET if action.is_empty() else HTTPClient.METHOD_POST
	await _call("friends", method, "" if action.is_empty() else "/" + action, body, friends_url())
	return _last_response if _last_error.is_empty() else {}


## A one-minute ticket for the ranked queue, or "" (see _last_error).
func ranked_ticket() -> String:
	await _call("ticket", HTTPClient.METHOD_POST, "/ticket", {}, ranked_url())
	return str(_last_response.get("ticket", "")) if _last_error.is_empty() else ""


## Top players: [{name, avatar, rating, rank, games}].
func leaderboard() -> Array:
	await _call("leaderboard", HTTPClient.METHOD_GET, "/leaderboard", {}, ranked_url())
	return _last_response.get("players", []) if _last_error.is_empty() else []


## A finished normal online match: the server adds the Access Level XP.
func report_online_result(won: bool) -> void:
	if has_account():
		await _call("online", HTTPClient.METHOD_POST, "/online", {"won": won})


## XP stored on the signed-in account, or -1 without one (see AccessLevel).
static func cached_xp() -> int:
	var config := ConfigFile.new()
	config.load(PROFILE_PATH)
	if str(config.get_value(SECTION, "code", "")).is_empty():
		return -1
	var cache: Dictionary = config.get_value(SECTION, "cache", {})
	return int(cache.get("xp", 0)) if not cache.is_empty() else -1


## Tells the server we are in the game; returns how many are, or -1 offline.
func presence() -> int:
	await _call("presence", HTTPClient.METHOD_POST, "/presence", {}, ranked_url())
	return int(_last_response.get("online", 0)) if _last_error.is_empty() else -1
