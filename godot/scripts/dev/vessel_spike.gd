extends Node3D

## G2 technical spike: one representative vessel, built procedurally.
## Isolated scene - it does not touch the gameplay scene or the 30-level build.
## Purpose is to judge glass, liquid, sorting and readability on the desktop,
## not to produce a final asset.

const VESSEL_H := 0.30
const VESSEL_R := 0.085
const LIQUID_R := 0.076
const BAND_H := VESSEL_H / 4.0

const COLOURS := {
	"A": Color("#FFC24B"),
	"B": Color("#46D8D0"),
	"C": Color("#2FA45F"),
	"D": Color("#4D7BF1"),
	"E": Color("#D0A2FF"),
	"F": Color("#F87AA7"),
}
const GLYPHS := {"A": "o", "B": "^", "C": "#", "D": "*", "E": "+", "F": "="}

func _ready() -> void:
	_setup_environment()
	_setup_lights()
	_build_vessel(Vector3(-0.24, 0, 0), ["A", "A", "B"])
	_build_vessel(Vector3(0, 0, 0), ["C", "C", "C", "C"])
	_build_vessel(Vector3(0.24, 0, 0), ["D", "E"])
	_setup_camera()
	_add_caption()

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0B1F27")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#3E6B7A")
	env.ambient_light_energy = 0.30
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

func _setup_lights() -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, 28, 0)
	key.light_energy = 1.05
	key.light_color = Color("#EAF7FF")
	key.shadow_enabled = false
	add_child(key)

	var rim := OmniLight3D.new()
	rim.position = Vector3(0.35, 0.42, -0.35)
	rim.light_energy = 2.2
	rim.light_color = Color("#7FE9FF")
	rim.omni_range = 2.0
	add_child(rim)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-0.3, 0.18, 0.45)
	fill.light_energy = 0.9
	fill.light_color = Color("#FFD9A0")
	fill.omni_range = 1.6
	add_child(fill)

func _glass_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.78, 0.93, 1.0, 0.16)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.06
	m.metallic = 0.0
	m.metallic_specular = 0.9
	m.rim_enabled = true
	m.rim = 0.65
	m.rim_tint = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	return m

func _liquid_material(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 0.18
	m.metallic = 0.0
	m.metallic_specular = 0.7
	m.rim_enabled = true
	m.rim = 0.25
	return m

func _build_vessel(origin: Vector3, bands: Array) -> void:
	var root := Node3D.new()
	root.position = origin
	add_child(root)

	# liquid, bottom up (opaque: avoids stacking transparent volumes)
	for i in bands.size():
		var colour: Color = COLOURS.get(bands[i], Color.MAGENTA)
		var mesh := CylinderMesh.new()
		mesh.top_radius = LIQUID_R
		mesh.bottom_radius = LIQUID_R
		mesh.height = BAND_H
		mesh.radial_segments = 40
		mesh.rings = 1

		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _liquid_material(colour)
		mi.position = Vector3(0, BAND_H * 0.5 + BAND_H * i, 0)
		root.add_child(mi)

		# permanent glyph cue, in front of the band
		var label := Label3D.new()
		label.text = GLYPHS.get(bands[i], "?")
		label.font_size = 44
		label.pixel_size = 0.00042
		label.modulate = Color(1, 1, 1, 0.92)
		label.outline_size = 8
		label.outline_modulate = Color(0, 0, 0, 0.45)
		label.position = Vector3(0, BAND_H * 0.5 + BAND_H * i, LIQUID_R + 0.012)
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		root.add_child(label)

	# glass shell last so it sorts in front of the liquid
	var shell := CylinderMesh.new()
	shell.top_radius = VESSEL_R
	shell.bottom_radius = VESSEL_R
	shell.height = VESSEL_H
	shell.radial_segments = 48
	shell.rings = 1

	var glass := MeshInstance3D.new()
	glass.mesh = shell
	glass.material_override = _glass_material()
	glass.position = Vector3(0, VESSEL_H * 0.5, 0)
	root.add_child(glass)

	# base disc so the vessel reads as standing, not floating
	var base := CylinderMesh.new()
	base.top_radius = VESSEL_R * 1.06
	base.bottom_radius = VESSEL_R * 1.06
	base.height = 0.012
	base.radial_segments = 48
	var base_mi := MeshInstance3D.new()
	base_mi.mesh = base
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color("#13272F")
	bm.roughness = 0.35
	bm.metallic = 0.4
	base_mi.material_override = bm
	base_mi.position = Vector3(0, 0.006, 0)
	root.add_child(base_mi)

func _setup_camera() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.21, 1.45)
	cam.look_at_from_position(cam.position, Vector3(0, 0.15, 0))
	cam.fov = 30.0
	cam.near = 0.02
	cam.far = 4.0
	add_child(cam)
	cam.current = true

func _add_caption() -> void:
	var label := Label3D.new()
	label.text = "rules-v1  |  mobile renderer  |  opaque liquid, alpha glass"
	label.font_size = 26
	label.pixel_size = 0.0004
	label.modulate = Color(0.85, 0.95, 1.0, 0.75)
	label.position = Vector3(0, 0.40, 0)
	add_child(label)
