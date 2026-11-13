extends Node3D

## 3D board rendered into a SubViewport behind the 2D HUD.
## Rendering only: it holds no puzzle state, it is given a snapshot to draw.
##
## The garden lives on a quad behind the vessels, inside this viewport. That is
## deliberately simpler than a transparent viewport: the board stays opaque, so
## there is no depth-sorting or camera-clipping edge case to get wrong, and the
## 2D hit strips keep using the same BoardLayout maths as the 3D placement.

const VesselBuilderScript = preload("res://scripts/presentation/vessel_builder.gd")
const GardenBackdropScript = preload("res://scripts/presentation/garden_backdrop.gd")
const BoardLayoutScript = preload("res://scripts/presentation/board_layout.gd")

const BACKDROP_Z := -1.4
const SELECTED_LIFT := 0.018   # world units, ~20 design px at phone scale

var camera: Camera3D

var _vessels: Node3D
var _backdrop: MeshInstance3D
var _layout: Dictionary = {}
var _signature := ""
var _selected := -1
var _tube_count := 0


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#081A22")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#2E5563")
	env.ambient_light_energy = 0.16
	env.glow_enabled = true
	env.glow_intensity = 0.40
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.15
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, 22, 0)
	key.light_energy = 0.55
	key.light_color = Color("#EAF7FF")
	key.shadow_enabled = false
	add_child(key)

	var rim := OmniLight3D.new()
	rim.position = Vector3(0.6, 0.7, -0.5)
	rim.light_energy = 1.4
	rim.light_color = Color("#7FE9FF")
	rim.omni_range = 3.0
	add_child(rim)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-0.8, 0.2, 0.9)
	fill.light_energy = 0.5
	fill.light_color = Color("#FFD9A0")
	fill.omni_range = 2.4
	add_child(fill)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0, 0, 2.0)
	camera.near = 0.05
	camera.far = 10.0
	add_child(camera)
	camera.current = true

	_backdrop = GardenBackdropScript.build()
	_backdrop.position = Vector3(0, 0, BACKDROP_Z)
	add_child(_backdrop)

	_vessels = Node3D.new()
	add_child(_vessels)

	_fit_camera()
	get_viewport().size_changed.connect(_on_viewport_resized)


func _on_viewport_resized() -> void:
	_fit_camera()


## Keeps the vessel placement and the camera in one coordinate system.
## BoardLayout converts design pixels to world units for both the 3D vessels
## and the 2D hit strips, so the tap targets can never drift from the art.
func _fit_camera() -> void:
	if camera == null:
		return
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 2.0 or vp.y < 2.0:
		return
	var n: int = maxi(1, _tube_count)
	_layout = BoardLayoutScript.compute(n, vp)
	if _layout.is_empty():
		return

	var ppu: float = _layout.ppu
	camera.size = vp.y / (ppu * _layout.scale)

	if _backdrop != null:
		var aspect := vp.x / vp.y
		# a little overscan so fractional window sizes never show an edge
		_backdrop.scale = Vector3(camera.size * aspect * 1.08, camera.size * 1.08, 1.0)
		_backdrop.position = Vector3(0, 0, BACKDROP_Z)
		var mat := _backdrop.material_override as ShaderMaterial
		if mat != null:
			var shelf: float = 0.5 + (_layout.baseline / _layout.design_h - 0.5) / 1.08
			mat.set_shader_parameter("shelf_y", shelf)

	_layout_vessels()


## Rebuilds every vessel from a board snapshot. Rebuilds only when the board
## actually changed; selection-only updates animate the existing meshes.
func set_board(tubes: Array, capacity: int, selected: int) -> void:
	if _vessels == null:
		return
	_tube_count = tubes.size()

	var sig := str(tubes) + "|" + str(capacity)
	if sig != _signature:
		_signature = sig
		for child in _vessels.get_children():
			_vessels.remove_child(child)
			child.queue_free()
		for i in tubes.size():
			_vessels.add_child(VesselBuilderScript.build(tubes[i], capacity, i == selected))
		_selected = selected
		_fit_camera()
		_apply_selection(selected, true)
	else:
		_apply_selection(selected, false)


func _layout_vessels() -> void:
	if _layout.is_empty():
		return
	var ppu: float = _layout.ppu
	var centres: Array = _layout.centres
	var offset_y: float = (_layout.design_h * 0.5 - _layout.baseline) / ppu
	var children := _vessels.get_children()
	for i in children.size():
		if i >= centres.size():
			break
		var v: Node3D = children[i]
		var x: float = (centres[i] - BoardLayoutScript.DESIGN_W * 0.5) / ppu
		v.set_meta("base_x", x)
		v.set_meta("base_y", offset_y)
		v.position = Vector3(x, offset_y, 0)


func _apply_selection(selected: int, instant: bool) -> void:
	if _layout.is_empty():
		return
	var children := _vessels.get_children()
	for i in children.size():
		var v: Node3D = children[i]
		var is_selected: bool = i == selected
		var glass = v.get_meta("glass", null)
		if glass != null:
			glass.material_override = VesselBuilderScript.glass_material(is_selected)
		var pool = v.get_meta("select_glow", null)
		if pool != null:
			pool.visible = is_selected
		var base_y: float = float(v.get_meta("base_y", v.position.y))
		var target_y: float = base_y + (SELECTED_LIFT if is_selected else 0.0)
		if instant:
			v.position.y = target_y
		else:
			var t := create_tween()
			t.tween_property(v, "position:y", target_y, 0.14).set_trans(Tween.TRANS_SINE)
	_selected = selected


## Short horizontal nudge used when a pour is rejected.
func reject(index: int) -> void:
	var children := _vessels.get_children()
	if index < 0 or index >= children.size():
		return
	var v: Node3D = children[index]
	var base_x: float = float(v.get_meta("base_x", v.position.x))
	var t := create_tween()
	t.tween_property(v, "position:x", base_x - 0.02, 0.05)
	t.tween_property(v, "position:x", base_x + 0.02, 0.06)
	t.tween_property(v, "position:x", base_x, 0.07)
