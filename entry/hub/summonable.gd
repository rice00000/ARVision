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

## The small solid stand-in (Effects supplies the look).
func make_impression() -> Node3D:
	return Node3D.new()

## Grow from the impression, then run.
func summon(_workspace: Transform3D) -> void:
	pass

## Shrink back into the impression.
func fold() -> void:
	pass

func pause() -> void:
	pass

func resume() -> void:
	pass
