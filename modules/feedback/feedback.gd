extends Module
## A judged response, given two ways: a sound and a mark where it happened
## (tracked hands cannot vibrate). Never colour alone: good is a rising chime and
## a ring, bad a soft falling tone and a cross, hint a single note and a dot.

const RATE := 22050
## Notes (Hz) of each kind's sound, played one after another.
const NOTES := {good = [660.0, 880.0], bad = [262.0, 220.0], hint = [523.0]}
const COLOURS := {good = Color(0.3, 0.9, 0.4), bad = Color(0.95, 0.35, 0.3), hint = Color(1.0, 0.85, 0.3)}

var _sounds: Dictionary[StringName, AudioStreamWAV] = {}


func _ready() -> void:
	for kind: StringName in NOTES:
		_sounds[kind] = _chime(NOTES[kind])
	Events.feedback.connect(_on_feedback)
	Events.scene_changing.connect(func() -> void:
		for node in get_children():
			node.free())


func _on_feedback(kind: StringName, at: Vector3) -> void:
	var player := AudioStreamPlayer3D.new()
	player.stream = _sounds[kind]
	add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
	_mark(kind, at)


## A shape that pops up at [param at], faces the eyes and fades.
func _mark(kind: StringName, at: Vector3) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.albedo_color = COLOURS[kind]
	var mark := Node3D.new()
	if kind == &"good":
		var ring := TorusMesh.new()
		ring.inner_radius = 0.05
		ring.outer_radius = 0.065
		_add_mesh(mark, ring, material, Vector3(PI / 2.0, 0.0, 0.0))
	elif kind == &"bad":
		for angle in [PI / 4.0, -PI / 4.0]:
			var bar := BoxMesh.new()
			bar.size = Vector3(0.12, 0.022, 0.01)
			_add_mesh(mark, bar, material, Vector3(0.0, 0.0, angle))
	else:
		var dot := SphereMesh.new()
		dot.radius = 0.02
		dot.height = 0.04
		_add_mesh(mark, dot, material, Vector3.ZERO)
	add_child(mark)
	mark.global_position = at + Vector3.UP * 0.1
	mark.look_at(App.head().global_position)
	mark.scale = Vector3.ONE * 0.3
	var tween := mark.create_tween()
	tween.tween_property(mark, ^"scale", Vector3.ONE, 0.15)
	tween.tween_property(material, ^"albedo_color:a", 0.0, 0.6).set_delay(0.4)
	tween.tween_callback(mark.queue_free)


func _add_mesh(parent: Node3D, mesh: Mesh, material: Material, rotation: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.rotation = rotation
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


## Soft sine notes, each with a short attack and a fade.
func _chime(notes: Array) -> AudioStreamWAV:
	var length := int(RATE * 0.14)
	var data := PackedByteArray()
	data.resize(notes.size() * length * 2)
	for n in notes.size():
		for i in length:
			var envelope := minf(1.0, i / 200.0) * (1.0 - float(i) / length)
			var sample := sin(TAU * notes[n] * i / RATE) * envelope * 0.35
			data.encode_s16((n * length + i) * 2, int(sample * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	return wav
