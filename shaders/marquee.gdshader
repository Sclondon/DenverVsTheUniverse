shader_type spatial;
render_mode unshaded;
// The carnival marquee: a row of coloured bulbs chasing along the front of the table.

const vec3 BULBS[4] = vec3[](vec3(1.0, 0.8, 0.25), vec3(1.0, 0.25, 0.5), vec3(0.3, 0.9, 1.0), vec3(0.6, 1.0, 0.3));
varying float lit;
varying vec3 tint;

void vertex() {
	float n = float(INSTANCE_ID);
	tint = BULBS[INSTANCE_ID % 4];
	// Every third bulb is on, and the lit ones march along; now and then the whole row flashes
	lit = step(0.5, fract((n - floor(TIME * 5.0)) / 3.0 + 0.4));
	lit = max(lit, step(0.86, fract(TIME * 0.11)) * step(0.5, fract(TIME * 4.0)));
}

void fragment() {
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	ALBEDO = tint * mix(0.22, 1.5, lit) + vec3(rim * 0.3);
}
