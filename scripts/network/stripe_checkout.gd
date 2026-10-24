class_name StripeCheckout
extends RefCounted

## Opens the Stripe Checkout page the server created. In the browser it gets a
## window of its own and the game stays open: going to Stripe and back in the
## same tab can land in another browser storage (installed web app, other
## page), and with it another account. Elsewhere the system browser opens.
## The payment itself only counts once Stripe tells the server (webhook).


## Call right when the player taps "buy": browsers only allow new windows
## shortly after a tap, and the server's answer may take longer than that.
static func reserve_window() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.igCheckout = window.open('', '_blank'); if (window.igCheckout) { window.igCheckout.document.write('<body style=\"background:#0a0e09;color:#6ee65a;font:20px monospace;display:grid;place-items:center;height:100vh;margin:0\">Kasse wird geöffnet …</body>'); }")


## Closes the reserved window again (the checkout could not be created).
static func release_window() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (window.igCheckout && !window.igCheckout.closed) { window.igCheckout.close(); } window.igCheckout = null;")


## Returns "window" (own window, game stays), "page" (popups blocked, this tab
## leaves for Stripe) or "external" (system browser).
static func open(url: String) -> String:
	if not OS.has_feature("web"):
		OS.shell_open(url)
		return "external"
	var target := JSON.stringify(url)
	var opened := str(JavaScriptBridge.eval("(function (url) { if (window.igCheckout && !window.igCheckout.closed) { window.igCheckout.location.href = url; return 'window'; } window.location.href = url; return 'page'; })(%s)" % target))
	return opened
