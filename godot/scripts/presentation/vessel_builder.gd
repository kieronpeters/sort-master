class_name VesselBuilder
extends RefCounted

## Builds one 3D vessel from a tube's contents. Shared by the G2 spike and the
## gameplay board so there is exactly one definition of the look.

const VESSEL_H := 0.30
const VESSEL_R := 0.085
const LIQUID_R := 0.076
const NECK_H := 0.045
const TOTAL_H := VESSEL_H + NECK_H

const COLOURS := {
	"A": Color("#FFC24B"),
	"B": Color("#46D8D0"),
	"C": Color("#2FA45F"),
	"D": Color("#4D7BF1"),
	"E": Color("#D0A2FF"),
	"F": Color("#F87AA7"),
}
const GLYPHS := {"A": "o", "B": "^", "C": "#", "D": "*", "E": "+", "F": "="}


static func bands_of(contents: Array, capacity: int) -> float:
	return float(contents.size()) / float(max(1, capacity))


static func build(contents: Array, capacity: int, selected: bool = false) -> Node3D:
	var root := Node3D.new()
	var band_h := VESSEL_H / float(capacity)

	for i in contents.size():
		var colour: Color = COLOURS.get(contents[i], Color.MAGENTA)

		var mesh := CylinderMesh.new()
		mesh.top_radius = LIQUID_R
		mesh.bottom_radius = LIQUID_R
		mesh.height = band_h
		mesh.radial_segments = 28
		mesh.rings = 1

		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _liquid_material(colour)
		mi.position = Vector3(0, band_h * 0.5 + band_h * i, 0)
		root.add_child(mi)

		var label := Label3D.new()
		label.text = GLYPHS.get(contents[i], "?")
		label.font_size = 44
		label.pixel_size = 0.00042
		label.modulate = _ink_for(colour)
		label.outline_size = 14
		label.outline_modulate = Color(1, 1, 1, 0.85) if colour.get_luminance() <= 0.55 else Color(0, 0, 0, 0.85)
		label.position = Vector3(0, band_h * 0.5 + band_h * i, LIQUID_R + 0.012)
		root.add_child(label)

	if contents.size() > 0:
		var surface: Color = COLOURS.get(contents[contents.size() - 1], Color.MAGENTA)
		var disc := CylinderMesh.new()
		disc.top_radius = LIQUID_R * 0.99
		disc.bottom_radius = LIQUID_R * 0.99
		disc.height = 0.004
		disc.radial_segments = 32
		var disc_mi := MeshInstance3D.new()
		disc_mi.mesh = disc
		var dm := StandardMaterial3D.new()
		dm.albedo_color = surface.lightened(0.22)
		dm.roughness = 0.12
		dm.metallic_specular = 0.9
		disc_mi.material_override = dm
		disc_mi.position = Vector3(0, band_h * contents.size() + 0.001, 0)
		root.add_child(disc_mi)

	var shell := CylinderMesh.new()
	shell.top_radius = VESSEL_R
	shell.bottom_radius = VESSEL_R
	shell.height = VESSEL_H
	shell.radial_segments = 32
	shell.rings = 1
	var glass := MeshInstance3D.new()
	glass.mesh = shell
	glass.material_override = _glass_material(selected)
	glass.position = Vector3(0, VESSEL_H * 0.5, 0)
	root.add_child(glass)

	var neck_mesh := CylinderMesh.new()
	neck_mesh.top_radius = VESSEL_R * 0.62
	neck_mesh.bottom_radius = VESSEL_R * 0.72
	neck_mesh.height = NECK_H
	neck_mesh.radial_segments = 28
	var neck := MeshInstance3D.new()
	neck.mesh = neck_mesh
	neck.material_override = _glass_material(selected)
	neck.position = Vector3(0, VESSEL_H + NECK_H * 0.5, 0)
	root.add_child(neck)

	var base := CylinderMesh.new()
	base.top_radius = VESSEL_R * 1.08
	base.bottom_radius = VESSEL_R * 1.08
	base.height = 0.012
	base.radial_segments = 32
	var base_mi := MeshInstance3D.new()
	base_mi.mesh = base
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color("#13272F")
	bm.roughness = 0.35
	bm.metallic = 0.4
	base_mi.material_override = bm
	base_mi.position = Vector3(0, 0.006, 0)
	root.add_child(base_mi)

	return root


static func _glass_material(selected: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.86, 0.45, 0.34) if selected else Color(0.80, 0.94, 1.0, 0.14)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic = 0.0
	m.metallic_specular = 0.95
	m.rim_enabled = true
	m.rim = 1.0 if selected else 0.8
	m.rim_tint = 0.15 if selected else 0.3
	m.emission_enabled = selected
	m.emission = Color("#FFD76A")
	m.emission_energy_multiplier = 1.1 if selected else 0.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	return m


static func _liquid_material(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	# Palette hex used verbatim as albedo. No emissive lift: emission was washing
	# the liquid toward pastel and collapsing aqua/amber luminance separation.
	m.albedo_color = colour
	m.emission_enabled = false
	m.roughness = 0.40
	m.metallic_specular = 0.15
	m.metallic = 0.0
	m.metallic_specular = 0.35
	return m


static func _ink_for(colour: Color) -> Color:
	return Color(0.04, 0.06, 0.08, 0.92) if colour.get_luminance() > 0.55 else Color(1, 1, 1, 0.95)
