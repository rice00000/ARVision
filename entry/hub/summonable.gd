## One activity the workshop hub can offer (WORKSHOP_PLAN v0.3, step 0).
## Every activity (shelf, dots, Turn to fit) extends this, so the hub treats
## them all the same way. The bodies below are safe defaults; subclasses
## override what they need.
class_name Summonable extends Node3D

signal finished(outcome: StringName)   # &"done", &"left", &"interrupted"

## &"shelf", &"dots", &"turn_to_fit"
func id() -> StringName:
	return &""

## false = not offered at all (no greyed-out choice)
func is_available() -> bool:
	return true

## The small solid stand-in in the hub's ring (Effects' look, `entry/fx/impression.gd`).
func make_impression() -> Node3D:
	return Impression.make(id())

## Grow from the impression, then run.
func summon(_workspace: Transform3D) -> void:
	pass

## Shrink back into the impression.
func fold() -> void:
	pass

## Ends it early (the exit-task token): it stops at once and still emits [signal finished] (&"left").
## (Added by the Hub chat, Nov 17.)
func leave() -> void:
	pass


# --- Levels (design chat, Nov 18, `claude/DESIGN_STONES_AND_LEVELS.md` §5) --------------------------------

## The level the next go plays (the hub sets it, from the game's own row); null = [method recommended].
var level: TaskLevel
## The level the last go played: the hub gives its stones (Wei's [code]TaskProgress.complete[/code]).
var played_level: TaskLevel


## Where this game's check-ins come from (CheckIns), or null: none.
func place() -> Place:
	return null


## Wei's task this game's levels live in, or null (no stones by level).
func task() -> Task:
	return null


## The hub's own level list for this game, easiest first (a slice of [method task]'s levels).
func level_ids() -> Array[StringName]:
	return []


func levels() -> Array[TaskLevel]:
	var list: Array[TaskLevel] = []
	var from := task()
	if from == null:
		return list
	for level_id in level_ids():
		var found := from.level_by_id(level_id)
		if found != null:
			list.append(found)
	return list


## The levels this child has finished (saved, in Wei's TaskProgress).
func done_levels() -> Array[TaskLevel]:
	return levels().filter(func(l: TaskLevel) -> bool:
		return App.main != null and App.main.progress.is_done(task(), l))


## The level to play next ([method TaskProgress.next]: not finished, or not yet climbed to 70 % of its range),
## else the last.
func recommended() -> TaskLevel:
	var list := levels()
	if list.is_empty():
		return null
	var next := App.main.progress.next(task(), list) if App.main != null else list[0]
	return next if next != null else list.back()


## What the next go plays (and forgets the hub's pick).
func take_level() -> TaskLevel:
	var next := level if level != null else recommended()
	level = null
	played_level = next
	return next


func pause() -> void:
	pass

func resume() -> void:
	pass
