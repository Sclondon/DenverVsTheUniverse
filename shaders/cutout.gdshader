shader_type spatial;
render_mode cull_disabled, specular_disabled;
#include "res://shaders/splat.gdshaderinc"
// A flat cut-out standing on the table, lit by the lamps overhead: art with an edge of bare
// material (plywood, card) around its silhouette. `cut` tears the top off (buildings crumble from
// the roof down) and scorches the torn edge. `solid` paints the whole shape one colour, for the
// plywood backing board behind each building.

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 texel = vec2(0.01);
uniform float border = 3.0;
uniform vec3 paper : source_color = vec3(0.97, 0.94, 0.86);
uniform vec3 tint : source_color = vec3(1.0);
uniform float flash = 0.0;
uniform float cut = 1.0;
uniform float solid = 0.0;
// How much of its own colour the piece shows even in shadow.
uniform float glow = 0.22;
// Pixel art: the size of one chunky pixel, in texels, so each is drawn as one crisp block (0 = smooth art).
uniform float chunk = 0.0;
// Plywood: real wood grain on the bare edge and back, and showing faintly through the paint.
uniform sampler2D wood : source_color, filter_linear_mipmap, repeat_enable;
uniform float wooden = 0.0;
// Flips the art left to right (turning the piece itself round would turn its face from the lamps).
uniform float mirror = 0.0;
varying vec2 grain_uv;
varying vec2 world_xy;

void vertex() {
	grain_uv = VERTEX.xy * 0.3;
	world_xy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xy + MODEL_MATRIX[3].z * 3.7;
	if (mirror > 0.5) {
		UV.x = 1.0 - UV.x;
	}
}

void fragment() {
	vec4 c = texture(tex, UV);
	if (chunk > 0.0) {
		vec2 cell = texel * chunk;
		c = textureGrad(tex, (floor(UV / cell) + 0.5) * cell, dFdx(UV), dFdy(UV));
	}
	vec2 o = texel * border;
	vec2 d = o * 0.7071;
	float edge = c.a;
	if (UV2.x < 0.5) {
	edge = max(edge, texture(tex, UV + vec2(o.x, 0.0)).a);
	edge = max(edge, texture(tex, UV - vec2(o.x, 0.0)).a);
	edge = max(edge, texture(tex, UV + vec2(0.0, o.y)).a);
	edge = max(edge, texture(tex, UV - vec2(0.0, o.y)).a);
	edge = max(edge, texture(tex, UV + d).a);
	edge = max(edge, texture(tex, UV - d).a);
	edge = max(edge, texture(tex, UV + vec2(d.x, -d.y)).a);
	edge = max(edge, texture(tex, UV + vec2(-d.x, d.y)).a);
	}
	// The layers behind the face are cut to the art itself; only the face has the routed rim
	if (edge < 0.5 || (UV2.x > 0.5 && c.a < 0.5)) {
		discard;
	}
	vec3 col = mix(paper, c.rgb, smoothstep(0.35, 0.65, c.a));
	// Layers behind the face (UV2.x = 1) are bare board: the thickness of the sheet
	float bare = max(solid, UV2.x);
	col = mix(col, paper, bare);
	if (wooden > 0.0) {
		vec3 g = texture(wood, grain_uv).rgb;
		float painted = smoothstep(0.35, 0.65, c.a) * (1.0 - bare);
		col = mix(g * 1.5 * (1.0 - 0.3 * UV2.y), col, painted);
		// Whoever painted it was not careful: splatter on the bare wood, the odd fleck on the art
		vec4 paint = splatter(world_xy * 1.1, mix(0.45, 0.025, painted));
		col = mix(col, paint.rgb, paint.a * 0.92);
	}
	if (cut < 0.999) {
		float h = 1.0 - UV.y;
		float jag = sin(UV.x * 37.0) * 0.012 + sin(UV.x * 91.0 + 1.7) * 0.008 + sin(UV.x * 13.0 + 0.4) * 0.015;
		float left = cut + jag - h;
		if (left < 0.0) {
			discard;
		}
		col = mix(col, vec3(0.08, 0.06, 0.08), smoothstep(0.09, 0.0, left) * 0.8);
	}
	col = mix(col * tint, vec3(1.0), flash);
	ALBEDO = col;
	EMISSION = col * (glow + flash);
	ROUGHNESS = 1.0;
}
