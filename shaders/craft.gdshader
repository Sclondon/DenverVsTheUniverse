shader_type canvas_item;
#include "res://shaders/splat.gdshaderinc"
// A panel made by hand: a piece of corrugated cardboard (or lined paper) cut out with scissors,
// outlined in marker, flecked with paint and stuck on with two strips of masking tape.
// Goes on a ColorRect; `size` must be the size of that rect in pixels.

uniform vec2 size = vec2(600.0, 160.0);
uniform vec3 base : source_color = vec3(0.80, 0.63, 0.42);
uniform float seed = 0.0;
// 0 = cardboard, 1 = lined paper.
uniform float lined = 0.0;
uniform float taped = 1.0;
// Room left round the panel for the tape to overhang.
uniform float inset = 14.0;

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(splat_hash(i), splat_hash(i + vec2(1.0, 0.0)), f.x), mix(splat_hash(i + vec2(0.0, 1.0)), splat_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// A strip of tape `len` long across the point `at`, turned by `turn`.
float tape(vec2 p, vec2 at, float turn, float len) {
	vec2 d = p - at;
	d = vec2(d.x * cos(turn) + d.y * sin(turn), d.y * cos(turn) - d.x * sin(turn));
	return step(abs(d.y), 13.0 + noise(vec2(d.x * 0.3, seed)) * 2.0) * step(abs(d.x) + noise(vec2(d.y * 0.9, seed + 4.0)) * 5.0, len);
}

void fragment() {
	vec2 p = UV * size;
	// Cut by hand: the edge wanders
	vec2 q = abs(p - size * 0.5) - (size * 0.5 - inset - 12.0);
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - 12.0;
	d += (noise(p * 0.035 + seed) - 0.5) * 7.0 + (noise(p * 0.2 + seed) - 0.5) * 1.5;
	float card = smoothstep(1.0, -1.0, d);
	vec3 col = base * (0.9 + 0.2 * noise(p * 0.5 + seed));
	// Corrugations on cardboard, ruled lines on paper
	col *= 1.0 - (1.0 - lined) * 0.07 * step(0.5, fract(p.y / 7.0));
	col = mix(col, vec3(0.45, 0.62, 0.85), lined * 0.5 * step(fract((p.y - inset) / 30.0), 0.05));
	vec4 paint = splatter(p * 0.02 + seed * 7.0, 0.05);
	col = mix(col, paint.rgb, paint.a * 0.85);
	// The outline, drawn round it twice in marker and not quite meeting
	float pen = smoothstep(2.6, 1.2, abs(d + 7.0 + (noise(p * 0.02 + seed + 9.0) - 0.5) * 5.0));
	pen = max(pen, 0.6 * smoothstep(1.8, 0.8, abs(d + 11.0 + (noise(p * 0.03 + seed + 2.0) - 0.5) * 7.0)));
	col = mix(col, vec3(0.1, 0.09, 0.16), pen * 0.9);
	// The cut edge is a shade darker
	col *= 1.0 - 0.3 * smoothstep(-3.0, 0.0, d);
	float strips = taped * max(tape(p, vec2(inset + 22.0, inset + 10.0), -0.6, 44.0), tape(p, vec2(size.x - inset - 22.0, inset + 10.0), 0.55, 44.0));
	col = mix(col, vec3(0.93, 0.87, 0.68) * (0.92 + 0.08 * step(0.5, fract(p.x * 0.5))), strips * 0.88);
	COLOR = vec4(col * COLOR.rgb, max(card, strips * 0.92) * COLOR.a);
}
