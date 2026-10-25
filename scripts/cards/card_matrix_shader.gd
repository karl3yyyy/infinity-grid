class_name CardMatrixShader
extends RefCounted

## Matrix look for the 3D cards: falling glyphs on the back, a scan reveal of the
## face, a neon rim and a halo around the picked card. The quad is larger than the
## card by `pad` pixels so the halo can spill over the edge.
const CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_test_disabled;

uniform sampler2D face_tex : source_color, filter_linear;
uniform vec4 glow_color : source_color = vec4(0.25, 1.0, 0.4, 1.0);
uniform vec4 team_color : source_color = vec4(0.4, 0.7, 1.0, 1.0);
uniform vec2 card_size = vec2(240.0, 270.0);
uniform float pad = 28.0;
uniform float margin = 5.0;
uniform float cut = 12.0;
uniform float selected : hint_range(0.0, 1.0) = 0.0;
uniform float hover : hint_range(0.0, 1.0) = 0.0;
uniform float dim : hint_range(0.0, 1.0) = 0.0;
// 0 = only the rain, 1 = the face is fully scanned in.
uniform float reveal : hint_range(0.0, 1.0) = 1.0;
// 0 = invisible, 1 = fully booted.
uniform float appear : hint_range(0.0, 1.0) = 1.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
// The scene tone mapper dulls everything; this puts the card back to flat-UI brightness.
uniform float exposure = 1.5;
// Skin: colour of the code rain, dark base of the back, back pattern and speed.
uniform vec4 rain_color : source_color = vec4(0.12, 1.0, 0.38, 1.0);
uniform vec4 base_color : source_color = vec4(0.0, 0.035, 0.02, 1.0);
uniform int back_mode = 0;
uniform float rain_speed = 1.0;

float rand(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453);
}

// Falling glyph columns: bright head, fading trail, flickering random glyphs.
vec3 rain(vec2 uv, float aspect, float t) {
	float columns = 13.0;
	float rows = columns * aspect;
	vec2 g = vec2(uv.x * columns, uv.y * rows);
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float column_rand = rand(vec2(cell.x, 1.0));
	float speed = (0.5 + column_rand * 1.1) * rain_speed;
	float span = rows + 10.0;
	float head = mod(t * speed * 5.0 + column_rand * 40.0, span) - 5.0;
	float behind = head - cell.y;
	float trail = (behind >= 0.0 && behind < 14.0) ? exp(-behind * 0.28) : 0.0;
	float glyph_seed = rand(cell + floor(t * 4.0 + column_rand * 9.0));
	vec2 gp = floor(f * vec2(4.0, 6.0));
	float lit = step(0.48, rand(gp + glyph_seed * 31.0));
	float inside_cell = step(0.12, f.x) * step(f.x, 0.88) * step(0.1, f.y) * step(f.y, 0.9);
	float strength = trail * lit * inside_cell;
	vec3 tint = rain_color.rgb * strength;
	if (behind >= 0.0 && behind < 1.0) {
		tint = mix(tint, mix(rain_color.rgb, vec3(1.0), 0.8), lit * inside_cell);
	}
	return tint;
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(rand(i), rand(i + vec2(1.0, 0.0)), f.x), mix(rand(i + vec2(0.0, 1.0)), rand(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Back of the card for every skin: rain, rising embers, synthwave grid or stars.
vec3 back_pattern(vec2 q, float aspect, float t) {
	vec3 color = base_color.rgb;
	if (back_mode == 1) {
		color += rain(vec2(q.x, 1.0 - q.y), aspect, t) * 0.95;
	} else if (back_mode == 2) {
		float horizon = 0.55;
		vec2 sun = (q - vec2(0.5, 0.36)) * vec2(1.0, aspect);
		float disc = 1.0 - smoothstep(0.2, 0.215, length(sun));
		float stripes = step(0.0, sin(q.y * 90.0 - t * 2.0)) * step(0.38, q.y) + step(q.y, 0.38);
		color += glow_color.rgb * disc * clamp(stripes, 0.0, 1.0) * 0.9 * step(q.y, horizon);
		if (q.y > horizon) {
			float depth = (q.y - horizon) / (1.0 - horizon);
			float rows = abs(fract(1.0 / (depth + 0.08) * 0.5 - t * 0.35) - 0.5);
			float columns = abs(fract((q.x - 0.5) / (depth + 0.08) * 0.9) - 0.5);
			float grid = max(smoothstep(0.06, 0.0, rows), smoothstep(0.06 + depth * 0.04, 0.0, columns));
			color += rain_color.rgb * grid * (0.35 + depth);
		}
	} else if (back_mode == 3) {
		vec2 g = q * vec2(26.0, 26.0 * aspect);
		float star = step(0.965, rand(floor(g)));
		float twinkle = 0.55 + 0.45 * sin(t * 3.0 + rand(floor(g) + 3.0) * 20.0);
		float cloud = noise(q * 4.0 + vec2(t * 0.05, 0.0)) * 0.6 + noise(q * 9.0 - vec2(0.0, t * 0.04)) * 0.4;
		color += glow_color.rgb * cloud * cloud * 0.35 + rain_color.rgb * star * twinkle;
	} else {
		color += rain(vec2(1.0 - q.x, q.y), aspect, t) * 0.95;
	}
	return color;
}

// Lemniscate (infinity sign) as a thin glowing line.
float infinity_line(vec2 p) {
	vec2 q = p * 2.4;
	float r2 = dot(q, q);
	float f = r2 * r2 - 0.9 * (q.x * q.x - q.y * q.y);
	return 1.0 - smoothstep(0.0, 2.2, abs(f) / (fwidth(f) + 1e-5));
}

void fragment() {
	vec2 total = card_size + vec2(pad * 2.0);
	vec2 px = UV * total - vec2(pad);
	vec2 q = px / card_size;
	// Signed distance to the rim of the (inset) card rectangle, in pixels.
	vec2 half_rect = card_size * 0.5 - vec2(margin);
	vec2 c = abs(px - card_size * 0.5) - half_rect;
	float sd = length(max(c, 0.0)) + min(max(c.x, c.y), 0.0);
	// Two cut corners like the flat card: top left and bottom right.
	vec2 local = px - vec2(margin);
	vec2 frame = card_size - vec2(margin * 2.0);
	float corner_a = local.x + local.y - cut;
	float corner_b = (frame.x - local.x) + (frame.y - local.y) - cut;
	sd = max(sd, -min(corner_a, corner_b) * 0.7071);

	float t = TIME;
	float aspect = card_size.y / card_size.x;
	vec3 color = vec3(0.0);
	float alpha = 0.0;

	float body = 1.0 - smoothstep(-0.5, 0.8, sd);
	if (body > 0.0) {
		vec3 base;
		float base_alpha;
		if (FRONT_FACING) {
			vec4 face = texture(face_tex, q);
			// Scan reveal: a bright line sweeps down, the face appears above it.
			float line = reveal * 1.25 - 0.1;
			float shown = 1.0 - smoothstep(line - 0.05, line, q.y + rand(vec2(floor(q.x * 40.0), 3.0)) * 0.08);
			vec3 digital = rain(q, aspect, t);
			base = mix(vec3(0.0, 0.03, 0.015) + digital, face.rgb, shown * face.a);
			float scan = smoothstep(0.03, 0.0, abs(q.y - line)) * step(reveal, 0.999) * step(0.001, reveal);
			base += vec3(0.5, 1.0, 0.6) * scan * 1.5;
			// Faint moving scanlines keep the glass alive.
			base *= 0.94 + 0.06 * sin(q.y * card_size.y * 0.9 - t * 4.0);
			base_alpha = max(face.a * shown, 0.94 * (1.0 - shown));
		} else {
			base = back_pattern(q, aspect, t);
			base += team_color.rgb * 0.12 * infinity_line((q - 0.5) * vec2(1.0, aspect));
			base += glow_color.rgb * infinity_line((q - 0.5) * vec2(1.0, aspect)) * 0.9;
			base_alpha = 0.97;
		}
		// Rain streaks along the rim of the picked card.
		float band = 1.0 - smoothstep(0.0, 22.0, -sd);
		base += rain(q, aspect, t * 1.6 + 7.0) * band * selected * 1.2;
		color = base;
		alpha = base_alpha * body;
	}

	// Neon rim, brighter when picked or hovered.
	float rim_core = 1.0 - smoothstep(0.0, 1.8, abs(sd + 1.0));
	float energy = 0.55 + hover * 0.5 + selected * (1.1 + 0.4 * sin(t * 5.0));
	vec3 rim_color = mix(team_color.rgb, glow_color.rgb, selected);
	color += rim_color * rim_core * energy * 1.6;
	alpha = max(alpha, rim_core * 0.95);

	// Halo outside the card.
	float outside = max(sd, 0.0);
	float halo = exp(-outside / 9.0) * step(0.0, sd - 0.5);
	float halo_energy = selected * (0.85 + 0.25 * sin(t * 5.0)) + hover * 0.25 + flash * 1.2;
	color += glow_color.rgb * halo * halo_energy * 2.0;
	alpha = max(alpha, clamp(halo * halo_energy, 0.0, 0.9));

	// Dimmed when it is the other side's turn.
	color *= 1.0 - dim * 0.5;
	color += vec3(0.7, 1.0, 0.8) * flash * body * 0.5;
	ALBEDO = color * exposure;
	ALPHA = clamp(alpha, 0.0, 1.0) * appear;
}
"""

static var _shader: Shader


static func make_material() -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CODE
	var material := ShaderMaterial.new()
	material.shader = _shader
	return material
