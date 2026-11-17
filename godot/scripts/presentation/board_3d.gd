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

## Pour feedback. The state is committed on the same frame (the flow suite
## asserts the move counter one frame after a tap), so this is presentation
## only: the source tilts, the arriving liquid rises out of nothing, and a short
## stream marks where it went. Without it a move just teleports liquid.
const POUR_TIP_DEG := 62.0
const POUR_LIFT := 0.62
const POUR_TRAVEL := 0.22
const POUR_POUR := 0.45
const POUR_RETURN := 0.20
## The travelling vessel is pulled toward the camera so it passes in front of
## its neighbours instead of behind them (all vessels sit at z = 0).
const POUR_FRONT := 0.55

var camera: Camera3D

var _vessels: Node3D
var _backdrop: MeshInstance3D
var _layout: Dictionary = {}
var _signature := ""
var _selected := -1
var _tube_count := 0
var _capacity := 4
var _pour_tweens: Array = []
var _pour_stream: MeshInstance3D = null


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0B1F27")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#2E5563")
	env.ambient_light_energy = 0.16
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.15
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
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
	_capacity = capacity

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


## The pour, as the genre does it: the source vessel lifts out of its slot,
## carries its liquid across, tips over the destination, pours, and returns.
##
## It runs against the *previous* visual board on purpose - the game state has
## already committed, so the vessels on screen still show the pre-pour board.
## `done` is called when the vessel is home; the caller rebuilds from state then.
func pour(from_i: int, to_i: int, units: int, colour_id: String, done: Callable) -> void:
	if DisplayServer.get_name() == "headless":
		done.call()
		return

	var children := _vessels.get_children()
	if from_i < 0 or to_i < 0 or from_i >= children.size() or to_i >= children.size():
		done.call()
		return

	var src: Node3D = children[from_i]
	var dst: Node3D = children[to_i]
	var hue: Color = VesselBuilderScript.COLOURS.get(colour_id, Color.WHITE)
	var count: int = maxi(1, units)

	var home := Vector3(float(src.get_meta("base_x", src.position.x)),
			float(src.get_meta("base_y", src.position.y)), 0.0)
	var dst_x: float = float(dst.get_meta("base_x", dst.position.x))
	var base_y: float = float(dst.get_meta("base_y", dst.position.y))
	var src_count := VesselBuilderScript.band_count(src)
	var dst_count := VesselBuilderScript.band_count(dst)

	# Tip right past horizontal and solve for the base, so the mouth lands exactly
	# over the destination. The vessel rotates about its base, so the mouth sits at
	# base + R(theta)*(0, h); inverting that pins the mouth where we want it
	# instead of guessing an offset and hoping the liquid lands in the tube.
	var lean: float = 1.0 if to_i > from_i else -1.0
	var theta := deg_to_rad(POUR_TIP_DEG) * -lean
	var mouth_h := 0.5
	var mouth := Vector3(dst_x, base_y + POUR_LIFT, POUR_FRONT)
	var hover := Vector3(mouth.x + mouth_h * sin(theta), mouth.y - mouth_h * cos(theta), POUR_FRONT)

	for old in _pour_tweens:
		if is_instance_valid(old):
			old.kill()
	_pour_tweens.clear()
	# Killing a chain skips its trailing callbacks, so any stream it still owned
	# would be orphaned and survive a level rebuild. Free it here explicitly.
	if _pour_stream != null and is_instance_valid(_pour_stream):
		_pour_stream.queue_free()
	_pour_stream = null

	var step: float = POUR_POUR / float(count)

	var t := create_tween()
	t.tween_property(src, "position", hover, POUR_TRAVEL) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(src, "rotation:z", theta, POUR_TRAVEL) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	t.tween_callback(func():
		_pour_stream = _make_stream(hue, Vector3(mouth.x, mouth.y, 0.05), Vector3(dst_x, base_y + 0.47, 0.05))
		# The source empties from the top down while the destination rises, so the
		# liquid moves continuously instead of teleporting when the pour ends.
		for k in count:
			var drained := src_count - 1 - k
			if drained < 0:
				continue
			var band := _find_band(src, drained)
			if band != null:
				var bottom := float(band.get_meta("band_bottom"))
				var drain := create_tween().set_parallel(true)
				drain.tween_property(band, "scale:y", 0.001, step) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
				drain.tween_property(band, "position:y", bottom, step) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
				drain.tween_interval(step * k)
				_pour_tweens.append(drain)

			var idx := dst_count + k
			var grown := VesselBuilderScript.make_band(colour_id, idx, _capacity)
			grown.scale = Vector3(1.0, 0.001, 1.0)
			grown.position.y = float(grown.get_meta("band_bottom"))
			dst.add_child(grown)
			var rise := create_tween().set_parallel(true)
			rise.tween_property(grown, "scale:y", 1.0, step) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			rise.tween_property(grown, "position:y", float(grown.get_meta("band_centre")), step) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			rise.tween_interval(step * k)
			_pour_tweens.append(rise))

	t.tween_interval(POUR_POUR)
	t.tween_callback(func():
		if _pour_stream != null and is_instance_valid(_pour_stream):
			var owned := _pour_stream
			_pour_stream = null
			var fade := create_tween()
			fade.tween_property(owned, "transparency", 1.0, 0.10)
			fade.tween_callback(owned.queue_free)
			_pour_tweens.append(fade))
	t.tween_property(src, "position", home, POUR_RETURN) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(src, "rotation:z", 0.0, POUR_RETURN) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func():
		src.position = home
		src.rotation.z = 0.0
		done.call())
	_pour_tweens.append(t)


func _find_band(vessel: Node3D, index: int) -> MeshInstance3D:
	for child in vessel.get_children():
		if child.has_meta("band_index") and int(child.get_meta("band_index")) == index:
			return child
	return null

## A short cylinder spanning the gap between the two mouths, in the liquid colour.
func _make_stream(hue: Color, from: Vector3, to: Vector3) -> MeshInstance3D:
	var delta := to - from
	var length := maxf(0.02, delta.length())

	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0085
	mesh.bottom_radius = 0.0045
	mesh.height = length
	mesh.radial_segments = 10
	mesh.rings = 1

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(hue.r, hue.g, hue.b, 0.92)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = (from + to) * 0.5 + Vector3(0, 0, 0.06)
	# the cylinder's axis is +Y, so align it with the stream direction
	mi.rotation.z = atan2(delta.y, delta.x) - PI * 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vessels.add_child(mi)
	return mi

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
