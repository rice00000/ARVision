extends CanvasLayer
## The trial block's on-screen panel (desktop): one neutral message, the buttons that make
## sense in the current phase, and a small developer line. The panel sits under the field,
## never on it, so nothing here is part of the judged stimulus.

signal pressed(action: StringName)

## Which buttons each phase offers. Pause and Leave are always there while running.
const BUTTONS := {
	&"menu": [&"demo", &"practice", &"start", &"setup", &"results", &"leave"],
	&"prepare": [&"pause", &"leave"],
	&"expose": [&"pause", &"leave"],
	&"respond": [&"left", &"right", &"pause", &"leave"],
	&"acknowledged": [&"next", &"pause", &"leave"],
	&"paused": [&"resume", &"change_setup", &"leave"],
	&"block_end": [&"results", &"rest", &"repeat", &"setup", &"leave"],
	&"resting": [&"continue", &"leave"],
	&"left": [],
}
const WORDS := {
	&"demo": "Watch an example", &"practice": "Practise answering", &"start": "Start the trials",
	&"left": "◀  Left", &"right": "Right  ▶", &"next": "Next", &"pause": "Pause",
	&"resume": "Resume", &"rest": "Rest", &"repeat": "Another set", &"continue": "Continue",
	&"leave": "Leave", &"setup": "Change setup", &"results": "See results",
	&"change_setup": "End set, change setup",
}

var _message: Label
var _row: HBoxContainer
var _dev: Label
var _buttons := {}


func _ready() -> void:
	layer = 2
	var box := VBoxContainer.new()
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_top = -250.0
	box.offset_left = 24.0
	box.offset_right = -24.0
	box.offset_bottom = -12.0
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_font_size_override("font_size", 30)
	box.add_child(_message)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 14)
	box.add_child(_row)
	for action: StringName in WORDS:
		var button := Button.new()
		button.text = WORDS[action]
		button.custom_minimum_size = Vector2(150, 56)
		button.add_theme_font_size_override("font_size", 22)
		button.focus_mode = Control.FOCUS_NONE   # keys go to the lab, not to a focused button
		button.pressed.connect(func() -> void: pressed.emit(action))
		_row.add_child(button)
		_buttons[action] = button
	_dev = Label.new()
	_dev.add_theme_font_size_override("font_size", 15)
	_dev.modulate = Color(1.0, 0.85, 0.45)
	_dev.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_dev)


## Shows [param flow] (a trial_block.gd instance).
func show_state(flow: RefCounted) -> void:
	if _message == null:
		return
	_message.text = flow.message
	var offered: Array = BUTTONS.get(flow.phase, [])
	for action: StringName in _buttons:
		_buttons[action].visible = action in offered
	# Results only once a block exists; ending a set early is only offered inside a block.
	_buttons[&"results"].visible = _buttons[&"results"].visible and not flow.block.is_empty()
	_buttons[&"change_setup"].visible = _buttons[&"change_setup"].visible \
		and not flow.block.is_empty() and flow.block.status == "running"
	var c: Dictionary = flow.config
	var a: Dictionary = flow.attempt
	_dev.text = "DEV · DESKTOP FALLBACK INPUT (←/→ keys or buttons; Space/Enter = Next/Continue, P = pause/resume, Esc = leave). Not hand-sweep or Quest verification.\n%s · coherence %d %% · %.2f m/s · blur %.2f° σ (PROVISIONAL, next set) · dataset %s · phase %s · %s%s\nRecord: %s" % [
		c.get("label", "?"), roundi(float(c.get("coherence", 0.0)) * 100.0), float(c.get("speed_m_s", 0.0)),
		float(c.get("blur_sigma_deg", 0.0)), flow.record.get("dataset_id", "?"), flow.phase, flow.summary(),
		(" · attempt %s" % a.id) if not a.is_empty() else "",
		flow.saved_path if flow.saved_path != "" else "(saved after the first answer, pause or leave)"]
