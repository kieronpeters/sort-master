extends Node3D

## 3D board rendered into a SubViewport behind the existing 2D HUD.
## Rendering only: it holds no puzzle state, it is given a snapshot to draw.

const VesselBuilderScript = preload("res://scripts/presentation/vessel_builder.gd")

# Design space shared with the 2D hit overlay (see main.gd)
const DESIGN_W := 1080.0
const DESIGN_H := 900.0
const VESSEL_PX_W := 132.0
const GAP_PX := 14.0
const PX_PER_UNIT := 870.0

var camera: Camera3D
var _vessels: Node3D

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0B1F27")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#2E5563")
	env.ambient_light_energy = 0.10
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.10
	env.glow_hdr_threshold = 1.1
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, 24, 0)
	key.light_energy = 0.60
	key.light_color = Color("#EAF7FF")
	key.shadow_enabled = false
	add_child(key)

	var rim := OmniLight3D.new()
	rim.position = Vector3(0.6, 0.7, -0.5)
	rim.light_energy = 1.5
	rim.light_color = Color("#7FE9FF")
	rim.omni_range = 3.0
	add_child(rim)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0, 0, 2.0)
	camera.near = 0.05
	camera.far = 10.0
	add_child(camera)
	camera.current = true
	_fit_camera()
	get_viewport().size_changed.connect(_fit_camera)

	_vessels = Node3D.new()
	add_child(_vessels)

## Keeps 1 design pixel equal to one screen pixel at any window size.
## The 2D hit areas scale by viewport_width / DESIGN_W, so the camera must use
## the same factor or the vessels and their hit strips drift apart.
func _fit_camera() -> void:
	if camera == null:
		return
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 2.0 or vp.y < 2.0:
		return
	var sx := vp.x / DESIGN_W
	camera.size = vp.y / (PX_PER_UNIT * sx)

## Rebuilds every vessel from a board snapshot.
func set_board(tubes: Array, capacity: int, selected: int) -> void:
	if _vessels == null:
		return
	for child in _vessels.get_children():
		child.queue_free()

	var n := tubes.size()
	if n == 0:
		return
	var total_w := n * VESSEL_PX_W + (n - 1) * GAP_PX
	var start_x := (DESIGN_W - total_w) * 0.5
	var baseline_y := DESIGN_H * 0.86

	for i in n:
		var v = VesselBuilderScript.build(tubes[i], capacity, i == selected)
		var centre_px := start_x + i * (VESSEL_PX_W + GAP_PX) + VESSEL_PX_W * 0.5
		var x := (centre_px - DESIGN_W * 0.5) / PX_PER_UNIT
		var y := (DESIGN_H * 0.5 - baseline_y) / PX_PER_UNIT
		v.position = Vector3(x, y, 0)
		_vessels.add_child(v)
