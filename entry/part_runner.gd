class_name PartRunner
extends Node
## Everything one part of the opening waits on lives here: its timers, its tweens, its frame ticks
## and the cauldron tap. Freeing the runner therefore cancels the part: whatever was awaiting
## one of these never continues. The Entry makes a new runner for the next part, so a jump
## button can cut in on a part that is still playing.

## Every frame while this runner lives.
signal tick
## The child touched the cauldron while it was asking for it.
signal cauldron_touched
## The child picked the gear up / set it into the socket (forwarded from the Carry, or the stand-in).
signal picked_up
signal docked


func _process(_delta: float) -> void:
	tick.emit()


## Waits [param seconds] (they stop while the game is paused).
func wait(seconds: float) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.start(maxf(seconds, 0.001))
	await timer.timeout
	timer.queue_free()


## Moves [param thing] smoothly to [param where] in [param seconds].
func move(thing: Node3D, where: Vector3, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(thing, "global_position", where, seconds).set_trans(Tween.TRANS_SINE)
	await tween.finished
