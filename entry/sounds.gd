class_name Sounds
extends Node
## The opening's and the hub's small sounds, each played from where it happens (a position in the room), on
## the SFX bus under the voice. Designed for these scenes (tools/sound/design.py `opening` and `hub`, sources in
## entry/assets/audio/README.md): the cauldron's rattles are built hit by hit from a lid and earthenware, the
## knock is muffled inside the pot, Onion's pop is a bubble with a glint, the gear seats with a click and two
## notes and the mechanism winds up humming (power_up), the reveal swells with the light into C major while
## each glint rings a small bell where it lights; every bubble over the cauldron has its own motif.

const DIR := "res://entry/assets/audio/"
const KEYS: Array[StringName] = [&"pre_rattle", &"rattle_soft", &"device_rattle", &"knock", &"pop", &"seat",
	&"gear_land", &"reveal", &"power_up", &"glint", &"hover_tink", &"bubble_pop", &"chosen_chime", &"locked_bonk",
	&"lock_click", &"unlock", &"brew_rise", &"brew_sink", &"stone_clink", &"gear_lift",
	&"impression_shelf", &"impression_dots", &"impression_turn_to_fit", &"impression_house",
	&"impression_butterflies", &"impression_real_life", &"impression_odd_color", &"impression_help",
	&"impression_eye", &"impression_look", &"impression_stop", &"impression_finish"]
## Moments that share a file: "found its place" is the seating click, quieter; the gear set down away from the
## socket is gear_land (never the click: a drop must not sound like success).
const BORROWS := {
	place = {file = &"seat", db = -6.0},
	gear_drop = {file = &"gear_land", db = 0.0},
}
## Seconds into brew_sink at which its gulp lands: [method ImpressionRing.sink] starts it this long before
## the bubbles reach the brew (tools/sound/design.py BREW_LAND).
const BREW_LAND := 0.42
## The C-major pentatonic, semitones: [method step] walks it so a row of bubbles rises in tune with the piano.
const PENTATONIC := [0, 2, 4, 7, 9]


## The pitch scale for the [param i]-th note up the pentatonic from a cue's own note (negative: down).
static func step(i: int) -> float:
	var octave := floori(i / 5.0)
	return pow(2.0, (PENTATONIC[posmod(i, 5)] + 12 * octave) / 12.0)


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
	player.pitch_scale = pitch
	player.bus = &"SFX"
	player.unit_size = 1.0
	player.max_db = 0.0
	add_child(player)
	player.global_position = where
	player.finished.connect(player.queue_free)
	player.play()
