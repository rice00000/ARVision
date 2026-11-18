class_name TurnToFitSlot
extends Summonable
## Turn to fit's place in the hub until the CV chat's TurnToFit Summonable lands (branch ttf-hub-1):
## never offered (WORKSHOP_SPEC_v0.3_REVIEW decision 4: only when the cup setup is saved, the camera
## server answers and the cup is seen).

func id() -> StringName:
	return &"turn_to_fit"


func is_available() -> bool:
	return false
