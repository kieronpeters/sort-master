extends Control

## Prism Garden backdrop: vertical gradient, vignette, soft botanical
## silhouettes and a few drifting motes. Drawn in 2D behind the 3D board so it
## costs one CanvasItem pass and never competes with the puzzle.

const TOP := Color("#0e2733")
const MID := Color("#0a1c25")
const BOTTOM := Color("#061116")

var _motes: Array = []
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 22:
		_motes.append({
			"x": rng.randf(),
			"y": rng.randf(),
			"r": rng.randf_range(1.1, 3.2),
			"speed": rng.randf_range(0.004, 0.014),
			"alpha": rng.randf_range(0.10, 0.30),
		})


func _process(delta: float) -> void:
	_t += delta
	for m in _motes:
		m["y"] -= m["speed"] * delta
		if m["y"] < -0.02:
			m["y"] = 1.02
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 2.0 or h < 2.0:
		return

	# vertical gradient in bands
	var bands := 48
	for i in bands:
		var t := float(i) / float(bands - 1)
		var c: Color = TOP.lerp(MID, min(1.0, t * 1.6)) if t < 0.62 else MID.lerp(BOTTOM, (t - 0.62) / 0.38)
		draw_rect(Rect2(0, h * float(i) / float(bands), w, h / float(bands) + 1.0), c)

	# botanical silhouettes, very low contrast
	var leaf := Color(0.16, 0.42, 0.40, 0.10)
	_leaf(Vector2(w * 0.06, h * 0.22), w * 0.42, h * 0.30, leaf)
	_leaf(Vector2(w * 0.96, h * 0.30), w * 0.38, h * 0.34, leaf)
	_leaf(Vector2(w * 0.10, h * 0.86), w * 0.36, h * 0.22, Color(0.10, 0.32, 0.34, 0.12))

	# vignette
	var v := 26
	for i in v:
		var t := float(i) / float(v)
		var a := 0.045 * (1.0 - t)
		var inset := w * 0.5 * t
		draw_rect(Rect2(0, 0, w, h * 0.5 * t), Color(0, 0, 0, a * 0.4), true)
		draw_rect(Rect2(0, h - h * 0.5 * t, w, h * 0.5 * t), Color(0, 0, 0, a), true)
		draw_rect(Rect2(0, 0, inset * 0.4, h), Color(0, 0, 0, a * 0.5), true)
		draw_rect(Rect2(w - inset * 0.4, 0, inset * 0.4, h), Color(0, 0, 0, a * 0.5), true)

	# motes
	for m in _motes:
		var p := Vector2(m["x"] * w, m["y"] * h)
		var glow := Color(0.72, 0.95, 1.0, m["alpha"])
		draw_circle(p, m["r"] * 2.6, Color(glow.r, glow.g, glow.b, m["alpha"] * 0.25))
		draw_circle(p, m["r"], glow)


func _leaf(centre: Vector2, rw: float, rh: float, colour: Color) -> void:
	draw_set_transform(centre, -0.35, Vector2(1.0, 1.0))
	draw_circle(Vector2.ZERO, rw * 0.5, colour)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.0))
