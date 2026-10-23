class_name StripeCheckout
extends RefCounted

## Sends the player to the Stripe Checkout page the server created. In the
## browser the game's tab goes there and Stripe brings the player back with
## ?checkout=success or ?checkout=cancel; elsewhere the system browser opens.
## The payment itself only counts once Stripe tells the server (webhook).


static func open(url: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.location.href = %s;" % JSON.stringify(url))
	else:
		OS.shell_open(url)


## "success" or "cancel" right after Stripe sent the player back, else "".
## Clears the marker from the address so a reload does not show it again.
static func returned() -> String:
	if not OS.has_feature("web"):
		return ""
	var result := str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('checkout') || ''"))
	if not result.is_empty():
		JavaScriptBridge.eval("history.replaceState(null, '', window.location.pathname);")
	return result
