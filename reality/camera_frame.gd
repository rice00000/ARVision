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


## Saves the image and where it was taken as [param path].jpg and .json (read by
## [method open] and tools/frames.py).
func save(path: String) -> void:
	image.save_jpg(path + ".jpg", 0.9)
	var basis := pose.basis
	FileAccess.open(path + ".json", FileAccess.WRITE).store_string(JSON.stringify({
		origin = [pose.origin.x, pose.origin.y, pose.origin.z],
		basis = [[basis.x.x, basis.x.y, basis.x.z], [basis.y.x, basis.y.y, basis.y.z], [basis.z.x, basis.z.y, basis.z.z]],
		fov_y = fov_y, size = [image.get_width(), image.get_height()]}))


## A frame saved with [method save].
static func open(path: String) -> CameraFrame:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path + ".json"))
	var axes: Array = data.basis.map(func(axis: Array) -> Vector3: return Vector3(axis[0], axis[1], axis[2]))
	var origin := Vector3(data.origin[0], data.origin[1], data.origin[2])
	return CameraFrame.new(Image.load_from_file(path + ".jpg"), Transform3D(Basis(axes[0], axes[1], axes[2]), origin), data.fov_y)

