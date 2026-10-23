extends Module
## Computer vision: which real objects are in view, and where. Keeps the latest
## list in [member detections] and sends it as [signal Events.detected] a few
## times a second.
##
## Two backends. [b]Sim[/b] reads the simulated room's RealObjects: those in the
## field of view and not hidden behind anything real. [b]Remote[/b] posts camera
## frames to tools/cv_server.py (YOLO on a laptop) and turns its boxes back into
## places in the room. Auto uses sim in the simulated room and remote on a Quest.

enum Backend { AUTO, SIM, REMOTE }

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
var _frame: CameraFrame
var _waiting := false
var _since := 0.0


func _ready() -> void:
	add_child(_http)
	_http.request_completed.connect(_on_reply)


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
	_waiting = true
	_http.request_raw(server, PackedStringArray(["Content-Type: image/jpeg"]), HTTPClient.METHOD_POST,
		_frame.image.save_jpg_to_buffer(0.8))


func _on_reply(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_waiting = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		Events.report(&"cv_error", {result = result, code = code})
		return
	var reply: Dictionary = JSON.parse_string(body.get_string_from_utf8())
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
