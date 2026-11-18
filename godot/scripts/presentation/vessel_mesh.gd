class_name VesselMesh
extends RefCounted

## Lathed glass profiles. Revolving a 2D profile is what separates a potion
## bottle from a cylinder; Godot has no lathe primitive, so the surface is
## stitched by hand here.

const SEGMENTS := 48

## Outer silhouette, bottom to top: (radius, height) in metres.
static var OUTER: Array = [
	Vector2(0.052, 0.000),
	Vector2(0.078, 0.014),
	Vector2(0.086, 0.040),
	Vector2(0.086, 0.070),
	Vector2(0.086, 0.375),
	Vector2(0.082, 0.398),
	Vector2(0.070, 0.425),
	Vector2(0.056, 0.450),
	Vector2(0.048, 0.468),
	Vector2(0.046, 0.480),
	Vector2(0.049, 0.487),
	Vector2(0.058, 0.498),
	Vector2(0.061, 0.506),
	Vector2(0.058, 0.512),
	Vector2(0.050, 0.510),
	Vector2(0.047, 0.501),
]

static var WALL: float = 0.006

static func build_glass(inner_wall: bool = true) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_stitch(st, OUTER, false)
	_bottom_cap(st, OUTER[0])
	if inner_wall:
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


## The silhouette is a surface of revolution, so the base was an open hole and the
## unlit interior read as a hard black bar under every bottle. A fan closes it.
## Both windings are emitted: the glass material does not cull, and a floor that
## vanishes from one side is worse than the hole it replaces.
static func _bottom_cap(st: SurfaceTool, base: Vector2) -> void:
	var centre := Vector3(0.0, base.y, 0.0)
	for s in SEGMENTS:
		var t0 := TAU * float(s) / float(SEGMENTS)
		var t1 := TAU * float(s + 1) / float(SEGMENTS)
		var p0 := _pt(base, t0)
		var p1 := _pt(base, t1)
		st.add_vertex(centre); st.add_vertex(p0); st.add_vertex(p1)
		st.add_vertex(centre); st.add_vertex(p1); st.add_vertex(p0)

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

## Liquid sits above the base fillet so no band can poke through the glass.
const LIQUID_BASE := 0.045

static func liquid_radius() -> float:
	return inner_radius_at(0.15) - 0.0005

static func capacity_height() -> float:
	# Raised with the shoulder (18 Nov 2026): a full column now reaches 0.370 of
	# the 0.512 vessel, so a full jug reads full instead of stopping a third short.
	return 0.325
