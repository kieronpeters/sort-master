class_name VesselBuilder
extends RefCounted

## Builds one vessel from a tube's contents.
## Glass is a lathed profile (VesselMesh); liquid is a stack of opaque bands
## inside the inner wall, with a meniscus disc at the surface and a designed
## symbol on every band so colour is never the only cue.

const VesselMeshScript = preload("res://scripts/presentation/vessel_mesh.gd")

const COLOURS := {
	"A": Color("#FFC24B"),
	"B": Color("#46D8D0"),
	"C": Color("#2FA45F"),
	"D": Color("#4D7BF1"),
	"E": Color("#D0A2FF"),
	"F": Color("#F87AA7"),
}

## Original symbols drawn by tools/make_glyphs.ps1: droplet, prism, leaf,
## sparkle, hexagon, ring. Shape carries the colour identity too.
const GLYPHS := {
	"A": preload("res://assets/2d/glyphs/glyph_a.png"),
	"B": preload("res://assets/2d/glyphs/glyph_b.png"),
	"C": preload("res://assets/2d/glyphs/glyph_c.png"),
	"D": preload("res://assets/2d/glyphs/glyph_d.png"),
	"E": preload("res://assets/2d/glyphs/glyph_e.png"),
	"F": preload("res://assets/2d/glyphs/glyph_f.png"),
}

const SYMBOL_WORLD_H := 0.040

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
		root.add_child(mi)

		var symbol := Sprite3D.new()
		symbol.texture = GLYPHS.get(contents[i], GLYPHS["A"])
		symbol.pixel_size = SYMBOL_WORLD_H / 128.0
		symbol.modulate = _ink_for(colour)
		symbol.shaded = false
		symbol.double_sided = true
		symbol.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		symbol.position = Vector3(0, base_y + band_h * 0.5 + band_h * i, r + 0.010)
		root.add_child(symbol)

	# meniscus: a lighter lip at the liquid surface, slightly inset
	if contents.size() > 0:
		var surface: Color = COLOURS.get(contents[contents.size() - 1], Color.MAGENTA)
		var disc := CylinderMesh.new()
		disc.top_radius = r * 0.97
		disc.bottom_radius = r
		disc.height = 0.005
		disc.radial_segments = 32
		var disc_mi := MeshInstance3D.new()
		disc_mi.mesh = disc
		var dm := StandardMaterial3D.new()
		dm.albedo_color = surface.lightened(0.10)
		dm.roughness = 0.22
		dm.metallic_specular = 0.55
		disc_mi.material_override = dm
		disc_mi.position = Vector3(0, base_y + band_h * contents.size() + 0.002, 0)
		root.add_child(disc_mi)

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
	base.top_radius = 0.090
	base.bottom_radius = 0.094
	base.height = 0.014
	base.radial_segments = 40
	var base_mi := MeshInstance3D.new()
	base_mi.mesh = base
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color("#1B3A44")
	bm.roughness = 0.38
	bm.metallic = 0.30
	base_mi.material_override = bm
	base_mi.position = Vector3(0, 0.006, 0)
	root.add_child(base_mi)

	return root

const GLASS_SHADER = preload("res://assets/shaders/glass.gdshader")

static func glass_material(selected: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GLASS_SHADER
	if selected:
		m.set_shader_parameter("body_colour", Color(1.0, 0.95, 0.85))
		m.set_shader_parameter("edge_colour", Color(1.0, 0.82, 0.38))
		m.set_shader_parameter("body_alpha", 0.0)
		m.set_shader_parameter("edge_alpha", 0.62)
		m.set_shader_parameter("edge_power", 5.0)
		m.set_shader_parameter("glow", 0.0)
	else:
		m.set_shader_parameter("body_colour", Color(0.70, 0.93, 1.0))
		m.set_shader_parameter("edge_colour", Color(0.80, 0.97, 1.0))
		m.set_shader_parameter("body_alpha", 0.0)
		m.set_shader_parameter("edge_alpha", 0.55)
		m.set_shader_parameter("edge_power", 5.0)
		m.set_shader_parameter("glow", 0.0)
	return m

static func _liquid_material(colour: Color, index: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	# deeper bands read as more liquid; the palette hex stays the base
	# unshaded keeps the palette hex faithful; the bands must stay the
	# brightest, most legible thing on screen
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = colour.darkened(0.03 * float(index))
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

static func _ink_for(colour: Color) -> Color:
	return Color(0.03, 0.05, 0.07, 0.92) if colour.get_luminance() > 0.55 else Color(1, 1, 1, 0.95)
