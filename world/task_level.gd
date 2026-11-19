class_name TaskLevel
extends Resource
## Stable within the task. Edit the title, project and rewards in the Inspector.

@export var id: StringName
@export var project: StringName
@export var title := ""
## Shown on the level's card for children who cannot read the title yet:
## content/tasks/pictures/, drawn by tools/card_pictures.py. Null = no picture.
@export var picture: Texture2D
@export_range(0, 9) var first_reward := 3
@export_range(0, 9) var repeat_reward := 2
@export var plan: SessionPlan


## The staircase of this level's adaptive block (Block.drive), or &"" when it plays fixed.
func staircase() -> StringName:
	for block in plan.blocks:
		if not block.drive.is_empty():
			return block.staircase if not block.staircase.is_empty() else block.trial.skill
	return &""


## How far up its range the child has climbed this level, 0 to 1; -1 when the
## level plays fixed (not adaptive, or the child is on fixed levels).
func climbed() -> float:
	var key := staircase()
	if key.is_empty() or not Vision.adaptive:
		return -1.0
	for block in plan.blocks:
		if not block.drive.is_empty():
			return Profile.level(key, maxf(block.difficulty, 0.0))
	return -1.0


## Whether the child has played this level's staircase at all.
func played() -> bool:
	return not staircase().is_empty() and staircase() in Profile.skills()
