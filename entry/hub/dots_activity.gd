class_name DotsActivity
extends Summonable
## The dots in the hub: Wei's Steady Flow level, unchanged (MotionVisit leads it: Onion's demonstration
## the first time). PLACEHOLDER entrance: the dots appear where Wei's game puts them; the rise from behind
## the table is the Effects chat's (EntryMotionLayout.entrance()).

var _motion: MotionVisit


func _init(motion: MotionVisit) -> void:
	_motion = motion
	name = "DotsActivity"


func id() -> StringName:
	return &"dots"


func summon(_workspace: Transform3D) -> void:
	finished.emit(await _motion.run_motion())


func leave() -> void:
	_motion.leave()
