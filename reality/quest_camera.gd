class_name QuestCamera
extends SubViewport
## Frames from the Quest 3 passthrough camera, for CV. Meta's Passthrough Camera
## API reaches Godot as a CameraServer feed (needs Horizon OS v74+ and the
## horizonos.permission.HEADSET_CAMERA permission, set in the export preset).
## The feed arrives as separate Y and CbCr images; a shader turns them into RGB
## in this viewport, which is read back when a frame is asked for.
##
## Not yet run on a headset: check the feed choice, colours and FOV there.

const PERMISSION := "horizonos.permission.HEADSET_CAMERA"
## Approximate vertical field of view of the passthrough camera, degrees.
const FOV_Y := 64.0
const YCBCR := """
shader_type canvas_item;
uniform sampler2D luma_plane;
uniform sampler2D chroma_plane;
void fragment() {
	float y = texture(luma_plane, UV).r;
	vec2 c = texture(chroma_plane, UV).rg - 0.5;
	COLOR = vec4(y + 1.402 * c.y, y - 0.344136 * c.x - 0.714136 * c.y, y + 1.772 * c.x, 1.0);
}
"""

var _feed: CameraFeed


func _ready() -> void:
	size = Vector2i(640, 480)
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
	return CameraFrame.new(get_texture().get_image(), App.head().global_transform, FOV_Y)


func _open_feed() -> void:
	if _feed or CameraServer.get_feed_count() == 0:
		return
	_feed = CameraServer.get_feed(0)
	_feed.set_format(0, {})
	_feed.feed_is_active = true
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = YCBCR
	for plane: Array in [["luma_plane", CameraServer.FEED_Y_IMAGE], ["chroma_plane", CameraServer.FEED_CBCR_IMAGE]]:
		var texture := CameraTexture.new()
		texture.camera_feed_id = _feed.get_id()
		texture.which_feed = plane[1]
		material.set_shader_parameter(plane[0], texture)
	var picture := ColorRect.new()
	picture.size = size
	picture.material = material
	add_child(picture)
