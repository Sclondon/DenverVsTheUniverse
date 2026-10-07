shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
// A tilt-shift lens: only a band around the play plane is sharp, and the table in front of it and
// the scenery behind it fall well out of focus, so the set reads as a small real model
// photographed from close up. Colours are pushed a little, as miniature photographs are.
// Drawn as one sheet over the whole view.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
// Distance to what is in focus, how far either side of it stays sharp, and the most blur.
uniform float focus = 30.0;
uniform float sharp = 4.6;
uniform float strength = 3.4;
uniform float saturation = 1.22;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(vec3(SCREEN_UV, depth) * 2.0 - 1.0, 1.0);
	float away = abs(-view.z / view.w - focus);
	float blur = clamp((away - sharp) / (sharp * 1.6), 0.0, 1.0);
	// The very bottom of the frame is always the near edge of the table
	blur = max(blur, smoothstep(0.86, 1.0, SCREEN_UV.y) * 0.8) * strength;
	vec2 px = blur * 2.2 / VIEWPORT_SIZE;
	vec3 col = textureLod(screen, SCREEN_UV, blur).rgb * 0.28;
	for (int i = 0; i < 6; i++) {
		float a = float(i) * 1.0472;
		col += textureLod(screen, SCREEN_UV + vec2(cos(a), sin(a)) * px, blur).rgb * 0.12;
	}
	col = mix(vec3(dot(col, vec3(0.299, 0.587, 0.114))), col, saturation);
	// A little darkening toward the corners, like a real lens
	vec2 c = SCREEN_UV - 0.5;
	ALBEDO = max(col, vec3(0.0)) * (1.0 - dot(c, c) * 0.6);
}
