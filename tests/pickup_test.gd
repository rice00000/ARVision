extends TestCase
## Scene 4, Pick it up (Megan's scene review, Nov 17): a soft sound as the gear is lifted and another
## as it is set down away from the socket; they differ, and the set-down is never the seating click.
## The teaching hand reminds after 10 s untouched (was 14).

var entry: Entry
var carry: Carry


func _boot_at_pickup() -> void:
	Engine.time_scale = 1.0
	await boot(null, &"intro")
	app.autostart = true
	entry = app.get_node(^"Intro/Entry")
	entry.plan_at_start = false
	entry.run()
	await until(func() -> bool: return entry.tools_ready and entry.get("_carry") != null, 20.0)
	carry = entry.get("_carry")
	entry.jump_to(&"pickup")
	await until(func() -> bool: return carry.enabled, 20.0)


func _count(key: StringName) -> int:
	return (entry.get("_sounds") as Sounds).played.count(key)


func test_the_lift_and_the_set_down_are_two_different_sounds_and_neither_is_the_click() -> void:
	var drop: Dictionary = Sounds.BORROWS.gear_drop
	expect(Sounds.KEYS.has(&"gear_lift"), "the lift has its own sound")
	expect(drop.file != &"seat", "the set-down never borrows the seating click's file (a drop is not a success)")
	expect(float(drop.db) <= 0.0, "no louder than its source on the SFX bus (%.0f dB)" % drop.db)


func test_picking_the_gear_up_plays_the_lift_from_the_gear() -> void:
	await _boot_at_pickup()
	var before := _count(&"gear_lift")
	carry.picked_up.emit()
	expect_eq(_count(&"gear_lift") - before, 1, "one lift sound")


func test_letting_go_away_from_the_socket_plays_the_set_down_when_it_lands() -> void:
	await _boot_at_pickup()
	var before := _count(&"gear_drop")
	carry.held = true
	carry.call("_release")   # the gear rests away from the socket: it floats down
	expect_eq(_count(&"gear_drop") - before, 0, "nothing yet: it is still floating down")
	expect(await until(func() -> bool: return _count(&"gear_drop") - before == 1, 3.0), "the set-down sound as it lands")


func test_docking_plays_no_set_down() -> void:
	await _boot_at_pickup()
	var before := _count(&"gear_drop")
	carry.call("_dock")
	expect(await until(func() -> bool: return carry.has_docked(), 3.0), "docked")
	await wait(0.5)
	expect_eq(_count(&"gear_drop") - before, 0, "the socket has its click, never the set-down")


func test_the_teaching_hand_reminds_after_ten_seconds() -> void:
	expect_eq(Entry.PICKUP_REMINDER_SECONDS, 10.0, "10 s untouched (was 14)")
	await _boot_at_pickup()
	expect_eq(carry.remind_after, 10.0, "Carry is told 10 s")
