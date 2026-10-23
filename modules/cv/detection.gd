class_name Detection
extends RefCounted
## One real object the camera sees.

## COCO class name ("cup", "bottle", "chair"...).
var label: String
## Where it is in the room, world space. Estimated for a real camera.
var position: Vector3
## How big it looks: the radius of a ball around [member position], metres.
var radius: float
var confidence: float


func _init(object_label: String, at: Vector3, size: float, score: float) -> void:
	label = object_label
	position = at
	radius = size
	confidence = score


## Degrees by which a ray from [param origin] along [param direction] misses
## this object's outline; 0 when it passes through it.
func miss(origin: Vector3, direction: Vector3) -> float:
	var to := position - origin
	return maxf(0.0, rad_to_deg(direction.angle_to(to) - atan(radius / to.length())))


func to_log() -> Dictionary:
	return {label = label, position = Log.plain(position), radius = snappedf(radius, 0.001), confidence = confidence}
