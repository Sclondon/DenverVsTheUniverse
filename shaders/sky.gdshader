shader_type spatial;
render_mode specular_disabled;
// The painted backdrop board at the back of the table: a Front Range winter dusk fading up into a
// starry night. It is lit by the lamps like everything else, so it falls off into the dark room.

uniform vec3 top : source_color = vec3(0.03, 0.03, 0.12);
uniform vec3 mid : source_color = vec3(0.50, 0.36, 0.74);
uniform vec3 low : source_color = vec3(0.98, 0.68, 0.80);
uniform float horizon = 0.08;
uniform vec2 cells = vec2(260.0, 50.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float h = 1.0 - UV.y;
	vec3 col = mix(low, mid, smoothstep(horizon, horizon + 0.3, h));
	col = mix(col, top, smoothstep(horizon + 0.2, horizon + 0.75, h));
	vec2 g = UV * cells;
	vec2 id = floor(g);
	float r = hash(id);
	vec2 off = vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5;
	float dist = length(fract(g) - 0.5 - off * 0.6);
	float twinkle = 0.65 + 0.35 * sin(TIME * (1.0 + r * 3.0) + r * 40.0);
	float star = step(0.9, r) * step(dist, 0.07 + 0.1 * fract(r * 17.0)) * twinkle;
	col += vec3(1.0, 0.97, 0.85) * star * smoothstep(horizon + 0.3, horizon + 0.6, h);
	ALBEDO = col;
	EMISSION = col * 0.2;
	ROUGHNESS = 1.0;
}
