class_name TrialCondition
extends RefCounted
## The exact settings one round runs at. A trial reads difficulty from here and
## nowhere else, and adds anything else it decides (the target, a seed) with
## [method set_value], so the log can replay the round.

var trial: StringName = &""
var skill: StringName = &""
## The 0-1 level these values were resolved from.
var level := 0.0
## 0-based round in the block. Help fades as it grows.
var round_index := 0
## Unscored check-in: no help, and the staircase does not move.
var probe := false
## How the real world was shown (View.to_log()).
var view: Dictionary = {}

var _values: Dictionary[StringName, Variant] = {}


func value(axis: StringName, default: Variant = 0.0) -> Variant:
	return _values.get(axis, default)


func set_value(axis: StringName, new_value: Variant) -> void:
	_values[axis] = new_value


## Everything above as one dictionary for the log.
func to_log() -> Dictionary:
	return {trial = trial, skill = skill, level = level, round = round_index,
		probe = probe, view = view, values = _values.duplicate()}
