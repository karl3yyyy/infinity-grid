class_name MatrixEffects
extends Node3D

## Falling green code on the hangar walls and a code stream under the floor
## trusses, with a sweeping scan line and short glitch bars. Purely visual.

const CODE_GREEN := Color("46ff6e")
## How far the code panels sit in front of the wall faces.
const WALL_INSET: float = 0.35

const CODE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 tint : source_color = vec4(0.27, 1.0, 0.43, 1.0);
uniform vec2 grid = vec2(40.0, 56.0);
uniform float strength = 0.55;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float column = floor(uv.x * grid.x);
	float row = floor(uv.y * grid.y);
	float head = fract(TIME * (0.12 + hash(vec2(column, 1.0)) * 0.45) + hash(vec2(column, 7.0)));
	// Distance behind the falling head; the trail fades with it.
	float behind = fract(head - uv.y);
	float trail = exp(-behind * 7.0);
	vec2 cell = fract(uv * grid);
	float glyph_id = hash(vec2(column, row) + floor(TIME * 3.0 * hash(vec2(row, column))));
	vec2 dots = floor(cell * vec2(3.0, 5.0));
	float dot_on = step(0.45, hash(dots + glyph_id * 17.0));
	float inside = step(0.15, cell.x) * step(cell.x, 0.85) * step(0.1, cell.y) * step(cell.y, 0.9);
	float glyph = dot_on * inside;
	float head_glow = smoothstep(0.035, 0.0, behind);
	vec3 color = tint.rgb * glyph * trail * strength + vec3(0.85, 1.0, 0.9) * glyph * head_glow;
	// A bright scan line that sweeps down, and rare glitch rows.
	color += tint.rgb * smoothstep(0.012, 0.0, abs(fract(TIME * 0.06) - uv.y)) * 0.25;
	color += tint.rgb * step(0.994, hash(vec2(row, floor(TIME * 5.0)))) * 0.5;
	color *= smoothstep(0.0, 0.1, uv.y) * smoothstep(1.0, 0.85, uv.y);
	ALBEDO = color;
}
"""

var _shader: Shader


func build(wall_half_width: float, wall_height: float, floor_y: float) -> void:
	_shader = Shader.new()
	_shader.code = CODE_SHADER
	var inner := wall_half_width - WALL_INSET
	var wall_center_y := floor_y + wall_height * 0.5
	for side: int in range(4):
		var panel := _make_panel(Vector2(inner * 2.0, wall_height), Vector2(40.0, 56.0), 0.5)
		var angle := float(side) * PI * 0.5
		panel.rotation.y = angle
		panel.position = Vector3(sin(angle), 0.0, cos(angle)) * inner + Vector3(0.0, wall_center_y, 0.0)
		add_child(panel)
	# Code streaming upwards under the truss floor.
	var stream := _make_panel(Vector2(inner * 2.0, inner * 2.0), Vector2(70.0, 70.0), 0.9)
	stream.rotation.x = -PI * 0.5
	stream.position = Vector3(0.0, floor_y + 0.1, 0.0)
	add_child(stream)


func _make_panel(size: Vector2, grid: Vector2, strength: float) -> MeshInstance3D:
	var panel := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	panel.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter("tint", CODE_GREEN)
	material.set_shader_parameter("grid", grid)
	material.set_shader_parameter("strength", strength)
	panel.material_override = material
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return panel
