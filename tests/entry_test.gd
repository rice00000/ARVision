extends TestCase
## Megan's opening (Entry in main.tscn): it plays before the World unless a
## session plan is given; the cauldron on the real table, touching it, finding
## the piece again (wrong pick, help, right pick), and the World waiting until
## the child chooses to begin.

const TIDY := preload("res://trials/tidy/tidy.tres")

var entry: Entry


## Boots main.tscn and starts the opening, like a launch without a plan does.
func _boot_entry() -> void:
	await boot()
	entry = app.get_node(^"Entry")
	entry.run()


func _said_line(said: Array, text: String) -> bool:
	return said.any(func(args: Array) -> bool: return args[0] == text)


## Waits until the guide has said [param text]; a line is 3 s, the opening ~40 s.
func _until_said(said: Array, text: String) -> bool:
	return await until(func() -> bool: return _said_line(said, text), 20.0)


## Puts the right fingertip on [param point], coming from in front of the eyes.
func _tip_to(point: Vector3) -> void:
	var eye := App.head().global_position
	var along := (point - (eye + Vector3.DOWN * 0.2)).normalized()
	input.point(&"right", point - along * App.rig.pointer(&"right").tip_reach, point)
	await frames(2)


func _target(id: StringName) -> Target:
	return entry.find_child(String(id), true, false) as Target


## Touches the cauldron once the guide has finished asking: the entry listens
## only after the line (a touch during it is missed).
func _touch_cauldron(said: Array) -> void:
	await _until_said(said, "Could you give me a hand? Touch the cauldron.")
	await wait(3.2)
	await _tip_to(_target(&"entry_cauldron").global_position)
	await _tip_to(App.head().global_position + Vector3(0.0, -0.25, -0.15)) # hand back


## Launches main.tscn as the game does, with only the session's autostart set by [param plan].
func _launch(plan: SessionPlan) -> void:
	app = load("res://main.tscn").instantiate()
	(app.get_node(^"Session") as Session).plan = plan
	add_child(app)
	input = App.sim_input
	await frames(2)


func test_a_launch_plays_the_opening_before_the_world() -> void:
	var said := record(Events.said)
	await _launch(null)
	expect(not App.world.autostart, "the opening holds the World back")
	expect(await _until_said(said, "Oh. You can see me?"), "the opening plays")
	expect(not _said_line(said, App.world.adventure.greeting), "and the World has not started")


func test_a_session_plan_skips_the_opening() -> void:
	var said := record(Events.said)
	await _launch(plan_of(TIDY, 1))
	await wait(4.0)
	expect(not _said_line(said, "Oh. You can see me?"), "no opening before a planned session")
	expect((app.get_node(^"Entry") as Entry).get("_found").is_empty(), "and nothing of it is built")


func test_the_cauldron_stands_on_the_table_and_waits_for_a_touch() -> void:
	await _boot_entry()
	var said := record(Events.said)
	expect(await _until_said(said, "Could you give me a hand? Touch the cauldron."), "the guide asks for a touch")
	var cauldron: Node3D = entry.get("_box")
	var table := App.reality.work_surface()
	expect(cauldron.global_position.distance_to(table.point(0, 0)) < 0.01, "the cauldron is on the table's centre")
	await wait(4.0)
	expect(entry.get("_found").is_empty(), "nothing comes out before the touch")
	await _tip_to(_target(&"entry_cauldron").global_position)
	expect(await _until_said(said, "There it is."), "touching the cauldron opens it")
	var found: Array = entry.get("_found")
	expect_eq(found.size(), 3, "three objects tumble out")
	for piece: Node3D in found:
		expect(absf(piece.global_position.y - table.transform.origin.y - 0.035) < 0.01, "%s landed on the table" % piece)


func test_finding_the_piece_again_with_a_wrong_pick_and_help() -> void:
	await _boot_entry()
	var said := record(Events.said)
	await _touch_cauldron(said)
	expect(await until(func() -> bool: return entry.get("_wanted") == 1, 30.0), "the child is asked to find piece 1")
	var found: Array = entry.get("_found")

	await select(found[0].global_position)
	expect(await _until_said(said, "Not that one. Have another look."), "a wrong pick is answered kindly")
	expect_eq(entry.get("_wanted"), 1, "and the search goes on")
	await wait(3.2) # the answer is said before the next pick counts

	await raise_hand()
	expect(await _until_said(said, "This one."), "a raised hand gets help")
	var orb: Node3D = entry.get("_orb")
	await wait(1.0)
	expect(orb.global_position.distance_to(found[1].global_position + Vector3.UP * 0.12) < 0.02, "the guide floats over the wanted piece")

	await select(found[1].global_position)
	expect(await _until_said(said, "Someone put that inside?"), "the right pick unfolds the fragment")
	expect_eq(entry.get("_wanted"), -1, "the search is over")
	expect(found[1].find_children("*", "Target", false, false).is_empty(), "the found piece can't be picked again")


func test_the_world_starts_only_when_the_child_chooses() -> void:
	await _boot_entry()
	var said := record(Events.said)
	await _touch_cauldron(said)
	await until(func() -> bool: return entry.get("_wanted") == 1, 30.0)
	await select(entry.get("_found")[1].global_position)
	expect(await until(func() -> bool: return _target(&"entry_begin") != null, 30.0), "a button to begin appears")
	var greeting := App.world.adventure.greeting
	await wait(8.0)
	expect(not _said_line(said, greeting), "the World waits while the child looks around")
	await select(_target(&"entry_begin").global_position)
	expect(await _until_said(said, greeting), "choosing the button starts the World")
	await frames(2)
	expect(_target(&"entry_begin") == null, "and the button goes")
