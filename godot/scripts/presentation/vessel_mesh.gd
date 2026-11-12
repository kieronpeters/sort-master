class_name VesselMesh
extends RefCounted

## Lathed glass profiles. Revolving a 2D profile is what separates a potion
## bottle from a cylinder; Godot has no lathe primitive, so the surface is
## stitched by hand here.

const SEGMENTS := 48

## Outer silhouette, bottom to top: (radius, height) in metres.
static var OUTER: Array = [
	Vector2(0.052, 0.000),
	Vector2(0.078, 0.010),
	Vector2(0.086, 0.030),
	Vector2(0.086, 0.055),
	Vector2(0.084, 0.150),
	Vector2(0.079, 0.196),
	Vector2(0.068, 0.232),
	Vector2(0.054, 0.262),
	Vector2(0.046, 0.286),
	Vector2(0.044, 0.306),
	Vector2(0.047, 0.318),
	Vector2(0.056, 0.328),
	Vector2(0.058, 0.334),
]

static var WALL: float = 0.006

static func build_glass() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_stitch(st, OUTER, false)
	_stitch(st, _inset(OUTER), true)
	st.generate_normals()
	return st.commit()

static func _inset(profile: Array) -> Array:
	var out := []
	for i in profile.size():
		var p: Vector2 = profile[i]
		var r: float = maxf(0.001, p.x - WALL)
		# keep the base and lip radii from collapsing
		out.append(Vector2(r, p.y))
	return out

static func _stitch(st: SurfaceTool, profile: Array, flip: bool) -> void:
	var rings := profile.size()
	for i in rings - 1:
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[i + 1]
		for s in SEGMENTS:
			var t0 := TAU * float(s) / float(SEGMENTS)
			var t1 := TAU * float(s + 1) / float(SEGMENTS)
			var p00 := _pt(a, t0)
			var p01 := _pt(a, t1)
			var p10 := _pt(b, t0)
			var p11 := _pt(b, t1)
			if flip:
				st.add_vertex(p00); st.add_vertex(p10); st.add_vertex(p11)
				st.add_vertex(p00); st.add_vertex(p11); st.add_vertex(p01)
			else:
				st.add_vertex(p00); st.add_vertex(p11); st.add_vertex(p10)
				st.add_vertex(p00); st.add_vertex(p01); st.add_vertex(p11)

static func _pt(p: Vector2, angle: float) -> Vector3:
	return Vector3(cos(angle) * p.x, p.y, sin(angle) * p.x)

## Inner radius at a given height, used to size the liquid so it never
## intersects the glass.
static func inner_radius_at(y: float) -> float:
	for i in OUTER.size() - 1:
		var a: Vector2 = OUTER[i]
		var b: Vector2 = OUTER[i + 1]
		if y >= a.y and y <= b.y:
			var t: float = (y - a.y) / max(0.0001, b.y - a.y)
			return lerp(a.x, b.x, t) - WALL
	return OUTER[OUTER.size() - 1].x - WALL

static func liquid_radius() -> float:
	return inner_radius_at(0.10) - 0.002

static func capacity_height() -> float:
	return 0.245
