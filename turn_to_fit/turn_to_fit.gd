class_name TurnToFit
extends Node3D
## The Turn to fit scene (Nov 15): the child turns their REAL cup until its shadow fits a card.
## Design and reasons: claude/CV_TURN_TO_FIT_GAME.md (Project doc). The rules are FitGame
## (modules/cv/fit_game.gd); the camera side is FitTracker (modules/cv/fit_tracker.gd), the same
## code as the laptop lab (tools/cv_lab/turn_to_fit_lab.gd).
##
## In the room, on the table in front of the child (this node stands there, facing the child):
##   * the shadow window: a framed screen showing the card (gold outline) and, as the help allows,
##     the live shadow of the real cup (grey); it turns green and hops on a fit
##   * Onion beside it, watching; it bobs on a fit
##   * a brass "It fits!" button, only in blind rounds ("real cup only")
##   * in "Which is mine?" rounds, the cards themselves, to point at and pinch
##   * the setup board on the left, for the adult: capture the targets, save them, start rounds, change the help
##
## Setup comes first, step by step (the words above the window say what to do next, and the board marks
## the next button with ▶): 1 cup in view, 2 capture handle left and right (toward you is optional),
## 3 save. A saved setup belongs to the player's save (Profile) and comes back by itself next time.
## Everything is pressed by pointing and pinching (a click on the laptop) or by a fingertip.
##
## The camera: the Quest's on a headset (PassthroughReality); on a laptop, its webcam.
## The CV server (YOLO + SAM) runs on the laptop: python3 tools/cv_server.py
## On a headset, give its address:  -- --cv-server=http://LAPTOP_IP:8765  (not yet tried).

const TARGETS := ["left", "right", "toward"]
const TITLES := {left = "handle left", right = "handle right", toward = "handle toward you"}
const GOLD := Color(0.95, 0.75, 0.2)
const GREEN := Color(0.35, 0.85, 0.45)
const BRASS := Color(0.78, 0.62, 0.28)
const BOARD := Color(0.22, 0.24, 0.3)
## Seconds a round's answer stays up before the next round starts.
const REVEAL := 2.5
## Seconds a short note ("hold still…") replaces the round's line.
const NOTE_TIME := 1.8

## The shadow window: its size, how far ahead of the eyes it stands and how high its centre is
## above the table. Its bottom stays well above the cup, so it never covers the real cup.
const WINDOW := Vector2(0.36, 0.27)
const AHEAD := 0.62
const WINDOW_HEIGHT := 0.30

## Onion's lines (SCRIPT.md owns dialogue: the story chat writes them, Megan approves, they get
## baked). Empty = Onion stays quiet and only the window's words show.
const LINES := {start = "", fit = "", miss = "", match = ""}
## The saved setup, in the player's save folder (Profile.path).
const SAVE_FILE := "turn_to_fit_cards.dat"
const SAVE_VERSION := 1

## Tests: () -> Image, instead of a camera.
var frame_source := Callable()
var tracker := FitTracker.new()
var matcher := FitMatcher.new()
var game := FitGame.new(matcher)
## target name → normalised shape
var shapes := {}
## "" = setup (the adult captures), "turn" or "pick" = rounds are playing.
var session := ""
## The last round's record, while it's revealed.
var result := {}

var _reveal := 0.0
var _note := ""
var _note_left := 0.0
var _camera: QuestCamera
var _onion: Onion
var _window: MeshInstance3D
var _window_material := StandardMaterial3D.new()
var _words: Label3D
var _info: Label3D
var _fits: EntryButton
var _cards: Array[MeshInstance3D] = []
var _board := {}                       # button id → EntryButton
var _thumbs := {}                      # target name → card picture
var _saved := false                    # the cards in use are the saved ones


func run() -> void:
	App.reality.apply_view(App.session.base_view)
	if not App.reality.is_settled:
		await App.reality.settled
	_place()
	_build()
	if not frame_source.is_valid() and App.reality.kind() != "passthrough":
		_camera = QuestCamera.new() # a laptop: its webcam (QuestCamera falls back to it)
		add_child(_camera)
	tracker.source = _frame
	tracker.stepped.connect(_step)
	tracker.captured.connect(_on_captured)
	tracker.capture_failed.connect(func(_target: String, why: String) -> void: _say_note(why))
	add_child(tracker)
	_rebuild_matcher()
	_load_setup()
	SceneMarker.show_text("Turn to fit")
	Events.selected.connect(_on_selected)
	Events.touched.connect(_on_touched)
	Events.report(&"turn_to_fit", {event = &"start"})
	if LINES.start != "":
		Onion.line(LINES.start, self)


## The newest camera picture: the headset's camera, the laptop's webcam, or the tests' photos.
func _frame() -> Image:
	if frame_source.is_valid():
		return frame_source.call()
	var frame: CameraFrame = App.reality.camera_frame() if App.reality.kind() == "passthrough" \
		else (_camera.frame() if _camera else null)
	return frame.image if frame else null


func _process(delta: float) -> void:
	_note_left -= delta
	if _reveal > 0.0:
		_reveal -= delta
		if _reveal <= 0.0 and session != "":
			_next_round()


# --- what the adult and the child press --------------------------------------------------------

func _on_selected(_hand: StringName, target: Target, _origin: Vector3, _direction: Vector3) -> void:
	_press(target.id)


## A fingertip presses only what the child presses (the button and the cards), not the board.
func _on_touched(_hand: StringName, target: Target) -> void:
	if target.id == &"fit_fits" or String(target.id).begins_with("fit_card_"):
		_press(target.id)


func _press(id: StringName) -> void:
	var key := String(id)
	if key.begins_with("fit_capture_") and session == "":
		var target := key.trim_prefix("fit_capture_")
		if tracker.capture(target):
			_say_note("Capturing %s… (the first one takes a few seconds)" % TITLES[target])
	elif id == &"fit_clear" and session == "":
		shapes.clear()
		_thumbs.clear()
		tracker.clear()
		_saved = false
		_rebuild_matcher()
		_say_note("Cleared. Start again from step 1 (a saved setup stays until you save a new one).")
	elif id == &"fit_save" and session == "":
		_save_setup()
	elif id == &"fit_play_turn":
		_begin("turn")
	elif id == &"fit_play_pick":
		_begin("pick")
	elif id == &"fit_help":
		game.set_help((game.help + 1) % FitGame.HELP_NAMES.size())
		_refresh_board()
	elif id == &"fit_stop":
		_stop()
	elif id == &"fit_fits" and session == "turn" and game.playing:
		game.commit()
	elif key.begins_with("fit_card_") and session == "pick" and game.playing:
		if game.pick(int(key.trim_prefix("fit_card_"))).get("unclear", false):
			_say_note("Hold the cup still, where the camera can see it, then pick again.")


func _begin(kind: String) -> void:
	if matcher.targets.size() < 2:
		_say_note("Capture at least 2 targets first.")
		return
	session = kind
	_next_round()


func _next_round() -> void:
	result = {}
	_reveal = 0.0
	game.start(FitGame.Mode.TURN if session == "turn" else FitGame.Mode.PICK)
	if _onion:
		_onion.attend(_window)
	_refresh_board()


func _stop() -> void:
	session = ""
	game.playing = false
	result = {}
	_reveal = 0.0
	if _onion:
		_onion.attend(null)
	_refresh_board()


func _on_captured(target: String, shape: PackedByteArray) -> void:
	_add_card(target, shape)
	_saved = false
	_rebuild_matcher()
	_say_note("Captured %s." % TITLES[target])


func _add_card(target: String, shape: PackedByteArray) -> void:
	shapes[target] = shape
	_thumbs[target] = ImageTexture.create_from_image(FitTracker.picture(shape, PackedByteArray(), GOLD, 2))


# --- a saved setup (the cards and the cup's colours), per player --------------------------------

## Keeps the cards and the colours in the player's save, for next time.
func _save_setup() -> void:
	if shapes.size() < 2:
		_say_note("Capture at least 2 cards before saving.")
		return
	DirAccess.make_dir_recursive_absolute(Profile.path())
	var file := FileAccess.open(Profile.path(SAVE_FILE), FileAccess.WRITE)
	if file == null:
		_say_note("Couldn't save the setup.")
		return
	file.store_var({version = SAVE_VERSION, shapes = shapes, model = tracker.model,
		saved = Time.get_datetime_string_from_system()})
	file.close()
	_saved = true
	Events.report(&"turn_to_fit", {event = &"setup_saved", cards = shapes.keys()})
	_say_note("Setup saved for this player: it comes back next time.")
	_refresh_board()


## Loads the player's saved setup, if there is one.
func _load_setup() -> void:
	var file := FileAccess.open(Profile.path(SAVE_FILE), FileAccess.READ)
	if file == null:
		return
	var data: Variant = file.get_var()
	file.close()
	if not data is Dictionary or data.get("version", 0) != SAVE_VERSION:
		return
	for target: String in data.shapes:
		if target in TARGETS:
			_add_card(target, data.shapes[target])
	tracker.model = data.model
	_saved = true
	_rebuild_matcher()
	Events.report(&"turn_to_fit", {event = &"setup_loaded", cards = shapes.keys()})


func _rebuild_matcher() -> void:
	matcher = FitMatcher.new()
	for target: String in TARGETS:
		if shapes.has(target):
			matcher.add_target(target, shapes[target])
	var help := game.help
	game = FitGame.new(matcher)
	game.set_help(help)
	game.finished.connect(_on_round)
	_refresh_board()


func _on_round(record: Dictionary) -> void:
	result = record
	_reveal = REVEAL
	Events.report(&"turn_to_fit_round", record)
	var success: bool = record.result in ["fit", "match"]
	if success and _onion:
		_onion.cheer()
	if success: # the shadow comes back to life: a little hop of the window
		var hop := create_tween()
		hop.tween_property(_window, "scale", Vector3.ONE * 1.06, 0.15)
		hop.tween_property(_window, "scale", Vector3.ONE, 0.25)
	var line: String = LINES.get(record.result if record.result != "timeout" else "miss", "")
	if line != "":
		Onion.line(line, self)
	_refresh_board()


func _say_note(text: String) -> void:
	_note = text
	_note_left = NOTE_TIME
	if _words:
		_words.text = text


# --- every FitTracker.TRACK_EVERY: match, play, draw ----------------------------------------------

func _step(shape: PackedByteArray, dt: float) -> void:
	var fit := matcher.update(shape, dt)
	game.update(dt)
	_draw(fit, shape)


func _draw(fit: int, live: PackedByteArray) -> void:
	var line := PackedByteArray()
	var fill := PackedByteArray()
	var colour := GOLD
	var revealing := not result.is_empty()
	if session == "":   # setup: the live shadow and the target it's closest to
		fill = live
		var near := -1
		for i in matcher.scores.size():
			if near < 0 or matcher.scores[i] > matcher.scores[near]:
				near = i
		if near >= 0:
			line = matcher.targets[near]
		colour = GREEN if fit >= 0 else GOLD
	elif session == "turn":
		line = matcher.targets[game.card]
		if game.shows_live() or revealing:
			fill = live
		if revealing and result.result == "fit":
			colour = GREEN
	elif revealing:     # Which is mine?: the answer, once picked
		line = matcher.targets[game.card]
		fill = live
		colour = GREEN if result.result == "match" else GOLD
	var picture := FitTracker.picture(line, fill, colour, 2)
	if _window_material.albedo_texture is ImageTexture and _window_material.albedo_texture.get_size() == Vector2(picture.get_size()):
		(_window_material.albedo_texture as ImageTexture).update(picture)
	else:
		_window_material.albedo_texture = ImageTexture.create_from_image(picture)
	_window.visible = not (session == "pick" and not revealing)
	_words.text = _note if _note_left > 0.0 else _line()
	_info.text = "camera: %s · server %s · cup %s\ntargets: %s · help: %s" % [
		"headset" if App.reality.kind() == "passthrough" else ("webcam" if _camera and _camera.frame() else "none"),
		"OK" if tracker.server_ok or not tracker.use_server else "NOT RUNNING",
		"seen" if tracker.box.size != Vector2i.ZERO else "not seen",
		", ".join(PackedStringArray(matcher.names)) if not matcher.names.is_empty() else "none yet",
		FitGame.HELP_NAMES[game.help]]


## The words under the window (placeholders until Onion's lines exist).
func _line() -> String:
	if session == "":
		return _setup_line()
	if not result.is_empty():
		match result.result:
			"fit":
				return "It fits! The shadow is back."
			"match":
				return "Yes, that's the shadow it makes."
			"timeout":
				return "Let's try a different one."
		return "Not this one. Grey is the shadow the cup made." if session == "turn" \
			else "Grey is the shadow it was making."
	if session == "pick":
		return "Hold the cup still. Which shadow is it making?"
	if game.help == FitGame.Help.BLIND:
		return "Look at the cup. Press \"It fits!\" when it makes this shadow."
	return "Turn the cup until its shadow fits the gold outline."


## Setup, one step at a time (the board marks the matching button with ▶).
func _setup_line() -> String:
	var next := _next_capture()
	if next != "" and tracker.box.size == Vector2i.ZERO:
		return "Setup 1/3: hold the cup where the camera can see it, about an arm's length away."
	if next != "":
		return "Setup 2/3: turn the cup so its handle points %s, hold it still, and press \"Capture: %s\"." % [
			"to your left" if next == "left" else "to your right", TITLES[next]]
	if not _saved:
		return "Setup 3/3: press \"Save setup\" to keep these cards for next time. (Handle toward you is optional.)"
	return "Ready: press \"Play: turn to fit\" or \"Play: which is mine?\"."


## The next card setup asks for: handle left, then handle right; "" once both are there.
func _next_capture() -> String:
	for target: String in ["left", "right"]:
		if not shapes.has(target):
			return target
	return ""


func _refresh_board() -> void:
	if _fits == null:
		return
	_fits.visible = session == "turn" and game.playing and game.help == FitGame.Help.BLIND
	_set_target_enabled(_fits, _fits.visible)
	for i in _cards.size():
		var shown := session == "pick" and game.playing and i < game.cards.size()
		_cards[i].visible = shown
		_set_target_enabled(_cards[i], shown)
		if shown:
			(_cards[i].material_override as StandardMaterial3D).albedo_texture = _thumbs[matcher.names[game.cards[i]]]
	(_board[&"fit_help"] as EntryButton).set_text("Help: %s" % FitGame.HELP_NAMES[game.help])
	var next := _next_capture() if session == "" else ""
	for target: String in TARGETS:
		var button: EntryButton = _board[StringName("fit_capture_" + target)]
		button.set_text(("✓ " if shapes.has(target) else ("▶ Capture: " if target == next else "Capture: ")) + TITLES[target])
	var save_text := "✓ Setup saved" if _saved else ("▶ Save setup" if session == "" and next == "" else "Save setup")
	(_board[&"fit_save"] as EntryButton).set_text(save_text)
	var ready := session == "" and _saved
	(_board[&"fit_play_turn"] as EntryButton).set_text(("▶ " if ready else "") + "Play: turn to fit")


## Hidden things can't be pressed: their hit boxes go too.
func _set_target_enabled(node: Node, on: bool) -> void:
	for target: Node in node.find_children("*", "Area3D", true, false):
		for shape: Node in target.find_children("*", "CollisionShape3D", false, false):
			(shape as CollisionShape3D).disabled = not on


# --- building it in the room -------------------------------------------------------------------

## Stands on the table, AHEAD in front of the eyes, facing the child.
func _place() -> void:
	var eye := App.head().global_transform
	var forward := Vector3(-eye.basis.z.x, 0.0, -eye.basis.z.z).normalized()
	var table_y := App.reality.work_surface().transform.origin.y
	var spot := Vector3(eye.origin.x, table_y, eye.origin.z) + forward * AHEAD
	global_transform = Transform3D(Basis.looking_at(forward), spot)


func _build() -> void:
	var centre := Vector3(0, WINDOW_HEIGHT, 0)
	# The shadow window: a wooden frame and the picture.
	var frame := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(WINDOW.x + 0.04, WINDOW.y + 0.04, 0.02)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.48, 0.32, 0.19)
	box.material = wood
	frame.mesh = box
	frame.position = centre + Vector3(0, 0, -0.012)
	add_child(frame)
	_window = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = WINDOW
	_window.mesh = quad
	_window_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_window_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_window.material_override = _window_material
	_window.position = centre
	add_child(_window)
	_words = _label("", 30, centre + Vector3(0, WINDOW.y * 0.5 + 0.05, 0))
	_words.width = 900
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD
	# "Which is mine?": the cards, in the window, to point at.
	for i in TARGETS.size():
		var card := MeshInstance3D.new()
		var face := QuadMesh.new()
		face.size = Vector2(0.112, 0.084)
		card.mesh = face
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		card.material_override = material
		card.position = centre + Vector3((i - 1) * 0.12, 0, 0.004)
		var target := UITarget.new()
		target.id = StringName("fit_card_%d" % i)
		target.name = String(target.id)
		var shape := CollisionShape3D.new()
		var hit := BoxShape3D.new()
		hit.size = Vector3(0.116, 0.1, 0.03)
		shape.shape = hit
		target.add_child(shape)
		card.add_child(target)
		var number := _label(str(i + 1), 40, Vector3(0, -0.062, 0.002), card)
		number.modulate = GOLD
		card.visible = false
		add_child(card)
		_cards.append(card)
	# The brass "It fits!" button, to the right of the window's foot, a little nearer than the window.
	_fits = EntryButton.new()
	add_child(_fits)
	_fits.setup("It fits!", &"fit_fits", BRASS, Vector2(0.16, 0.07), 0.02)
	_fits.position = Vector3(WINDOW.x * 0.5 + 0.1, 0.16, 0.08)
	_fits.rotation.y = -0.3
	# Onion, to the right of the window, watching (the board is on the left).
	_onion = Onion.new()
	add_child(_onion)
	_onion.position = centre + Vector3(WINDOW.x * 0.5 + 0.1, 0.06, 0.05)
	# The adult's setup board, to the left.
	var board := Node3D.new()
	board.name = "SetupBoard"
	add_child(board)
	board.position = Vector3(-0.44, 0.38, 0.16)
	board.rotation.y = 0.6
	var rows := [
		[&"fit_capture_left", "Capture: handle left"], [&"fit_capture_right", "Capture: handle right"],
		[&"fit_capture_toward", "Capture: handle toward you"], [&"fit_save", "Save setup"], [&"fit_clear", "Clear targets"],
		[&"fit_play_turn", "Play: turn to fit"], [&"fit_play_pick", "Play: which is mine?"],
		[&"fit_help", "Help: mirror"], [&"fit_stop", "Stop"]]
	for i in rows.size():
		var button := EntryButton.new()
		board.add_child(button)
		button.setup(rows[i][1], rows[i][0], BOARD, Vector2(0.2, 0.034), 0.004)
		button.position = Vector3(0, 0.12 - i * 0.04, 0)
		_board[rows[i][0]] = button
	_info = _label("", 18, Vector3(0, 0.165, 0), board)
	_refresh_board()
	_draw(-1, PackedByteArray())


func _label(text: String, size: int, at: Vector3, parent: Node = self) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.0006
	label.outline_size = 6
	label.position = at
	parent.add_child(label)
	return label
