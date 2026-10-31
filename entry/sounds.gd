class_name Sounds
extends Node
## The opening's small sounds. Each is played from where it happens (a position in the room),
## softly, below the voice. A file that is missing is skipped: the scene stays silent there.
## Files and licences: entry/assets/audio/README.md.
##
## Onion's pop has two candidates (A: gentle air bubble, C: light bubble pop) to compare in the
## scene at the same timing and loudness: [member pop] picks one, [method toggle_pop] flips it.

const DIR := "res://entry/assets/audio/"
const FILES := {
	pre_rattle = "onion-pre-rattle-preview.mp3",
	device_rattle = "device-rattle-preview.mp3",
	seat = "device-seat-click-preview.mp3",
	pop_a = "onion-pop-a.mp3",
	pop_c = "onion-pop-c.mp3",
	reveal = "workshop-reveal.mp3",
}
## Loudness of each, in dB: all well under the speech. (The pops are matched by ear in the headset.)
const LEVEL := {pre_rattle = -14.0, device_rattle = -10.0, seat = -8.0, pop_a = -12.0, pop_c = -12.0, reveal = -16.0}
## The reveal pad is 5 s long; this fades it out after about this long.
const REVEAL_SECONDS := 3.0

## "a" or "c".
var pop := "a"
var played: Array[StringName] = []   # what has been played, for the tests

var _streams := {}


func _ready() -> void:
	for key: StringName in FILES:
		var path: String = DIR + FILES[key]
		if ResourceLoader.exists(path):
			_streams[key] = load(path)


func toggle_pop() -> String:
	pop = "c" if pop == "a" else "a"
	return pop


## Plays [param key] at [param where] (world position).
func play(key: StringName, where: Vector3) -> void:
	played.append(key)
	var stream: AudioStream = _streams.get(key)
	if stream == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = LEVEL.get(key, -12.0)
	player.unit_size = 3.0
	add_child(player)
	player.global_position = where
	player.finished.connect(player.queue_free)
	player.play()
	if key == &"reveal":   # a shorter bloom: fade the 5 s file out
		var fade := create_tween()
		fade.tween_interval(REVEAL_SECONDS)
		fade.tween_property(player, "volume_db", -60.0, 1.5)
		fade.tween_callback(player.queue_free)


func play_pop(where: Vector3) -> void:
	play(&"pop_a" if pop == "a" else &"pop_c", where)
