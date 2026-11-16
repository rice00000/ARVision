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

# --- Recording (Nov 11, Turn to fit): right-hand pinch starts/stops; while on, a frame
# is saved every RECORD_EVERY seconds with the head pose, as CameraFrame.save() writes it
# (NNNN.jpg + NNNN.json). Pull them to the laptop with:
#   adb exec-out run-as edu.mit.arvision.cvlab tar -C files/frames -cf - . > frames.tar
const RECORD_EVERY := 0.25   # seconds between saved frames (4 per second)
const RECORD_LIMIT := 240    # at most this many per recording (= 60 s)
var _recording := false
var _record_folder := ""
var _recorded := 0
var _since_record := 0.0
func _ready() -> void:
	print("CVLAB 1: ready started")
	if not USE_YOLO:
		_yolo = null
	# Passthrough: draw nothing where the app has nothing, blend with the real room.
	get_viewport().transparent_bg = true
	App.xr.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND

	add_child(_camera)                       # starts the camera (asks permission)
	Events.button.connect(_on_button)        # right-hand pinch = start/stop recording

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
	_record_step(delta)
	if _yolo and not _waiting:
		_sent_at = Time.get_ticks_msec()
		var frame := _camera.frame()
		if frame:
			_waiting = true
			_yolo.detect(frame.jpeg())

	_since += delta
	if _since < 1.0:
		return
	_label.text = "%.1f detections/s\n%s%s" % [_done / _since, _result,
		"\nREC %d / %d" % [_recorded, RECORD_LIMIT] if _recording else "\npinch (right hand) to record"]
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


func _on_button(hand: StringName, action: StringName, pressed: bool) -> void:
	if hand != &"right" or action != &"trigger_click" or not pressed:
		return
	_recording = not _recording
	if _recording:
		# a new folder per recording, named by the time it started
		_record_folder = "user://frames/" + Time.get_datetime_string_from_system().replace(":", "-")
		DirAccess.make_dir_recursive_absolute(_record_folder)
		_recorded = 0
		_since_record = RECORD_EVERY # save the first frame straight away
	print("CVLAB record: ", "start " + _record_folder if _recording else "stop after %d frames" % _recorded)


func _record_step(delta: float) -> void:
	if not _recording:
		return
	_since_record += delta
	if _since_record < RECORD_EVERY:
		return
	_since_record = 0.0
	var frame := _camera.frame()
	if frame == null:
		return
	frame.save(_record_folder.path_join("%04d" % _recorded)) # NNNN.jpg + NNNN.json (pose, fov, time)
	_recorded += 1
	if _recorded >= RECORD_LIMIT:
		_recording = false
		print("CVLAB record: limit reached, stopped")
