extends Node
## Vision (autoload "Vision"): how this child needs the game set up, kept in
## their save next to the staircase levels. Staff edit it on the facilitator's
## Vision page; it applies everywhere except where a session plan says otherwise.
##
## [codeblock]
## view          the child's own filter: every block without a Block.view, the
##               world and the intro. A block's own view still wins (filter A/B).
## size_scale    times every axis tagged scaled_by = &"size" (TrialAxis)
## help_scale    times TrialDef.hint_after and hint_fade: 0.5 = help twice as soon
## time_scale    times TrialDef.time_limit
## offsets       staircase -> added to a level's fixed difficulty
## adaptive      menu levels adapt to the child, each on its own staircase
##               (Block.drive); off = each plays fixed at its starting difficulty
## [/codeblock]
##
## Every change is reported as vision_changed with before and after, and bumps
## [member revision]; each block logs the whole profile, so two probes run under
## different profiles can be told apart.

const SIZE_RANGE := Vector2(0.75, 2.0)
const HELP_RANGE := Vector2(0.5, 2.0)
const TIME_RANGE := Vector2(1.0, 3.0)
const OFFSET_LIMIT := 0.5
const MARK := &"vision"

var save_key := "vision"

## Changed while the game runs; the Session applies it when no block view is
## set. Always this profile's own copy, marked [constant MARK], so a view in use
## can be told apart from a block's or a room's.
var view := _own(View.new()):
	set(value):
		view = _own(value)
var size_scale := 1.0
var help_scale := 1.0
var time_scale := 1.0
var offsets: Dictionary[StringName, float] = {}
var adaptive := true
## The preset this profile started from; edits keep it. Empty = none.
var preset := ""
## Number of changes since this save began.
var revision := 0


func save_state() -> Dictionary:
	var data := to_log()
	data.adaptive_levels = data.adaptive # a new key: before adaptive levels, "adaptive" meant something else
	data.erase("adaptive")
	return data


func load_state(data: Dictionary) -> void:
	view = View.from_log(data.get("view", {}))
	size_scale = clampf(data.get("size_scale", 1.0), SIZE_RANGE.x, SIZE_RANGE.y)
	help_scale = clampf(data.get("help_scale", 1.0), HELP_RANGE.x, HELP_RANGE.y)
	time_scale = clampf(data.get("time_scale", 1.0), TIME_RANGE.x, TIME_RANGE.y)
	offsets.clear()
	for skill: String in data.get("offsets", {}):
		offsets[StringName(skill)] = clampf(data.offsets[skill], -OFFSET_LIMIT, OFFSET_LIMIT)
	adaptive = data.get("adaptive_levels", true)
	preset = data.get("preset", "")
	revision = int(data.get("revision", 0))


func to_log() -> Dictionary:
	return {view = view.to_log(), size_scale = size_scale, help_scale = help_scale,
		time_scale = time_scale, offsets = offsets.duplicate(), adaptive = adaptive, preset = preset, revision = revision}


## How much axes tagged [param kind] grow for this child; 1 for any other kind.
func scale(kind: StringName) -> float:
	return size_scale if kind == &"size" else 1.0


func offset(skill: StringName) -> float:
	return offsets.get(skill, 0.0)


## Takes [param chosen]'s filter and scales, keeping offsets and adaptive.
func use_preset(chosen: VisionPreset) -> void:
	change(func() -> void:
		var shown: View = chosen.view.duplicate() if chosen.view else View.new()
		shown.title = chosen.label
		view = shown
		size_scale = chosen.size_scale
		help_scale = chosen.help_scale
		time_scale = chosen.time_scale
		preset = chosen.label)


func set_view(new_view: View) -> void:
	change(func() -> void: view = new_view)


func set_size_scale(value: float) -> void:
	change(func() -> void: size_scale = clampf(value, SIZE_RANGE.x, SIZE_RANGE.y))


func set_help_scale(value: float) -> void:
	change(func() -> void: help_scale = clampf(value, HELP_RANGE.x, HELP_RANGE.y))


func set_time_scale(value: float) -> void:
	change(func() -> void: time_scale = clampf(value, TIME_RANGE.x, TIME_RANGE.y))


func set_offset(skill: StringName, value: float) -> void:
	change(func() -> void:
		value = clampf(snappedf(value, 0.01), -OFFSET_LIMIT, OFFSET_LIMIT)
		if is_zero_approx(value):
			offsets.erase(skill)
		else:
			offsets[skill] = value)


func set_adaptive(on: bool) -> void:
	change(func() -> void: adaptive = on)


## Back to no customisation.
func reset() -> void:
	change(func() -> void:
		view = View.new()
		size_scale = 1.0
		help_scale = 1.0
		time_scale = 1.0
		offsets.clear()
		adaptive = true
		preset = "")


## Runs [param edit], then logs and saves the change if it made one. The filter
## shows at once unless a block's own view is in charge.
func change(edit: Callable) -> void:
	var before := to_log()
	edit.call()
	var after := to_log()
	if after == before:
		return
	revision += 1
	after.revision = revision
	Events.report(&"vision_changed", {before = before, after = after})
	if App.reality and is_childs(App.reality.view):
		App.reality.apply_view(view)


## Whether [param shown] is this child's view, now or before a change.
func is_childs(shown: View) -> bool:
	return shown != null and shown.has_meta(MARK)


static func _own(source: View) -> View:
	var copy: View = source.duplicate()
	copy.set_meta(MARK, true)
	return copy
