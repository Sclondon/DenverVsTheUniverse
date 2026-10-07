shader_type spatial;
render_mode cull_disabled, specular_disabled;
#include "res://shaders/splat.gdshaderinc"
// A cut-out standing on the table, lit by the lamps overhead. Two kinds:
// - A flat sheet of art (a quad) with a rim of bare paper found round its silhouette (`border`).
// - A piece of cardboard (`card`): a real thin slab cut to the outline of the art (Cutout.add_backing),
//   with the art on its face, bare board on its edge and back (UV2.x = 1), paint splatter, and
//   damage. `wear` (0 to 1) scorches it, then blows holes through it; `cut` brings the top down.

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 texel = vec2(0.01);
uniform float border = 3.0;
uniform vec3 paper : source_color = vec3(0.97, 0.94, 0.86);
uniform vec3 tint : source_color = vec3(1.0);
uniform float flash = 0.0;
uniform float cut = 1.0;
uniform float wear = 0.0;
// How much of its own colour the piece shows even in shadow.
uniform float glow = 0.22;
// Pixel art: the size of one chunky pixel, in texels, so each is drawn as one crisp block (0 = smooth art).
uniform float chunk = 0.0;
uniform float card = 0.0;
// Mirrors the art on a flat sheet (`mirror`) or the whole slab (`flip`). Turning the piece itself
// round would turn its face from the lamps.
uniform float mirror = 0.0;
uniform float flip = 0.0;
varying vec2 world_xy;
varying float world_x;
// Nothing is drawn further than this from the middle of the table (0 = no limit): the backdrop
// stops where the table does.
uniform float world_clip = 0.0;

void vertex() {
	if (flip > 0.5) {
		VERTEX.x = -VERTEX.x;
		NORMAL.x = -NORMAL.x;
	}
	world_xy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xy + MODEL_MATRIX[3].z * 3.7;
	world_x = (MODEL_MATRIX * vec4(VERTEX, 1.0)).x;
	if (mirror > 0.5) {
		UV.x = 1.0 - UV.x;
	}
}

void fragment() {
	if (world_clip > 0.0 && abs(world_x) > world_clip) {
		discard;
	}
	vec4 c = texture(tex, UV);
	if (chunk > 0.0) {
		vec2 cell = texel * chunk;
		// Crisp blocks only while a block is bigger than a pixel on screen. Smaller than that,
		// picking blocks one by one turns rows of windows into crawling lines, so the art is
		// left to blend smoothly.
		if (cell.y > fwidth(UV).y * 1.6) {
			c = textureGrad(tex, (floor(UV / cell) + 0.5) * cell, dFdx(UV), dFdy(UV));
		}
	}
	vec3 col = mix(paper, c.rgb, smoothstep(0.35, 0.65, c.a));
	if (card < 0.5) {
		// A flat sheet: keep the art and a rim of paper round it
		vec2 o = texel * border;
		vec2 d = o * 0.7071;
		float edge = c.a;
		edge = max(edge, texture(tex, UV + vec2(o.x, 0.0)).a);
		edge = max(edge, texture(tex, UV - vec2(o.x, 0.0)).a);
		edge = max(edge, texture(tex, UV + vec2(0.0, o.y)).a);
		edge = max(edge, texture(tex, UV - vec2(0.0, o.y)).a);
		edge = max(edge, texture(tex, UV + d).a);
		edge = max(edge, texture(tex, UV - d).a);
		edge = max(edge, texture(tex, UV + vec2(d.x, -d.y)).a);
		edge = max(edge, texture(tex, UV + vec2(-d.x, d.y)).a);
		if (edge < 0.5) {
			discard;
		}
	} else {
		float painted = step(0.5, c.a) * (1.0 - UV2.x);
		// Bare cardboard: kraft brown, with the flutes showing as stripes along the cut edge
		vec3 board = paper * (0.86 + 0.14 * splat_hash(floor(world_xy * 30.0))) * (1.0 - 0.25 * UV2.y * step(0.5, fract(world_xy.y * 14.0 + world_xy.x * 14.0)));
		col = mix(board, col, painted);
		// Whoever painted it was not careful: splatter on the bare board, the odd fleck on the art
		vec4 paint = splatter(world_xy * 1.1, mix(0.45, 0.01, painted));
		col = mix(col, paint.rgb, paint.a * 0.92);
		if (wear > 0.02) {
			// Damage comes in stages: grime, then scorch marks, then holes blown clean through
			vec2 at = world_xy * 1.5 + 31.0;
			vec4 burn = splatter(at, wear * 0.75);
			col = mix(col, vec3(0.07, 0.06, 0.07), burn.a * 0.88 * painted);
			col *= 1.0 - 0.3 * wear;
			if (wear > 0.28 && splatter(at, (wear - 0.28) * 0.7).a > 0.9) {
				discard;
			}
			// Ember glow round fresh holes
			col += vec3(1.0, 0.35, 0.05) * burn.a * (1.0 - burn.a) * 1.6 * wear * painted;
		}
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
