shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

// Glass without the plastic look: an almost invisible body and a bright
// Fresnel edge. Lighting is intentionally bypassed so the rim stays readable
// against the garden no matter where the key light points.
//
// The Fresnel term is computed from explicitly interpolated view-space
// normals and positions: the built-in NORMAL/VIEW pair is not reliable across
// all of Godot's renderers, and getting it wrong turns the whole body milky.

uniform vec4 body_colour : source_color = vec4(0.70, 0.93, 1.0, 1.0);
uniform vec4 edge_colour : source_color = vec4(0.80, 0.97, 1.0, 1.0);
uniform float body_alpha = 0.035;
uniform float edge_alpha = 0.45;
uniform float edge_power = 2.6;
uniform float glow = 0.0;

varying vec3 v_normal;
varying vec3 v_position;

void vertex() {
	v_normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 view_dir = normalize(-v_position);
	float f = 1.0 - abs(dot(normalize(v_normal), view_dir));
	f = pow(clamp(f, 0.0, 1.0), edge_power);

	ALBEDO = mix(body_colour.rgb, edge_colour.rgb, f);
	ALPHA = clamp(mix(body_alpha, edge_alpha, f) + glow * 0.10, 0.0, 1.0);
}
