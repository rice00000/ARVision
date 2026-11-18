extends TestCase
## FitTracker off the main thread (Nov 18 decision: "CV off the main thread"): a threaded step hands the
## colour tracking to the WorkerThreadPool, the frame goes on, and the same shadow arrives on a later frame;
## a step while one is still running is skipped (its time is kept). The server address is kept on the device.
##   godot --headless --xr-mode off --fixed-fps 60 --path . res://tests/run.tscn -- --profile=test --only=fit_tracker

const DATA := "res://tests/data/turn_to_fit/"


func _box(view: String) -> Rect2i:
	var b: Array = JSON.parse_string(FileAccess.get_file_as_string(DATA + "santa.json")).boxes[view]
	return Rect2i(int(b[0]), int(b[1]), int(b[2] - b[0]), int(b[3] - b[1]))


func _tracker(threaded: bool) -> FitTracker:
	var tracker := FitTracker.new()
	tracker.use_server = false
	tracker.threaded = threaded
	var photo := Image.load_from_file(DATA + "santa_right.jpg")
	tracker.source = func() -> Image: return photo
	tracker.model = ShapeCV.learn_colours(Image.load_from_file(DATA + "santa_left.jpg"),
		Image.load_from_file(DATA + "santa_left_sam.png"), _box("left"))
	tracker.set_box(_box("right"))
	tracker.set_process(false)   # the test steps it by hand
	add_child(tracker)
	return tracker


func test_a_threaded_step_leaves_the_frame_and_brings_the_same_shadow_back_later() -> void:
	var main_thread := _tracker(false)
	var expected: Array = []
	main_thread.stepped.connect(func(shape: PackedByteArray, _dt: float) -> void: expected.append(shape))
	main_thread.step(0.2)
	expect_eq(expected.size(), 1, "on the main thread: the shadow comes at once")
	var threaded := _tracker(true)
	var got: Array = []
	threaded.stepped.connect(func(shape: PackedByteArray, dt: float) -> void: got.append([shape, dt]))
	var start := Time.get_ticks_usec()
	threaded.step(0.2)
	var frame_ms := (Time.get_ticks_usec() - start) / 1000.0
	expect(got.is_empty(), "threaded: nothing yet on this frame")
	threaded.step(0.2)   # still working: skipped, its time joins the result
	var waited := 0
	while got.is_empty() and waited < 300:
		await frames(1)
		threaded.call(&"_collect")
		waited += 1
	expect_eq(got.size(), 1, "one shadow arrives later")
	if got.size() == 1 and expected.size() == 1:
		expect(not (got[0][0] as PackedByteArray).is_empty(), "the cup is tracked")
		expect(got[0][0] == expected[0], "the same shadow as on the main thread")
		expect(is_equal_approx(got[0][1], 0.4), "the skipped step's time is kept (%.2f)" % got[0][1])
	print("    track on the main thread %.1f ms; a threaded step costs the frame %.2f ms" % [main_thread.track_ms, frame_ms])
	expect(frame_ms < main_thread.track_ms, "a threaded step costs the frame less than tracking does")
	main_thread.queue_free()
	threaded.queue_free()


func test_the_server_address_is_kept_on_the_device() -> void:
	var before := FitTracker.saved_server()
	FitTracker.save_server("http://192.168.1.23:8765")
	expect_eq(FitTracker.saved_server(), "http://192.168.1.23:8765", "saved")
	expect_eq(TurnToFit.address_of(FitTracker.saved_server()), "192.168.1.23", "shown as the address typed")
	FitTracker.save_server(before)
