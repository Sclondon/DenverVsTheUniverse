// Paint splatter: fat carnival-coloured blobs with ragged edges, as if flicked off a brush.

const vec3 PAINTS[5] = vec3[](vec3(1.0, 0.24, 0.5), vec3(0.2, 0.85, 0.9), vec3(1.0, 0.82, 0.12), vec3(0.55, 1.0, 0.25), vec3(0.6, 0.3, 0.9));

float splat_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// The paint at `p`: rgb is its colour and a how thickly it lies. `amount` (0 to 1) is how much
// of the surface has been splattered.
vec4 splatter(vec2 p, float amount) {
	vec4 best = vec4(0.0);
	vec2 cell = floor(p);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = cell + vec2(float(i), float(j));
			float h = splat_hash(c);
			if (h > amount) {
				continue;
			}
			vec2 d = p - c - vec2(splat_hash(c + 3.1), splat_hash(c + 7.7));
			float ang = atan(d.y, d.x);
			float r = (0.14 + 0.3 * splat_hash(c + 1.3)) * (1.0 + 0.35 * sin(ang * 5.0 + h * 40.0) + 0.2 * sin(ang * 11.0 + h * 90.0));
			float a = smoothstep(r, r * 0.86, length(d));
			if (a > best.a) {
				best = vec4(PAINTS[int(splat_hash(c + 9.4) * 4.99)], a);
			}
		}
	}
	return best;
}
