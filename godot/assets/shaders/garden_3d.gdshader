shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

// Prism Garden atmosphere, drawn on a quad behind the vessels.
// Deliberately dark and low contrast: the liquid bands must stay the
// brightest thing on screen, so the garden is mostly silhouette and a single
// pool of light on the shelf where the vessels stand.

uniform vec3 top_colour : source_color = vec3(0.059, 0.188, 0.239);
uniform vec3 mid_colour : source_color = vec3(0.039, 0.129, 0.169);
uniform vec3 low_colour : source_color = vec3(0.025, 0.075, 0.095);
uniform vec3 glow_colour : source_color = vec3(0.250, 0.800, 0.780);
uniform vec3 leaf_colour : source_color = vec3(0.055, 0.220, 0.205);
uniform float glow_strength = 0.18;
uniform float shelf_y = 0.82;
uniform float shelf_strength = 0.14;
uniform float leaf_strength = 0.45;
uniform float mote_strength = 0.22;
uniform float vignette_strength = 0.45;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float leaf_mask(vec2 p, vec2 centre, vec2 radii, float angle) {
	vec2 d = p - centre;
	float s = sin(angle);
	float c = cos(angle);
	d = vec2(c * d.x + s * d.y, -s * d.x + c * d.y);
	d /= radii;
	return 1.0 - smoothstep(0.40, 1.0, length(d));
}

void fragment() {
	vec2 uv = UV;

	vec3 col = mix(top_colour, mid_colour, smoothstep(0.0, 0.60, uv.y));
	col = mix(col, low_colour, smoothstep(0.60, 1.0, uv.y));

	// A wide pool of cool light on the shelf line, where the vessels stand.
	vec2 g = uv - vec2(0.5, shelf_y);
	g.x *= 0.55;
	g.y *= 4.2;
	col += glow_colour * exp(-dot(g, g) * 6.0) * glow_strength;

	// A fine band of light directly under the vessels.
	float shelf = exp(-pow((uv.y - shelf_y) * 40.0, 2.0));
	col += glow_colour * shelf * shelf_strength;

	// Botanical silhouettes entering from the corners.
	float leaves = 0.0;
	leaves += leaf_mask(uv, vec2(-0.02, 0.16), vec2(0.20, 0.13), -0.42);
	leaves += leaf_mask(uv, vec2(1.02, 0.26), vec2(0.18, 0.16), 0.55);
	leaves += leaf_mask(uv, vec2(0.02, 0.90), vec2(0.17, 0.10), 0.30);
	leaves += leaf_mask(uv, vec2(0.98, 0.86), vec2(0.15, 0.09), -0.25);
	leaves = clamp(leaves, 0.0, 1.0);
	col = mix(col, leaf_colour, leaves * leaf_strength * 0.55);

	// Stems: barely-there vertical strokes.
	float stems = 0.0;
	stems += smoothstep(0.004, 0.0, abs(uv.x - 0.10)) * smoothstep(0.98, 0.45, uv.y);
	stems += smoothstep(0.003, 0.0, abs(uv.x - 0.905)) * smoothstep(0.90, 0.35, uv.y);
	col = mix(col, leaf_colour * 0.8, clamp(stems, 0.0, 1.0) * 0.12);

	// Sparse drifting motes, only in the upper half.
	vec2 cell_count = vec2(26.0, 42.0);
	vec2 cell = fract(uv * cell_count) - 0.5;
	vec2 id = floor(uv * cell_count);
	float h = hash21(id);
	float twinkle = 0.45 + 0.55 * sin(TIME * 0.9 + h * 6.2831);
	float mote = smoothstep(0.11, 0.0, length(cell)) * step(0.965, h);
	col += vec3(0.70, 0.95, 1.0) * mote * twinkle * mote_strength * smoothstep(0.95, 0.35, uv.y);

	// Vignette keeps the eye on the board.
	vec2 v = (uv - 0.5) * vec2(1.0, 0.86);
	float vig = smoothstep(0.74, 0.18, length(v));
	col *= mix(1.0 - vignette_strength, 1.0, vig);

	// sub-LSB dither: kills the 8-bit staircases in a near-black gradient
	col += (hash21(uv * vec2(1920.0, 1080.0) + TIME) - 0.5) * (1.6 / 255.0);

	ALBEDO = col;
}
