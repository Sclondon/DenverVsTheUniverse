shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
// The lens the whole view goes through, drawn as one sheet over it. Two looks at once:
// - Tilt-shift: only a band around the play plane is sharp, and the table in front of it and the
//   scenery behind it fall out of focus, so the set reads as a small model shot from close up.
// - Nintendo 64: a light dither to a reduced palette. The low resolution itself is real: the
//   3D picture is rendered small and stretched (Diorama.set_quality), which is also what keeps
//   phones fast.

uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
// Distance to what is in focus, how far either side of it stays sharp, and the most blur (in
// pixels of the small picture).
uniform float focus = 30.0;
uniform float sharp = 4.6;
uniform float strength = 3.0;
uniform float saturation = 1.22;
// Colour levels per channel (0 turns the dither off), and whether to blur at all: the lowest
// quality setting skips it.
uniform float levels = 64.0;
uniform float blurring = 1.0;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

void fragment() {
	vec3 col = texture(screen, SCREEN_UV).rgb;
	if (blurring > 0.5) {
		float depth = texture(depth_tex, SCREEN_UV).r;
		vec4 view = INV_PROJECTION_MATRIX * vec4(vec3(SCREEN_UV, depth) * 2.0 - 1.0, 1.0);
		float away = abs(-view.z / view.w - focus);
		float blur = clamp((away - sharp) / (sharp * 1.6), 0.0, 1.0);
		// The very bottom of the frame is always the near edge of the table
		blur = max(blur, smoothstep(0.86, 1.0, SCREEN_UV.y) * 0.8);
		if (blur > 0.02) {
			// Out of focus is a ring of taps round the spot, wider the further off it is
			vec2 r = blur * strength / VIEWPORT_SIZE;
			col *= 0.2;
			col += texture(screen, SCREEN_UV + vec2(r.x, r.y * 0.4)).rgb * 0.2;
			col += texture(screen, SCREEN_UV + vec2(-r.x, -r.y * 0.4)).rgb * 0.2;
			col += texture(screen, SCREEN_UV + vec2(-r.x * 0.4, r.y)).rgb * 0.2;
			col += texture(screen, SCREEN_UV + vec2(r.x * 0.4, -r.y)).rgb * 0.2;
		}
	}
	col = mix(vec3(dot(col, vec3(0.299, 0.587, 0.114))), col, saturation);
	if (levels > 0.0) {
		ivec2 at = ivec2(mod(FRAGCOORD.xy, 4.0));
		float nudge = (BAYER[at.y * 4 + at.x] + 0.5) / 16.0 - 0.5;
		col = floor(col * (levels - 1.0) + 0.5 + nudge) / (levels - 1.0);
	}
	// A little darkening toward the corners, like a real lens
	vec2 c = SCREEN_UV - 0.5;
	ALBEDO = max(col, vec3(0.0)) * (1.0 - dot(c, c) * 0.6);
}
