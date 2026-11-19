class_name TaskActivity
extends Summonable
## One of Wei's tasks as a hub game (Real Life, Odd Color): a slice of its levels, easiest first, each played as
## Wei's own level at his bench spot with his own lines. Its bubble and its levels' row show the levels' own
## drawings (TaskLevel.picture, Wanchun's tools/card_pictures.py) in the game's frame (LevelPiece.drawn).

var _id: StringName
var _task: Task
var _level_ids: Array[StringName]
var _place: Place
var _left := false


## [param at]: whose check-in runs before it, or null (none).
func _init(game: StringName, from: Task, ids: Array[StringName], at: Place) -> void:
	_id = game
	_place = at
	_task = from
	_level_ids = ids
	name = "%sActivity" % String(game).to_pascal_case()


func id() -> StringName:
	return _id


func place() -> Place:
	return _place


func task() -> Task:
	return _task


func level_ids() -> Array[StringName]:
	return _level_ids


## The bubble: the first level's drawing.
func make_impression() -> Node3D:
	return Impression.make_drawn(_id, levels()[0].picture)


func summon(_workspace: Transform3D) -> void:
	_left = false
	SceneMarker.show_text("%s: %s" % [Impression.title_for(_id), take_level().title])
	await App.session.play(played_level.plan)
	finished.emit(&"done" if App.session.won and not _left else &"left")


## The cauldron's ✕: the round is dropped and the game ends.
func leave() -> void:
	_left = true
	App.session.stop()   # the ✕ leaves the whole level, not just its block
