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


func pause() -> void:
	pass

func resume() -> void:
	pass
