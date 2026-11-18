extends TestCase
## The desktop's dev skip in every game (Megan, Nov 18 6:05, prototype testing): Turn to fit's go ends as a full
## go ("done", so the hub gives its stones). The shelf, the dots and the butterflies: hub_test.gd.
##   godot --headless --xr-mode off --fixed-fps 60 --path . res://tests/run.tscn -- --profile=test --only=dev_skip

const DATA := "res://tests/data/turn_to_fit/"
const VIEWS := ["left", "right", "toward"]


func _box(view: String) -> Rect2i:
	var b: Array = JSON.parse_string(FileAccess.get_file_as_string(DATA + "santa.json")).boxes[view]
	return Rect2i(int(b[0]), int(b[1]), int(b[2] - b[0]), int(b[3] - b[1]))


func _save_setup() -> void:
	var shapes := {}
	for view: String in VIEWS:
		shapes[view] = ShapeCV.target_from_mask(Image.load_from_file(DATA + "santa_%s_sam.png" % view), _box(view)).shape
	var photo := Image.load_from_file(DATA + "santa_left.jpg")
	var model := ShapeCV.learn_colours(photo, Image.load_from_file(DATA + "santa_left_sam.png"), _box("left"))
	DirAccess.make_dir_recursive_absolute(Profile.path())
	var file := FileAccess.open(Profile.path(TurnToFit.SAVE_FILE), FileAccess.WRITE)
	file.store_var({version = TurnToFit.SAVE_VERSION, shapes = shapes, model = model, saved = "test"})
	file.close()


func test_skip_ends_a_turn_to_fit_go_as_a_full_go() -> void:
	_save_setup()
	await boot(null, &"turn_to_fit")
	var activity := TurnToFitActivity.new()
	activity.server_override = true
	activity.use_server = false
	activity.threaded = false
	var photo := Image.load_from_file(DATA + "santa_left.jpg")
	activity.frame_source = func() -> Image: return photo
	app.add_child(activity)
	var outcomes := record(activity.finished)
	expect(not DevSkip.finish_go(activity), "nothing to skip before a go")
	activity.summon(Transform3D.IDENTITY)
	await wait(1.0)
	expect(DevSkip.finish_go(activity), "skip ends the go")
	expect(not DevSkip.finish_go(activity), "once")
	expect(await until(func() -> bool: return not outcomes.is_empty(), 30.0), "the go ends")
	expect_eq(outcomes[0][0] if not outcomes.is_empty() else &"", &"done", "as a full go: the hub gives its stones")
	activity.fold()
