shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
// The Mile High Dome: a half-ellipse energy shield drawn on a quad whose bottom edge is the ground.

uniform vec3 color : source_color = vec3(0.35, 0.85, 1.0);
uniform float charge = 1.0;
uniform float hit = 0.0;

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
	float r = length(p);
	float inside = step(r, 0.97);
	float ring = smoothstep(0.03, 0.0, abs(r - 0.955));
	float a = atan(p.y, p.x);
	float ribs = smoothstep(0.92, 1.0, abs(sin(a * 9.0))) * 0.5 + smoothstep(0.9, 1.0, abs(sin(r * 16.0 - TIME * 1.5))) * 0.35;
	float glow = inside * r * r * (0.05 + 0.10 * ribs);
	ALBEDO = mix(color, vec3(1.0), hit * 0.6);
	ALPHA = ring * (0.18 + 0.82 * charge) + glow * charge + inside * hit * 0.4 * r;
}
