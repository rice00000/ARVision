class_name Detection
extends RefCounted
## One real object the camera sees.

## COCO class name ("cup", "bottle", "chair"...).
var label: String
## Where it is in the room, world space. Estimated for a real camera.
var position: Vector3
var confidence: float


func _init(object_label: String, at: Vector3, score: float) -> void:
	label = object_label
	position = at
	confidence = score


func to_log() -> Dictionary:
	return {label = label, position = Log.plain(position), confidence = confidence}
