extends Module
## Computer vision: which real objects are in view, and where. Keeps the latest
## list in [member detections] and sends it as [signal Events.detected] a few
## times a second.
##
## Three backends. [b]Sim[/b] reads the simulated room's RealObjects: those in the
## field of view and not hidden behind anything real. [b]Headset[/b] runs YOLO on
## the Quest itself (addons/yolo, an Android plugin). [b]Remote[/b] posts camera
## frames to tools/cv_server.py (YOLO on a PC; the rendered tests use it). Both
## YOLO backends' boxes are turned back into places in the room. Auto uses sim in
## the simulated room and headset on a Quest.

enum Backend { AUTO, SIM, REMOTE, HEADSET }

## YOLO11n (Ultralytics, COCO), exported to ONNX at 640 px; run by the headset backend.
const MODEL := "res://modules/cv/yolo11n.onnx"

## Debug builds on a Quest keep the frames they send, at most this many per run,
## in user://frames/<start time>/ (tools/frames.py pulls and checks them).
const RECORD_LIMIT := 240

@export var backend := Backend.AUTO
## tools/cv_server.py as the headset reaches it, e.g. after
## `adb reverse tcp:8765 tcp:8765` over USB.
@export var server := "http://127.0.0.1:8765/detect"
## Seconds between looks.
@export var interval := 0.5
## Half the camera's field of view, degrees: farther off-centre is out of view.
@export var view_angle := 45.0
@export var min_confidence := 0.4

var detections: Array[Detection] = []

var _http := HTTPRequest.new()
## The Yolo Android plugin; null off Android.
var _yolo: Object = Engine.get_singleton(&"Yolo") if Engine.has_singleton(&"Yolo") else null
var _frame: CameraFrame
var _waiting := false
var _since := 0.0
var _recorded := 0
var _record_folder := ""
## The recorded frame now being looked at; empty when it is not recorded.
var _record_path := ""


func _ready() -> void:
	add_child(_http)
	_http.request_completed.connect(_on_reply)
	if _yolo:
		_yolo.open(FileAccess.get_file_as_bytes(MODEL))
		_yolo.connect(&"detected", func(reply: String) -> void: _on_seen(JSON.parse_string(reply)))


func _process(delta: float) -> void:
	_since += delta
	if _since < interval:
		return
	_since = 0.0
	if backend == Backend.SIM or (backend == Backend.AUTO and App.reality is SimReality):
		_publish(_see_sim())
	elif not _waiting:
		_send_frame()


## The detection of [param label] in view now, or null.
func find(label: String) -> Detection:
	for detection in detections:
		if detection.label == label:
			return detection
	return null


func _publish(found: Array[Detection]) -> void:
	detections = found
	Events.detected.emit(found)


func _see_sim() -> Array[Detection]:
	var eye := App.head().global_transform
	var space := App.head().get_world_3d().direct_space_state
	var seen: Array[Detection] = []
	for object in (App.reality as SimReality).objects():
		var centre := object.centre()
		if rad_to_deg((centre - eye.origin).angle_to(-eye.basis.z)) > view_angle:
			continue
		var query := PhysicsRayQueryParameters3D.create(eye.origin, centre, Reality.REALITY_LAYER, object.bodies())
		if space.intersect_ray(query):
			continue # something real is in the way
		seen.append(Detection.new(object.label, centre, object.radius(), 1.0))
	return seen


func _send_frame() -> void:
	_frame = App.reality.camera_frame()
	if _frame == null:
		return
	_record_path = ""
	if OS.is_debug_build() and App.reality.kind() == "passthrough" and _recorded < RECORD_LIMIT:
		_record(_frame)
	_waiting = true
	var jpeg := _frame.jpeg()
	if backend == Backend.REMOTE:
		_http.request_raw(server, PackedStringArray(["Content-Type: image/jpeg"]), HTTPClient.METHOD_POST, jpeg)
	else:
		_yolo.detect(jpeg)


func _record(frame: CameraFrame) -> void:
	if _record_folder.is_empty():
		_record_folder = "user://frames/" + Time.get_datetime_string_from_system().replace(":", "-")
		DirAccess.make_dir_recursive_absolute(_record_folder)
	_record_path = _record_folder.path_join("%04d" % _recorded)
	frame.save(_record_path)
	_recorded += 1


func _on_reply(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_waiting = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		Events.report(&"cv_error", {result = result, code = code})
		return
	_on_seen(JSON.parse_string(body.get_string_from_utf8()))


## A YOLO reply (tools/cv_server.py or the Yolo plugin): boxes to places in the room.
## A recorded frame keeps it as <frame>.seen.json (tools/frames.py compares it).
func _on_seen(reply: Dictionary) -> void:
	_waiting = false
	if not _record_path.is_empty():
		FileAccess.open(_record_path + ".seen.json", FileAccess.WRITE).store_string(JSON.stringify(reply))
	var found: Array[Detection] = []
	for item: Dictionary in reply.detections:
		if item.confidence < min_confidence:
			continue
		var box: Array = item.box # x0, y0, x1, y1, 0..1 from the top left
		var middle: float = (box[1] + box[3]) * 0.5
		var direction := _frame.ray((box[0] + box[2]) * 0.5, middle)
		var at := _locate(_frame.pose.origin, direction)
		var half_width := _frame.ray(box[0], middle).angle_to(_frame.ray(box[2], middle)) * 0.5
		found.append(Detection.new(item.label, at, at.distance_to(_frame.pose.origin) * tan(half_width), item.confidence))
	_publish(found)


## Where a seen object probably is: where its ray meets something scanned, else 1 m out.
func _locate(origin: Vector3, direction: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 4.0, Reality.REALITY_LAYER)
	var hit := App.head().get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if hit else origin + direction
