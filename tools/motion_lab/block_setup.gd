extends CanvasLayer
## Setup before a replay (Nov 10 plan). Keep the setup, or change coherence, speed and
## stimulus-only blur; other visibility settings sit under "More visibility settings". Reset,
## an unscored preview, then an explicit Start. The lab snapshots the result at block start, so
## nothing here can change a block that is already running. The panel itself is never blurred.
## Ranges come from block_config.gd RANGES (developer bounds, not clinical ranges).

const BlockConfig := preload("res://tools/motion_lab/block_config.gd")

signal changed(stimulus: Dictionary, block_timing: Dictionary)
signal action(what: StringName)   # &"preview", &"start", &"close", &"new_dataset"

var stimulus := {}
var block_timing := {}
var _sliders := {}
var _values := {}
var _more: VBoxContainer
var _field: OptionButton
var _summary: Label
var _dataset: Label
var _building := false


func _ready() -> void:
	layer = 3
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.07, 0.09, 1.0)
	shade.anchor_right = 1.0
	shade.anchor_bottom = 1.0
	add_child(shade)
	var box := VBoxContainer.new()
	box.anchor_right = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 120.0
	box.offset_right = -120.0
	box.offset_top = 30.0
	box.offset_bottom = -20.0
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	box.add_child(_label("Setup for the next set", 28))
	box.add_child(_label("Keep it, or change one thing at a time to compare. Changes apply only to the next set.", 17))
	_slider(box, "coherence", "Coherence (dots moving together)", 100.0, "%d %%")
	_slider(box, "speed_m_s", "Dot speed", 1.0, "%.2f m/s")
	_slider(box, "blur_sigma_deg", "Blur (dots only)", 1.0, "%.2f° σ")
	var toggle := Button.new()
	toggle.text = "More visibility settings ▾"
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.add_theme_font_size_override("font_size", 18)
	toggle.pressed.connect(func() -> void: _more.visible = not _more.visible)
	box.add_child(toggle)
	_more = VBoxContainer.new()
	_more.visible = false
	_more.add_theme_constant_override("separation", 10)
	box.add_child(_more)
	var field_row := HBoxContainer.new()
	field_row.add_child(_label("Field shape", 18, 360))
	_field = OptionButton.new()
	_field.add_item("Rectangle (preview default)")
	_field.add_item("Circle, 10°, 15 dots (reference-sized)")
	_field.focus_mode = Control.FOCUS_NONE
	_field.item_selected.connect(_on_field)
	field_row.add_child(_field)
	_more.add_child(field_row)
	_slider(_more, "dots", "Number of dots", 1.0, "%d")
	_slider(_more, "dot_radius_m", "Dot size (radius)", 100.0, "%.1f cm")
	_slider(_more, "expose_s", "How long the dots show", 1.0, "%.2f s")
	_summary = _label("", 15)
	_summary.modulate = Color(1.0, 0.85, 0.45)
	box.add_child(_summary)
	_dataset = _label("", 15)
	_dataset.modulate = Color(0.75, 0.8, 0.85)
	box.add_child(_dataset)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	_button(row, "Reset to defaults", func() -> void:
		set_setup(BlockConfig.preview(0.9), BlockConfig.timing())
		_emit())
	_button(row, "Preview (unscored)", func() -> void: action.emit(&"preview"))
	_button(row, "Start a set", func() -> void: action.emit(&"start"))
	_button(row, "Back", func() -> void: action.emit(&"close"))
	_button(row, "New dataset", func() -> void: action.emit(&"new_dataset"))


func set_setup(s: Dictionary, t: Dictionary) -> void:
	stimulus = s.duplicate(true)
	block_timing = t.duplicate(true)
	_building = true
	_field.select(1 if stimulus.get("aperture", "") == "circle" else 0)
	for key: String in _sliders:
		var value: float = float(block_timing.expose_s) if key == "expose_s" else float(stimulus.get(key, 0.0))
		_sliders[key].value = value
	_building = false
	_refresh()


func show_dataset(dataset_id: String) -> void:
	_dataset.text = "Results collect in dataset \"%s\" (non-identifying label). Start a new dataset for a different person or visit." % dataset_id


func _slider(parent: Control, key: String, text: String, scale: float, fmt: String) -> void:
	var r: Dictionary = BlockConfig.RANGES[key]
	var row := HBoxContainer.new()
	row.add_child(_label(text, 18, 360))
	var slider := HSlider.new()
	slider.min_value = r.min
	slider.max_value = r.max
	slider.step = r.step
	slider.custom_minimum_size = Vector2(420, 32)
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(_v: float) -> void:
		if not _building:
			_emit())
	row.add_child(slider)
	var value := _label("", 18, 140)
	row.add_child(value)
	parent.add_child(row)
	_sliders[key] = slider
	_values[key] = [value, scale, fmt]


func _on_field(index: int) -> void:
	if _building:
		return
	var base := BlockConfig.reference_circle(float(stimulus.coherence)) if index == 1 else BlockConfig.preview(float(stimulus.coherence))
	for key: String in ["speed_m_s", "blur_sigma_deg"]:
		base[key] = stimulus.get(key, base[key])
	set_setup(base, block_timing)
	_emit()


func _emit() -> void:
	var changes := {}
	for key: String in _sliders:
		if key != "expose_s":
			changes[key] = _sliders[key].value
	stimulus = BlockConfig.customized(stimulus, changes)
	block_timing = BlockConfig.customized_timing(block_timing, _sliders.expose_s.value)
	_refresh()
	changed.emit(stimulus, block_timing)


func _refresh() -> void:
	for key: String in _values:
		var v: Array = _values[key]
		v[0].text = v[2] % (_sliders[key].value * v[1])
	var deg_s := rad_to_deg(atan(float(stimulus.get("speed_m_s", 0.0)) / maxf(float(stimulus.get("distance_m", 1.0)), 0.01)))
	_summary.text = "PROVISIONAL developer settings · %s\nSpeed ≈ %.1f °/s at the field's centre · blur: %s" % [
		BlockConfig.condition_label(stimulus, block_timing), deg_s,
		"none" if float(stimulus.get("blur_sigma_deg", 0.0)) <= 0.0 else "Gaussian edge on each dot (dots only; not a simulation of any condition)"]


func _label(text: String, size: int, width := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if width == 0 else TextServer.AUTOWRAP_OFF
	l.add_theme_font_size_override("font_size", size)
	if width > 0:
		l.custom_minimum_size = Vector2(width, 0)
	return l


func _button(parent: Control, text: String, call: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(170, 52)
	b.add_theme_font_size_override("font_size", 18)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(call)
	parent.add_child(b)
