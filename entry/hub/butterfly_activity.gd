class_name ButterflyActivity
extends Summonable
## Wei's "Catch the butterflies" in the hub (Megan, Nov 18): his first level (Butterfly Circle), unchanged,
## with his own narrator's instructions for now. Locked from the first visit; it opens after the dots
## (WorkshopController). Each go plays the first of his levels this child hasn't finished (saved).

const TASK := preload("res://content/tasks/catch_butterflies.tres")
const LEVELS: Array[StringName] = [&"one_way", &"both_ways"]

var _left := false


func _init() -> void:
	name = "ButterflyActivity"


func id() -> StringName:
	return &"butterflies"


func task() -> Task:
	return TASK


func level_ids() -> Array[StringName]:
	return LEVELS


func summon(_workspace: Transform3D) -> void:
	_left = false
	await App.session.play(take_level().plan, false)
	finished.emit(&"left" if _left else &"done")


## The cauldron's ✕: the round is dropped and the game ends.
func leave() -> void:
	_left = true
	App.session.skip_block()
