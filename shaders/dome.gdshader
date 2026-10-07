shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
// The Mile High Dome: a half-ellipse energy shield drawn on a quad whose bottom edge is the ground.
// Honeycomb cells bulge toward the rim like a real bubble, a band of light sweeps up it, and it
// rings and flashes when it soaks up a bomb.

uniform vec3 color : source_color = vec3(0.35, 0.85, 1.0);
uniform float charge = 1.0;
uniform float hit = 0.0;

float hex(vec2 p) {
	p.x *= 1.1547;
	p.y += mod(floor(p.x), 2.0) * 0.5;
	p = abs(fract(p) - 0.5);
	return abs(max(p.x * 1.5 + p.y, p.y * 2.0) - 1.0);
}

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
	float r = length(p);
	float inside = step(r, 0.97);
	float ring = smoothstep(0.03, 0.0, abs(r - 0.955));
	// Wrap the honeycomb over a sphere: cells crowd together toward the edge
	vec2 ball = p / max(r, 0.001) * asin(min(r, 1.0)) * 1.2;
	float cells = smoothstep(0.09, 0.0, hex(ball * 9.0));
	float sweep = smoothstep(0.1, 0.0, abs(fract(r * 1.2 - TIME * 0.3) - 0.5));
	float ripple = smoothstep(0.06, 0.0, abs(r - (1.0 - hit))) * hit;
	float glow = inside * (r * r * 0.06 + cells * (0.05 + 0.3 * r * r * r + 0.25 * sweep));
	ALBEDO = mix(color, vec3(1.0), hit * 0.6 + sweep * 0.2);
	ALPHA = ring * (0.18 + 0.82 * charge) + glow * charge + inside * (hit * 0.35 * r + ripple * 0.8);
}
