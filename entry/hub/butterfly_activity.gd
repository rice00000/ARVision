class_name ButterflyActivity
extends Summonable
## Wei's "Catch the butterflies" in the hub (Megan, Nov 18): his four levels, unchanged,
## with his own narrator's instructions, and Onion's lines round them (story chat). Locked from the first visit; it opens after the dots
## (WorkshopController). Each go plays the first of his levels this child hasn't finished (saved).

const TASK := preload("res://content/tasks/catch_butterflies.tres")
const LEVELS: Array[StringName] = [&"one_way", &"both_ways", &"swarm", &"busy_swarm"]

var _left := false


func _init() -> void:
	name = "ButterflyActivity"


func id() -> StringName:
	return &"butterflies"


func place() -> Place:
	return preload("res://content/places/motion.tres")


func task() -> Task:
	return TASK


func level_ids() -> Array[StringName]:
	return LEVELS


## Onion's lines round Wei's narration (story chat revision, Nov 18): gentle, fond and whimsical. Wei's own
## instructions play unchanged in between; Onion stays quiet while the child catches.
const ON_ENTERING := "They never do take the shortest way around."
const ENDING := "Off they go. They'll be back."


func summon(_workspace: Transform3D) -> void:
	_left = false
	var memory := HubMemory.get_or_make()
	if memory == null or memory.first_time(&"butterflies_entered"):
		await Onion.line(ON_ENTERING, self)
		await get_tree().create_timer(0.7, false).timeout
	await App.session.play(take_level().plan, false)
	if not _left:
		await Onion.line(ENDING, self)   # Onion watches them go
	finished.emit(&"left" if _left else &"done")


## The cauldron's ✕: the round is dropped and the game ends.
func leave() -> void:
	_left = true
	App.session.stop()   # the ✕ leaves the whole level, not just its block
