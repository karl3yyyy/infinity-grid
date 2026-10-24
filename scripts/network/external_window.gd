class_name ExternalWindow
extends RefCounted

## Opens a page of another service (Stripe's checkout, Google's sign-in) in a
## window of its own while the game stays open and waits for the server.
## Going there and back in the same tab can land in another browser storage
## (installed web app, other page), and with it another account. Outside the
## browser the system browser opens.


## Call right when the player taps: browsers only allow new windows shortly
## after a tap, and the server's answer may take longer than that.
static func reserve(message: String = "Wird geöffnet …") -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.igExternal = window.open('', '_blank'); if (window.igExternal) { window.igExternal.document.write('<body style=\"background:#0a0e09;color:#6ee65a;font:20px monospace;display:grid;place-items:center;height:100vh;margin:0\">' + %s + '</body>'); }" % JSON.stringify(message))


## Closes the reserved window again (nothing to show in it).
static func release() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (window.igExternal && !window.igExternal.closed) { window.igExternal.close(); } window.igExternal = null;")


## Returns "window" (own window, game stays), "page" (popups blocked, this tab
## leaves) or "external" (system browser).
static func open(url: String) -> String:
	if not OS.has_feature("web"):
		OS.shell_open(url)
		return "external"
	return str(JavaScriptBridge.eval("(function (url) { if (window.igExternal && !window.igExternal.closed) { window.igExternal.location.href = url; return 'window'; } window.location.href = url; return 'page'; })(%s)" % JSON.stringify(url)))
