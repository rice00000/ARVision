class_name CameraFrame
extends RefCounted
## One camera image of the real world with where the camera was, so CV results
## (boxes in the image) can be turned back into directions in the room.

var image: Image
## Camera pose when the image was taken: -Z forward, +Y up.
var pose: Transform3D
## Vertical field of view, degrees.
var fov_y: float


func _init(picture: Image, camera_pose: Transform3D, vertical_fov: float) -> void:
	image = picture
	pose = camera_pose
	fov_y = vertical_fov


## World direction through image point ([param u], [param v]), both 0..1 from the top left.
func ray(u: float, v: float) -> Vector3:
	var half := tan(deg_to_rad(fov_y) * 0.5)
	var aspect := float(image.get_width()) / image.get_height()
	var local := Vector3((u * 2.0 - 1.0) * half * aspect, (1.0 - v * 2.0) * half, -1.0)
	return (pose.basis * local).normalized()
