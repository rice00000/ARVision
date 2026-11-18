class_name ButterflyActivity
extends Summonable
## Wei's "Catch the butterflies" in the hub (Megan, Nov 18): his first level (Butterfly Circle), unchanged,
## with his own narrator's instructions for now. Locked from the first visit; it opens after the dots
## (WorkshopController). Each go plays the next of his levels the child hasn't played this visit.

const TASK := preload("res://content/tasks/catch_butterflies.tres")
const LEVELS: Array[StringName] = [&"one_way", &"both_ways"]

var _plays := 0
var _left := false


func _init() -> void:
	name = "ButterflyActivity"


func id() -> StringName:
	return &"butterflies"


func summon(_workspace: Transform3D) -> void:
	_left = false
	var level := TASK.level_by_id(LEVELS[mini(_plays, LEVELS.size() - 1)])
	_plays += 1
	await App.session.play(level.plan, false)
	finished.emit(&"left" if _left else &"done")


## The cauldron's ✕: the round is dropped and the game ends.
func leave() -> void:
	_left = true
	App.session.skip_block()
