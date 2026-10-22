extends Module
## The guide's voice: a subtitle under the eyes, read aloud by the system's
## text-to-speech when it has a voice for [member language]. Unplugged, the
## guide is silent.

@export var language := "en"
## How long a subtitle stays, per character; never under two seconds.
@export var seconds_per_char := 0.065

var _label := Label3D.new()
var _voice := ""
var _hide_at := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label.position = Vector3(0.0, -0.18, -0.75)
	_label.pixel_size = 0.0006
	_label.font_size = 48
	_label.outline_size = 14
	_label.no_depth_test = true
	_label.render_priority = 10
	_label.outline_render_priority = 9
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.width = 900.0
	_label.visible = false
	App.rig.head.add_child(_label)
	var voices := DisplayServer.tts_get_voices_for_language(language)
	if not voices.is_empty():
		_voice = voices[0]
	Events.said.connect(_say)


func _process(_delta: float) -> void:
	if _label.visible and _now() >= _hide_at:
		_label.visible = false


func _say(text: String) -> void:
	_label.text = text
	_label.visible = true
	_hide_at = _now() + maxf(2.0, text.length() * seconds_per_char)
	if not _voice.is_empty():
		DisplayServer.tts_speak(text, _voice, 50, 1.0, 1.0, 0, true)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
