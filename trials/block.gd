class_name Block
extends Resource
## A run of rounds of one trial, under one view of the real world.

@export var trial: TrialDef
@export var rounds := 5
## Unscored check-in: no help, the staircase does not move. Run the same probe
## before and after training for a pre / post comparison.
@export var probe := false
## Level for every round, 0-1. Negative = the child's staircase level.
@export_range(-1.0, 1.0) var difficulty := -1.0
## How the real world is shown. Empty = normal.
@export var view: View
## Said once before the first round.
@export var intro := ""
## Seconds between rounds.
@export var pause_between := 1.5
