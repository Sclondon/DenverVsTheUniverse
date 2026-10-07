shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
// The lens the whole view goes through, drawn as one sheet over it. Two looks at once:
// - Tilt-shift: only a band around the play plane is sharp, and the table in front of it and the
//   scenery behind it fall well out of focus, so the set reads as a small model shot from close up.
// - Nintendo 64: the picture is drawn at under 300 lines, in 15-bit colour with the console's dither,
//   and smoothed back up to the screen the soft way its video output did.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
// Distance to what is in focus, how far either side of it stays sharp, and the most blur.
uniform float focus = 30.0;
uniform float sharp = 4.6;
uniform float strength = 2.6;
uniform float saturation = 1.22;
// Lines the picture is drawn at (0 turns the N64 look off) and colour levels per channel.
uniform float lines = 288.0;
uniform float levels = 32.0;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

// The scene at `uv`, out of focus by however far that spot is from the focal plane.
vec3 shot(vec2 uv, float coarse, mat4 unproject) {
	float depth = texture(depth_tex, uv).r;
	vec4 view = unproject * vec4(vec3(uv, depth) * 2.0 - 1.0, 1.0);
	float away = abs(-view.z / view.w - focus);
	float blur = clamp((away - sharp) / (sharp * 1.6), 0.0, 1.0);
	// The very bottom of the frame is always the near edge of the table
	blur = max(blur, smoothstep(0.86, 1.0, uv.y) * 0.8) * strength;
	return textureLod(screen, uv, coarse + blur).rgb;
}

// One pixel of the low picture: the scene there, dithered down to the console's colours.
vec3 console(vec2 cell, vec2 res, float coarse, mat4 unproject) {
	vec3 col = shot((cell + 0.5) / res, coarse, unproject);
	ivec2 at = ivec2(mod(cell, 4.0));
	float nudge = (BAYER[at.y * 4 + at.x] + 0.5) / 16.0 - 0.5;
	return floor(col * (levels - 1.0) + 0.5 + nudge) / (levels - 1.0);
}

void fragment() {
	vec3 col;
	if (lines > 0.0) {
		vec2 res = floor(VIEWPORT_SIZE * lines / VIEWPORT_SIZE.y);
		float coarse = log2(VIEWPORT_SIZE.y / lines);
		vec2 p = SCREEN_UV * res - 0.5;
		vec2 cell = floor(p);
		vec2 f = fract(p);
		col = mix(mix(console(cell, res, coarse, INV_PROJECTION_MATRIX), console(cell + vec2(1.0, 0.0), res, coarse, INV_PROJECTION_MATRIX), f.x),
				mix(console(cell + vec2(0.0, 1.0), res, coarse, INV_PROJECTION_MATRIX), console(cell + vec2(1.0, 1.0), res, coarse, INV_PROJECTION_MATRIX), f.x), f.y);
	} else {
		col = shot(SCREEN_UV, 0.0, INV_PROJECTION_MATRIX);
	}
	col = mix(vec3(dot(col, vec3(0.299, 0.587, 0.114))), col, saturation);
	// A little darkening toward the corners, like a real lens
	vec2 c = SCREEN_UV - 0.5;
	ALBEDO = max(col, vec3(0.0)) * (1.0 - dot(c, c) * 0.6);
}
