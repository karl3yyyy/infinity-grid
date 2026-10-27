class_name ChaosWeather
extends CanvasLayer

const WEATHER_SHADER := """
shader_type canvas_item;

uniform float weather_kind = 0.0;
uniform float intensity = 0.12;

float hash(float value) {
	return fract(sin(value * 127.1) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float alpha = 0.0;
	vec3 tint = vec3(0.30, 1.0, 0.42);
	if (weather_kind < 0.5) {
		float column = floor(uv.x * 150.0);
		float fall = fract(uv.y * 7.0 + TIME * (0.55 + hash(column) * 0.35) + hash(column + 4.0));
		float drop = step(0.91, fall) * (0.35 + hash(column + 9.0) * 0.65);
		alpha = drop * intensity;
	} else if (weather_kind < 1.5) {
		float storm = step(0.9, fract((uv.y * 9.0 + uv.x * 2.5) - TIME * 1.4));
		float pulse = 0.5 + 0.5 * sin(TIME * 2.4 + uv.y * 18.0);
		tint = vec3(0.20, 0.72, 1.0);
		alpha = storm * pulse * intensity * 1.8;
	} else {
		float fog = smoothstep(0.35, 0.95, sin(uv.y * 13.0 + TIME * 0.3) * 0.5 + 0.5);
		float glitch = step(0.985, fract(TIME * 0.17 + floor(uv.y * 70.0) * 0.37));
		tint = vec3(0.73, 0.34, 1.0);
		alpha = fog * intensity * 0.45 + glitch * intensity * 1.4;
	}
	COLOR = vec4(tint, clamp(alpha, 0.0, 0.22));
}
"""

var weather_kind: int = 0
var _overlay: ColorRect
var _material: ShaderMaterial


func _ready() -> void:
	layer = 0
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color.WHITE
	var shader := Shader.new()
	shader.code = WEATHER_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_overlay.material = _material
	add_child(_overlay)
	visible = false


func begin(options: Dictionary) -> void:
	var variants := 0
	variants += 1 if bool(options.get("hidden_king", false)) else 0
	variants += 1 if bool(options.get("shifting_tiles", false)) else 0
	variants += 1 if bool(options.get("card_effects", false)) else 0
	weather_kind = randi_range(0, 2)
	_material.set_shader_parameter("weather_kind", float(weather_kind))
	_material.set_shader_parameter("intensity", 0.06 + float(variants) * 0.035)
	visible = variants > 0


func stop() -> void:
	visible = false
