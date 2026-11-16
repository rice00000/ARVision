extends Control
## Turn to fit lab (laptop, Nov 15): the whole CV loop without a headset.
##
## Camera: the webcam (QuestCamera falls back to it on a laptop) or, when there is no
## camera, Megan's mug photos in tests/data/turn_to_fit/ (← → switch photo).
## Needs the CV server running in a second Terminal window:
##     python3 tools/cv_server.py        (YOLO for /detect, MobileSAM for /segment)
## Run:
##     Godot --xr-mode off --path . res://tools/cv_lab/turn_to_fit_lab.tscn
##     add  -- --demo  to capture 3 targets from the photos by itself and save screenshots
##
## Keys: 1 2 3 = capture target (handle left / right / toward you) · C = clear · ← → = photo
##
## The loop (see claude/CV_TURN_TO_FIT_BUILD.md):
##   every 0.5 s  the server's YOLO finds the cup's box            (Layer 2, laptop)
##   on 1/2/3     the server's SAM outlines the cup → a target;    (Layer 2, laptop)
##                the first capture also teaches the cup's colours
##   every 0.2 s  ShapeCV.track finds the cup by colour in the box (Layer 1, here)
##                → FitMatcher: fits once it holds 0.5 s

const SERVER := "http://127.0.0.1:8765"
const TARGETS := ["left", "right", "toward"]
const TRACK_EVERY := 0.2
const DETECT_EVERY := 0.5
## Without a cup for this long, the box is dropped.
const BOX_TIMEOUT := 1.5
const PHOTOS := "res://tests/data/turn_to_fit/"
const PANEL_SCALE := 5 # the 64 × 48 shape drawn 5× bigger
const GOLD := Color(0.95, 0.75, 0.2)
const GREEN := Color(0.35, 0.85, 0.45)

var _camera := QuestCamera.new()
var _photos: Array[Image] = []
var _photo_index := 0
var _model := PackedFloat32Array()     # the cup's colours (from the first capture)
var _shapes := {}                      # target name → normalised shape
var _matcher := FitMatcher.new()
var _box := Rect2i()                   # YOLO's cup box, camera pixels (empty = none)
var _box_age := 0.0
var _since_track := 0.0
var _since_detect := 0.0
var _detecting := false
var _capturing := ""                   # target name waiting for /segment, or ""
var _capture_image: Image
var _capture_box := Rect2i()
var _last_live := {}
var _track_ms := 0.0
var _server_ok := true
var _demo_step := -1

var _detect_http := HTTPRequest.new()
var _segment_http := HTTPRequest.new()
var _view := TextureRect.new()
var _box_layer := Control.new()
var _panel := TextureRect.new()
var _status := Label.new()
var _info := Label.new()
var _rows := {}                        # name → {thumb, bar, label}


func _ready() -> void:
	get_window().size = Vector2i(1120, 640)
	add_child(_camera) # starts the webcam if there is one
	for view: String in ["left", "right", "toward", "away"]:
		var photo := Image.load_from_file(PHOTOS + "santa_%s.jpg" % view)
		if photo:
			_photos.append(photo)
	add_child(_detect_http)
	add_child(_segment_http)
	_detect_http.request_completed.connect(_on_detected)
	_segment_http.request_completed.connect(_on_segmented)
	_build_ui()
	_matcher.fitted.connect(func(_index: int, target: String) -> void: print("TURN TO FIT: fits ", target))
	if "--demo" in OS.get_cmdline_user_args():
		_demo_step = 0


func _process(delta: float) -> void:
	_box_age += delta
	if _box_age > BOX_TIMEOUT:
		_box = Rect2i()
	_since_detect += delta
	if _since_detect >= DETECT_EVERY and not _detecting:
		_since_detect = 0.0
		_detect()
	_since_track += delta
	if _since_track >= TRACK_EVERY:
		_step(_since_track)
		_since_track = 0.0
	if _demo_step >= 0:
		_demo(delta)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1, KEY_2, KEY_3:
			_capture(TARGETS[key.keycode - KEY_1])
		KEY_C:
			_model = PackedFloat32Array()
			_shapes.clear()
			_rebuild_matcher()
		KEY_LEFT, KEY_RIGHT:
			if not _photos.is_empty():
				_photo_index = (_photo_index + (1 if key.keycode == KEY_RIGHT else -1) + _photos.size()) % _photos.size()
				_box = Rect2i() # a new picture: wait for YOLO again


# --- the camera -------------------------------------------------------------------------

## The newest picture: the webcam's, or the current photo when there's no camera.
func _grab() -> Image:
	var frame := _camera.frame()
	if frame:
		return frame.image
	return _photos[_photo_index] if not _photos.is_empty() else null


func _using_webcam() -> bool:
	return _camera.frame() != null


# --- Layer 2 on the laptop: YOLO finds the box, SAM outlines a capture -------------------

func _detect() -> void:
	var image := _grab()
	if image == null:
		return
	_detecting = true
	var size := image.get_size()
	var error := _detect_http.request_raw(SERVER + "/detect", PackedStringArray(["Content-Type: image/jpeg"]),
		HTTPClient.METHOD_POST, image.save_jpg_to_buffer(0.85))
	if error != OK:
		_detecting = false
	_detect_http.set_meta(&"size", size)


func _on_detected(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_detecting = false
	_server_ok = result == HTTPRequest.RESULT_SUCCESS and code == 200
	if not _server_ok:
		return
	var size: Vector2i = _detect_http.get_meta(&"size")
	var best := {}
	for found: Dictionary in JSON.parse_string(body.get_string_from_utf8()).detections:
		if found.label == "cup" and found.confidence > best.get("confidence", 0.3):
			best = found
	if best.is_empty():
		return
	var b: Array = best.box # 0..1 corners
	_box = Rect2i(Vector2i(roundi(b[0] * size.x), roundi(b[1] * size.y)),
		Vector2i(roundi((b[2] - b[0]) * size.x), roundi((b[3] - b[1]) * size.y)))
	_box_age = 0.0


func _capture(target: String) -> void:
	if _capturing != "":
		return
	var image := _grab()
	if image == null or _box.size == Vector2i.ZERO:
		_status.text = "No cup found yet: is the CV server running and the cup in view?"
		return
	_capturing = target
	_capture_image = image.duplicate()
	_capture_box = _box
	var query := "%s/segment?box=%d,%d,%d,%d" % [SERVER, _box.position.x, _box.position.y, _box.end.x, _box.end.y]
	_segment_http.request_raw(query, PackedStringArray(["Content-Type: image/jpeg"]), HTTPClient.METHOD_POST,
		_capture_image.save_jpg_to_buffer(0.9))
	_status.text = "Capturing \"%s\"… (SAM takes a few seconds the first time)" % target


func _on_segmented(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var target := _capturing
	_capturing = ""
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_status.text = "Capture failed (server reply %d)" % code
		return
	var mask := Image.new()
	if mask.load_png_from_buffer(body) != OK:
		_status.text = "Capture failed: the reply wasn't a picture"
		return
	if _model.is_empty(): # the first capture teaches the tracker this cup's colours
		_model = ShapeCV.learn_colours(_capture_image, mask, _capture_box)
	var shape := ShapeCV.target_from_mask(mask, _capture_box)
	if not shape.ok:
		_status.text = "Capture of \"%s\" found no cup outline" % target
		return
	_shapes[target] = shape.shape
	_rebuild_matcher()
	_rows[target].thumb.texture = ImageTexture.create_from_image(_shape_picture(shape.shape, PackedByteArray(), GOLD, 2))
	_status.text = "Captured \"%s\"." % target


func _rebuild_matcher() -> void:
	_matcher = FitMatcher.new()
	_matcher.fitted.connect(func(_index: int, target: String) -> void: print("TURN TO FIT: fits ", target))
	for target: String in TARGETS:
		if _shapes.has(target):
			_matcher.add_target(target, _shapes[target])
		else:
			_rows[target].thumb.texture = null


# --- Layer 1, every 0.2 s: track → match ---------------------------------------------------

func _step(dt: float) -> void:
	var image := _grab()
	if image == null:
		_status.text = "No camera and no photos found."
		return
	if not _using_webcam():
		_view.texture = ImageTexture.create_from_image(image)
	var live := {}
	if not _model.is_empty() and _box.size != Vector2i.ZERO:
		var start := Time.get_ticks_usec()
		live = ShapeCV.track(image, _box, _model)
		_track_ms = (Time.get_ticks_usec() - start) / 1000.0
	_last_live = live
	var fit := _matcher.update(live.shape if live.get("ok", false) else PackedByteArray(), dt)
	_show(fit, image.get_size())


func _show(fit: int, image_size: Vector2i) -> void:
	# the panel: the live shape filled, the target it's closest to as an outline
	var near := -1
	for i in _matcher.scores.size():
		if near < 0 or _matcher.scores[i] > _matcher.scores[near]:
			near = i
	var live_shape: PackedByteArray = _last_live.get("shape", PackedByteArray())
	var target: PackedByteArray = _matcher.targets[near] if near >= 0 else PackedByteArray()
	_panel.texture = ImageTexture.create_from_image(_shape_picture(target, live_shape, GREEN if fit >= 0 else GOLD, 1))
	for i in _matcher.names.size():
		var row: Dictionary = _rows[_matcher.names[i]]
		row.bar.value = _matcher.scores[i] * 100.0
		row.label.text = "%s  %.2f" % [_matcher.names[i], _matcher.scores[i]]
	if _capturing == "":
		if _model.is_empty():
			_status.text = "Show the cup, then press 1, 2 or 3 to capture a target."
		elif fit >= 0:
			_status.text = "FITS: %s ✓" % _matcher.names[fit]
		elif _matcher.candidate >= 0:
			_status.text = "Holding %s… %.1f s" % [_matcher.names[_matcher.candidate], _matcher.held]
		else:
			_status.text = "Turn the cup (or move) to match a target."
	_info.text = "%s · server %s · box %s · track %.1f ms" % [
		"webcam" if _using_webcam() else "photo %d/%d (← →)" % [_photo_index + 1, _photos.size()],
		"OK" if _server_ok else "NOT RUNNING: python3 tools/cv_server.py",
		"yes" if _box.size != Vector2i.ZERO else "none", _track_ms]
	_box_layer.set_meta(&"image_size", image_size)
	_box_layer.queue_redraw()


## A 64 × 48 shape picture, PANEL_SCALE× bigger: [param fill] in light grey, the contour
## of [param line] in [param colour] (thickness in shape pixels).
func _shape_picture(line: PackedByteArray, fill: PackedByteArray, colour: Color, thickness: int) -> Image:
	var w := ShapeCV.NORM_W
	var h := ShapeCV.NORM_H
	var picture := Image.create(w, h, false, Image.FORMAT_RGB8)
	picture.fill(Color(0.12, 0.12, 0.14))
	var edge := ShapeCV.outline(line, w, h, thickness) if not line.is_empty() else PackedByteArray()
	for i in w * h:
		if not fill.is_empty() and fill[i] == 1:
			picture.set_pixel(i % w, i / w, Color(0.8, 0.8, 0.8))
		if not edge.is_empty() and edge[i] == 1:
			picture.set_pixel(i % w, i / w, colour)
	picture.resize(w * PANEL_SCALE, h * PANEL_SCALE, Image.INTERPOLATE_NEAREST)
	return picture


# --- the window ---------------------------------------------------------------------------

func _build_ui() -> void:
	var columns := HBoxContainer.new()
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	add_child(columns)
	var left := VBoxContainer.new()
	columns.add_child(left)
	left.add_child(_heading("Camera (green box = YOLO's cup)"))
	_view.custom_minimum_size = Vector2(640, 480)
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	left.add_child(_view)
	if _camera.get_texture():
		_view.texture = _camera.get_texture() # the webcam, at full speed
	_box_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box_layer.draw.connect(_draw_box)
	_view.add_child(_box_layer)
	_info.add_theme_font_size_override(&"font_size", 13)
	left.add_child(_info)
	var right := VBoxContainer.new()
	columns.add_child(right)
	right.add_child(_heading("Shadow panel: live (grey) vs target (outline)"))
	_panel.custom_minimum_size = Vector2(ShapeCV.NORM_W, ShapeCV.NORM_H) * PANEL_SCALE
	_panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_panel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED # never stretch the shape
	right.add_child(_panel)
	_status.add_theme_font_size_override(&"font_size", 20)
	_status.custom_minimum_size.x = 420
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	right.add_child(_status)
	for i in TARGETS.size():
		var row := HBoxContainer.new()
		var thumb := TextureRect.new()
		thumb.custom_minimum_size = Vector2(ShapeCV.NORM_W, ShapeCV.NORM_H) * 1.25
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var label := Label.new()
		label.text = "%d · %s (not captured)" % [i + 1, TARGETS[i]]
		label.custom_minimum_size.x = 150
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(180, 20)
		bar.show_percentage = false
		row.add_child(thumb)
		row.add_child(label)
		row.add_child(bar)
		right.add_child(row)
		_rows[TARGETS[i]] = {thumb = thumb, bar = bar, label = label}
	var help := Label.new()
	help.text = "1 2 3 capture (handle left / right / toward you) · C clear · ← → photo"
	help.add_theme_font_size_override(&"font_size", 13)
	right.add_child(help)


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", 15)
	return label


func _draw_box() -> void:
	if _box.size == Vector2i.ZERO or not _box_layer.has_meta(&"image_size"):
		return
	var image_size: Vector2 = _box_layer.get_meta(&"image_size")
	var area := _box_layer.size
	var scale := minf(area.x / image_size.x, area.y / image_size.y) # the picture is centred, aspect kept
	var offset := (area - image_size * scale) * 0.5
	_box_layer.draw_rect(Rect2(offset + Vector2(_box.position) * scale, Vector2(_box.size) * scale), GREEN, false, 2.0)


# --- --demo: capture from the photos by itself, then check each photo (also a self-test) --

var _demo_wait := 0.0

func _demo(delta: float) -> void:
	_demo_wait += delta
	if _demo_wait < 2.0 or _capturing != "":
		return
	_demo_wait = 0.0
	var plan := [[0, "left"], [1, "right"], [2, "toward"]]
	if _demo_step < plan.size():
		if _photo_index != plan[_demo_step][0]:
			_photo_index = plan[_demo_step][0]
			_box = Rect2i()
			return
		if _box.size == Vector2i.ZERO:
			return
		_capture(plan[_demo_step][1])
		_demo_step += 1
		return
	var check := _demo_step - plan.size() # then show each photo and save a screenshot
	if check >= _photos.size():
		print("TURN TO FIT DEMO: done")
		get_tree().quit()
		return
	if _photo_index != check:
		_photo_index = check
		_box = Rect2i()
		return
	var shot := get_viewport().get_texture().get_image()
	shot.save_png("user://turn_to_fit_demo_%d.png" % check)
	print("TURN TO FIT DEMO: photo %d → %s" % [check, _status.text])
	_demo_step += 1
