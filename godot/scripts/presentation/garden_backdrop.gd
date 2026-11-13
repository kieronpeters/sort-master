class_name GardenBackdrop
extends RefCounted

## The gameplay backdrop: a single unshaded quad behind the vessels carrying
## the procedural Prism Garden shader. A 3D plane (rather than viewport
## transparency) keeps the board opaque, so the vessel render, depth sorting
## and camera fit stay exactly as they are.

const SHADER_PATH := "res://assets/shaders/garden_3d.gdshader"

static func build() -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE

	var mi := MeshInstance3D.new()
	mi.name = "GardenBackdrop"
	mi.mesh = quad
	mi.material_override = material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 8.0
	return mi

static func material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_PATH)
	return mat
