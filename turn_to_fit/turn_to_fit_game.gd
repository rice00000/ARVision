class_name TurnToFitGame
extends Node3D
## One go of Turn to fit in the workshop hub: what the child sees and hears (Megan, Nov 18;
## `claude/SCENE_REVIEW_DECISIONS.md` → "Turn to fit", beat by beat; lines in `claude/SCRIPT.md` → "Turn to fit").
## The rules are FitGo / FitGame / FitMatcher (modules/cv); the camera side is FitTracker. The grown-up's setup
## (capturing the cards) happens before, outside the child's view (Staff tools); this node only plays.
##
## On the table, 62 cm ahead of the child's eyes, facing them (Megan: today's spot): the shadow window (a
## framed screen; its bottom stays above the real cup, which virtual things would otherwise cover), and to the
## right of the cup, in easy reach, the round ✓ button (blind rounds only). For the check-in, a wider black
## board with the cards, big and well spaced.
##
## The go (beats 1–6):
## 1. The window appears in place. If the cup isn't in view: "Hold the cup up, where I can see it." (once).
##    First go only (per child): a free look (the live grey shadow only, no card, no green) for ~5 s or until
##    the cup has turned a bit; then "This shadow is looking for its cup." / "Turn the cup slowly, until it
##    fits." and the first card.
## 2–4. Five turn rounds on the help ladder (Mirror → Glimmer → Blind, FitGame). A fit: the card goes green,
##    the shadow hops, the shared "found its place" ring and click; no line. A miss or time-out: quiet. After
##    each round the answer stays up for REVEAL seconds. The first blind round: "Now just look at the cup.
##    Press the button when it fits."
## 5. The check-in: "Hold it still. Which shadow is it making?"; the child points at a card; the answer shows.
## 6. The ending line (4–5 fits: "There. Everything's found its place.", else "We can come back to these."),
##    the window goes in place (≤ 0.5 s). The first full go earns magic stones (Wei's first-level reward).
## Leaving early (the hub's exit token → [method leave]): the round is logged as interrupted, "We can come back
## to these.", the window goes.

signal _ended(outcome: StringName)

const OPEN_LOOKING := "This shadow is looking for its cup."
const OPEN_TURN := "Turn the cup slowly, until it fits."
const CUP_MISSING := "Hold the cup up, where I can see it."
const FIRST_BLIND := "Now just look at the cup. Press the button when it fits."
const CHECK_IN := "Hold it still. Which shadow is it making?"
const FOUND_PLACE := "There. Everything's found its place."
const COME_BACK := "We can come back to these."
## Every line this game can say (content/voice/speech.tts must list them, or the bake drops their clips).
const LINES: Array[String] = [OPEN_LOOKING, OPEN_TURN, CUP_MISSING, FIRST_BLIND, CHECK_IN, FOUND_PLACE, COME_BACK]

const AHEAD := 0.62             # Megan, Nov 18: today's spot, centred
const WINDOW := Vector2(0.36, 0.27)
const WINDOW_HEIGHT := 0.30     # the window's centre above the table
const CARD := Vector2(0.12, 0.09)   # each check-in card ≥ 12 cm (4:3 like the shapes)
const CARD_GAP := 0.06          # half a card between cards (crowding)
const LINE_WIDTH := 1.0        # half-width of the card outline in the window, in shape pixels (64 × 48)
const CARD_LINE_WIDTH := 1.6   # thicker on the check-in cards (beat 5)
const REVEAL := 2.5             # the answer stays up this long after each round
const FREE_LOOK := 5.0          # the free look's longest wait (first go)
const FREE_LOOK_TURNED := 0.8   # ...or until the shadow has changed this much (IoU with the first one)
const CUP_MISSING_AFTER := 2.5  # seconds with no cup before "Hold the cup up…" (once per go)
const APPEAR := 0.4
const STONES := 3               # the first full go: Wei's first-level reward
const PROGRESS_FILE := "turn_to_fit_progress.dat"
const GOLD := Color(0.95, 0.75, 0.20)
const GREEN := Color(0.35, 0.85, 0.45)

## Tests: () -> Image instead of a camera.
var frame_source := Callable()
var tracker := FitTracker.new()
var matcher := FitMatcher.new()
var game := FitGame.new(matcher)
var go := FitGo.new(game)
## The workshop (Onion and its sounds), when in the hub. Duck-typed: attend(), cheer(), _sounds.
var workshop: Node
## &"intro", &"turn", &"reveal", &"pick", &"end", &"left"
var phase := &"intro"
## The last round's record while it's shown.
var result := {}
## True while the free look runs (first go).
var free_look := false
var first_go := false

var _window: MeshInstance3D
var _window_material := ShaderMaterial.new()
var _frame: MeshInstance3D
var _board: Node3D
var _cards: Array[MeshInstance3D] = []
var _card_materials: Array[ShaderMaterial] = []
var fits: FitsButton
var _camera: QuestCamera
var _reveal_left := 0.0
var _missing := 0.0
var _said_missing := false
var _first_shape := PackedByteArray()
var _free_time := 0.0
var _live := PackedByteArray()
var _seen_cup := false
var _ending := false


func _init() -> void:
	name = "TurnToFitGame"
	process_mode = Node.PROCESS_MODE_PAUSABLE   # the hub's controller always runs: this game must pause with the world


# --- the saved setup and the child's progress (per player) -----------------------------------------

## A setup with at least two cards is saved for this player.
static func has_setup() -> bool:
	return load_setup().get("shapes", {}).size() >= 2


## The player's saved setup: {shapes = {target: shape}, model = colours}, or {}.
static func load_setup() -> Dictionary:
	var file := FileAccess.open(Profile.path(TurnToFit.SAVE_FILE), FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = file.get_var()
	file.close()
	if not data is Dictionary or data.get("version", 0) != TurnToFit.SAVE_VERSION:
		return {}
	return data


static func progress() -> Dictionary:
	var file := FileAccess.open(Profile.path(PROGRESS_FILE), FileAccess.READ)
	if file == null:
		return {goes = 0, stones = false}
	var data: Variant = file.get_var()
	file.close()
	return data if data is Dictionary else {goes = 0, stones = false}


static func save_progress(data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(Profile.path())
	var file := FileAccess.open(Profile.path(PROGRESS_FILE), FileAccess.WRITE)
	if file:
		file.store_var(data)
		file.close()


# --- the go ------------------------------------------------------------------------------------------

## Plays one go; returns &"done" (it ended) or &"left" (the exit token).
func play() -> StringName:
	var setup := load_setup()
	for target: String in TurnToFit.TARGETS:
		if setup.get("shapes", {}).has(target):
			matcher.add_target(target, setup.shapes[target])
	tracker.model = setup.get("model", PackedFloat32Array())
	game = FitGame.new(matcher)
	go = FitGo.new(game)
	game.finished.connect(_on_round)
	if matcher.targets.size() < 2:
		return &"done"
	var record := progress()
	first_go = int(record.get("goes", 0)) == 0
	_place()
	_build()
	if not frame_source.is_valid() and App.reality.kind() != "passthrough":
		_camera = QuestCamera.new()   # a laptop: its webcam
		add_child(_camera)
	tracker.source = _frame_image
	tracker.stepped.connect(_step)
	add_child(tracker)
	Events.report(&"turn_to_fit", {event = &"go_start", first = first_go, cards = matcher.names})
	await _appear()
	if _ending:
		return await _ended
	if workshop != null and workshop.has_method(&"attend"):
		workshop.attend(_window)
	if first_go:
		free_look = true
		while free_look and not _ending:
			await get_tree().process_frame
		if _ending:
			return await _ended
		await _say(OPEN_LOOKING)
		await _say(OPEN_TURN)
	record.goes = int(record.get("goes", 0)) + 1
	save_progress(record)
	if _ending:
		return await _ended
	go.start()
	phase = &"turn"
	_round_started()
	return await _ended


## Ends the go early (the hub's exit token): the round is logged as interrupted, "We can come back to these."
func leave() -> void:
	if _ending:
		return
	_ending = true
	if game.playing:
		Events.report(&"turn_to_fit_round", {mode = "turn" if game.mode == FitGame.Mode.TURN else "pick",
			help = FitGame.HELP_NAMES[game.help] if game.mode == FitGame.Mode.TURN else "none",
			card = matcher.names[game.card] if game.card >= 0 else "", chosen = "", result = "interrupted",
			seconds = snappedf(game.time, 0.1), score = 0.0, next_help = FitGame.HELP_NAMES[game.help]})
		game.playing = false
	phase = &"left"
	free_look = false
	_finish(&"left", COME_BACK)


func _round_started() -> void:
	result = {}
	_reveal_left = 0.0
	if go.first_blind_now():
		_say(FIRST_BLIND)
	_refresh()


func _on_round(record: Dictionary) -> void:
	result = record
	Events.report(&"turn_to_fit_round", record)
	phase = &"reveal"
	_reveal_left = REVEAL
	if record.result in ["fit", "match"]:
		_hop()
	_refresh()


func _after_reveal() -> void:
	var next := go.next(result)
	match next:
		&"turn":
			phase = &"turn"
			_round_started()
		&"pick":
			phase = &"pick"
			_round_started()
			_say(CHECK_IN)
		_:
			_end()


func _end() -> void:
	if _ending:
		return
	_ending = true
	phase = &"end"
	Events.report(&"turn_to_fit", {event = &"go_end", fits = go.fits, ending = go.ending()})
	var record := progress()
	if not record.get("stones", false):
		record.stones = true
		save_progress(record)
		Events.level_won.emit(&"turn_to_fit", 1, STONES)   # Inventory adds them (first full go only)
	_finish(&"done", FOUND_PLACE if go.ending() == &"found_place" else COME_BACK)


func _finish(outcome: StringName, line: String) -> void:
	_refresh()
	if workshop != null and workshop.has_method(&"attend"):
		workshop.attend(null)
	await _say(line)
	await _disappear()
	_ended.emit(outcome)


# --- every tracking step ---------------------------------------------------------------------------

func _step(shape: PackedByteArray, dt: float) -> void:
	_live = shape
	var cup := not shape.is_empty()
	_seen_cup = _seen_cup or cup
	_missing = 0.0 if cup else _missing + dt
	if _missing >= CUP_MISSING_AFTER and not _said_missing and not _ending and phase != &"reveal":
		_said_missing = true
		_say(CUP_MISSING)
	if free_look:
		if cup:
			if _first_shape.is_empty():
				_first_shape = shape
			_free_time += dt
			if _free_time >= FREE_LOOK or ShapeCV.iou(_first_shape, shape) < FREE_LOOK_TURNED:
				free_look = false
		_draw()
		return
	matcher.update(shape, dt)
	if phase == &"turn" or phase == &"pick":
		game.update(dt)
		if go.tick(dt):
			_end()
	_draw()


func _process(delta: float) -> void:
	if phase == &"reveal" and _reveal_left > 0.0:
		_reveal_left -= delta
		if _reveal_left <= 0.0 and not _ending:
			_after_reveal()


## What the window shows now. Green only ever after a fit (never before a round, never in the free look).
func _draw() -> void:
	if _window == null:
		return
	var line := PackedByteArray()
	var fill := PackedByteArray()
	var colour := GOLD
	var revealing := phase == &"reveal" or (phase == &"end" and not result.is_empty())
	if free_look or phase == &"intro":
		fill = _live
	elif phase == &"turn" and game.playing:
		line = matcher.targets[game.card]
		if game.shows_live():
			fill = _live
	elif revealing and game.card >= 0:
		line = matcher.targets[game.card]
		fill = _live
		if result.get("result", "") in ["fit", "match"]:
			colour = GREEN
	_window_material.set_shader_parameter(&"mask", ImageTexture.create_from_image(mask_image(line, fill)))
	_window_material.set_shader_parameter(&"line", Vector3(colour.r, colour.g, colour.b))


## The CV's 64 × 48 shapes as a small RGB mask for the window's shader: R = the live shadow, G = the
## card's shape (filled; the shader draws its outline). The shader blurs and smooths both edges.
static func mask_image(card: PackedByteArray, live: PackedByteArray) -> Image:
	var w := ShapeCV.NORM_W
	var h := ShapeCV.NORM_H
	var bytes := PackedByteArray()
	bytes.resize(w * h * 3)
	for i in w * h:
		bytes[i * 3] = 255 if not live.is_empty() and live[i] == 1 else 0
		bytes[i * 3 + 1] = 255 if not card.is_empty() and card[i] == 1 else 0
	return Image.create_from_data(w, h, false, Image.FORMAT_RGB8, bytes)


## Shows or hides what each phase needs: the window or the check-in board, the ✓ button, the cards.
func _refresh() -> void:
	if _window == null:
		return
	var picking := phase == &"pick" and game.playing
	_board.visible = picking
	_frame.visible = not picking
	_window.visible = not picking
	fits.set_open(phase == &"turn" and game.playing and game.help == FitGame.Help.BLIND)
	for i in _cards.size():
		var shown := picking and i < game.cards.size()
		_cards[i].visible = shown
		_set_target_enabled(_cards[i], shown)
		if shown:
			_card_materials[i].set_shader_parameter(&"mask", ImageTexture.create_from_image(
				mask_image(matcher.targets[game.cards[i]], PackedByteArray())))


# --- what the child presses --------------------------------------------------------------------------

func _on_fits() -> void:
	if phase == &"turn" and game.playing and game.help == FitGame.Help.BLIND:
		_play_sound(&"pop", fits.global_position, 1.1)
		game.commit()


func _on_selected(_hand: StringName, target: Target, _origin: Vector3, _direction: Vector3) -> void:
	_on_card(target)


func _on_touched(_hand: StringName, target: Target) -> void:
	_on_card(target)


func _on_card(target: Target) -> void:
	if target == null or not String(target.id).begins_with("ttf_card_") or phase != &"pick" or not game.playing:
		return
	if get_tree().paused:
		return
	var slot := int(String(target.id).trim_prefix("ttf_card_"))
	game.pick(slot)   # {unclear = true}: the camera isn't sure; nothing scored, the child can pick again


# --- the room ----------------------------------------------------------------------------------------

## The newest camera picture: the headset's camera, the laptop's webcam, or the tests' photos.
func _frame_image() -> Image:
	if frame_source.is_valid():
		return frame_source.call()
	var frame: CameraFrame = App.reality.camera_frame() if App.reality.kind() == "passthrough" \
		else (_camera.frame() if _camera else null)
	return frame.image if frame else null


## On the table, AHEAD in front of the eyes, facing the child.
func _place() -> void:
	var eye := App.head().global_transform
	var forward := Vector3(-eye.basis.z.x, 0.0, -eye.basis.z.z).normalized()
	var table_y := App.reality.work_surface().transform.origin.y
	var spot := Vector3(eye.origin.x, table_y, eye.origin.z) + forward * AHEAD
	global_transform = Transform3D(Basis.looking_at(forward), spot)


func _build() -> void:
	var shader: Shader = load("res://turn_to_fit/shadow_window.gdshader")
	var centre := Vector3(0, WINDOW_HEIGHT, 0)
	_frame = _box_mesh(Vector3(WINDOW.x + 0.04, WINDOW.y + 0.04, 0.02), Color(0.48, 0.32, 0.19))
	_frame.position = centre + Vector3(0, 0, -0.012)
	add_child(_frame)
	_window = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = WINDOW
	_window.mesh = quad
	_window_material.shader = shader
	_window.material_override = _window_material
	_window.position = centre
	add_child(_window)
	# The check-in board: wider, black, framed like the window, with the cards well apart.
	_board = Node3D.new()
	_board.name = "CheckInBoard"
	add_child(_board)
	var count := TurnToFit.TARGETS.size()
	var width := count * CARD.x + (count + 1) * CARD_GAP
	var board_frame := _box_mesh(Vector3(width + 0.04, CARD.y + 2.0 * CARD_GAP + 0.04, 0.02), Color(0.48, 0.32, 0.19))
	board_frame.position = centre + Vector3(0, 0, -0.012)
	_board.add_child(board_frame)
	var back := _box_mesh(Vector3(width, CARD.y + 2.0 * CARD_GAP, 0.004), Color(0.10, 0.10, 0.12), true)
	back.position = centre + Vector3(0, 0, -0.001)
	_board.add_child(back)
	for i in count:
		var card := MeshInstance3D.new()
		var face := QuadMesh.new()
		face.size = CARD
		card.mesh = face
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter(&"line_width", CARD_LINE_WIDTH)
		card.material_override = material
		card.position = centre + Vector3((i - (count - 1) * 0.5) * (CARD.x + CARD_GAP), 0, 0.004)
		var target := UITarget.new()
		target.id = StringName("ttf_card_%d" % i)
		target.name = String(target.id)
		var shape := CollisionShape3D.new()
		var hit := BoxShape3D.new()
		hit.size = Vector3(CARD.x + CARD_GAP * 0.8, CARD.y + CARD_GAP, 0.04)
		shape.shape = hit
		target.add_child(shape)
		card.add_child(target)
		card.visible = false
		_board.add_child(card)
		_cards.append(card)
		_card_materials.append(material)
	_board.visible = false
	# The ✓ button: on the table to the right of the cup, ~40 cm from the eyes (beat 4).
	fits = FitsButton.make()
	add_child(fits)
	var eye := App.head().global_position
	var floor_eye := Vector3(eye.x, global_position.y, eye.z)
	var forward := (global_position - floor_eye).normalized()
	var right := forward.cross(Vector3.UP)
	fits.global_position = floor_eye + forward * 0.42 + right * 0.11 + Vector3.UP * 0.05
	fits.face(eye)
	fits.set_open(false)
	fits.pressed.connect(_on_fits)
	Events.selected.connect(_on_selected)
	Events.touched.connect(_on_touched)
	_draw()


func _box_mesh(size: Vector3, colour: Color, unshaded := false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material = material
	node.mesh = box
	return node


## Hidden things can't be pressed: their hit boxes go too.
func _set_target_enabled(node: Node, on: bool) -> void:
	for target: Node in node.find_children("*", "Area3D", true, false):
		for shape: Node in target.find_children("*", "CollisionShape3D", false, false):
			(shape as CollisionShape3D).disabled = not on


# --- small helpers -----------------------------------------------------------------------------------

func _say(line: String) -> void:
	await Onion.line(line, self)


func _hop() -> void:
	var hop := create_tween()
	hop.tween_property(_window, "scale", Vector3.ONE * 1.06, 0.15)
	hop.tween_property(_window, "scale", Vector3.ONE, 0.25)
	var at := _window.global_position
	PlaceSignal.play(self, at + global_basis.z * 0.01, global_basis.z, 0.1)   # the shared "found its place" ring and click
	if workshop != null and workshop.has_method(&"cheer"):
		workshop.cheer()


func _play_sound(key: StringName, at: Vector3, pitch := 1.0) -> void:
	var sounds: Variant = workshop.get("_sounds") if workshop != null else null
	if sounds != null and is_instance_valid(sounds):
		(sounds as Sounds).play(key, at, pitch)


## Appears in place: a short grow from its middle (≤ 0.5 s). Uniform scale only (Jolt refuses squashed hit boxes).
func _appear() -> void:
	scale = Vector3.ONE * 0.05
	var grow := create_tween()
	grow.tween_property(self, "scale", Vector3.ONE, APPEAR).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await grow.finished


## Goes in place (≤ 0.5 s), like the shelf.
func _disappear() -> void:
	if not is_inside_tree():
		return
	fits.set_open(false)
	var shrink := create_tween()
	shrink.tween_property(self, "scale", Vector3.ONE * 0.05, APPEAR).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await shrink.finished
	visible = false
