extends Node3D
##CV Lab V1: passthrough on, the camera's picture on a panel(which are frames that YOLO will look at. Will check if they match later on. 
const MODEL := "res://modules/cv/yolo11n.onnx"
const MIN_CONFIDENCE := 0.4
const USE_YOLO := true   # DEBUG: switch YOLO off to test the display alone

var _saved := false   # have we saved a test frame yet?
var _camera := QuestCamera.new()
var _preview :=Sprite3D.new()  #flat picture
var _label := Label3D.new() #floating text
var _since := 0.0  #seconds since last readout update
var _yolo: Object = Engine.get_singleton("Yolo") if Engine.has_singleton("Yolo") else null
var _waiting := false     # is YOLO busy with a frame?
var _sent_at := 0         # when we grabbed the frame now being detected (ms)
var _done := 0            # detections finished since the last readout
var _result := "no detections yet"
func _ready() -> void:
	print("CVLAB 1: ready started")
	if not USE_YOLO:
		_yolo = null
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
	print("CVLAB 2: panel and label added")
	if _yolo:
		_yolo.open(FileAccess.get_file_as_bytes(MODEL))
		_yolo.connect("detected", _on_detected)
		print("CVLAB 3: yolo opened")
	else:
		_result = "YOLO plugin missing"
		
func _process(delta: float) -> void:
	if _yolo and not _waiting:
		_sent_at = Time.get_ticks_msec()
		var frame := _camera.frame()
		if frame:
			_waiting = true
			_yolo.detect(frame.jpeg())

	_since += delta
	if _since < 1.0:
		return
	_label.text = "%.1f detections/s\n%s" % [_done / _since, _result]
	print("CVLAB readout: ", _label.text.replace("\n", " | "))   # same text in Godot's Output
	_done = 0
	_since = 0.0

func _on_detected(reply: String) -> void:
	_waiting = false
	_done += 1
	var total := Time.get_ticks_msec() - _sent_at
	var data: Dictionary = JSON.parse_string(reply)
	var seen := PackedStringArray()
	for item: Dictionary in data.detections:
		if item.confidence >= MIN_CONFIDENCE:
			seen.append("%s %.2f" % [item.label, item.confidence])
	_result = "model %d ms, total %d ms\n%s" % [data.ms, total, ", ".join(seen.slice(0, 4))]
