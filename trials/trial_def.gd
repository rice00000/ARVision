class_name TrialDef
extends Resource
## One kind of measured round: the scene that runs it, the skill it trains, its
## difficulty axes, how help arrives and how the staircase moves. Lives next to
## its scene as trials/<kind>/<id>.tres; the file name is the trial id.

@export var title := ""
## Root extends [Trial]. One instance runs every round of a block.
@export var scene: PackedScene
## Staircase this trial moves. Trials training the same thing share one.
@export var skill: StringName = &""
@export var axes: Array[TrialAxis] = []
## Modules the trial cannot run without (node names under Main/Modules, e.g.
## &"Detector"). The session skips the block when one is unplugged.
@export var requires: Array[StringName] = []
## Free notes: which axis is driven and why, what is measured.
@export_multiline var notes := ""

@export_group("Staircase")
## Successes in a row before it gets harder (2-up / 1-down ~ 71% correct).
@export var up_after := 2
@export var step := 0.1

@export_group("Help")
## Seconds without progress before the next hint. 0 = only when asked.
@export var hint_after := 8.0
## Added to [member hint_after] each round, so help fades as the child improves.
@export var hint_fade := 1.0
## Highest hint level this trial offers (see [method Trial._hint]).
@export var max_hint := 2
## Seconds before an unsolved round ends as a failure. 0 = never.
@export var time_limit := 0.0

var id: StringName:
	get:
		return StringName(resource_path.get_file().get_basename())


## The settings for one round at [param level]. [param pins] fixes axes by name;
## [param drive] (Block.drive) makes the named axes follow the level from their
## easiest to their hardest value instead of this trial's own driven axis;
## axes tagged [member TrialAxis.scaled_by] grow with the child's Vision.
func condition(level: float, round_index: int, probe: bool, pins: Dictionary = {}, drive: Dictionary = {}) -> TrialCondition:
	var round_condition := TrialCondition.new()
	round_condition.trial = id
	round_condition.skill = skill
	round_condition.level = level
	round_condition.round_index = round_index
	round_condition.probe = probe
	for axis in axes:
		var scale := Vision.scale(axis.scaled_by)
		if pins.has(axis.name):
			round_condition.set_value(axis.name, pins[axis.name])
		elif drive.has(axis.name):
			var span: Vector2 = drive[axis.name]
			round_condition.set_value(axis.name, axis.grown(lerpf(span.x, span.y, clampf(level, 0.0, 1.0)), scale))
		else: # a driven level moves only its own axes
			round_condition.set_value(axis.name, axis.scaled(0.0 if axis.driven and not drive.is_empty() else level, scale))
	return round_condition
