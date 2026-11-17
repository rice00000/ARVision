class_name FitTracker
extends Node
## Turn to fit, the camera side: finds the cup, captures targets and tracks the live shape.
## Shared by the laptop lab (tools/cv_lab/turn_to_fit_lab.gd) and the game scene
## (turn_to_fit/turn_to_fit.gd), so both run the same CV.
##
##   every DETECT_EVERY  the CV server's YOLO finds the cup's box         (laptop server, /detect)
##   capture(name)       the server's SAM outlines the cup → a target     (laptop server, /segment)
##                       the first capture also teaches the cup's colours
##   every TRACK_EVERY   ShapeCV.track finds the cup by colour in the box → [signal stepped]
##
## The server runs on the laptop: python3 tools/cv_server.py. Another address:  -- --cv-server=http://IP:8765
## Tests set [member use_server] false and give boxes and masks directly ([method set_box], [method add_capture]).

const DEFAULT_SERVER := "http://127.0.0.1:8765"
const TRACK_EVERY := 0.2
const DETECT_EVERY := 0.5
## Without a cup for this long, the box is dropped.
const BOX_TIMEOUT := 1.5
## The panel picture: the 64 × 48 shape drawn this many times bigger.
const PICTURE_SCALE := 5

## Every TRACK_EVERY: the live shape (empty when the cup wasn't found) and the seconds since the last step.
signal stepped(shape: PackedByteArray, dt: float)
## A target was captured: its name and normalised shape.
signal captured(target: String, shape: PackedByteArray)
## A capture didn't work, and why (in plain words).
signal capture_failed(target: String, why: String)

## The newest camera picture, or null: () -> Image.
var source := Callable()
var server := DEFAULT_SERVER
## False: no HTTP at all (tests, or a later on-headset detector).
var use_server := true
## YOLO's cup box, camera pixels (empty = none).
var box := Rect2i()
## The cup's colours (from the first capture); empty until then.
var model := PackedFloat32Array()
## The last tracking result (ShapeCV.track), {} when there was none.
var live := {}
var track_ms := 0.0
var server_ok := true
## The target waiting for /segment, or "".
var capturing := ""

var _box_age := 0.0
var _since_track := 0.0
var _since_detect := 0.0
var _detecting := false
var _capture_image: Image
var _capture_box := Rect2i()
var _detect_http := HTTPRequest.new()
var _segment_http := HTTPRequest.new()


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cv-server="):
			server = arg.trim_prefix("--cv-server=")
	add_child(_detect_http)
	add_child(_segment_http)
	_detect_http.request_completed.connect(_on_detected)
	_segment_http.request_completed.connect(_on_segmented)


func _process(delta: float) -> void:
	_box_age += delta
	if _box_age > BOX_TIMEOUT and use_server:
		box = Rect2i()
	_since_detect += delta
	if use_server and _since_detect >= DETECT_EVERY and not _detecting:
		_since_detect = 0.0
		_detect()
	_since_track += delta
	if _since_track >= TRACK_EVERY:
		step(_since_track)
		_since_track = 0.0


## The newest picture from [member source], or null.
func grab() -> Image:
	return source.call() if source.is_valid() else null


## One tracking step (called by itself every TRACK_EVERY; tests may call it).
func step(dt: float) -> void:
	live = {}
	var image := grab()
	if image != null and not model.is_empty() and box.size != Vector2i.ZERO:
		var start := Time.get_ticks_usec()
		live = ShapeCV.track(image, box, model)
		track_ms = (Time.get_ticks_usec() - start) / 1000.0
	stepped.emit(live.shape if live.get("ok", false) else PackedByteArray(), dt)


## Tests and on-headset detectors: the cup's box, as if YOLO had just found it.
func set_box(cup: Rect2i) -> void:
	box = cup
	_box_age = 0.0


## Forgets the colours (the next capture teaches them again).
func clear() -> void:
	model = PackedFloat32Array()


## Asks SAM to outline the cup in the newest picture as [param target]. False (and nothing
## sent) when no cup is in view or a capture is already waiting.
func capture(target: String) -> bool:
	if capturing != "":
		return false
	var image := grab()
	if image == null or box.size == Vector2i.ZERO:
		capture_failed.emit(target, "No cup found yet: is the CV server running and the cup in view?")
		return false
	if not use_server:
		capture_failed.emit(target, "No CV server in this run.")
		return false
	capturing = target
	_capture_image = image.duplicate()
	_capture_box = box
	var query := "%s/segment?box=%d,%d,%d,%d" % [server, box.position.x, box.position.y, box.end.x, box.end.y]
	_segment_http.request_raw(query, PackedStringArray(["Content-Type: image/jpeg"]), HTTPClient.METHOD_POST,
		_capture_image.save_jpg_to_buffer(0.9))
	return true


## A capture from a mask (SAM's reply, or a saved one in tests): the first one also teaches
## the colours. Returns whether a cup outline was found.
func add_capture(target: String, image: Image, mask: Image, cup: Rect2i) -> bool:
	if model.is_empty():
		model = ShapeCV.learn_colours(image, mask, cup)
	var shape := ShapeCV.target_from_mask(mask, cup)
	if not shape.ok:
		capture_failed.emit(target, "The capture of \"%s\" found no cup outline." % target)
		return false
	captured.emit(target, shape.shape)
	return true


func _detect() -> void:
	var image := grab()
	if image == null:
		return
	_detecting = true
	_detect_http.set_meta(&"size", image.get_size())
	if _detect_http.request_raw(server + "/detect", PackedStringArray(["Content-Type: image/jpeg"]),
			HTTPClient.METHOD_POST, image.save_jpg_to_buffer(0.85)) != OK:
		_detecting = false


func _on_detected(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_detecting = false
	server_ok = result == HTTPRequest.RESULT_SUCCESS and code == 200
	if not server_ok:
		return
	var size: Vector2i = _detect_http.get_meta(&"size")
	var reply: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not reply is Dictionary:
		return
	var best := {}
	for found: Dictionary in reply.get("detections", []):
		if found.label == "cup" and found.confidence > best.get("confidence", 0.3):
			best = found
	if best.is_empty():
		return
	var b: Array = best.box # 0..1 corners
	set_box(Rect2i(Vector2i(roundi(b[0] * size.x), roundi(b[1] * size.y)),
		Vector2i(roundi((b[2] - b[0]) * size.x), roundi((b[3] - b[1]) * size.y))))


func _on_segmented(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var target := capturing
	capturing = ""
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		capture_failed.emit(target, "Capture failed (server reply %d)." % code)
		return
	var mask := Image.new()
	if mask.load_png_from_buffer(body) != OK:
		capture_failed.emit(target, "Capture failed: the reply wasn't a picture.")
		return
	add_capture(target, _capture_image, mask, _capture_box)


## A 64 × 48 shape picture, [param scale]× bigger: [param fill] in light grey, the contour
## of [param line] in [param colour] ([param thickness] in shape pixels), on dark.
static func picture(line: PackedByteArray, fill: PackedByteArray, colour: Color, thickness: int,
		scale := PICTURE_SCALE) -> Image:
	var w := ShapeCV.NORM_W
	var h := ShapeCV.NORM_H
	var image := Image.create(w, h, false, Image.FORMAT_RGB8)
	image.fill(Color(0.12, 0.12, 0.14))
	var edge := ShapeCV.outline(line, w, h, thickness) if not line.is_empty() else PackedByteArray()
	for i in w * h:
		if not fill.is_empty() and fill[i] == 1:
			image.set_pixel(i % w, i / w, Color(0.8, 0.8, 0.8))
		if not edge.is_empty() and edge[i] == 1:
			image.set_pixel(i % w, i / w, colour)
	image.resize(w * scale, h * scale, Image.INTERPOLATE_NEAREST)
	return image
