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
## A dark plate behind the words, so they read on pale walls and bright passthrough.
var _backing := MeshInstance3D.new()
var _player := AudioStreamPlayer.new()
var _hide_at := 0.0
var _speaking := ""
var _finish_at := INF
var _suspended_line := ""
var _simulate_audio := false
var _simulated_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_simulate_audio = AudioServer.get_driver_name() == "Dummy"
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
	var plate := StandardMaterial3D.new()
	plate.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plate.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plate.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	plate.no_depth_test = true
	plate.render_priority = 8
	plate.albedo_color = Color(0.05, 0.06, 0.08, 0.72)
	_backing.mesh = QuadMesh.new()
	_backing.material_override = plate
	_backing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_label.add_child(_backing)
	_player.bus = &"Voice"
	add_child(_player)
	Events.said.connect(_say)
	Events.player_menu_toggled.connect(_player_menu)
	if not _simulate_audio:
		_player.finished.connect(_end_line.bind(true))
	Events.scene_changing.connect(func() -> void:
		_suspended_line = ""
		_player.stop()
		_label.visible = false
		_end_line(false))


## Keep an awaited story line pending while the player menu speaks.
func _player_menu(open: bool) -> void:
	if open:
		_suspended_line = _speaking
		_player.stop()
		_speaking = ""
		_label.visible = false
	else:
		var resume := _suspended_line
		_suspended_line = ""
		_player.stop()
		_end_line(false)
		_label.visible = false
		if not resume.is_empty(): _say(resume)


func _process(delta: float) -> void:
	if _simulate_audio:
		_simulated_time += delta # Silent audio follows game time in the lockstep simulator.
	var now := _now()
	if _speaking != "" and now >= _finish_at:
		_player.stop()
		_end_line(true)
	if _label.visible and _speaking == "" and now >= _hide_at:
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
	_fit_backing()


## The plate just around the words (centred, as the label centres them).
func _fit_backing() -> void:
	var font := _label.font if _label.font else ThemeDB.fallback_font
	var words := font.get_multiline_string_size(_label.text, HORIZONTAL_ALIGNMENT_CENTER, _label.width, _label.font_size,
		-1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
	(_backing.mesh as QuadMesh).size = words * _label.pixel_size + Vector2(0.04, 0.02)


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
	var now := _now()
	_hide_at = now + maxf(2.0, maxf(shown, spoken))
	_speaking = text
	_finish_at = INF
	if stream == null:
		_finish_at = now + maxf(1.0, shown)
	elif _simulate_audio:
		_finish_at = now + spoken


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
	return _simulated_time if _simulate_audio else Time.get_ticks_msec() / 1000.0
