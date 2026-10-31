class_name EntryMotionDev
extends Node3D
## DEV only (TESTING), for the motion route: a small head-locked marker at the top left of the view naming
## the scene that is running ("Opening", "Tutorial", "Motion", "Shelf"), and a coherence control under the
## DEV jump panel: a readout of the coherence the next round runs at and buttons that PIN it, exactly the way
## Wei's facilitator panel does (Session.pinned plus a `level_pinned` event, so every pinned level is logged,
## never an unlogged change).
##
## Where things stand is [EntryMotionLayout] (marker_spot, coherence_spot). Use:
##   var dev := EntryMotionDev.new(); add_child(dev); dev.set_scene(&"Motion")
## The scene that owns it frees it (or [method queue_free]) when it ends. Pressing works like the entry's own DEV
## buttons: poke a fingertip into a button, or point and pinch.

## Pressed: the coherence now pinned, percent.
signal pinned(percent: float)

const WORDS := {&"Opening": "Opening", &"Tutorial": "Tutorial", &"Motion": "Motion", &"Shelf": "Shelf"}
const STEP := 5.0

var _label: Label3D
var _readout: Label3D
var _buttons: Array[EntryButton] = []
var _poking := {}
var _clock := 0.0
var _since_readout := 1.0


func _ready() -> void:
	var head := App.head().global_transform
	# The marker rides on the head: top left, small, off the middle of the view.
	_label = Label3D.new()
	_label.font_size = 24
	_label.pixel_size = 0.0006
	_label.outline_size = 8
	_label.modulate = Color(1, 1, 1, 0.85)
	_label.no_depth_test = true
	_label.render_priority = 10
	App.head().add_child(_label)
	_label.visible = false   # SceneMarker is the marker
	_label.global_position = EntryMotionLayout.marker_spot(head)
	_label.global_rotation = App.head().global_rotation
	_readout = Label3D.new()
	_readout.font_size = 26
	_readout.pixel_size = 0.0006
	_readout.outline_size = 8
	_readout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_readout)
	_readout.global_position = EntryMotionLayout.coherence_row(head, 0)
	var presets: Array = EntryMotionLayout.COHERENCE_PRESETS
	for i in presets.size():
		_button("%d" % presets[i], EntryMotionLayout.coherence_spot(head, 1, i, presets.size(), EntryMotionLayout.COHERENCE_PRESET_WIDE),
				StringName("dev_coh_%d" % presets[i]), EntryMotionLayout.COHERENCE_PRESET_WIDE)
	_button("-5", EntryMotionLayout.coherence_spot(head, 2, 0, 2, EntryMotionLayout.COHERENCE_STEP_WIDE), &"dev_coh_down", EntryMotionLayout.COHERENCE_STEP_WIDE)
	_button("+5", EntryMotionLayout.coherence_spot(head, 2, 1, 2, EntryMotionLayout.COHERENCE_STEP_WIDE), &"dev_coh_up", EntryMotionLayout.COHERENCE_STEP_WIDE)
	Events.selected.connect(_on_selected)
	_refresh()


func _exit_tree() -> void:
	if _label != null and is_instance_valid(_label):
		_label.queue_free()
	if Events.selected.is_connected(_on_selected):
		Events.selected.disconnect(_on_selected)


## Names the running scene in the marker. (Organizer: the one marker is SceneMarker, which rides on
## the head across scenes; this panel's own label stays hidden so there are never two.)
func set_scene(scene: StringName) -> void:
	_label.visible = false
	SceneMarker.show_text(String(WORDS.get(scene, scene)))


## The coherence (percent) the next round runs at.
func coherence() -> float:
	if App.session == null:
		return 90.0
	if not is_nan(App.session.pinned):
		return EntryMotionLayout.percent_for(App.session.pinned)
	return EntryMotionLayout.percent_for(App.session.level()) if App.session.block != null else 90.0


## Pins the coherence the way the facilitator's Easier/Harder do (logged as `level_pinned`).
func pin(percent: float) -> void:
	if App.session == null:
		return
	var level := EntryMotionLayout.level_for(clampf(percent, 15.0, 90.0))
	App.session.pinned = level
	Events.report(&"level_pinned", {level = level, coherence = EntryMotionLayout.percent_for(level), source = &"dev_coherence"})
	pinned.emit(EntryMotionLayout.percent_for(level))
	_refresh()


func _refresh() -> void:
	var on := App.session != null and not is_nan(App.session.pinned)
	_readout.text = "DEV · coherence %d %% %s" % [roundi(coherence()), "(pinned, next round)" if on else "(auto)"]


func _button(text: String, at: Vector3, id: StringName, wide: float) -> void:
	var button := EntryButton.new()
	add_child(button)
	button.setup(text, id, Color(0.35, 0.4, 0.55), Vector2(wide, 0.05), 0.005)
	button.global_position = at
	var head := App.head().global_position
	button.look_at(Vector3(head.x, at.y, head.z), Vector3.UP)
	button.rotate_object_local(Vector3.UP, PI)
	button.born = _clock
	_buttons.append(button)


func _process(delta: float) -> void:
	_clock += delta
	_since_readout += delta
	if _since_readout > 0.3:
		_since_readout = 0.0
		_refresh()
	for side: StringName in [&"left", &"right"]:
		var tip: Variant = _fingertip(side)
		var inside: EntryButton = null
		if tip != null:
			var best := INF
			for button in _buttons:
				if button.reaches(tip) and button.off_centre(tip) < best:
					best = button.off_centre(tip)
					inside = button
		var was: Variant = _poking.get(side)
		_poking[side] = inside
		if inside != null and inside != was and _clock - inside.born > 0.8:
			_press(inside.id)
	for button in _buttons:
		var hot := false
		for side: StringName in [&"left", &"right"]:
			var aimed := App.rig.pointer(side).aimed
			hot = hot or (aimed != null and aimed.get_parent() == button) or _poking.get(side) == button
		button.set_hot(hot)


func _on_selected(_hand: StringName, target: Target, _origin: Vector3, _direction: Vector3) -> void:
	if target != null and target.get_parent() in _buttons:
		_press(target.id)


func _press(id: StringName) -> void:
	var text := String(id)
	if text == "dev_coh_up":
		pin(coherence() + STEP)
	elif text == "dev_coh_down":
		pin(coherence() - STEP)
	elif text.begins_with("dev_coh_"):
		pin(float(text.trim_prefix("dev_coh_")))


func _fingertip(side: StringName) -> Variant:
	if App.xr != null:
		var joints := App.rig.tracked_hand(side).joints()
		if joints == null or not joints.has_tracking_data:
			return null
		if (joints.get_hand_joint_flags(TrackedHand.INDEX) & XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID) == 0:
			return null
		return App.rig.global_transform * joints.get_hand_joint_transform(TrackedHand.INDEX).origin
	return null
