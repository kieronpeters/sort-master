class_name VesselBuilder
extends RefCounted

## Builds one vessel from a tube's contents.
## Glass is a lathed profile (VesselMesh); liquid is a stack of opaque bands
## inside the inner wall, with a meniscus disc at the surface.

const VesselMeshScript = preload("res://scripts/presentation/vessel_mesh.gd")

const COLOURS := {
	"A": Color("#FFC24B"),
	"B": Color("#46D8D0"),
	"C": Color("#2FA45F"),
	"D": Color("#4D7BF1"),
	"E": Color("#D0A2FF"),
	"F": Color("#F87AA7"),
}
const GLYPHS := {"A": "o", "B": "^", "C": "#", "D": "*", "E": "+", "F": "="}

static func build(contents: Array, capacity: int, selected: bool = false) -> Node3D:
	var root := Node3D.new()
	var band_h: float = VesselMeshScript.capacity_height() / float(capacity)
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
		mi.position = Vector3(0, band_h * 0.5 + band_h * i, 0)
		root.add_child(mi)

		var label := Label3D.new()
		label.text = GLYPHS.get(contents[i], "?")
		label.font_size = 84
		label.pixel_size = 0.0005
		label.modulate = _ink_for(colour)
		label.outline_size = 26
		label.outline_modulate = Color(1, 1, 1, 0.85) if colour.get_luminance() <= 0.55 else Color(0, 0, 0, 0.85)
		label.position = Vector3(0, band_h * 0.5 + band_h * i, r + 0.008)
		root.add_child(label)

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
		dm.albedo_color = surface.lightened(0.18)
		dm.roughness = 0.10
		dm.metallic_specular = 0.95
		disc_mi.material_override = dm
		disc_mi.position = Vector3(0, band_h * contents.size() + 0.002, 0)
		root.add_child(disc_mi)

	# lathed glass
	var glass := MeshInstance3D.new()
	glass.mesh = VesselMeshScript.build_glass()
	glass.material_override = _glass_material(selected)
	root.add_child(glass)

	# base plinth
	var base := CylinderMesh.new()
	base.top_radius = 0.090
	base.bottom_radius = 0.094
	base.height = 0.014
	base.radial_segments = 40
	var base_mi := MeshInstance3D.new()
	base_mi.mesh = base
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color("#12242b")
	bm.roughness = 0.30
	bm.metallic = 0.55
	base_mi.material_override = bm
	base_mi.position = Vector3(0, 0.006, 0)
	root.add_child(base_mi)

	return root

static func _glass_material(selected: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.86, 0.45, 0.30) if selected else Color(0.86, 0.96, 1.0, 0.13)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.03
	m.metallic = 0.0
	m.metallic_specular = 1.0
	m.rim_enabled = true
	m.rim = 1.0 if selected else 0.85
	m.rim_tint = 0.15 if selected else 0.45
	m.emission_enabled = selected
	m.emission = Color("#FFD76A")
	m.emission_energy_multiplier = 0.9 if selected else 0.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	return m

static func _liquid_material(colour: Color, index: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	# deeper bands read as more liquid; the palette hex stays the base
	var shade: float = 0.04 * float(index)
	m.albedo_color = colour.darkened(shade)
	m.emission_enabled = false
	m.roughness = 0.38
	m.metallic_specular = 0.18
	return m

static func _ink_for(colour: Color) -> Color:
	return Color(0.04, 0.06, 0.08, 0.92) if colour.get_luminance() > 0.55 else Color(1, 1, 1, 0.95)
