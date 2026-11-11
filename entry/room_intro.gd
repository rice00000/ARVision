class_name RoomIntro
extends Node
## Onion's room intro: the first time a child opens My room, Onion appears beside the room's bar and walks
## them through buying one thing and placing it. Like the first visit, doing it is the answer: there is
## nothing to confirm, a step the child has already done is not explained, and a line that has gone stale
## is not said. Onion gives one magic stone when the child cannot afford the cheapest furniture. If a step
## waits, the teaching hand shows the point-and-pinch at the button (or the furniture) to press.
## Leaving the room stops it and the room tries again next time; it counts as seen only once finished.
## Staff tools > Tools > Room intro plays it again (Events.room_intro_requested), seen or not.
## It runs while the menu pauses the game.

## Seconds a step waits before the teaching hand shows it.
const HAND_AFTER := 6.0
## How many stones Onion gives when the child cannot buy anything.
const GIFT := 1
## Where Onion floats, in the menu panel's space: left of the bar and the shop.
const SPOT := Vector3(-0.40, 0.05, 0.05)
## What Onion says about each button it asks for.
const LINES := {
	&"home_shop": "Pinch Shop to see what you can buy.",
	&"home_next": "Pinch the arrow to see more things.",
	&"home_buy": "You can buy this one. Pinch Buy.",
	&"home_confirm": "Pinch the check mark to buy it.",
	&"home_tab_shop": "Pinch Furniture to see the furniture.",
	&"home_back": "Pinch the arrow to go back to your room.",
}

## False under tests (a test turns it on): the first room visit starts it.
var automatic := not PlayMode.testing_now()
## The child finished it once (saved with their progress).
var seen := false
var running := false

var _asked := false          # the staff tools asked for it
var _runs := 0               # a new start or a stop ends the run in progress
var _onion: Onion
var _demo: DemoHand
var _bought := &""           # what the child bought during this run
var _placing := &""          # the furniture that came into the room
var _placed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.home_toggled.connect(func(open: bool) -> void:
		if not open:
			stop()
		elif _asked or (automatic and not seen):
			_asked = false
			_run())
	Events.room_intro_requested.connect(func() -> void:
		_asked = true
		Events.room_requested.emit())
	Events.reported.connect(_on_reported)


func save_state() -> Dictionary:
	return {seen = seen}


func load_state(data: Dictionary) -> void:
	seen = data.get("seen", false)


## Ends the intro now (the child left the room); it is not marked seen.
func stop() -> void:
	_runs += 1
	running = false
	if is_instance_valid(_onion):
		_onion.queue_free()
	if is_instance_valid(_demo):
		_demo.queue_free()


func _run() -> void:
	stop()
	var run := _runs
	running = true
	_bought = &""
	_placing = &""
	_placed = false
	Events.report(&"room_intro", {event = &"start"})
	await get_tree().process_frame   # the room is built and its hint started: Onion's welcome replaces that hint
	if run != _runs: return
	var voice := App.module(&"Voice")
	if voice != null and voice.has_method(&"skip"):
		voice.skip()
	_onion = Onion.new()
	add_child(_onion)
	_demo = DemoHand.new()
	add_child(_demo)
	var bar := _find(&"home_shop")
	_onion.global_position = bar.get_parent().global_transform * SPOT
	_onion.scale = Vector3.ONE * 0.01
	create_tween().tween_property(_onion, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await say("This is your room!")
	if run != _runs: return
	await _gift(run)
	if run != _runs: return
	await _shop(run)
	if run != _runs: return
	if _placing != &"":
		await _place(run)
		if run != _runs: return
	_demo.stop()
	_onion.attend(null)
	_onion.cheer()
	await say("Your room is yours to make. Come back any time.")
	if run != _runs: return
	seen = true
	running = false
	Events.report(&"room_intro", {event = &"done"})
	Save.request()
	_demo.queue_free()
	var away := create_tween()
	away.tween_property(_onion, "scale", Vector3.ONE * 0.01, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	away.tween_callback(_onion.queue_free)


## One stone when the child cannot buy even the cheapest furniture.
func _gift(run: int) -> void:
	var inventory := App.module(&"Inventory")
	var cheapest: int = ItemDef.all(ItemDef.Kind.FURNITURE).map(func(item: ItemDef) -> int: return item.price).min()
	if inventory.count(&"magic_stone") >= cheapest:
		return
	await say("Here is a magic stone for you.")
	if run != _runs: return
	inventory.add(&"magic_stone", GIFT)
	Events.report(&"room_intro_gift", {stones = GIFT})
	Events.feedback.emit(&"good", _onion.global_position)


## Until the child buys something: Onion and the hand point at what to press next on the page shown.
func _shop(run: int) -> void:
	var asked := &""
	var waited := 0.0
	while _bought == &"":
		await get_tree().process_frame
		if run != _runs: return
		var button := _next()
		if button == null:
			continue   # the panel is being rebuilt
		_onion.attend(button)   # the panel rebuilds its buttons: follow the one shown now
		if button.id != asked:
			asked = button.id
			waited = 0.0
			_demo.stop()
			_tell(run, asked, LINES[asked])   # not awaited: the child may act while Onion talks
		waited += get_process_delta_time()
		if waited >= HAND_AFTER:
			_demo.aim_pinch(button)


## Until the new furniture is put down on a free spot (or into the box).
func _place(run: int) -> void:
	_demo.stop()
	var piece := _furniture()
	_onion.attend(piece)
	_tell(run, &"place", "Now pinch it, move your hand, and let go where you see the tick.")
	var waited := 0.0
	while not _placed:
		await get_tree().process_frame
		if run != _runs: return
		waited += get_process_delta_time()
		piece = _furniture()
		if piece == null:
			return   # put away in the box
		if waited >= HAND_AFTER and App.module(&"Decor").held == null:
			_demo.aim_pinch(piece)
		elif App.module(&"Decor").held != null:
			_demo.stop()
	_demo.stop()
	await say("That looks lovely there.")


## Says [param text] for step [param step] once the voice is quiet, unless the child has moved on by then.
func _tell(run: int, step: StringName, text: String) -> void:
	var voice := App.module(&"Voice")
	while voice != null and voice.speaking() != "":
		await get_tree().process_frame
		if run != _runs or step != _step_now():
			return
	await say(text)


## Onion speaks [param text] and it waits for the line (see [method Onion.line]).
func say(text: String) -> void:
	await Onion.line(text, self)


## The step shown now: the button to press next, or &"place" while the furniture is out.
func _step_now() -> StringName:
	if _placing != &"":
		return &"place"
	var button := _next()
	return button.id if button != null else &""


## The button to press next on the page the menu shows (null while it is being rebuilt).
func _next() -> Target:
	var id := &""
	match App.module(&"Home").page:
		&"room": id = &"home_shop"
		&"bag": id = &"home_back"
		&"confirm_item", &"confirm_pet", &"confirm_room": id = &"home_confirm"
		&"shop": id = &"home_buy" if _find(&"home_buy") != null else &"home_next"
		_: id = &"home_buy" if _find(&"home_buy") != null else &"home_tab_shop"   # pets, rooms
	return _find(id)


func _find(id: StringName) -> Target:
	return App.main.find_child(String(id), true, false) as Target


## The piece that came into the room (the newest of its kind), or null once it went into the box.
func _furniture() -> Target:
	var found: Target
	for piece: Target in App.module(&"Decor").items():
		if piece.id == _placing:
			found = piece
	return found


func _on_reported(what: StringName, data: Dictionary) -> void:
	if not running:
		return
	match what:
		&"purchased": _bought = data.item
		&"furniture_taken_out": _placing = data.item
		&"furniture_placed": _placed = true
