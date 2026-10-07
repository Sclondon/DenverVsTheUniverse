shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
// The robot's force field: a bubble of hexagonal cells that glows at its rim, with a bright band
// sweeping over it. `power` fades it in and out; `pop` (1 falling to 0) is the flash as it takes a hit.

uniform vec3 color : source_color = vec3(0.5, 1.0, 0.35);
uniform float power = 1.0;
uniform float pop = 0.0;

// Distance to the nearest edge of a honeycomb, 0 on the lines.
float hex(vec2 p) {
	p.x *= 1.1547;
	p.y += mod(floor(p.x), 2.0) * 0.5;
	p = abs(fract(p) - 0.5);
	return abs(max(p.x * 1.5 + p.y, p.y * 2.0) - 1.0);
}

void fragment() {
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.5);
	float cells = smoothstep(0.1, 0.0, hex(UV * vec2(26.0, 13.0)));
	float sweep = smoothstep(0.12, 0.0, abs(fract(UV.y * 1.5 - TIME * 0.35) - 0.5));
	float flicker = 0.85 + 0.15 * sin(TIME * 17.0 + UV.y * 30.0);
	ALBEDO = mix(color, vec3(1.0), pop * 0.7 + sweep * 0.3);
	ALPHA = clamp((rim * 0.45 + cells * (0.04 + 0.35 * rim + 0.3 * sweep)) * flicker * power + pop * (0.35 + cells * 0.5), 0.0, 1.0);
}
