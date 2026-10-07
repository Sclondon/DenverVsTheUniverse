shader_type spatial;
render_mode specular_disabled;
// The big table. Its top carries the diorama's ground mat (winter plains, with the street the robot
// runs along); around the mat and down the sides it is bare planks.

uniform vec2 mat_half = vec2(24.5, 0.0);
uniform vec2 mat_z = vec2(-16.6, 4.6);
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Planks run the length of the table
	float plank = floor(wp.z * 0.9);
	float grain = sin(wp.x * 1.7 + plank * 5.0) * 0.5 + sin(wp.x * 23.0 + plank) * 0.5;
	vec3 wood = vec3(0.36, 0.22, 0.13) * (0.85 + 0.1 * fract(plank * 0.37) + 0.05 * grain);
	wood *= 1.0 - 0.5 * step(0.94, fract(wp.z * 0.9));
	vec3 col = wood;
	if (wp.y > -0.02 && abs(wp.x) < mat_half.x && wp.z > mat_z.x && wp.z < mat_z.y) {
		// Winter on the plains: bare brown ground with patches of old snow
		col = mix(vec3(0.38, 0.29, 0.22), vec3(0.24, 0.21, 0.27), smoothstep(3.0, -14.0, wp.z));
		vec2 cell = floor(vec2(wp.x * 0.4 + floor(wp.z * 0.7) * 0.37, wp.z * 0.7));
		float patch = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
		col *= 0.9 + 0.2 * patch;
		col = mix(col, vec3(0.86, 0.88, 0.96), step(0.72, patch) * 0.85);
		vec3 asphalt = vec3(0.19, 0.19, 0.26);
		float dash = step(abs(wp.z), 0.045) * step(fract(wp.x * 0.5), 0.5);
		asphalt = mix(asphalt, vec3(0.96, 0.8, 0.3), dash);
		col = mix(col, asphalt, step(abs(wp.z), 0.8));
		col = mix(col, vec3(0.78, 0.76, 0.7), step(abs(abs(wp.z) - 0.8), 0.06));
	}
	ALBEDO = col;
	EMISSION = col * 0.12;
	ROUGHNESS = 1.0;
}
