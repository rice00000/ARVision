extends Node3D
##CV Lab V1: passthrough on, the camera's picture on a panel(which are frames that YOLO will look at. Will check if they match later on. 
var _saved := false   # have we saved a test frame yet?
var _camera := QuestCamera.new()
var _preview :=Sprite3D.new()  #flat picture
var _label := Label3D.new() #floating text
var _since := 0.0  #seconds since last readout update

func _ready() -> void:
	# Passthrough: draw nothing where the app has nothing, blend with the real room.
	get_viewport().transparent_bg = true
	App.xr.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND

	add_child(_camera)                       # starts the camera (asks permission)

	_preview.texture = _camera.get_texture() # show what the camera sees
	_preview.pixel_size = 0.0004             # metres per pixel: 640 px → 26 cm wide
	_preview.position = Vector3(0, -0.05, -0.8)   # 80 cm ahead, a bit low
	App.rig.head.add_child(_preview)         # attached to the head: follows your gaze

	_label.font_size = 32
	_label.pixel_size = 0.0006
	_label.position = Vector3(0, 0.12, -0.6)
	App.rig.head.add_child(_label)

func _process(delta: float) -> void:
	_since += delta
	if _since < 1.0:      # update once a second
		return
	_since = 0.0
	var frame := _camera.frame()
	if frame == null:
		_label.text = "no camera yet"
	else:
		_label.text = "camera %d x %d" % [frame.image.get_width(), frame.image.get_height()]
		if not _saved:
			_saved = true
			frame.image.save_png("user://frame.png")
			print("feed: ", _camera._feed.get_name(), "  type: ", _camera._feed.get_datatype())
			print("formats: ", _camera._feed.get_formats())
