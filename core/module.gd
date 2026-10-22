class_name Module
extends Node
## An optional feature: a child of Main/Modules (Voice, Feedback, Detector,
## Facilitator...).
##
## Unplug one by deleting its node from main.tscn. Nothing calls a module
## directly: others reach it through [method App.module], which returns null once
## it is gone, or talk to it through [Events]. A trial that cannot run without a
## module lists it in [member TrialDef.requires], and the session skips it.

const GROUP := &"modules"


func _enter_tree() -> void:
	add_to_group(GROUP)
