class_name TempleMarker
extends RefCounted

## The glowing crown on a KERN's starting square: the enemy KERN that steps onto
## it wins the match (see GridBattleManager.temple_of). Purely visual.

## Same colours as GridBattleUI.TEAM_COLORS; kept here so the arena does not depend on the UI.
const TEAM_COLORS: Array[Color] = [Color("3fa9ff"), Color("ff5a3c")]
const SIZE: float = 1.25
## Cell centre of the KERN's start, in the platform half's local space.
const LOCAL_POSITION := Vector3(0.0, 0.0, 0.7)

const SHADER_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 tint : source_color = vec4(0.25, 0.66, 1.0, 1.0);

float ring(float distance_to_centre, float radius, float width) {
	return smoothstep(width, 0.0, abs(distance_to_centre - radius));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	float pulse = 0.65 + 0.35 * sin(TIME * 2.4);
	float glow = ring(d, 0.9, 0.06) * pulse + ring(d, 0.7, 0.03) * 0.55;
	// Dashes turning slowly between the two rings.
	float turn = atan(p.y, p.x) / 6.2831853 + TIME * 0.05;
	glow += step(0.5, fract(turn * 12.0)) * ring(d, 0.8, 0.04) * 0.5;
	// Crown: a bar with three spikes, point up (screen up is -p.y).
	float x = p.x;
	float y = -p.y;
	float spike = 1.0 - abs(fract((x + 0.5) * 3.0) - 0.5) * 2.0;
	float within = step(-0.5, x) * step(x, 0.5);
	float bar = step(-0.3, y) * step(y, -0.18);
	float spikes = step(-0.18, y) * step(y, -0.18 + spike * 0.5);
	float crown = within * max(bar, spikes);
	float tips = 0.0;
	for (int i = -1; i <= 1; i++) {
		tips = max(tips, smoothstep(0.075, 0.05, length(vec2(x - float(i) * 0.333, y - 0.32))));
	}
	crown = max(crown, tips);
	vec3 color = tint.rgb * (glow + crown * 0.9) + vec3(1.0) * crown * 0.25 * pulse;
	ALBEDO = color * step(d, 1.0);
}
"""

static var _shader: Shader


## A flat marker for `team`'s KERN, lying on the floor at height `y` in the half's space.
static func make(team: int, y: float) -> MeshInstance3D:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	var marker := MeshInstance3D.new()
	marker.name = "TempleMarker"
	var quad := QuadMesh.new()
	quad.size = Vector2(SIZE, SIZE)
	marker.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter("tint", TEAM_COLORS[team])
	marker.material_override = material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.position = LOCAL_POSITION + Vector3(0.0, y, 0.0)
	# Lying flat; the half of team 1 is turned round, so spin the crown back to stand upright for the player.
	marker.rotation = Vector3(-PI * 0.5, 0.0, PI if team == 1 else 0.0)
	return marker
