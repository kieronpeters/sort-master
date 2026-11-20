class_name VesselBuilder
extends RefCounted

## Builds one vessel from a tube's contents.
## Glass is a lathed profile (VesselMesh); liquid is a stack of opaque bands
## inside the inner wall, with a meniscus disc at the surface and a designed
## Colour is the only cue on the liquid itself, as in the genre.

const VesselMeshScript = preload("res://scripts/presentation/vessel_mesh.gd")

const COLOURS := {
	"A": Color("#FFC24B"),
	"B": Color("#46D8D0"),
	"C": Color("#2FA45F"),
	"D": Color("#4D7BF1"),
	"E": Color("#D0A2FF"),
	"F": Color("#F87AA7"),
	# Added 17 Nov 2026 for headroom: eight is the practical ceiling that still
	# clears the separation floor. No shipped level uses G or H yet.
	"G": Color("#FF4428"),
	"H": Color("#4FFFB2"),
}

## Original symbols drawn by tools/make_glyphs.ps1: droplet, prism, leaf,
## sparkle, hexagon, ring. Shape carries the colour identity too.
const GLYPHS_UNUSED := {
	"A": preload("res://assets/2d/glyphs/glyph_a.png"),
	"B": preload("res://assets/2d/glyphs/glyph_b.png"),
	"C": preload("res://assets/2d/glyphs/glyph_c.png"),
	"D": preload("res://assets/2d/glyphs/glyph_d.png"),
	"E": preload("res://assets/2d/glyphs/glyph_e.png"),
	"F": preload("res://assets/2d/glyphs/glyph_f.png"),
	# G and H reuse existing marks; they are secondary cues, not identifiers.
	"G": preload("res://assets/2d/glyphs/glyph_a.png"),
	"H": preload("res://assets/2d/glyphs/glyph_c.png"),
}

## The mark is a quiet secondary cue, not a badge: small, set toward the band's
## left edge, and tinted from the band colour rather than inked in near-black.
## At 4.5:1 the glyphs read as stickers pasted on the liquid, which is what they
## looked like; at this size and contrast the band reads as colour first.

## One liquid band, for callers that need to build or extend a band outside
## build() — the pour animation grows the receiving vessel's level this way.
static func make_band(colour_id: String, index: int, capacity: int, veiled: bool = false) -> MeshInstance3D:
	var band_h: float = VesselMeshScript.capacity_height() / float(maxi(1, capacity))
	var base_y: float = VesselMeshScript.LIQUID_BASE
	var r: float = VesselMeshScript.liquid_radius()

	var mesh := CylinderMesh.new()
	mesh.top_radius = r
	mesh.bottom_radius = r
	mesh.height = band_h
	mesh.radial_segments = 32
	mesh.rings = 1

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _liquid_material(COLOURS.get(colour_id, Color.MAGENTA), index, veiled)
	mi.position = Vector3(0, base_y + band_h * 0.5 + band_h * index, 0)
	mi.set_meta("band_index", index)
	mi.set_meta("band_h", band_h)
	mi.set_meta("band_bottom", base_y + band_h * index)
	mi.set_meta("band_centre", base_y + band_h * 0.5 + band_h * index)
	return mi


## How many liquid bands a built vessel currently shows.
static func band_count(vessel: Node) -> int:
	var n := 0
	for child in vessel.get_children():
		if child.has_meta("band_index"):
			n += 1
	return n


static func build(contents: Array, capacity: int, selected: bool = false, veils: Array = []) -> Node3D:
	var root := Node3D.new()
	var band_h: float = VesselMeshScript.capacity_height() / float(capacity)
	var base_y: float = VesselMeshScript.LIQUID_BASE
	var r: float = VesselMeshScript.liquid_radius()

	var top_band: MeshInstance3D = null
	for i in contents.size():
		var colour: Color = COLOURS.get(contents[i], Color.MAGENTA)

		var mesh := CylinderMesh.new()
		mesh.top_radius = r
		mesh.bottom_radius = r
		mesh.height = band_h
		mesh.radial_segments = 32
		mesh.rings = 1

		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _liquid_material(colour, i, i in veils)
		mi.position = Vector3(0, base_y + band_h * 0.5 + band_h * i, 0)
		# Tagged so the board can animate a band rising when liquid arrives.
		mi.set_meta("band_index", i)
		mi.set_meta("band_h", band_h)
		mi.set_meta("band_bottom", base_y + band_h * i)
		mi.set_meta("band_centre", base_y + band_h * 0.5 + band_h * i)
		root.add_child(mi)
		if i == contents.size() - 1:
			top_band = mi


	# meniscus: a lighter lip at the liquid surface, slightly inset
	if contents.size() > 0:
		var surface: Color = COLOURS.get(contents[contents.size() - 1], Color.MAGENTA)
		# A domed surface, not a flat cap: real liquid bulges slightly at the
		# rim of the tube, and the curved highlight is what makes the top band
		# read as a fluid surface rather than a cut-off cylinder.
		var dome := SphereMesh.new()
		dome.radius = r * 0.995
		dome.height = 0.026
		dome.radial_segments = 32
		dome.rings = 8
		dome.is_hemisphere = true
		var disc_mi := MeshInstance3D.new()
		disc_mi.mesh = dome
		var dm := StandardMaterial3D.new()
		dm.albedo_color = surface.lightened(0.11)
		dm.roughness = 0.14
		dm.metallic_specular = 0.85
		disc_mi.material_override = dm
		# Parented to the top band, so the surface sinks and flattens as that band
		# drains. As a sibling it stayed at the original height, which is why a
		# draining bottle kept a coloured cap floating above the receding liquid.
		if top_band != null:
			top_band.add_child(disc_mi)
			disc_mi.position = Vector3(0, band_h * 0.5 - 0.002, 0)
		else:
			disc_mi.position = Vector3(0, base_y + band_h * contents.size() - 0.004, 0)
			root.add_child(disc_mi)

	# dark inner neck, so the mouth reads as an opening rather than a cap
	var bore := CylinderMesh.new()
	bore.top_radius = 0.045
	bore.bottom_radius = 0.045
	bore.height = 0.055
	bore.radial_segments = 32
	var bore_mi := MeshInstance3D.new()
	bore_mi.mesh = bore
	var bm_inner := StandardMaterial3D.new()
	bm_inner.albedo_color = Color("#081A20")
	bm_inner.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm_inner.cull_mode = BaseMaterial3D.CULL_DISABLED
	bore_mi.material_override = bm_inner
	bore_mi.position = Vector3(0, 0.482, 0)
	root.add_child(bore_mi)

	# A contact shadow used to sit here: a dark sprite squashed to 0.38 and laid on
	# the ground. Seen from this camera it collapsed into a hard black bar across
	# the base of every bottle, reading as a gap rather than as glass. The base is
	# drawn by the vessel mesh itself, so the shadow is gone.

	# The selection used to draw a soft glow sprite here. It was parented to the
	# vessel, so it lifted and tilted with the bottle and stayed visible right
	# through the pour, which read as a yellow aura under a moving object. The
	# glass tint and the raised slot already mark the selection, so the glow is
	# gone rather than moved.

	# lathed glass
	# A finished bottle gets corked, like the reference: the cork is the "done"
	# signal you can read at a glance without counting bands.
	var full := contents.size() == capacity and contents.size() > 0
	if full:
		var same := true
		for c in contents:
			if c != contents[0]:
				same = false
				break
		if same:
			var cork := MeshInstance3D.new()
			var cork_mesh := CylinderMesh.new()
			cork_mesh.top_radius = 0.044
			cork_mesh.bottom_radius = 0.038
			cork_mesh.height = 0.052
			cork_mesh.radial_segments = 24
			cork.mesh = cork_mesh
			var cork_mat := StandardMaterial3D.new()
			cork_mat.albedo_color = Color(0.68, 0.47, 0.28)
			cork_mat.roughness = 0.85
			cork.material_override = cork_mat
			cork.position = Vector3(0, 0.508, 0)
			root.add_child(cork)

	var glass := MeshInstance3D.new()
	glass.mesh = VesselMeshScript.build_glass(false)
	glass.material_override = glass_material(selected)
	root.add_child(glass)
	root.set_meta("glass", glass)

	# This used to draw a dark cylinder at the foot of every bottle. It was meant
	# as a plinth but rendered as a hard near-black bar across the base, which read
	# as a gap under the glass. The silhouette now closes its own floor, so the
	# plinth is gone.

	return root

const GLASS_SHADER = preload("res://assets/shaders/glass.gdshader")
const LIQUID_SHADER = preload("res://assets/shaders/liquid.gdshader")

static func glass_material(selected: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GLASS_SHADER
	if selected:
		m.set_shader_parameter("body_colour", Color(1.0, 0.95, 0.85))
		m.set_shader_parameter("edge_colour", Color(1.0, 0.82, 0.38))
		m.set_shader_parameter("body_alpha", 0.022)
		m.set_shader_parameter("edge_alpha", 0.62)
		m.set_shader_parameter("edge_power", 5.0)
		m.set_shader_parameter("glow", 0.0)
	else:
		m.set_shader_parameter("body_colour", Color(0.50, 0.66, 0.72))
		m.set_shader_parameter("edge_colour", Color(0.80, 0.97, 1.0))
		m.set_shader_parameter("body_alpha", 0.014)
		m.set_shader_parameter("edge_alpha", 0.55)
		m.set_shader_parameter("edge_power", 5.0)
		m.set_shader_parameter("glow", 0.0)
	return m

static func _liquid_material(colour: Color, index: int, veiled: bool = false) -> ShaderMaterial:
	# Deeper bands read as more liquid; the palette hue stays the base and the
	# shader leaves the middle of the band at full brightness, so sampled colours
	# still match the authored hex. The shader supplies the cylindrical shading
	# the old flat unshaded albedo could not, which is what made the bands read
	# as paper strips instead of liquid.
	var m := ShaderMaterial.new()
	m.shader = LIQUID_SHADER
	m.set_shader_parameter("band_colour", colour.darkened(0.03 * float(index)))
	m.set_shader_parameter("edge_dim", 0.52)
	m.set_shader_parameter("edge_power", 0.62)
	m.set_shader_parameter("top_light", 0.08)
	m.set_shader_parameter("bottom_dim", 0.14)
	m.set_shader_parameter("sheen", 0.13)
	m.set_shader_parameter("sheen_centre", 0.55)
	m.set_shader_parameter("band_radius", VesselMeshScript.liquid_radius())
	m.set_shader_parameter("veiled", 1.0 if veiled else 0.0)
	m.set_shader_parameter("sheen_power", 5.0)
	return m

## Soft radial falloff used for the contact shadow behind each vessel.
static func _shadow_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.0, 0.02, 0.03, 0.55))
	grad.set_color(1, Color(0.0, 0.02, 0.03, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex

static func _glow_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.86, 0.52, 0.55))
	grad.set_color(1, Color(1.0, 0.86, 0.52, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex

## The mark's tint: a lightened version of the band, kept deliberately close to
## it. Shape stays available as a cue without the black silhouette dominating.

