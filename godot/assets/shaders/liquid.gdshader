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
uniform float top_light : hint_range(0.0, 0.5) = 0.0;
uniform float bottom_dim : hint_range(0.0, 0.5) = 0.0;

// Seam. Zeroed deliberately: bands are drawn as separate cylinders, and any
// darkening at their top and bottom edges turns a stack of one colour into
// visible squares. Real liquid in a tube is one continuous body, so the bands
// must meet with no line between them. Left as a parameter for future use.
uniform float seam_dim : hint_range(0.0, 0.6) = 0.0;
uniform float seam_width : hint_range(0.01, 0.35) = 0.085;

// A soft vertical sheen on the camera-facing side, like light through glass.
uniform float sheen : hint_range(0.0, 0.4) = 0.07;
uniform float sheen_centre : hint_range(0.0, 1.0) = 0.55;

// The gloss. This is the single biggest difference between flat bands and
// liquid that reads as a substance: a bright, narrow streak down one side where
// the surface catches the light, exactly where a rounded column would.
uniform float highlight : hint_range(0.0, 0.8) = 0.20;

// Veil. A "hidden colour" band is drawn as fabric instead of liquid: the player
// can see that something is there but not what colour, so they have to reason
// about it rather than read it. Revealing is handled by the game, which clears
// the flag; the shader only draws what it is told.
uniform float veiled : hint_range(0.0, 1.0) = 0.0;
uniform vec3 cloth_colour : source_color = vec3(0.36, 0.40, 0.44);
uniform float cloth_weave : hint_range(0.0, 0.5) = 0.16;
uniform float highlight_pos : hint_range(0.0, 1.0) = 0.30;

// Fresnel rim. This is the term the band was missing: a real column of liquid
// brightens at its silhouette because you are looking through more of it edge-on.
// It is driven by the geometry normal against the view direction, not by the
// lateral coordinate, so it stays correct when the vessel is tilted - which is
// exactly when the flat readings fall apart.
uniform float rim : hint_range(0.0, 0.9) = 0.42;
uniform float rim_power : hint_range(0.5, 8.0) = 2.4;

// A slow, shallow wobble on the gloss so a still surface does not look like a
// painted stripe. Kept very small: this is life, not movement.
uniform float flow : hint_range(0.0, 0.2) = 0.035;
uniform float flow_speed : hint_range(0.0, 2.0) = 0.18;
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

	// 1.0 across the middle of the band, falling to 0 at both seams.
	float seam = smoothstep(0.0, seam_width, UV.y) * smoothstep(1.0, 1.0 - seam_width, UV.y);
	shade *= mix(1.0 - seam_dim, 1.0, seam);

	// Sheen: a soft vertical band where a round surface would catch light.
	float sheen_band = exp(-pow((lateral - sheen_centre) * 3.2, 2.0));
	shade += sheen * sheen_band;

	// Gloss streak, plus a tight core so it reads as a reflection, not a wash.
	float drift = flow * sin(TIME * flow_speed + UV.y * 6.2831);
	float gloss = exp(-pow((lateral_signed + highlight_pos + drift) / highlight_width, 2.0));
	float core = exp(-pow((lateral_signed + highlight_pos) / (highlight_width * 0.42), 2.0));
	shade += highlight * gloss + highlight * 0.45 * core;

	vec3 colour = band_colour;

	// Woven cross-hatch so a veil reads as cloth rather than a flat grey band.
	if (veiled > 0.001) {
		float weave = sin(UV.y * 220.0) * sin(lateral_signed * 26.0);
		colour = mix(band_colour, cloth_colour * (1.0 + weave * cloth_weave), veiled);
		// veiled bands keep the cross-section shading but lose the liquid gloss
		shade = mix(shade, shade * 0.92, veiled);
	}

	// Rim last, and additive: it is light that has travelled through the liquid
	// and come out at the edge, so it brightens rather than tints.
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	shade += rim * pow(1.0 - facing, rim_power);

	ALBEDO = colour * shade;
}
