class_name EntryMotionDev
extends Node3D
## Dev controls for the coherence of the next round.

const STEP := 5.0

var _block: Block
var _axis: TrialAxis
var _readout: Label3D
var _buttons: Array[EntryButton] = []
var _since_readout := 1.0


func _init(block: Block) -> void:
	_block = block
	_axis = block.trial.axes.filter(func(axis: TrialAxis) -> bool: return axis.name == &"coherence")[0]


func _ready() -> void:
	var head := App.head().global_transform
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


## The coherence (percent) the next round runs at.
func coherence() -> float:
	var level := App.session.level() if App.session.block != null else _block.difficulty
	return _axis.resolve(level) * 100.0


## Pins a percentage using the same difficulty axis as the round.
func pin(percent: float) -> void:
	var level := clampf(inverse_lerp(_axis.easy, _axis.hard, percent / 100.0), 0.0, 1.0)
	App.session.pin(level, {coherence = _axis.resolve(level) * 100.0, source = &"dev_coherence"})
	_refresh()


func _refresh() -> void:
	var on := not is_nan(App.session.pinned)
	_readout.text = "DEV · coherence %d %% %s" % [roundi(coherence()), "(pinned, next round)" if on else "(auto)"]


func _button(text: String, at: Vector3, id: StringName, wide: float) -> void:
	var button := EntryButton.new()
	add_child(button)
	button.setup(text, id, Color(0.35, 0.4, 0.55), Vector2(wide, 0.05), 0.005)
	button.global_position = at
	var head := App.head().global_position
	button.look_at(Vector3(head.x, at.y, head.z), Vector3.UP)
	button.rotate_object_local(Vector3.UP, PI)
	_buttons.append(button)


func _process(delta: float) -> void:
	_since_readout += delta
	if _since_readout > 0.3:
		_since_readout = 0.0
		_refresh()


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
