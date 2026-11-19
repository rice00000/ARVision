extends TestCase
## Scene 0, setup (Megan's scene review, Nov 17, SCENE_REVIEW_DECISIONS.md): the last table and
## reach reused with one press when the room scan still finds that table; "Skip setup" in play
## too; "Redo setup" in the staff tools.

var entry: Entry


func _boot_entry() -> void:
	Engine.time_scale = 1.0
	await boot(null, &"intro")
	app.autostart = true
	entry = app.get_node(^"Intro/Entry")
	entry.plan_at_start = false
	entry.skip_setup = false
	entry.run()


func _target(id: StringName) -> Target:
	return entry.find_child(String(id), true, false) as Target


func _press(id: StringName) -> bool:
	if not await until(func() -> bool: return _target(id) != null, 20.0):
		return false
	await select(_target(id).global_position)
	await frames(2)
	await wait(0.7)
	return true


func _remember() -> void:
	DirAccess.make_dir_recursive_absolute(Profile.path())
	SetupMemory.path = Profile.path("last_setup.cfg")
	SetupMemory.forget()


func _done() -> void:
	SetupMemory.forget()
	SetupMemory.path = ""
	PlayMode.reset_for_tests()


## The four steps, ending at "All set".
func _four_steps() -> void:
	await until(func() -> bool: return _target(&"entry_step_next") != null, 20.0)
	input.click(&"right", &"trigger_click")
	await frames(3)
	await wait(0.7)
	await _press(&"entry_step_next")
	await _press(&"entry_confirm_yes")
	await _press(&"entry_step_alt")
	await _press(&"entry_step_next")
	await until(func() -> bool: return _target(&"entry_part_all") != null, 20.0)


## The room scan's table (the sim room has one).
func _scanned_table() -> Surface:
	return App.reality.surfaces(&"table")[0]


func test_under_tests_the_memory_is_off_unless_a_test_turns_it_on() -> void:
	expect_eq(SetupMemory.path, "", "tests never read a setup left by a real launch")
	expect(SetupMemory.last().is_empty(), "so there is nothing to reuse")


func test_the_same_table_means_same_place_height_and_size_either_way_round() -> void:
	var table := Surface.new(&"table", Transform3D(Basis.IDENTITY, Vector3(0.1, 0.72, -0.6)), Vector2(1.2, 0.7))
	expect(SetupMemory.same_table(table, Vector3(0.1, 0.72, -0.6), Vector2(1.2, 0.7)), "the very same")
	expect(SetupMemory.same_table(table, Vector3(0.2, 0.74, -0.55), Vector2(1.1, 0.8)), "a scan a little off")
	expect(SetupMemory.same_table(table, Vector3(0.1, 0.72, -0.6), Vector2(0.7, 1.2)), "its sides the other way round")
	expect(not SetupMemory.same_table(table, Vector3(0.4, 0.72, -0.6), Vector2(1.2, 0.7)), "30 cm along: another place")
	expect(not SetupMemory.same_table(table, Vector3(0.1, 0.80, -0.6), Vector2(1.2, 0.7)), "8 cm higher: another table")
	expect(not SetupMemory.same_table(table, Vector3(0.1, 0.72, -0.6), Vector2(0.6, 0.5)), "much smaller: another table")


func test_a_full_setup_keeps_the_table_and_reach_and_the_next_launch_offers_them() -> void:
	_remember()
	await _boot_entry()
	await _four_steps()
	var kept := SetupMemory.last()
	expect(not kept.is_empty(), "the four steps keep the table")
	expect_eq(kept.get("reach", -1.0), 0.0, "\"Use usual spot\" keeps reach 0")
	await shutdown()
	var reports := record(Events.reported)
	await _boot_entry()
	expect(await until(func() -> bool: return _target(&"entry_reuse_yes") != null, 20.0), "the next launch offers the last setup")
	expect(_target(&"entry_step_next") == null, "before the steps")
	expect(_target(&"entry_skip_setup") != null, "Skip setup is there too")
	await _press(&"entry_reuse_yes")
	expect(await until(func() -> bool: return _target(&"entry_part_all") != null, 10.0), "one press: straight to All set")
	expect(SetupMemory.same_table(App.reality.work_surface(), kept.centre, kept.size), "the kept table is the work surface")
	expect(reports.any(func(a: Array) -> bool: return a[0] == &"setup_reused"), "the reuse is logged")
	_done()


func test_the_kept_reach_sets_the_layout() -> void:
	_remember()
	await boot(null, &"intro")
	SetupMemory.remember(_scanned_table(), 0.45)
	await shutdown()
	await _boot_entry()
	await _press(&"entry_reuse_yes")
	await until(func() -> bool: return _target(&"entry_part_all") != null, 10.0)
	expect_eq(entry.get("_reach_measured"), 0.45, "the kept reach is used")
	expect_eq(entry.get("_cauldron_distance"), EntryLayout.cauldron_out(0.45), "the cauldron goes where that reach puts it")
	expect_eq(entry.shelf_push, EntryLayout.shelf_push(0.45), "and the shelf")
	_done()


func test_when_the_scan_no_longer_finds_that_table_setup_runs_as_usual() -> void:
	_remember()
	await boot(null, &"intro")
	var table := _scanned_table()
	var moved := Surface.new(&"table", table.transform.translated(Vector3(0.6, 0.0, 0.0)), table.size)
	SetupMemory.remember(moved, 0.4)
	await shutdown()
	await _boot_entry()
	expect(await until(func() -> bool: return _target(&"entry_step_next") != null, 20.0), "step 1 at once")
	expect(_target(&"entry_reuse_yes") == null, "no offer for a table that is not there")
	_done()


func test_set_up_again_runs_the_four_steps() -> void:
	_remember()
	await boot(null, &"intro")
	SetupMemory.remember(_scanned_table(), 0.0)
	await shutdown()
	await _boot_entry()
	await _press(&"entry_reuse_no")
	expect(await until(func() -> bool: return _target(&"entry_step_next") != null, 10.0), "\"Set up again\": step 1")
	_done()


## Merge with Wei (Nov 18): Skip setup starts the opening in one pinch (it used to stop at "All set").
func test_play_mode_has_skip_setup_and_it_starts_the_opening() -> void:
	await _boot_entry()
	await until(func() -> bool: return entry.get("_panel") != null, 20.0)
	PlayMode.set_dev(false, "test")
	entry.get("_panel").show_mode(PlayMode.name(), PlayMode.is_dev())   # as the Mode toggle does
	expect(not PlayMode.is_dev(), "play")
	expect(await until(func() -> bool: return _target(&"entry_step_next") != null, 20.0), "setup runs in play")
	expect(_target(&"entry_skip_setup") != null, "play: Skip setup is on the panel")
	await _press(&"entry_skip_setup")
	expect(await until(func() -> bool: return not entry.setting_up(), 10.0), "Skip setup starts the opening")
	_done()


func test_redo_setup_in_the_staff_tools_runs_every_step_without_the_offer() -> void:
	_remember()
	await boot(null, &"intro")
	SetupMemory.remember(_scanned_table(), 0.0)
	await shutdown()
	await _boot_entry()
	await _press(&"entry_reuse_yes")
	await until(func() -> bool: return _target(&"entry_part_all") != null, 10.0)
	await open_intro_tools()
	expect(App.module(&"Facilitator").find_child("fac_redo_setup", true, false) != null, "the Tools page has Redo setup")
	await press_facilitator("fac_redo_setup")
	await frames(2)
	await press_facilitator("fac_confirm_tool")   # it asks first
	await wait(0.5)
	entry = app.get_node(^"Intro/Entry")   # the opening started again
	expect(await until(func() -> bool: return _target(&"entry_step_next") != null, 20.0), "Redo: step 1")
	expect(_target(&"entry_reuse_yes") == null, "Redo never offers the last setup")
	expect(not Entry.redo_next, "and it is used once")
	_done()


## Megan, Nov 18: "New player save" on a setup screen, then Skip (or Start): the opening plays on a new save, from
## the hello, with no setup questions; the old save is kept.
func test_new_player_save_starts_the_opening_on_a_new_save() -> void:
	await _boot_entry()
	expect(await until(func() -> bool: return _target(&"entry_new_save") != null, 20.0), "the toggle is on the setup panel")
	var before := Profile.id
	HubMemory.get_or_make().mark_played(&"shelf")
	Save.write()
	await _press(&"entry_new_save")
	expect(entry.new_save, "pinched: on")
	await _press(&"entry_skip_setup")
	expect(await until(func() -> bool: return Profile.id != before and App.main.current_scene == &"intro" and not App.main.switching, 30.0), "a new save")
	expect(Profile.saves().has(before), "the old save is kept")
	expect(HubMemory.get_or_make().played.is_empty(), "nothing played on the new one")
	expect(await until(func() -> bool:
		var opening := App.main.intro()
		return opening != null and String(opening.beat).begins_with("1"), 30.0), "the opening plays from the hello, no setup asked")
	_done()
