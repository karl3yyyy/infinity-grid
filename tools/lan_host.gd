extends SceneTree

## Runs the Wi-Fi host headless:
##   godot --headless --path . --script res://tools/lan_host.gd -- --web=build/web --port=8060

const LanHostServerScript := preload("res://scripts/network/lan_host_server.gd")

var _server: LanHostServer
var _last_match_count: int = 0


func _initialize() -> void:
	var options := _parse_arguments()
	var web_option := str(options.get("web", "build/web"))
	var web_root := web_option if web_option.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(web_option)
	if not FileAccess.file_exists(web_root.path_join("index.html")):
		push_error("Web-Export fehlt: %s/index.html" % web_root)
		quit(1)
		return
	_server = LanHostServerScript.new()
	var port := int(options.get("port", "8060"))
	var error := _server.start(web_root, port)
	if error != OK:
		push_error("Port %d oder %d ist belegt (Fehler %d)." % [port, port + 1, error])
		quit(1)
		return
	print("")
	print("Infinity Grid WLAN-Host läuft.")
	print("Öffne auf beiden Handys im selben WLAN:")
	for address: String in LanHostServer.local_addresses():
		print("    http://%s:%d" % [address, port])
	print("Dann im Spiel: MULTIPLAYER > IM WLAN SPIELEN.")
	print("Beenden mit Strg+C.")
	print("")


func _process(_delta: float) -> bool:
	if _server == null:
		return false
	_server.poll()
	if _server.match_count != _last_match_count:
		_last_match_count = _server.match_count
		print("Partie %d gestartet." % _last_match_count)
	return false


func _finalize() -> void:
	if _server != null:
		_server.stop()


func _parse_arguments() -> Dictionary:
	var options := {}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			options[argument.substr(2).get_slice("=", 0)] = argument.get_slice("=", 1)
	return options
