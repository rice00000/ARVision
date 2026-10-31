extends Module
## The guide's voice: a subtitle, read aloud from [BakedSpeech] files baked
## ahead of time (docs/baked-speech.md). A newer line cuts off the one playing.
## Unplugged, the guide is silent.
##
## [signal line_finished] says when a line ends, so a story can wait for the real end of
## the voice instead of guessing how long it takes.
##
## The subtitle never covers the work: it floats ahead at [member above_horizon]
## degrees over the horizon, above the motion cloud, and when the child looks
## down at the table it stays [member above_gaze] degrees over the gaze, above
## the toys.

## How long a subtitle stays, per character; never under two seconds or the spoken line.
@export var seconds_per_char := 0.065
@export var above_horizon := 20.0
@export var above_gaze := 25.0
@export var distance := 0.75

## A line ended: its [param text], and whether it played to the end ([param completed]); false
## when a newer line or a scene change cut it off. A line with no baked clip ends after
## the time its subtitle shows.
signal line_finished(text: String, completed: bool)

var _label := Label3D.new()
var _player := AudioStreamPlayer.new()
var _hide_at := 0.0
var _speaking := ""
var _finish_at := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.0006
	_label.font_size = 48
	_label.outline_size = 14
	_label.no_depth_test = true
	_label.render_priority = 10
	_label.outline_render_priority = 9
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.width = 900.0
	_label.visible = false
	App.rig.add_child(_label)
	add_child(_player)
	Events.said.connect(_say)
	_player.finished.connect(func() -> void: _end_line(true))
	Events.scene_changing.connect(func() -> void:
		_player.stop()
		_label.visible = false
		_end_line(false))


func _process(_delta: float) -> void:
	if _speaking != "" and _now() >= _finish_at:
		_end_line(true)   # also covers a player that never reports the end (no sound device)
	if _label.visible and _now() >= _hide_at:
		_label.visible = false
	if _label.visible:
		_place()


func _place() -> void:
	var eye := App.head().global_transform
	var gaze := -eye.basis.z
	var ahead := Vector3(gaze.x, 0.0, gaze.z).normalized()
	var pitch := rad_to_deg(asin(gaze.y))
	var elevation := deg_to_rad(minf(above_horizon, pitch + above_gaze))
	_label.global_position = eye.origin + (ahead * cos(elevation) + Vector3.UP * sin(elevation)) * distance


func _say(text: String) -> void:
	_end_line(false)   # a newer line cuts off the one playing
	_label.text = text
	_label.visible = true
	_place()
	var stream := BakedSpeech.stream(text)
	_player.stream = stream
	var spoken := 0.0
	if stream != null:
		_player.play()
		spoken = stream.get_length()
	else:
		push_warning("Voice: no baked clip for \"%s\" (open the project in the editor to bake it)" % text)
	var shown := text.length() * seconds_per_char
	_hide_at = _now() + maxf(2.0, maxf(shown, spoken))
	_speaking = text
	_finish_at = _now() + (spoken + 0.15 if stream != null else maxf(1.0, shown))


## The line being spoken now, or "" when none is.
func speaking() -> String:
	return _speaking


## Cuts the line being spoken short (a child pressed Onion): the audio stops, the subtitle goes and
## [signal line_finished] says (text, false). False when nothing was being spoken.
func skip() -> bool:
	if _speaking == "":
		return false
	_player.stop()
	_label.visible = false
	_end_line(false)
	return true


func _end_line(completed: bool) -> void:
	if _speaking == "":
		return
	var text := _speaking
	_speaking = ""
	line_finished.emit(text, completed)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
