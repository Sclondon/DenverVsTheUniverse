shader_type spatial;
#include "res://shaders/splat.gdshaderinc"
// The big table: real planks, with the diorama's ground laid on top of it. The ground is scenic
// turf (dry prairie, green in the parks), a resin lake in each park, and the asphalt street the
// robot runs along.

uniform sampler2D planks_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D planks_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D planks_r : filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 mat_half = vec2(68.5, 0.0);
uniform vec2 mat_z = vec2(-28.6, 7.9);
// Centres of the two parks along the table, and half their length.
uniform vec2 parks = vec2(-37.7, 37.7);
uniform float park_half = 9.3;
uniform vec3 lake = vec3(-6.4, 5.6, 2.3);
varying vec3 wp;
varying float top;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	top = step(0.5, NORMAL.y);
}

void fragment() {
	vec2 uv = mix(vec2(wp.x + wp.z, wp.y), wp.xz, top) * 0.11;
	vec3 col = texture(planks_c, uv).rgb * 0.8;
	vec3 nm = texture(planks_n, uv).rgb;
	float rough = texture(planks_r, uv).r * 0.8;
	// The table has been painted on for years
	vec4 paint = splatter(mix(vec2(wp.x, wp.y * 2.0), wp.xz, top) * 0.9, 0.42);
	col = mix(col, paint.rgb * (0.5 + col.g * 1.6), paint.a * 0.9);
	if (top > 0.5 && abs(wp.x) < mat_half.x && wp.z > mat_z.x && wp.z < mat_z.y) {
		float px = min(abs(wp.x - parks.x), abs(wp.x - parks.y));
		float park = smoothstep(park_half + 0.6, park_half - 0.6, px);
		vec2 guv = wp.xz * 0.13;
		vec3 turf = texture(grass_c, guv).rgb;
		float lum = dot(turf, vec3(0.3, 0.5, 0.2));
		// Outside the parks it is winter prairie: the same turf, dried to straw
		col = mix(vec3(0.4, 0.34, 0.24) * (0.5 + lum * 1.5), turf * vec3(0.5, 0.64, 0.36), park);
		nm = texture(grass_n, guv).rgb;
		rough = 0.95;
		// The lake: poured resin with a sandy shore
		vec2 q = vec2(px, wp.z - lake.x) / lake.yz;
		float shore = length(q) + sin(atan(q.y, q.x) * 5.0 + wp.x) * 0.06;
		col = mix(col, vec3(0.7, 0.62, 0.45), smoothstep(1.16, 1.06, shore));
		float water = smoothstep(1.02, 0.98, shore);
		col = mix(col, mix(vec3(0.1, 0.3, 0.42), vec3(0.03, 0.1, 0.2), smoothstep(1.0, 0.3, shore)), water);
		nm = mix(nm, vec3(0.5, 0.5, 1.0), water);
		rough = mix(rough, 0.04, water);
		// The street, with its kerbs and centre line
		float road = step(abs(wp.z), 1.05);
		vec2 auv = wp.xz * 0.3;
		vec3 asphalt = texture(asphalt_c, auv).rgb * 0.55;
		asphalt = mix(asphalt, vec3(0.86, 0.68, 0.2), step(abs(wp.z), 0.045) * step(fract(wp.x * 0.5), 0.5) * 0.85);
		asphalt = mix(asphalt, vec3(0.62, 0.61, 0.58) * (0.8 + 0.4 * texture(asphalt_c, auv * 2.0).g), step(0.82, abs(wp.z)));
		col = mix(col, asphalt, road);
		nm = mix(nm, texture(asphalt_n, auv).rgb, road);
		rough = mix(rough, 0.82, road);
	}
	ALBEDO = col;
	NORMAL_MAP = nm;
	ROUGHNESS = rough;
	SPECULAR = 0.4;
}
