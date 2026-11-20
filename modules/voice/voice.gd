extends Module
## The guide's voice: a subtitle, read aloud from [BakedSpeech] files baked
## ahead of time (docs/baked-speech.md). A newer line cuts off the one playing.
## Unplugged, the guide is silent.
##
## [signal line_finished] says when a line ends, so a story can wait for the real end of
## the voice instead of guessing how long it takes.
##
## The subtitle never covers the work: it is placed ahead at [member above_horizon]
## degrees over the horizon, above the motion cloud, and when the child looks
## down at the table [member above_gaze] degrees over the gaze, above the toys.
##
## It stays IN THE ROOM where it was placed, not head-locked (Megan's scene review, Nov 17:
## head-locked text is uncomfortable, and the bottom of the view is where the table, hands and
## shelf are). It is placed when a line starts, and glides to a new place only when the head
## turns far from it ([member recentre_degrees]). Bigger text on a dark, high-contrast plate.

## How long a subtitle stays, per character; never under two seconds or the spoken line.
@export var seconds_per_char := 0.065
@export var above_horizon := 20.0
@export var above_gaze := 25.0
## Never lower than this (degrees from the horizon): looking down at the shelf no longer pulls the
## subtitle across its top row (polish, Nov 16). Higher than the shelf top seen from a seated child.
@export var min_elevation := -3.0
@export var distance := 0.75
## How far (degrees, left-right) the head turns away from the subtitle before it moves to the new view.
@export var recentre_degrees := 35.0
## When set (degrees from the horizon, straight ahead), subtitles stand there instead: the dots visit puts them
## under the dot cloud (Scene 9, Megan Nov 17). NAN = the usual place.
var fixed_elevation := NAN
## The text size and its plate (high contrast: near-white on near-black).
const FONT_SIZE := 72
const PIXEL := 0.0006
const PLATE := Color(0.05, 0.06, 0.08, 0.86)
const PLATE_PAD := Vector2(0.018, 0.012)   # metres round the text
const GLIDE := 0.45   # seconds to glide to a new place after the head turned far

## A line ended: its [param text], and whether it played to the end ([param completed]); false
## when a newer line or a scene change cut it off. A line with no baked clip ends after
## the time its subtitle shows.
signal line_finished(text: String, completed: bool)

var _label := Label3D.new()
var _plate := MeshInstance3D.new()   # the dark plate behind the text (a child of the label)
var _anchor := Vector3.ZERO          # where the subtitle stands in the room
var _gliding := 0.0                  # seconds left of a glide to a new place
var _player := AudioStreamPlayer.new()
var _hide_at := 0.0
var _speaking := ""
var _hover_target: UITarget
var _finish_at := INF
var _suspended_line := ""
var _simulate_audio := false
var _simulated_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_simulate_audio = AudioServer.get_driver_name() == "Dummy"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = PIXEL
	_label.font_size = FONT_SIZE
	_label.modulate = Color(1.0, 0.98, 0.94)
	_label.outline_size = 6
	_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	_label.no_depth_test = true
	_label.render_priority = 10
	_label.outline_render_priority = 9
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.width = 900.0
	_label.visible = false
	var plate := StandardMaterial3D.new()
	plate.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plate.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plate.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	plate.no_depth_test = true
	plate.render_priority = 8
	plate.albedo_color = PLATE
	_plate.mesh = QuadMesh.new()
	_plate.material_override = plate
	_plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_plate.name = "Plate"
	_label.add_child(_plate)
	App.rig.add_child(_label)
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
		if _hover_target != null:
			skip()
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
		_follow(delta)


## Keeps the subtitle where it stands in the room; it moves only when the head has turned far
## from it (then glides over [constant GLIDE] s), or to stay above an open panel.
func _follow(delta: float) -> void:
	var slot := App.subtitle_slot()
	if slot:   # a panel is open: just above its top edge, at the usual distance (polish V2: never over a title)
		var from := App.head().global_position
		_label.global_position = from + (slot.global_position - from).normalized() * distance
		_anchor = _label.global_position
		return
	if turned_away() > recentre_degrees:
		_anchor = spot()
		_gliding = GLIDE
	if _gliding > 0.0:
		_gliding = maxf(0.0, _gliding - delta)
		var k := 1.0 - _gliding / GLIDE
		_label.global_position = _label.global_position.lerp(_anchor, clampf(k * k, 0.15, 1.0))
	else:
		_label.global_position = _anchor


## Places the subtitle at once where the head looks now.
func _place() -> void:
	var slot := App.subtitle_slot()
	_anchor = spot()
	_gliding = 0.0
	_label.global_position = _anchor
	if slot:
		_follow(0.0)


## Where a subtitle goes for the head's pose now: ahead, above the work.
func spot() -> Vector3:
	var eye := App.head().global_transform
	var gaze := -eye.basis.z
	var ahead := Vector3(gaze.x, 0.0, gaze.z).normalized()
	var pitch := rad_to_deg(asin(clampf(gaze.y, -1.0, 1.0)))
	var elevation := deg_to_rad(clampf(pitch + above_gaze, min_elevation, above_horizon))
	if not is_nan(fixed_elevation):
		elevation = deg_to_rad(fixed_elevation)
	return eye.origin + (ahead * cos(elevation) + Vector3.UP * sin(elevation)) * distance


## Degrees (left-right, seen from above) between where the head faces and where the subtitle stands.
func turned_away() -> float:
	var eye := App.head().global_transform
	var gaze := Vector2(-eye.basis.z.x, -eye.basis.z.z)
	var to := Vector2(_anchor.x - eye.origin.x, _anchor.z - eye.origin.z)
	if gaze.length() < 0.001 or to.length() < 0.001:
		return 0.0
	return rad_to_deg(absf(gaze.angle_to(to)))


## The plate's size for [param text], metres (the text's own size plus a margin).
func _fit_plate(text: String) -> void:
	var font := _label.font if _label.font else ThemeDB.fallback_font
	var size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, _label.width, FONT_SIZE,
			-1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
	(_plate.mesh as QuadMesh).size = size * PIXEL + PLATE_PAD * 2.0


## The subtitle's plate size now, metres (tests).
func plate_size() -> Vector2:
	return (_plate.mesh as QuadMesh).size


func _say(text: String) -> void:
	_end_line(false)   # a newer line cuts off the one playing
	_label.text = text
	_fit_plate(text)
	var was_up := _label.visible
	_label.visible = true
	if not was_up or turned_away() > recentre_degrees:
		_place()   # a new line: placed where the child looks; a line right after another keeps its place
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


## A focused button can replace another button's label. Guide lines take priority.
func say_hover(button: UITarget) -> void:
	if _speaking != "" and _hover_target == null:
		return
	Events.say(button.speech)
	_hover_target = button


func stop_hover(button: UITarget) -> void:
	if _hover_target == button:
		skip()


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
	_hover_target = null
	if _speaking == "":
		return
	var text := _speaking
	_speaking = ""
	line_finished.emit(text, completed)


func _now() -> float:
	return _simulated_time if _simulate_audio else Time.get_ticks_msec() / 1000.0
