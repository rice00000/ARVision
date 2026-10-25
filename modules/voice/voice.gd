extends Module
## The guide's voice: a subtitle, read aloud from [BakedSpeech] files baked
## ahead of time (docs/baked-speech.md). A newer line cuts off the one playing.
## Unplugged, the guide is silent.
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

var _label := Label3D.new()
var _player := AudioStreamPlayer.new()
var _hide_at := 0.0


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


func _process(_delta: float) -> void:
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
	_label.text = text
	_label.visible = true
	_place()
	_player.stream = BakedSpeech.stream(text)
	_player.play()
	_hide_at = _now() + maxf(2.0, maxf(text.length() * seconds_per_char, _player.stream.get_length()))


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
