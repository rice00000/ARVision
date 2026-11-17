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
## Setup keys: 1 2 3 = capture target (handle left / right / toward you) · C = clear · ← → = photo
## Play keys (after 2+ captures; the game rules are FitGame, modules/cv/fit_game.gd):
##   G = Turn to fit rounds · P = "Which is mine?" rounds (the check-in) · Esc = back to setup
##   H = change the help (mirror → glimmer → blind) · Space = "it fits!" (blind rounds)
##   1 2 3 = pick a card (Which is mine?)
## While playing, the score bars are hidden: they would give the answer away.
##
## The loop (see claude/CV_TURN_TO_FIT_BUILD.md):
##   every 0.5 s  the server's YOLO finds the cup's box            (Layer 2, laptop)
##   on 1/2/3     the server's SAM outlines the cup → a target;    (Layer 2, laptop)
##                the first capture also teaches the cup's colours
##   every 0.2 s  ShapeCV.track finds the cup by colour in the box (Layer 1, here)
##                → FitMatcher: fits once it holds 0.5 s → FitGame: the round's rules
## The camera side (box, captures, tracking) is FitTracker (modules/cv/fit_tracker.gd), shared with the game scene.

const TARGETS := ["left", "right", "toward"]
const PHOTOS := "res://tests/data/turn_to_fit/"
const PANEL_SCALE := FitTracker.PICTURE_SCALE
const GOLD := Color(0.95, 0.75, 0.2)
const GREEN := Color(0.35, 0.85, 0.45)
## Seconds a round's answer stays up before the next round starts.
const REVEAL := 2.5
## Seconds a short note ("hold still…") replaces the round's line.
const NOTE_TIME := 1.5

var _camera := QuestCamera.new()
var _photos: Array[Image] = []
var _photo_index := 0
var _cv := FitTracker.new()            # camera → cup box → captures → live shape (shared with the game)
var _shapes := {}                      # target name → normalised shape
var _matcher := FitMatcher.new()
var _game := FitGame.new(_matcher)
var _session := ""                     # "" = setup (capture), "turn" or "pick" = playing rounds
var _result := {}                      # the last round's record, while it's revealed
var _reveal := 0.0                     # seconds left of the reveal
var _note := ""
var _note_left := 0.0
var _thumbs := {}                      # target name → its card picture
var _demo_step := -1

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
	_cv.source = _grab
	_cv.stepped.connect(_step)
	_cv.captured.connect(_on_captured)
	_cv.capture_failed.connect(func(_target: String, why: String) -> void: _status.text = why)
	add_child(_cv)
	_build_ui()
	_matcher.fitted.connect(func(_index: int, target: String) -> void: print("TURN TO FIT: fits ", target))
	_game.finished.connect(_on_round)
	if "--demo" in OS.get_cmdline_user_args():
		_demo_step = 0


func _process(delta: float) -> void:
	_note_left -= delta
	if _reveal > 0.0:
		_reveal -= delta
		if _reveal <= 0.0 and _session != "":
			_next_round()
	if _demo_step >= 0:
		_demo(delta)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1, KEY_2, KEY_3:
			if _session == "pick":
				_pick(key.keycode - KEY_1)
			elif _session == "":
				_capture(TARGETS[key.keycode - KEY_1])
		KEY_C:
			if _session == "":
				_cv.clear()
				_shapes.clear()
				_thumbs.clear()
				_rebuild_matcher()
		KEY_G:
			_begin("turn")
		KEY_P:
			_begin("pick")
		KEY_H:
			_game.set_help((_game.help + 1) % FitGame.HELP_NAMES.size())
			_say("Help: %s" % FitGame.HELP_NAMES[_game.help])
		KEY_SPACE:
			if _session == "turn" and _game.playing and _game.commit().is_empty():
				_say("Space is for blind rounds. Now: turn until it fits (H changes the help).")
		KEY_ESCAPE:
			_stop()
		KEY_LEFT, KEY_RIGHT:
			if not _photos.is_empty():
				_photo_index = (_photo_index + (1 if key.keycode == KEY_RIGHT else -1) + _photos.size()) % _photos.size()
				_cv.box = Rect2i() # a new picture: wait for YOLO again


# --- the camera -------------------------------------------------------------------------

## The newest picture: the webcam's, or the current photo when there's no camera.
func _grab() -> Image:
	var frame := _camera.frame()
	if frame:
		return frame.image
	return _photos[_photo_index] if not _photos.is_empty() else null


func _using_webcam() -> bool:
	return _camera.frame() != null


# --- Layer 2 on the laptop (FitTracker): YOLO finds the box, SAM outlines a capture ---------

func _capture(target: String) -> void:
	if _cv.capture(target):
		_status.text = "Capturing \"%s\"… (SAM takes a few seconds the first time)" % target


func _on_captured(target: String, shape: PackedByteArray) -> void:
	_shapes[target] = shape
	_thumbs[target] = ImageTexture.create_from_image(FitTracker.picture(shape, PackedByteArray(), GOLD, 2))
	_rebuild_matcher()
	_status.text = "Captured \"%s\"." % target


func _rebuild_matcher() -> void:
	_matcher = FitMatcher.new()
	_matcher.fitted.connect(func(_index: int, target: String) -> void: print("TURN TO FIT: fits ", target))
	for target: String in TARGETS:
		if _shapes.has(target):
			_matcher.add_target(target, _shapes[target])
	var help := _game.help
	_game = FitGame.new(_matcher)
	_game.set_help(help)
	_game.finished.connect(_on_round)
	_show_rows()


# --- the game: rounds of FitGame -------------------------------------------------------------

func _begin(kind: String) -> void:
	if _matcher.targets.size() < 2:
		_say("Capture at least 2 targets first (1, 2, 3).")
		return
	_session = kind
	_next_round()


func _next_round() -> void:
	_result = {}
	_reveal = 0.0
	_game.start(FitGame.Mode.TURN if _session == "turn" else FitGame.Mode.PICK)
	_show_rows()


func _stop() -> void:
	_session = ""
	_game.playing = false
	_result = {}
	_reveal = 0.0
	_show_rows()


func _pick(slot: int) -> void:
	if not _game.playing:
		return
	if _game.pick(slot).get("unclear", false):
		_say("The camera can't tell yet: hold the cup still, in view, and pick again.")


func _on_round(record: Dictionary) -> void:
	_result = record
	_reveal = REVEAL
	print("TURN TO FIT ROUND: ", JSON.stringify(record))
	if record.result in ["fit", "match"]: # the shadow comes back to life: a little hop
		_panel.pivot_offset = _panel.size * 0.5
		var hop := create_tween()
		hop.tween_property(_panel, "scale", Vector2(1.08, 1.08), 0.15)
		hop.tween_property(_panel, "scale", Vector2.ONE, 0.25)


func _say(text: String) -> void:
	_note = text
	_note_left = NOTE_TIME


## The round's line under the panel.
func _game_line() -> String:
	if _note_left > 0.0:
		return _note
	if not _result.is_empty():
		var line: String
		match _result.result:
			"fit":
				line = "It fits! The shadow is back."
			"match":
				line = "Yes, that's the shadow it makes."
			"timeout":
				line = "Let's try a different one."
			_:
				line = "Not this one. Grey is the shadow your cup made." if _session == "turn" \
					else "Grey is the shadow it was making (gold: that card)."
		if _result.help != "none" and _result.next_help != _result.help:
			line += "  Help now: %s." % _result.next_help
		return line
	if _session == "pick":
		return "Hold the cup still. Which shadow is it making? Press %s." % ("1 or 2" if _game.cards.size() == 2 else "1, 2 or 3")
	if _game.help == FitGame.Help.BLIND:
		return "Look at the real cup. Press Space when you think it makes this shadow."
	return "Turn the cup until its shadow fits the gold outline."


# --- Layer 1, every 0.2 s: track → match ---------------------------------------------------

func _step(shape: PackedByteArray, dt: float) -> void:
	var image := _grab()
	if image == null:
		_status.text = "No camera and no photos found."
		return
	if not _using_webcam():
		_view.texture = ImageTexture.create_from_image(image)
	var fit := _matcher.update(shape, dt)
	_game.update(dt)
	_show(fit, image.get_size())


func _show(fit: int, image_size: Vector2i) -> void:
	_draw_info(image_size)
	if _session != "":
		_show_game()
		return
	# setup: the live shape filled, the target it's closest to as an outline
	var near := -1
	for i in _matcher.scores.size():
		if near < 0 or _matcher.scores[i] > _matcher.scores[near]:
			near = i
	var live_shape: PackedByteArray = _cv.live.get("shape", PackedByteArray())
	var target: PackedByteArray = _matcher.targets[near] if near >= 0 else PackedByteArray()
	_panel.texture = ImageTexture.create_from_image(FitTracker.picture(target, live_shape, GREEN if fit >= 0 else GOLD, 1))
	for i in _matcher.names.size():
		var row: Dictionary = _rows[_matcher.names[i]]
		row.bar.value = _matcher.scores[i] * 100.0
		row.label.text = "%s  %.2f" % [_matcher.names[i], _matcher.scores[i]]
	if _cv.capturing == "":
		if _cv.model.is_empty():
			_status.text = "Show the cup, then press 1, 2 or 3 to capture a target."
		elif fit >= 0:
			_status.text = "FITS: %s ✓" % _matcher.names[fit]
		elif _matcher.candidate >= 0:
			_status.text = "Holding %s… %.1f s" % [_matcher.names[_matcher.candidate], _matcher.held]
		elif _matcher.targets.size() >= 2:
			_status.text = "Turn the cup (or move) to match a target. Ready to play: G or P."
		else:
			_status.text = "Turn the cup (or move) to match a target."
	if _note_left > 0.0:
		_status.text = _note


## Playing: the card, and the live shadow only when the help (or the reveal) allows it.
func _show_game() -> void:
	var live: PackedByteArray = _cv.live.get("shape", PackedByteArray())
	var revealing := not _result.is_empty()
	var line := PackedByteArray()
	var fill := PackedByteArray()
	var colour := GOLD
	if _session == "turn":
		line = _matcher.targets[_game.card]
		if _game.shows_live() or revealing:
			fill = live
		if revealing and _result.result == "fit":
			colour = GREEN
	elif revealing: # Which is mine?: the cards are in the rows; the answer shows once picked
		line = _matcher.targets[_game.card]
		fill = live
		colour = GREEN if _result.result == "match" else GOLD
	_panel.texture = ImageTexture.create_from_image(FitTracker.picture(line, fill, colour, 2))
	_status.text = _game_line()


func _draw_info(image_size: Vector2i) -> void:
	var playing := "setup (help: %s)" % FitGame.HELP_NAMES[_game.help]
	if _session == "turn":
		playing = "turn to fit · help %s · round %d" % [FitGame.HELP_NAMES[_game.help], _game.rounds.size() + 1]
	elif _session == "pick":
		playing = "which is mine? · round %d" % (_game.rounds.size() + 1)
	_info.text = "%s · server %s · box %s · track %.1f ms\n%s" % [
		"webcam" if _using_webcam() else "photo %d/%d (← →)" % [_photo_index + 1, _photos.size()],
		"OK" if _cv.server_ok else "NOT RUNNING: python3 tools/cv_server.py",
		"yes" if _cv.box.size != Vector2i.ZERO else "none", _cv.track_ms, playing]
	_box_layer.set_meta(&"image_size", image_size)
	_box_layer.queue_redraw()


## The rows under the panel: targets and score bars in setup; numbered cards in
## "Which is mine?"; hidden in Turn to fit (the panel shows the card).
func _show_rows() -> void:
	for i in TARGETS.size():
		var row: Dictionary = _rows[TARGETS[i]]
		row.bar.visible = _session == ""
		if _session == "pick":
			row.box.visible = i < _game.cards.size()
			if row.box.visible:
				row.thumb.texture = _thumbs[_matcher.names[_game.cards[i]]]
				row.label.text = "  %d" % (i + 1)
		else:
			row.box.visible = _session == ""
			row.thumb.texture = _thumbs.get(TARGETS[i])
			if not _shapes.has(TARGETS[i]):
				row.label.text = "%d · %s (not captured)" % [i + 1, TARGETS[i]]
				row.bar.value = 0.0


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
		thumb.custom_minimum_size = Vector2(ShapeCV.NORM_W, ShapeCV.NORM_H) * 1.5
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
		_rows[TARGETS[i]] = {box = row, thumb = thumb, bar = bar, label = label}
	var help := Label.new()
	help.text = "Setup: 1 2 3 capture (handle left / right / toward you) · C clear · ← → photo\n" \
		+ "Play: G turn to fit · P which is mine? · H help · Space it fits! · 1 2 3 pick · Esc stop"
	help.add_theme_font_size_override(&"font_size", 13)
	help.custom_minimum_size.x = 420
	help.autowrap_mode = TextServer.AUTOWRAP_WORD
	right.add_child(help)


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", 15)
	return label


func _draw_box() -> void:
	if _cv.box.size == Vector2i.ZERO or not _box_layer.has_meta(&"image_size"):
		return
	var image_size: Vector2 = _box_layer.get_meta(&"image_size")
	var area := _box_layer.size
	var scale := minf(area.x / image_size.x, area.y / image_size.y) # the picture is centred, aspect kept
	var offset := (area - image_size * scale) * 0.5
	_box_layer.draw_rect(Rect2(offset + Vector2(_cv.box.position) * scale, Vector2(_cv.box.size) * scale), GREEN, false, 2.0)


# --- --demo: capture from the photos by itself, then check each photo (also a self-test) --

var _demo_wait := 0.0

func _demo(delta: float) -> void:
	_demo_wait += delta
	if _demo_wait < 2.0 or _cv.capturing != "":
		return
	_demo_wait = 0.0
	var plan := [[0, "left"], [1, "right"], [2, "toward"]]
	if _demo_step < plan.size():
		if _photo_index != plan[_demo_step][0]:
			_photo_index = plan[_demo_step][0]
			_cv.box = Rect2i()
			return
		if _cv.box.size == Vector2i.ZERO:
			return
		_capture(plan[_demo_step][1])
		_demo_step += 1
		return
	var check := _demo_step - plan.size() # then show each photo and save a screenshot
	if check >= _photos.size():
		_demo_play(check - _photos.size())
		_demo_step += 1
		return
	if _photo_index != check:
		_photo_index = check
		_cv.box = Rect2i()
		return
	var shot := get_viewport().get_texture().get_image()
	shot.save_png("user://turn_to_fit_demo_%d.png" % check)
	print("TURN TO FIT DEMO: photo %d → %s" % [check, _status.text])
	_demo_step += 1


## Then play: one "Which is mine?" round on the handle-right photo, and one blind
## Turn to fit round on the card's own photo (the targets are in the photos' order).
func _demo_play(step: int) -> void:
	match step:
		0:
			_begin("pick")
			_photo_index = 1
			_cv.box = Rect2i()
		1:
			var slot := _game.cards.find(_matcher.names.find("right"))
			print("TURN TO FIT DEMO: which is mine (right photo, card %d) → %s" % [slot + 1, _game.pick(slot)])
		2:
			_stop()
			_game.set_help(FitGame.Help.BLIND)
			_begin("turn")
			_photo_index = TARGETS.find(_matcher.names[_game.card])
			_cv.box = Rect2i()
		3:
			print("TURN TO FIT DEMO: blind turn to fit (card %s, its photo) → %s" % [_matcher.names[_game.card], _game.commit()])
		4:
			get_viewport().get_texture().get_image().save_png("user://turn_to_fit_demo_game.png")
			print("TURN TO FIT DEMO: done")
			get_tree().quit()
