class_name WebTextInput
extends RefCounted

## Keeps Godot's visible field in the menu while a browser input opens the
## phone keyboard and forwards typed text back into it.

static var _next_id: int = 0
static var _fields: Dictionary = {}
static var _callback: Variant
static var _bridge_ready: bool = false


static func attach(field: LineEdit, title: String) -> void:
	if not OS.has_feature("web") or not DisplayServer.is_touchscreen_available():
		return
	_ensure_bridge()
	var input_id := "ig-text-input-%d" % _next_id
	_next_id += 1
	_fields[input_id] = weakref(field)
	var input_type := "password" if field.secret else (
		"email" if field.virtual_keyboard_type == LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS else "text"
	)
	var window := JavaScriptBridge.get_interface("window")
	window.igGodotTextInputCreate(input_id, title, input_type, field.text)
	field.focus_entered.connect(_focus_input.bind(field, input_id))
	field.focus_exited.connect(_blur_input.bind(input_id))
	field.text_changed.connect(_sync_input.bind(input_id))
	field.tree_exiting.connect(_remove_input.bind(input_id))


static func _ensure_bridge() -> void:
	if _bridge_ready:
		return
	var window := JavaScriptBridge.get_interface("window")
	_callback = JavaScriptBridge.create_callback(_receive_input)
	window.igGodotTextInputCallback = _callback
	JavaScriptBridge.eval("""
		window.igGodotTextInputCreate = function(id, label, type, value) {
			if (document.getElementById(id)) return;
			const input = document.createElement("input");
			input.id = id;
			input.type = type;
			input.setAttribute("aria-label", label);
			input.autocomplete = "off";
			input.autocapitalize = "none";
			input.spellcheck = false;
			Object.assign(input.style, {
				position: "fixed", left: "0px", top: "0px",
				width: "2px", height: "2px", padding: "0", border: "0",
				opacity: "0.02", fontSize: "16px", zIndex: "2147483647",
				pointerEvents: "none"
			});
			input.addEventListener("input", function() {
				if (window.igGodotTextInputCallback)
					window.igGodotTextInputCallback(id, input.value);
			});
			input.addEventListener("keydown", function(event) {
				if (event.key === "Enter") {
					event.preventDefault();
					input.blur();
				}
			});
			input.value = value || "";
			document.body.appendChild(input);
		};
		window.igGodotTextInputFocus = function(id, value) {
			const input = document.getElementById(id);
			if (!input) return;
			input.value = value || "";
			input.focus({preventScroll: true});
		};
		window.igGodotTextInputSet = function(id, value) {
			const input = document.getElementById(id);
			if (input && input.value !== value) input.value = value;
		};
		window.igGodotTextInputBlur = function(id) {
			const input = document.getElementById(id);
			if (input) input.blur();
		};
		window.igGodotTextInputRemove = function(id) {
			const input = document.getElementById(id);
			if (input) input.remove();
		};
	""")
	_bridge_ready = true


static func _focus_input(field: LineEdit, input_id: String) -> void:
	if field.is_inside_tree():
		JavaScriptBridge.get_interface("window").igGodotTextInputFocus(input_id, field.text)


static func _blur_input(input_id: String) -> void:
	JavaScriptBridge.get_interface("window").igGodotTextInputBlur(input_id)


static func _sync_input(value: String, input_id: String) -> void:
	JavaScriptBridge.get_interface("window").igGodotTextInputSet(input_id, value)


static func _receive_input(args: Array) -> void:
	if args.size() < 2:
		return
	var input_id := str(args[0])
	var reference: WeakRef = _fields.get(input_id)
	if reference == null:
		return
	var field := reference.get_ref() as LineEdit
	if field == null or not field.is_inside_tree():
		return
	var value := str(args[1]).substr(0, field.max_length if field.max_length > 0 else 254)
	if field.text != value:
		field.text = value


static func _remove_input(input_id: String) -> void:
	_fields.erase(input_id)
	JavaScriptBridge.get_interface("window").igGodotTextInputRemove(input_id)
