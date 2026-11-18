class_name HubAmbience
extends AudioStreamPlayer
## The workshop's warm background (Megan, Nov 18): a low fireplace crackle, looped, far under Onion's
## voice and the task sounds. It fades in gently when the hub opens, sits a little lower while a game
## runs, pauses in Wei's room, and fades out when the closing starts. Every change is a slow fade:
## never a sharp volume step. File: entry/assets/audio/workshop-fireplace-loop.ogg (CC0, sfxmint
## "Low Embers Fireplace Crackling 52", a prepared 21.9 s loop; the seam is clean: both ends ~−30 dB).

const FILE := "res://entry/assets/audio/workshop-fireplace-loop.ogg"
const HUB_DB := -30.0       # Megan's starting level; adjust by ear in the headset
const GAME_DB := -36.0      # a little further under the task sounds
const SILENT_DB := -60.0
const FADE_IN := 4.0
const FADE := 2.0

var _tween: Tween


static func make(parent: Node) -> HubAmbience:
	var player := HubAmbience.new()
	player.name = "Ambience"
	var stream := load(FILE) as AudioStreamOggVorbis
	if stream != null:
		stream = stream.duplicate() as AudioStreamOggVorbis
		stream.loop = true
	player.stream = stream
	player.volume_db = SILENT_DB
	parent.add_child(player)
	return player


## Fades to [param db] over [param seconds], starting the loop if it isn't playing.
func fade_to(db: float, seconds := FADE) -> void:
	if stream == null:
		return
	if not playing:
		play(randf() * stream.get_length())   # start somewhere in the loop, so it never sounds like a cue
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, ^"volume_db", db, seconds).set_trans(Tween.TRANS_SINE)


func hub() -> void:
	fade_to(HUB_DB, FADE_IN if volume_db <= SILENT_DB + 1.0 else FADE)


func game() -> void:
	fade_to(GAME_DB)


## Fades out and stops (Wei's room, the closing).
func fade_out(seconds := FADE) -> void:
	if not playing:
		return
	fade_to(SILENT_DB, seconds)
	_tween.tween_callback(stop)
