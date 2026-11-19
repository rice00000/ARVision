class_name Block
extends Resource
## A run of rounds of one trial, under one view of the real world.

@export var trial: TrialDef
## -1 repeats until the player or facilitator ends the block.
@export var rounds := 5
## Unscored check-in: no help, the staircase does not move. Run the same probe
## before and after training for a pre / post comparison.
@export var probe := false
## Level for every round, 0-1. Negative = the child's staircase level.
@export_range(-1.0, 1.0) var difficulty := -1.0
## Axes fixed for this block, by name (e.g. &"direction": 1.0), over the TrialDef's values.
@export var pins: Dictionary[StringName, float] = {}
## An adaptive level: these axes follow the child's level for this block, from
## the first value (level 0, easiest) to the second (level 1, hardest), e.g.
## &"clutter": Vector2(2, 12). The block then has its own staircase per child
## ([member staircase]) and [member difficulty] is where a new child starts.
## Empty = the trial's own driven axis at [member difficulty], fixed.
@export var drive: Dictionary[StringName, Vector2] = {}
## The staircase this block moves; empty = its trial's skill. Give each adaptive
## level its own, so each keeps its purpose: &"visual_matching.shadow".
@export var staircase: StringName = &""
## How the real world is shown. Empty = normal.
@export var view: View
## Replay tutorial for training, read before the first round in a probe.
@export var intro := ""
## Point and pinch from afar with the hand ray. Off: the child reaches out and
## grabs (touch, pinch on it, or close the hand on it); the ray then shows only
## for the facilitator panel.
@export var ray := true
## Seconds between rounds.
@export var pause_between := 1.5
## Seconds after the last round. A negative value uses [member pause_between].
@export var pause_after := -1.0
