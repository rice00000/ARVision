class_name Rig
extends XROrigin3D
## The child: a head and two hands. On a Quest the headset tracks them; without
## one, SimInput moves them (desktop driver, tests). Found everywhere as App.rig.

@onready var head: XRCamera3D = $Head
@onready var left: XRController3D = $LeftHand
@onready var right: XRController3D = $RightHand


func _ready() -> void:
	App.rig = self


func hand(side: StringName) -> XRController3D:
	return left if side == &"left" else right


func pointer(side: StringName) -> Pointer:
	return hand(side).get_node(^"Pointer")


## Vibrates both controllers.
func pulse(strength: float, seconds: float) -> void:
	for controller in [left, right]:
		controller.trigger_haptic_pulse(&"haptic", 0.0, strength, seconds, 0.0)
