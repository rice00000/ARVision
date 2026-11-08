class_name SweepTrail
extends Node3D
## What the rig saw one hand sweep: strands of wind winding from where the sweep
## set off to the hand, fading once the sweep stops. Silent. White either way: it
## shows the hand was seen, never whether the answer is right. Wind shader: see
## wind_trail.gdshader.

const WIND := preload("res://trials/motion/wind_trail.gdshader")
## Per strand: time offset and how much wider its loop is.
const STRANDS: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(2.1, 0.015), Vector2(4.2, -0.012)]
const STRENGTH := 0.75
const FADE_SECONDS := 0.4

var _material := ShaderMaterial.new()
var _strength := 0.0


func _ready() -> void:
	_material.shader = WIND
	var tube := TubeTrailMesh.new()
	tube.radius = 0.007
	tube.radial_steps = 6
	tube.sections = 24
	tube.section_length = 1.0 / tube.sections
	tube.cap_top = false
	tube.cap_bottom = false
	tube.curve = Curve.new()
	tube.curve.add_point(Vector2(0.0, 0.15))
	tube.curve.add_point(Vector2(0.85, 1.0))
	tube.curve.add_point(Vector2(1.0, 0.4))
	tube.material = _material
	for strand in STRANDS:
		var mesh := MeshInstance3D.new()
		mesh.mesh = tube
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.extra_cull_margin = 0.2
		mesh.set_instance_shader_parameter(&"extra_offset_time", strand.x)
		mesh.set_instance_shader_parameter(&"extra_loop_radius", strand.y)
		mesh.visible = false
		add_child(mesh)


## The sweep so far: from [param from] to [param to].
func show_sweep(from: Vector3, to: Vector3) -> void:
	var way := to - from
	var up := way.normalized()
	var side := up.cross(Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT).normalized()
	var place := Transform3D(Basis(side, up * way.length(), side.cross(up)), (from + to) * 0.5)
	for mesh: MeshInstance3D in get_children():
		mesh.global_transform = place
		mesh.visible = true
	_strength = 1.0


func _process(delta: float) -> void:
	if _strength <= 0.0:
		return
	_strength = maxf(0.0, _strength - delta / FADE_SECONDS)
	_material.set_shader_parameter(&"strength", STRENGTH * _strength)
	if _strength > 0.0:
		return
	for mesh: MeshInstance3D in get_children():
		mesh.visible = false
