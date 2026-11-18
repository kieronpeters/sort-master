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
static func make_band(colour_id: String, index: int, capacity: int) -> MeshInstance3D:
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
	mi.material_override = _liquid_material(COLOURS.get(colour_id, Color.MAGENTA), index)
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


static func build(contents: Array, capacity: int, selected: bool = false) -> Node3D:
	var root := Node3D.new()
	var band_h: float = VesselMeshScript.capacity_height() / float(capacity)
	var base_y: float = VesselMeshScript.LIQUID_BASE
	var r: float = VesselMeshScript.liquid_radius()

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
		mi.material_override = _liquid_material(colour, i)
		mi.position = Vector3(0, base_y + band_h * 0.5 + band_h * i, 0)
		# Tagged so the board can animate a band rising when liquid arrives.
		mi.set_meta("band_index", i)
		mi.set_meta("band_h", band_h)
		mi.set_meta("band_bottom", base_y + band_h * i)
		mi.set_meta("band_centre", base_y + band_h * 0.5 + band_h * i)
		root.add_child(mi)


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

	# contact shadow, so the vessel sits on the garden rather than floating
	var shadow := Sprite3D.new()
	shadow.texture = _shadow_texture()
	shadow.pixel_size = 0.34 / 64.0
	shadow.scale = Vector3(1.0, 0.38, 1.0)
	shadow.position = Vector3(0, 0.030, -0.10)
	shadow.modulate = Color(1, 1, 1, 0.55)
	shadow.shaded = false
	root.add_child(shadow)

	# selection pool, so the chosen tube reads at a glance
	var pool := Sprite3D.new()
	pool.texture = _glow_texture()
	pool.pixel_size = 0.46 / 64.0
	pool.scale = Vector3(1.0, 0.42, 1.0)
	pool.position = Vector3(0, 0.045, -0.09)
	pool.modulate = Color(1, 1, 1, 0.55)
	pool.visible = selected
	pool.shaded = false
	root.add_child(pool)
	root.set_meta("select_glow", pool)

	# lathed glass
	var glass := MeshInstance3D.new()
	glass.mesh = VesselMeshScript.build_glass(false)
	glass.material_override = glass_material(selected)
	root.add_child(glass)
	root.set_meta("glass", glass)

	# base plinth
	var base := CylinderMesh.new()
	base.top_radius = 0.088
	base.bottom_radius = 0.091
	base.height = 0.010
	base.radial_segments = 40
	var base_mi := MeshInstance3D.new()
	base_mi.mesh = base
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color("#16323C")
	bm.roughness = 0.42
	bm.metallic = 0.20
	base_mi.material_override = bm
	base_mi.position = Vector3(0, 0.006, 0)
	root.add_child(base_mi)

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

static func _liquid_material(colour: Color, index: int) -> ShaderMaterial:
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

