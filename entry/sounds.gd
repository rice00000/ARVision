class_name Sounds
extends Node
## The opening's small sounds, each played from where it happens (a position in the room), on the
## SFX bus under the voice. Designed for this scene (tools/sound/design.py, sources in
## entry/assets/audio/README.md): the cauldron's rattles are built hit by hit from a lid and
## earthenware, the knock is muffled inside the pot, Onion's pop is a bubble with a glint, the gear
## seats with a click and two notes, and the reveal is a harp sweep into a C-major bloom.

const DIR := "res://entry/assets/audio/"
const KEYS: Array[StringName] = [&"pre_rattle", &"rattle_soft", &"device_rattle", &"knock", &"pop", &"seat",
	&"gear_land", &"reveal"]

var played: Array[StringName] = []   # what has been played, for the tests

var _streams := {}


func _ready() -> void:
	for key in KEYS:
		_streams[key] = load(DIR + String(key) + ".ogg")


## Plays [param key] at [param where] (world position).
func play(key: StringName, where: Vector3) -> void:
	played.append(key)
	var player := AudioStreamPlayer3D.new()
	player.stream = _streams[key]
	player.bus = &"SFX"
	player.unit_size = 1.0
	player.max_db = 0.0
	add_child(player)
	player.global_position = where
	player.finished.connect(player.queue_free)
	player.play()
