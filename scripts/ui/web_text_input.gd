class_name WebTextInput
extends RefCounted

## Phones in the browser often do not raise the keyboard for Godot's LineEdit.
## There the field asks through the browser's own text prompt instead, which
## always opens the keyboard. Elsewhere the LineEdit works as usual.


static func attach(field: LineEdit, title: String) -> void:
	if not OS.has_feature("web") or not DisplayServer.is_touchscreen_available():
		return
	field.focus_entered.connect(func() -> void:
		var current := "" if field.secret else field.text
		var answer: Variant = JavaScriptBridge.eval("window.prompt(%s, %s)" % [JSON.stringify(title), JSON.stringify(current)])
		if answer != null:
			field.text = str(answer).substr(0, field.max_length if field.max_length > 0 else 254)
			field.text_changed.emit(field.text)
		field.release_focus())
