class_name Emblem
extends Control

## Home-screen lockup: a slow halo, a thin orbit ring and the original bottle
## mark. Drawn rather than composited so it stays crisp at every size.

const P = preload("res://scripts/ui/palette.gd")
const TEX = preload("res://assets/2d/icons/icon_foreground.png")

var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(300, 300)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r: float = minf(size.x, size.y) * 0.5

	# halo
	for i in 8:
		var k := 1.0 - float(i) * 0.075
		draw_circle(c, r * k, Color(P.ACCENT.r, P.ACCENT.g, P.ACCENT.b, 0.018))

	# orbit ring, broken so it reads as drawn rather than a border
	draw_arc(c, r * 0.88, -0.35 + _t * 0.05, PI * 1.25 + _t * 0.05, 64,
		Color(P.ACCENT.r, P.ACCENT.g, P.ACCENT.b, 0.42), 2.0, true)
	draw_arc(c, r * 0.88, PI * 1.45 + _t * 0.05, PI * 1.85 + _t * 0.05, 32,
		Color(P.GOLD.r, P.GOLD.g, P.GOLD.b, 0.35), 2.0, true)

	# mark
	var mark: float = r * 1.32
	var rect := Rect2(c - Vector2(mark, mark) * 0.5, Vector2(mark, mark))
	draw_texture_rect(TEX, rect, false, Color(1, 1, 1, 0.98))

	# two small sparkles
	for i in 2:
		var a := _t * 0.35 + float(i) * PI
		var p := c + Vector2(cos(a), sin(a) * 0.55) * r * 0.78
		var s: float = r * (0.045 + 0.012 * float(i))
		draw_circle(p, s, Color(P.GOLD.r, P.GOLD.g, P.GOLD.b, 0.75))
		draw_circle(p, s * 2.4, Color(P.GOLD.r, P.GOLD.g, P.GOLD.b, 0.10))
