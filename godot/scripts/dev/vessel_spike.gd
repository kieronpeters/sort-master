extends Node3D

## G2 technical spike: one representative vessel, built procedurally.
## Isolated scene - it does not touch the gameplay scene or the 30-level build.
##
## Run with `-- --detail` for a closer three-quarter angle, otherwise the
## gameplay angle is used.

const VESSEL_H := 0.30
const VESSEL_R := 0.085
const LIQUID_R := 0.076
const BAND_H := VESSEL_H / 4.0
const NECK_H := 0.045

const COLOURS := {
	"A": Color("#FFC24B"),
	"B": Color("#46D8D0"),
	"C": Color("#2FA45F"),
	"D": Color("#4D7BF1"),
	"E": Color("#D0A2FF"),
	"F": Color("#F87AA7"),
}
const GLYPHS := {"A": "o", "B": "^", "C": "#", "D": "*", "E": "+", "F": "="}

var detail_view := false

func _ready() -> void:
	detail_view = OS.get_cmdline_user_args().has("--detail")
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
	env.ambient_light_color = Color("#2E5563")
	env.ambient_light_energy = 0.16
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.10
	env.glow_hdr_threshold = 1.1
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

func _setup_lights() -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, 28, 0)
	key.light_energy = 0.80
	key.light_color = Color("#EAF7FF")
	key.shadow_enabled = false
	add_child(key)

	var rim := OmniLight3D.new()
	rim.position = Vector3(0.35, 0.42, -0.35)
	rim.light_energy = 2.0
	rim.light_color = Color("#7FE9FF")
	rim.omni_range = 2.0
	add_child(rim)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-0.30, 0.18, 0.45)
	fill.light_energy = 0.40
	fill.light_color = Color("#FFD9A0")
	fill.omni_range = 1.6
	add_child(fill)

func _glass_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.80, 0.94, 1.0, 0.14)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic = 0.0
	m.metallic_specular = 0.95
	m.rim_enabled = true
	m.rim = 0.8
	m.rim_tint = 0.3
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	return m

func _liquid_material(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	# slight darkening counteracts the tonemap lift that washed the palette out
	m.albedo_color = colour.darkened(0.06)
	m.emission_enabled = true
	m.emission = colour.darkened(0.15)
	m.emission_energy_multiplier = 0.18
	m.roughness = 0.22
	m.metallic = 0.0
	m.metallic_specular = 0.35
	return m

func _ink_for(colour: Color) -> Color:
	# dark ink on light liquids, white on dark ones - the same contrast rule
	# M5-01 applies to text
	return Color(0.04, 0.06, 0.08, 0.92) if colour.get_luminance() > 0.55 else Color(1, 1, 1, 0.95)

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

		var label := Label3D.new()
		label.text = GLYPHS.get(bands[i], "?")
		label.font_size = 44
		label.pixel_size = 0.00042
		label.modulate = _ink_for(colour)
		label.outline_size = 14
		label.outline_modulate = Color(1, 1, 1, 0.55) if colour.get_luminance() <= 0.55 else Color(0, 0, 0, 0.55)
		label.position = Vector3(0, BAND_H * 0.5 + BAND_H * i, LIQUID_R + 0.012)
		root.add_child(label)

	# meniscus: a thin disc plus a bright ring at the liquid surface
	if bands.size() > 0:
		var surface_colour: Color = COLOURS.get(bands[bands.size() - 1], Color.MAGENTA)
		var disc := CylinderMesh.new()
		disc.top_radius = LIQUID_R * 0.99
		disc.bottom_radius = LIQUID_R * 0.99
		disc.height = 0.004
		disc.radial_segments = 40
		var disc_mi := MeshInstance3D.new()
		disc_mi.mesh = disc
		var dm := StandardMaterial3D.new()
		dm.albedo_color = surface_colour.lightened(0.22)
		dm.roughness = 0.12
		dm.metallic_specular = 0.9
		disc_mi.material_override = dm
		disc_mi.position = Vector3(0, BAND_H * bands.size() + 0.001, 0)
		root.add_child(disc_mi)


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

	# neck and lip
	var neck_mesh := CylinderMesh.new()
	neck_mesh.top_radius = VESSEL_R * 0.62
	neck_mesh.bottom_radius = VESSEL_R * 0.72
	neck_mesh.height = NECK_H
	neck_mesh.radial_segments = 40
	var neck := MeshInstance3D.new()
	neck.mesh = neck_mesh
	neck.material_override = _glass_material()
	neck.position = Vector3(0, VESSEL_H + NECK_H * 0.5, 0)
	root.add_child(neck)


	# base disc
	var base := CylinderMesh.new()
	base.top_radius = VESSEL_R * 1.08
	base.bottom_radius = VESSEL_R * 1.08
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
	if detail_view:
		cam.position = Vector3(0.13, 0.20, 0.92)
		cam.look_at_from_position(cam.position, Vector3(-0.05, 0.16, 0))
		cam.fov = 26.0
	else:
		cam.position = Vector3(0, 0.21, 1.45)
		cam.look_at_from_position(cam.position, Vector3(0, 0.17, 0))
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
