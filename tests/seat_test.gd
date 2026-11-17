extends TestCase
## Scene 5, Set it in (Megan's scene review, Nov 17): when the gear seats, the "found its place"
## signal (PlaceSignal: one soft ring) plays at the socket with the click, and it is the only feedback
## (no generic hint). Then about a second passes before the reveal's light starts, so the two don't blur.

var entry: Entry


func _boot() -> void:
	Engine.time_scale = 1.0
	await boot(null, &"intro")
	app.autostart = true
	entry = app.get_node(^"Intro/Entry")
	entry.plan_at_start = false
	entry.simulate_child = true
	entry.run()
	await until(func() -> bool: return entry.tools_ready and entry.get("_carry") != null, 20.0)


func test_seating_plays_the_place_signal_at_the_socket_and_one_click_only() -> void:
	await _boot()
	var feedback := record(Events.feedback)
	var sounds: Sounds = entry.get("_sounds")
	entry.jump_to(&"place")
	expect(await until(func() -> bool: return sounds.played.has(&"seat"), 30.0), "seated, with the click")
	await frames(2)
	var ring := entry.find_child("place_signal", true, false) as Node3D
	expect(ring != null, "the found-its-place ring plays")
	if ring != null:
		var socket: Vector3 = entry.get("_socket_at")
		expect(Vector2(ring.global_position.x - socket.x, ring.global_position.z - socket.z).length() < 0.01, "at the socket")
		expect(ring.is_in_group(&"entry_transient"), "a jump clears it")
	expect_eq(sounds.played.count(&"seat"), 1, "one click")
	expect(feedback.is_empty(), "no generic hint sound or mark on top")


func test_about_a_second_of_quiet_after_the_signal_before_the_reveal() -> void:
	await _boot()
	var sounds: Sounds = entry.get("_sounds")
	entry.jump_to(&"place")
	await until(func() -> bool: return bool(entry.get("_part_running")), 10.0)
	await until(func() -> bool: return sounds.played.has(&"seat"), 30.0)
	var seated := Engine.get_process_frames()   # game time: the runner's --fixed-fps 60 outruns the clock
	# A jump plays one part: Set in ends here, and in a full run the reveal starts right after it.
	await until(func() -> bool: return not bool(entry.get("_part_running")), 10.0)
	var gap := (Engine.get_process_frames() - seated) / 60.0
	# The ring takes PlaceSignal.SECONDS; then Onion's 1 s rise; then the reveal (its light, or first the
	# socket's slide where the layout moves it: neither starts while the ring plays).
	expect(gap >= PlaceSignal.SECONDS + 0.8 and gap <= PlaceSignal.SECONDS + 1.4, "the reveal starts ~1 s after the ring (%.2f s after the seat)" % gap)


func test_carry_still_sends_its_hint_where_nobody_turned_it_off() -> void:
	var carry := Carry.new()
	expect(carry.dock_feedback, "Wei's hint stays the default outside the opening")
	carry.free()
