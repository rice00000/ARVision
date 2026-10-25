class_name QuestCamera
extends SubViewport
## Frames from the Quest 3 passthrough camera, for CV. Meta's Passthrough Camera
## API reaches Godot as CameraServer feeds (needs Horizon OS v74+ and the
## horizonos.permission.HEADSET_CAMERA permission, set in the export preset).
## A Quest 3 lists three: "1 | FRONT" is a virtual avatar camera (a test
## pattern), "50 | BACK" and "51 | BACK" the left and right passthrough cameras;
## this uses the left one. A shader turns the feed (RGB, or separate Y and CbCr
## images) into RGB in this viewport, which is read back when a frame is asked for.
##
## Where the camera sits and how wide it sees come from its Camera2 calibration
## (adb shell dumpsys media.camera, camera 50 on a Quest 3): tilted 11 degrees
## down from the head, 3 cm left, 2 cm down and 6 cm ahead of it; focal length
## 864.6 px on the 1280 x 1280 sensor, which 640 x 480 crops to 1280 x 960 and halves.

const PERMISSION := "horizonos.permission.HEADSET_CAMERA"
## The left passthrough camera's feed name starts with its Camera2 id.
const LEFT_CAMERA := "50"
const SIZE := Vector2i(640, 480)
## Vertical field of view of a 640 x 480 frame: 2 atan(240 / 432.3), degrees.
const FOV_Y := 58.1
## The left camera in the head's frame.
const IN_HEAD := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-11.1)), Vector3(-0.032, -0.018, -0.063))
const YCBCR := """
shader_type canvas_item;
uniform sampler2D luma_plane;
uniform sampler2D chroma_plane;
uniform bool rgb = false;
void fragment() {
	if (rgb) {
		COLOR = vec4(texture(luma_plane, UV).rgb, 1.0);
	} else {
		float y = texture(luma_plane, UV).r;
		vec2 c = texture(chroma_plane, UV).rg - 0.5;
		COLOR = vec4(y + 1.402 * c.y, y - 0.344136 * c.x - 0.714136 * c.y, y + 1.772 * c.x, 1.0);
	}
}
"""

var _feed: CameraFeed
var _material := ShaderMaterial.new()


func _ready() -> void:
	size = SIZE
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	CameraServer.camera_feeds_updated.connect(_open_feed)
	if OS.request_permission(PERMISSION):
		CameraServer.monitoring_feeds = true
	else: # asked now; feeds appear once the child (or facilitator) allows it
		get_tree().on_request_permissions_result.connect(func(permission: String, granted: bool) -> void:
			if permission == PERMISSION and granted:
				CameraServer.monitoring_feeds = true)


## The newest frame, or null until the camera runs.
func frame() -> CameraFrame:
	if _feed == null:
		return null
	return CameraFrame.new(get_texture().get_image(), App.head().global_transform * IN_HEAD, FOV_Y)


func _process(_delta: float) -> void:
	if _feed:
		_material.set_shader_parameter(&"rgb", _feed.get_datatype() == CameraFeed.FEED_RGB)


func _open_feed() -> void:
	if _feed:
		return
	for feed in CameraServer.feeds():
		if feed.get_name().begins_with(LEFT_CAMERA):
			_feed = feed
	if _feed == null:
		return
	var formats := _feed.get_formats()
	_feed.set_format(maxi(0, formats.find_custom(func(format: Dictionary) -> bool:
		return format.width == SIZE.x and format.height == SIZE.y)), {})
	_feed.feed_is_active = true
	_material.shader = Shader.new()
	_material.shader.code = YCBCR
	for plane: Array in [["luma_plane", CameraServer.FEED_Y_IMAGE], ["chroma_plane", CameraServer.FEED_CBCR_IMAGE]]:
		var texture := CameraTexture.new()
		texture.camera_feed_id = _feed.get_id()
		texture.which_feed = plane[1]
		_material.set_shader_parameter(plane[0], texture)
	var picture := ColorRect.new()
	picture.size = size
	picture.material = _material
	add_child(picture)
