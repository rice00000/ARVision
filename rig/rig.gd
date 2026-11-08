class_name Rig
extends XROrigin3D
## The child: a head and two tracked hands (no controllers). On a Quest the
## headset tracks them; without one, SimInput moves them (desktop driver,
## tests). Found everywhere as App.rig.
##
## [member menu] is Meta's left-hand menu pinch (palm facing you, pinch): it
## arrives as [signal Events.button] (&"left", &"menu_pressed") and opens the
## facilitator panel. The right-hand one belongs to the system.

@onready var head: XRCamera3D = $Head
@onready var left: XRController3D = $LeftHand
@onready var right: XRController3D = $RightHand
@onready var menu: XRController3D = $Menu
@onready var _left_joints: TrackedHand = $LeftJoints
@onready var _right_joints: TrackedHand = $RightJoints


func _ready() -> void:
	App.rig = self
	menu.button_pressed.connect(func(action: String) -> void:
		if action == "menu_pressed":
			Events.button.emit(&"left", &"menu_pressed", true))


func hand(side: StringName) -> XRController3D:
	return left if side == &"left" else right


func pointer(side: StringName) -> Pointer:
	return hand(side).get_node(^"Pointer")


func tracked_hand(side: StringName) -> TrackedHand:
	return _left_joints if side == &"left" else _right_joints
