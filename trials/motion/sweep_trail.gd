class_name SweepTrail
extends Node3D
## What the rig saw one hand sweep: a white streak from where the sweep set off
## to where the hand has got, a soft whoosh as it starts, then a fade. White
## either way: it shows the hand was seen, never whether the answer is right.

const WIDTH := 0.02
const ALPHA := 0.6
const FADE_SECONDS := 0.5
const RATE := 22050

var _streak := MeshInstance3D.new()
var _material := StandardMaterial3D.new()
var _whoosh := AudioStreamPlayer3D.new()
var _from := Vector3.INF


func _ready() -> void:
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	var box := BoxMesh.new()
	box.size = Vector3(WIDTH, WIDTH, 1.0)
	_streak.mesh = box
	_streak.material_override = _material
	_streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_streak.visible = false
	add_child(_streak)
	_whoosh.stream = _sound()
	add_child(_whoosh)


## The sweep so far: from [param from] to [param to].
func show_sweep(from: Vector3, to: Vector3) -> void:
	if from != _from:
		_from = from
		_whoosh.global_position = to
		_whoosh.play()
	var way := to - from
	_streak.global_transform = Transform3D(Basis.looking_at(way) * Basis.from_scale(Vector3(1.0, 1.0, way.length())),
		(from + to) * 0.5)
	_material.albedo_color.a = ALPHA
	_streak.visible = true


func _process(delta: float) -> void:
	if not _streak.visible:
		return
	_material.albedo_color.a -= ALPHA * delta / FADE_SECONDS
	_streak.visible = _material.albedo_color.a > 0.0


## Soft noise that swells and fades, brighter in the middle.
func _sound() -> AudioStreamWAV:
	var samples := PackedByteArray()
	samples.resize(int(RATE * 0.3) * 2)
	var count := samples.size() / 2
	var low := 0.0
	for i in count:
		var t := float(i) / count
		var envelope := sin(PI * t) * sin(PI * t)
		low += (randf_range(-1.0, 1.0) - low) * (0.05 + 0.25 * envelope)
		samples.encode_s16(i * 2, int(low * envelope * 0.8 * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = samples
	return stream
