shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

// One liquid band.
//
// The bands used to be flat unshaded albedo, which is why they read as paper
// strips rather than liquid: a cylinder with no lateral shading loses all of
// its volume. This shades the band across its width and down its height, so the
// liquid reads as round and as sitting in something.
//
// The lateral coordinate deliberately comes from the *model-space x of the
// vertex*, not from NORMAL: on a cylinder seen face-on the normal turns very
// rapidly only at the silhouette, so a normal-driven ramp collapses into the
// outer few pixels and does nothing. Model-space x maps linearly across the
// width, which is what the eye expects.
//
// The authored palette hex stays the base colour and the middle of the band is
// left at full brightness, so sampled colours still match the palette; only the
// grazing sides and the bottom of each band are pulled down. Liquid must remain
// the brightest thing on screen, so nothing here adds light beyond the rim.

uniform vec3 band_colour : source_color = vec3(1.0, 0.76, 0.29);
uniform float band_radius = 0.0865;

// How far the silhouette edges fall off. 0 = flat, 1 = black edges.
uniform float edge_dim : hint_range(0.0, 1.0) = 0.34;
// Curvature of the falloff: <1 keeps a wider bright core.
uniform float edge_power : hint_range(0.2, 4.0) = 0.85;

// Vertical shaping within the band.
uniform float top_light : hint_range(0.0, 0.5) = 0.06;
uniform float bottom_dim : hint_range(0.0, 0.5) = 0.10;

// A soft vertical sheen on the camera-facing side, like light through glass.
uniform float sheen : hint_range(0.0, 0.4) = 0.07;
uniform float sheen_centre : hint_range(0.0, 1.0) = 0.55;

// The gloss. This is the single biggest difference between flat bands and
// liquid that reads as a substance: a bright, narrow streak down one side where
// the surface catches the light, exactly where a rounded column would.
uniform float highlight : hint_range(0.0, 0.8) = 0.20;
uniform float highlight_pos : hint_range(0.0, 1.0) = 0.30;
uniform float highlight_width : hint_range(0.02, 0.35) = 0.070;

varying float lateral;
varying float lateral_signed;

void vertex() {
	lateral = clamp(abs(VERTEX.x) / max(band_radius, 0.0001), 0.0, 1.0);
	// Signed, so the gloss can sit on one side only. abs() mirrored it and made
	// the highlight read as a wash across the whole band.
	lateral_signed = clamp(VERTEX.x / max(band_radius, 0.0001), -1.0, 1.0);
}

void fragment() {
	float shade = 1.0 - edge_dim * pow(lateral, edge_power);
	shade *= mix(1.0 - bottom_dim, 1.0 + top_light, clamp(UV.y, 0.0, 1.0));

	// Sheen: a soft vertical band where a round surface would catch light.
	float sheen_band = exp(-pow((lateral - sheen_centre) * 3.2, 2.0));
	shade += sheen * sheen_band;

	// Gloss streak, plus a tight core so it reads as a reflection, not a wash.
	float gloss = exp(-pow((lateral_signed + highlight_pos) / highlight_width, 2.0));
	float core = exp(-pow((lateral_signed + highlight_pos) / (highlight_width * 0.42), 2.0));
	shade += highlight * gloss + highlight * 0.45 * core;

	ALBEDO = band_colour * shade;
}
