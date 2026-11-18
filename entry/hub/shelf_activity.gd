class_name ShelfActivity
extends Summonable
## The shelf in the hub: Wei's Shadow Match with Onion's lines the first time, his next levels after that
## (FirstVisit holds that story). Wei's levels run unchanged, at his bench spot (the layout's bench frame,
## where the opening planned it): the shelf appears there, in place (Scene 8: no glide).

var _visit: FirstVisit


func _init(visit: FirstVisit) -> void:
	_visit = visit
	name = "ShelfActivity"


func id() -> StringName:
	return &"shelf"


func summon(_workspace: Transform3D) -> void:
	finished.emit(await _visit.play_shelf())


func leave() -> void:
	_visit.leave_shelf()
