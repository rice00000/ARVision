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
## Merge of Wei's designed sounds (Nov 18): the hub's extra cues have no files of their own yet, so they borrow
## his, with pitch and level. The impressions each keep their own sound (Effects chat, Nov 17); Scene 4's lift
## and drop differ, and the drop is never the seating click (a drop must not sound like success): it is his
## gear_land.
const BORROWS := {
	impression_shelf = {file = &"knock", pitch = 1.0, db = -4.0},
	impression_dots = {file = &"pop", pitch = 1.4, db = -6.0},
	impression_turn_to_fit = {file = &"seat", pitch = 1.6, db = -8.0},
	impression_house = {file = &"knock", pitch = 0.8, db = -4.0},
	bubble_pop = {file = &"pop", pitch = 1.8, db = -4.0},      # the chosen bubble bursts (a real pop sound to come)
	chosen_chime = {file = &"reveal", pitch = 1.5, db = -10.0},  # the name appears: "you did it"
	hover_tink = {file = &"pop", pitch = 2.4, db = -18.0},       # a hand comes to a bubble (pitch varies per bubble)
	locked_bonk = {file = &"knock", pitch = 0.6, db = -10.0},    # a closed bubble pressed: soft, never a buzzer
	unlock = {file = &"reveal", pitch = 1.2, db = -8.0},        # a closed bubble opens
	menu_open = {file = &"pop", pitch = 0.7, db = -10.0},
	menu_close = {file = &"pop", pitch = 0.55, db = -14.0},
	place = {file = &"seat", pitch = 1.0, db = -6.0},
	gear_lift = {file = &"pop", pitch = 1.3, db = -10.0},
	gear_drop = {file = &"gear_land", pitch = 1.0, db = 0.0},
}

var played: Array[StringName] = []   # what has been played, for the tests

var _streams := {}


func _ready() -> void:
	for key in KEYS:
		_streams[key] = load(DIR + String(key) + ".ogg")


## Plays [param key] at [param where] (world position).
func play(key: StringName, where: Vector3, pitch := 1.0) -> void:
	played.append(key)
	var borrowed: Dictionary = BORROWS.get(key, {})
	var stream: AudioStream = _streams.get(borrowed.get("file", key))
	if stream == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = borrowed.get("db", 0.0)
	player.pitch_scale = borrowed.get("pitch", 1.0) * pitch
	player.bus = &"SFX"
	player.unit_size = 1.0
	player.max_db = 0.0
	add_child(player)
	player.global_position = where
	player.finished.connect(player.queue_free)
	player.play()
