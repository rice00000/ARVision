extends Node
## Signal bus (autoload "Events"): the only contract modules share.
##
## Emitters never know who listens, so any module can be unplugged without
## breaking the others. Everything a session does passes through here, which is
## also what the research log and the tests listen to.

# -- the child's input (sent by the rig's Pointers) ---------------------------

## A hand input changed. [param action] is the OpenXR action: trigger_click
## (pinch), grip_click (grasp), or menu_pressed (left-hand menu pinch).
signal button(hand: StringName, action: StringName, pressed: bool)
## The child pinched while pointing. [param target] is the virtual Target
## the ray hit, or null; the ray itself always comes along, so a trial can judge
## pointing at a real object that has no collider.
signal selected(hand: StringName, target: Target, origin: Vector3, direction: Vector3)
## A fingertip entered a Target.
signal touched(hand: StringName, target: Target)
## A hand swept: one brisk move from [param from] to [param to] that took
## [param seconds], the longest leg of a move from rest to rest. No pinch
## needed; a wind-up before it or the way back after it is not one.
signal swept(hand: StringName, from: Vector3, to: Vector3, seconds: float)
## The child asked for help (raised a hand).
signal help_requested
## A hand lost or regained tracking.
signal hand_tracking(hand: StringName, tracked: bool)

# -- what the child sees and hears --------------------------------------------

## The guide speaks. Voice shows it as a subtitle and reads it aloud.
signal said(text: String)
## A response was judged: &"good", &"bad" or &"hint". Feedback answers with a
## sound and a mark at [param at]: never colour alone.
signal feedback(kind: StringName, at: Vector3)
## How the real world is shown changed (passthrough filter, dimming, focus).
signal view_changed(view: Dictionary)

# -- measurement (sent by Trial and Session) ----------------------------------

## A round starts. [param condition] is TrialCondition.to_log(): everything it runs at.
signal trial_started(trial: StringName, condition: Dictionary)
## A scored round is over. Abandoned rounds never send this.
signal trial_ended(skill: StringName, success: bool, data: Dictionary)
signal block_started(index: int, info: Dictionary)
signal session_finished

# -- the rest -----------------------------------------------------------------

## Real objects the CV module sees now (Array of Detection).
signal detected(detections: Array)
## The facilitator panel opened or closed. Play pauses while it is open.
signal facilitator_toggled(open: bool)
## Any other fact worth a line in the research log.
signal reported(what: StringName, data: Dictionary)


func say(text: String) -> void:
	said.emit(text)


func report(what: StringName, data: Dictionary = {}) -> void:
	reported.emit(what, data)
