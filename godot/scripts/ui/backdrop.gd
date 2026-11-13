extends Control

## Prism Garden backdrop for the menus: vertical gradient, vignette, soft
## botanical silhouettes and a few drifting motes. Drawn in 2D behind the
## screens so it costs one CanvasItem pass and never competes with the puzzle.

const TOP := Color("#0f3340")
const MID := Color("#0a212b")
const BOTTOM := Color("#061218")

var _motes: Array = []
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 26:
		_motes.append({
			"x": rng.randf(),
			"y": rng.randf(),
			"r": rng.randf_range(1.0, 2.8),
			"speed": rng.randf_range(0.004, 0.014),
			"alpha": rng.randf_range(0.10, 0.28),
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

	var bands := 64
	for i in bands:
		var t := float(i) / float(bands - 1)
		var c: Color = TOP.lerp(MID, minf(1.0, t * 1.6)) if t < 0.62 else MID.lerp(BOTTOM, (t - 0.62) / 0.38)
		draw_rect(Rect2(0, h * float(i) / float(bands), w, h / float(bands) + 1.0), c)

	# botanical silhouettes, very low contrast, drawn as leaf pairs
	var leaf := Color(0.08, 0.30, 0.28, 0.30)
	_leaf(Vector2(w * 0.02, h * 0.20), w * 0.30, h * 0.22, -0.55, leaf)
	_leaf(Vector2(w * 0.98, h * 0.30), w * 0.28, h * 0.24, 0.55, leaf)
	_leaf(Vector2(w * 0.06, h * 0.92), w * 0.26, h * 0.16, 0.25, Color(0.06, 0.26, 0.26, 0.34))
	_leaf(Vector2(w * 0.96, h * 0.86), w * 0.22, h * 0.14, -0.25, Color(0.06, 0.26, 0.26, 0.30))

	# soft pool of light low in the frame
	var glow_c := Vector2(w * 0.5, h * 0.78)
	for i in 14:
		var k := 1.0 - float(i) / 14.0
		draw_circle(glow_c, w * 0.60 * k, Color(0.20, 0.62, 0.58, 0.012))

	# vignette
	var v := 30
	for i in v:
		var t := float(i) / float(v)
		var a := 0.040 * (1.0 - t)
		draw_rect(Rect2(0, 0, w, h * 0.5 * t), Color(0, 0, 0, a * 0.45), true)
		draw_rect(Rect2(0, h - h * 0.5 * t, w, h * 0.5 * t), Color(0, 0, 0, a), true)
		draw_rect(Rect2(0, 0, w * 0.5 * t * 0.35, h), Color(0, 0, 0, a * 0.5), true)
		draw_rect(Rect2(w - w * 0.5 * t * 0.35, 0, w * 0.5 * t * 0.35, h), Color(0, 0, 0, a * 0.5), true)

	# motes
	for m in _motes:
		var p := Vector2(m["x"] * w, m["y"] * h)
		var glow := Color(0.72, 0.95, 1.0, m["alpha"])
		draw_circle(p, m["r"] * 2.6, Color(glow.r, glow.g, glow.b, m["alpha"] * 0.25))
		draw_circle(p, m["r"], glow)


## A pointed leaf built from two quadratic-ish curves.
func _leaf(centre: Vector2, rw: float, rh: float, angle: float, colour: Color) -> void:
	var pts := PackedVector2Array()
	var steps := 14
	for i in steps + 1:
		var t := float(i) / float(steps)
		var x := (t - 0.5) * rw
		var y := -sin(t * PI) * rh * 0.5
		pts.append(Vector2(x, y))
	for i in range(steps, -1, -1):
		var t := float(i) / float(steps)
		var x := (t - 0.5) * rw
		var y := sin(t * PI) * rh * 0.5
		pts.append(Vector2(x, y))
	var out := PackedVector2Array()
	var c := cos(angle)
	var s := sin(angle)
	for p in pts:
		out.append(centre + Vector2(p.x * c - p.y * s, p.x * s + p.y * c))
	draw_colored_polygon(out, colour)
