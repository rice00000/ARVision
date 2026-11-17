extends TestCase
## Scene 2, Tap (Megan's scene review, Nov 17): the tap plays the cauldron's own knock, from the
## cauldron, and sends no Events.feedback (Wei's generic hint sound and mark).
##
## Why the first attempt failed: on the desktop (no headset, App.xr == null) a direct touch on the
## cauldron counts only when [member Entry.touch_cauldron_in_sim] is on (it is off by default, so a
## mouse hand resting near the pot can't tap it by accident). Its Events.touched never reached
## Entry._on_target. Also, "knock" is already in Sounds.played from the hello beat (Onion's knock),
## so "knock in played" says nothing about the tap: the tests count from just before it.

var entry: Entry


func _boot(touch_in_sim: bool) -> void:
	Engine.time_scale = 1.0
	await boot(null, &"intro")
	app.autostart = true
	entry = app.get_node(^"Intro/Entry")
	entry.plan_at_start = false
	entry.touch_cauldron_in_sim = touch_in_sim
	entry.run()
	await until(func() -> bool: return entry.tools_ready and entry.get("_cauldron_target") != null, 20.0)
	entry.jump_to(&"touch")
	await until(func() -> bool: return (entry.get("_orb") as Onion).cue, 20.0)   # the Tap beat: the cauldron glows


func _sounds() -> Sounds:
	return entry.get("_sounds")


func _knocks() -> int:
	return _sounds().played.count(&"knock")


func test_a_tap_on_the_cauldron_knocks_and_sends_no_feedback() -> void:
	await _boot(true)
	var before := _knocks()
	var feedback := record(Events.feedback)
	Events.touched.emit(&"right", entry.get("_cauldron_target"))
	await frames(2)
	expect(bool(entry.get("_tapped")), "the tap counts")
	expect_eq(_knocks() - before, 1, "one knock")
	expect(feedback.is_empty(), "no generic hint sound or mark")


func test_a_pinch_on_the_cauldron_knocks_too() -> void:
	await _boot(false)
	var before := _knocks()
	var feedback := record(Events.feedback)
	var target: Target = entry.get("_cauldron_target")
	Events.selected.emit(&"right", target, App.head().global_position, (target.global_position - App.head().global_position).normalized())
	await frames(2)
	expect(bool(entry.get("_tapped")), "the pinch counts")
	expect_eq(_knocks() - before, 1, "one knock")
	expect(feedback.is_empty(), "no generic hint")


func test_on_the_desktop_a_direct_touch_needs_touch_cauldron_in_sim() -> void:
	await _boot(false)
	var before := _knocks()
	Events.touched.emit(&"right", entry.get("_cauldron_target"))
	await frames(2)
	expect(not bool(entry.get("_tapped")), "ignored: what made the first attempt fail")
	expect_eq(_knocks() - before, 0, "and no knock")
