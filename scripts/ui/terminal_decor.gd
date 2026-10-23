class_name TerminalDecor
extends RefCounted

## Small drawn ornaments for the terminal menu footer.


## Wireframe globe: outline, equator, two meridians and two latitudes.
class Globe:
	extends Control

	func _init() -> void:
		custom_minimum_size = Vector2(46.0, 34.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center := size / 2.0
		var radius := Vector2(size.x * 0.46, size.y * 0.46)
		var color := TerminalTheme.GREEN
		_ellipse(center, radius, color)
		_ellipse(center, Vector2(radius.x * 0.45, radius.y), color)
		draw_line(center - Vector2(0.0, radius.y), center + Vector2(0.0, radius.y), color, 1.5)
		for latitude: float in [-0.5, 0.0, 0.5]:
			var y := center.y + radius.y * latitude
			var half := radius.x * sqrt(1.0 - latitude * latitude)
			draw_line(Vector2(center.x - half, y), Vector2(center.x + half, y), color, 1.5)

	func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
		var points := PackedVector2Array()
		for step: int in range(33):
			var angle := TAU * float(step) / 32.0
			points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
		draw_polyline(points, color, 1.5, true)


## Barcode with a fixed bar pattern so it looks the same on every start.
class Barcode:
	extends Control

	const PATTERN := [2, 1, 1, 3, 1, 2, 1, 1, 2, 3, 1, 1, 2, 1, 3, 1, 1, 2, 1, 1, 3, 2, 1, 1, 2, 1, 1, 3, 1, 2]

	func _init() -> void:
		custom_minimum_size = Vector2(110.0, 30.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var total := 0
		for width: int in PATTERN:
			total += width
		var unit := size.x / float(total)
		var x := 0.0
		for index: int in range(PATTERN.size()):
			var width: float = PATTERN[index] * unit
			if index % 2 == 0:
				draw_rect(Rect2(x, 0.0, maxf(width - 0.5, 1.0), size.y), TerminalTheme.GREEN)
			x += width
