class_name SweepTrail
extends Node3D
## What the rig saw one hand sweep: strands of wind winding from where the sweep
## set off to the hand, and the hiss of air that rises with the hand's speed.
## Both fade once the sweep stops. White either way: it shows the hand was seen,
## never whether the answer is right. Wind shader: see wind_trail.gdshader.

const WIND := preload("res://trials/motion/wind_trail.gdshader")
## Per strand: time offset and how much wider its loop is.
const STRANDS: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(2.1, 0.015), Vector2(4.2, -0.012)]
const STRENGTH := 0.75
const FADE_SECONDS := 0.4
## The hiss is silent at the slowest sweep and full at this speed, m/s.
const FULL_SPEED := 1.5
const RATE := 22050

var _material := ShaderMaterial.new()
var _wind := AudioStreamPlayer3D.new()
var _strength := 0.0
var _speed := 0.0
var _from := Vector3.INF
var _to := Vector3.ZERO
var _at := 0.0


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
	_wind.stream = _hiss()
	_wind.volume_db = -80.0
	add_child(_wind)


## The sweep so far: from [param from] to [param to].
func show_sweep(from: Vector3, to: Vector3) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if from == _from:
		_speed = lerpf(_speed, to.distance_to(_to) / maxf(now - _at, 0.001), 0.5)
	else:
		_from = from
		_speed = 0.0
	_to = to
	_at = now
	var way := to - from
	var up := way.normalized()
	var side := up.cross(Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT).normalized()
	var place := Transform3D(Basis(side, up * way.length(), side.cross(up)), (from + to) * 0.5)
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", false, false):
		mesh.global_transform = place
		mesh.visible = true
	_strength = 1.0
	_wind.global_position = to
	if not _wind.playing:
		_wind.play()


func _process(delta: float) -> void:
	if _strength <= 0.0:
		return
	_strength = maxf(0.0, _strength - delta / FADE_SECONDS)
	_material.set_shader_parameter(&"strength", STRENGTH * _strength)
	var loud := clampf(_speed / FULL_SPEED, 0.05, 1.0) * _strength
	_wind.volume_db = linear_to_db(loud)
	_wind.pitch_scale = 0.8 + 0.6 * clampf(_speed / FULL_SPEED, 0.0, 1.0)
	if _strength > 0.0:
		return
	_wind.stop()
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", false, false):
		mesh.visible = false


## A second of airy noise that loops without a seam: the filter runs round the
## buffer twice, so its end flows into its start.
func _hiss() -> AudioStreamWAV:
	var count := RATE
	var white := PackedFloat32Array()
	white.resize(count)
	for i in count:
		white[i] = randf_range(-1.0, 1.0)
	var low := 0.0
	var lower := 0.0
	var samples := PackedByteArray()
	samples.resize(count * 2)
	for i in count * 2:
		low += (white[i % count] - low) * 0.35
		lower += (low - lower) * 0.08
		if i >= count:
			samples.encode_s16((i - count) * 2, int(clampf((low - lower) * 1.6, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = samples
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = count
	return stream
