shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
// A close-up lens: everything nearer or farther than the play plane goes softly out of focus, so
// the table reads as a small real model photographed from a foot away. Drawn over the whole view.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
// Distance to what is in focus, how far either side of it stays sharp, and the most blur.
uniform float focus = 30.0;
uniform float sharp = 6.5;
uniform float strength = 2.0;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(vec3(SCREEN_UV, depth) * 2.0 - 1.0, 1.0);
	float away = abs(-view.z / view.w - focus);
	float blur = clamp((away - sharp) / (sharp * 1.5), 0.0, 1.0) * strength;
	vec2 px = blur * 1.5 / VIEWPORT_SIZE;
	vec3 col = textureLod(screen, SCREEN_UV, blur).rgb * 0.4;
	col += textureLod(screen, SCREEN_UV + vec2(px.x, px.y), blur).rgb * 0.15;
	col += textureLod(screen, SCREEN_UV + vec2(-px.x, px.y), blur).rgb * 0.15;
	col += textureLod(screen, SCREEN_UV + vec2(px.x, -px.y), blur).rgb * 0.15;
	col += textureLod(screen, SCREEN_UV + vec2(-px.x, -px.y), blur).rgb * 0.15;
	// A little darkening toward the corners, like a real lens
	vec2 c = SCREEN_UV - 0.5;
	ALBEDO = col * (1.0 - dot(c, c) * 0.55);
}
