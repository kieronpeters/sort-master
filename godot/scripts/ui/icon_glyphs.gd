class_name IconGlyphs
extends RefCounted

## Vector icon language for the interface. Drawn with lines and polygons so
## the HUD stays sharp at every density without shipping raster UI atlases.

static func draw(ci: CanvasItem, kind: String, origin: Vector2, s: float, colour: Color) -> void:
	var w: float = maxf(2.0, s * 0.105)
	match kind:
		"back":
			_poly(ci, origin, s, [[0.68, 0.15], [0.32, 0.5], [0.68, 0.85]], colour, w)
		"next":
			_poly(ci, origin, s, [[0.36, 0.15], [0.72, 0.5], [0.36, 0.85]], colour, w)
		"undo":
			_poly(ci, origin, s, [[0.72, 0.20], [0.34, 0.50], [0.72, 0.80]], colour, w)
			_line(ci, origin, s, 0.34, 0.50, 0.86, 0.50, colour, w)
		"restart":
			_refresh(ci, origin, s, colour, w)
		"play":
			var tri := PackedVector2Array([
				_p(origin, s, 0.30, 0.16),
				_p(origin, s, 0.84, 0.50),
				_p(origin, s, 0.30, 0.84),
			])
			ci.draw_colored_polygon(tri, colour)
		"home":
			_poly(ci, origin, s, [[0.12, 0.50], [0.50, 0.16], [0.88, 0.50]], colour, w)
			_line(ci, origin, s, 0.22, 0.48, 0.22, 0.86, colour, w)
			_line(ci, origin, s, 0.78, 0.48, 0.78, 0.86, colour, w)
			_line(ci, origin, s, 0.22, 0.86, 0.78, 0.86, colour, w)
		"check":
			_poly(ci, origin, s, [[0.18, 0.53], [0.41, 0.76], [0.82, 0.24]], colour, w * 1.15)
		"close":
			_line(ci, origin, s, 0.22, 0.22, 0.78, 0.78, colour, w)
			_line(ci, origin, s, 0.78, 0.22, 0.22, 0.78, colour, w)
		"lock":
			_lock(ci, origin, s, colour, w)
		"sound_on":
			_speaker(ci, origin, s, colour)
			for i in 2:
				var r: float = s * (0.17 + 0.11 * float(i))
				ci.draw_arc(_p(origin, s, 0.52, 0.50), r, -PI * 0.42, PI * 0.42, 18, colour, w, true)
		"sound_off":
			_speaker(ci, origin, s, colour)
			_line(ci, origin, s, 0.62, 0.34, 0.90, 0.66, colour, w)
			_line(ci, origin, s, 0.90, 0.34, 0.62, 0.66, colour, w)
		"spark":
			_poly(ci, origin, s, [
				[0.50, 0.08], [0.58, 0.42], [0.92, 0.50], [0.58, 0.58],
				[0.50, 0.92], [0.42, 0.58], [0.08, 0.50], [0.42, 0.42],
			], colour, w * 0.7, true)
		_:
			ci.draw_circle(_p(origin, s, 0.5, 0.5), s * 0.22, colour)


static func _refresh(ci: CanvasItem, origin: Vector2, s: float, colour: Color, w: float) -> void:
	var c := _p(origin, s, 0.50, 0.52)
	var r: float = s * 0.30
	var a0: float = -PI * 0.10
	var a1: float = PI * 1.50
	ci.draw_arc(c, r, a0, a1, 36, colour, w, true)

	# arrowhead at the end of the sweep
	var dir := Vector2(cos(a1), sin(a1))
	var tangent := Vector2(-sin(a1), cos(a1))
	var base := c + dir * r
	var tip := base + tangent * (s * 0.14)
	var tri := PackedVector2Array([
		tip,
		base - dir * (s * 0.10),
		base + dir * (s * 0.10),
	])
	ci.draw_colored_polygon(tri, colour)


static func _lock(ci: CanvasItem, origin: Vector2, s: float, colour: Color, w: float) -> void:
	var body := Rect2(_p(origin, s, 0.22, 0.46), Vector2(s * 0.56, s * 0.40))
	ci.draw_rect(body, colour, true)
	ci.draw_arc(_p(origin, s, 0.50, 0.46), s * 0.19, PI, TAU, 20, colour, w, true)
	_line(ci, origin, s, 0.31, 0.46, 0.31, 0.38, colour, w)
	_line(ci, origin, s, 0.69, 0.46, 0.69, 0.38, colour, w)


static func _speaker(ci: CanvasItem, origin: Vector2, s: float, colour: Color) -> void:
	var body := PackedVector2Array([
		_p(origin, s, 0.10, 0.38),
		_p(origin, s, 0.30, 0.38),
		_p(origin, s, 0.50, 0.18),
		_p(origin, s, 0.50, 0.82),
		_p(origin, s, 0.30, 0.62),
		_p(origin, s, 0.10, 0.62),
	])
	ci.draw_colored_polygon(body, colour)


static func _p(origin: Vector2, s: float, x: float, y: float) -> Vector2:
	return origin + Vector2(x, y) * s


static func _poly(ci: CanvasItem, origin: Vector2, s: float, pts: Array, colour: Color, w: float, filled: bool = false) -> void:
	var packed := PackedVector2Array()
	for pt in pts:
		packed.append(_p(origin, s, pt[0], pt[1]))
	if filled:
		ci.draw_colored_polygon(packed, colour)
	else:
		ci.draw_polyline(packed, colour, w, true)


static func _line(ci: CanvasItem, origin: Vector2, s: float, x0: float, y0: float, x1: float, y1: float, colour: Color, w: float) -> void:
	ci.draw_line(_p(origin, s, x0, y0), _p(origin, s, x1, y1), colour, w, true)
