class_name TestCase
extends Node
## Base for the headless GDScript tests (see tests/run.gd). Every test_* method
## runs on a wiped profile; [method boot] starts a fresh app on the simulated
## room, and [member input] drives its hands like a child would.

var failures: Array[String] = []
## The running main.tscn, after [method boot].
var app: Node3D
var input: SimInput

var _recordings: Array[Array] = []


func expect(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)
		print("    FAIL: ", what)


func expect_eq(actual: Variant, expected: Variant, what: String) -> void:
	expect(actual == expected, "%s: expected %s, got %s" % [what, expected, actual])


## Starts main.tscn with [param plan] (none: the World's adventure). None of
## Session, World and Entry starts by itself: call App.session.run() or App.world.run().
func boot(plan: SessionPlan = null) -> void:
	app = load("res://main.tscn").instantiate()
	var session: Session = app.get_node(^"Session")
	session.autostart = false
	(app.get_node(^"World") as World).autostart = false
	(app.get_node(^"Entry") as Entry).autostart = false
	if plan:
		session.plan = plan
	add_child(app)
	input = App.sim_input
	await frames(2)


## Every emission of [param event] from now on, as an array of its arguments.
func record(event: Signal) -> Array:
	var emissions := []
	var listener := func(...args: Array) -> void: emissions.append(args)
	event.connect(listener)
	_recordings.append([event, listener])
	return emissions


## Frees the app. The runner calls it after every test.
func shutdown() -> void:
	for recording in _recordings:
		(recording[0] as Signal).disconnect(recording[1])
	_recordings.clear()
	if app:
		app.queue_free()
		app = null
		await frames(2)


func frames(count := 1) -> void:
	for i in count:
		await get_tree().process_frame


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Waits until [param condition] returns true, at most [param timeout] seconds.
## Returns whether it did.
func until(condition: Callable, timeout := 5.0) -> bool:
	var end := Time.get_ticks_msec() + int(timeout * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > end:
			return false
		await frames(1)
	return true


## Raises [param side]'s hand above the eyes until it asks for help, then puts it back.
func raise_hand(side := &"right") -> void:
	var down := App.rig.hand(side).global_transform
	var eye := App.head().global_position
	input.set_hand(side, Transform3D(Basis.IDENTITY, eye + Vector3(0.2 if side == &"right" else -0.2, 0.2, -0.3)))
	await wait(App.rig.pointer(side).raise_seconds + 0.1)
	input.set_hand(side, down)
	await frames(2)


## Points [param side]'s hand at [param at] from just below the eyes and pinches.
func select(at: Vector3, side := &"right") -> void:
	var eye := App.head().global_position
	input.point(side, eye + (at - eye).normalized() * 0.25 + Vector3.DOWN * 0.05, at)
	await frames(1)
	input.click(side, &"trigger_click")
	await frames(1)


## A one-block plan with no greeting or farewell to sit through.
static func plan_of(def: TrialDef, rounds: int, probe := false, difficulty := -1.0, view: View = null,
		pins: Dictionary = {}) -> SessionPlan:
	var block := Block.new()
	block.trial = def
	block.rounds = rounds
	block.probe = probe
	block.difficulty = difficulty
	block.view = view
	block.pins.assign(pins)
	block.pause_between = 0.2
	var plan := SessionPlan.new()
	plan.greeting = ""
	plan.farewell = ""
	plan.blocks.append(block)
	return plan
