extends TestCase
## Turn to fit, Layer 1 (live CV), on Megan's real mug: 4 phone photos shrunk to the Quest
## camera's 640 × 480, with YOLO's cup boxes and SAM's outlines saved alongside
## (tests/data/turn_to_fit/, made Nov 15 with the headset's YOLO11n and MobileSAM).
##   godot --headless --xr-mode off --fixed-fps 60 --path . res://tests/run.tscn -- --profile=test --only=turn_to_fit

const DATA := "res://tests/data/turn_to_fit/"
const VIEWS := ["left", "right", "toward", "away"]


func _photo(view: String) -> Image:
	return Image.load_from_file(DATA + "santa_%s.jpg" % view)


func _sam(view: String) -> Image:
	return Image.load_from_file(DATA + "santa_%s_sam.png" % view)


func _box(view: String) -> Rect2i:
	var b: Array = JSON.parse_string(FileAccess.get_file_as_string(DATA + "santa.json")).boxes[view]
	return Rect2i(int(b[0]), int(b[1]), int(b[2] - b[0]), int(b[3] - b[1]))


## The colours learned once, from the handle-left capture.
func _model() -> PackedFloat32Array:
	return ShapeCV.learn_colours(_photo("left"), _sam("left"), _box("left"))


func test_learned_colours_find_the_mug_in_the_other_photos() -> void:
	var model := _model()
	for view: String in VIEWS:
		var live := ShapeCV.track(_photo(view), _box(view), model)
		var answer := ShapeCV.target_from_mask(_sam(view), _box(view))
		expect(live.ok, "%s: the mug is found" % view)
		# same area, same pixel size: compare the two outlines pixel by pixel
		var score := ShapeCV.iou(live.small, answer.small)
		expect(score >= 0.85, "%s: colour tracking matches SAM's outline (IoU %.2f)" % [view, score])


func test_each_live_view_picks_its_own_target() -> void:
	var model := _model()
	var matcher := FitMatcher.new()
	for view: String in ["left", "right", "toward"]: # not "away": it looks like "toward" (CV_PLAN §3)
		matcher.add_target(view, ShapeCV.target_from_mask(_sam(view), _box(view)).shape)
	for i in matcher.targets.size():
		var live: PackedByteArray = ShapeCV.track(_photo(matcher.names[i]), _box(matcher.names[i]), model).shape
		var scores := matcher.targets.map(func(t: PackedByteArray) -> float: return ShapeCV.iou(live, t))
		var best: int = scores.find(scores.max())
		var others := scores.duplicate()
		others.remove_at(best)
		expect_eq(matcher.names[best], matcher.names[i], "%s is recognised (scores %s)" % [matcher.names[i], str(scores)])
		expect(scores[best] - others.max() >= FitMatcher.MARGIN, "%s wins by at least the margin" % matcher.names[i])


func test_a_fit_needs_the_hold() -> void:
	var m := _matcher()
	expect_eq(m.update(m.targets[1], 0.2), -1, "0.2 s: not yet")
	expect_eq(m.update(m.targets[1], 0.2), -1, "0.4 s: not yet")
	expect_eq(m.update(m.targets[1], 0.2), 1, "0.6 s: fits")
	expect_eq(m.update(m.targets[1], 0.2), 1, "still fits")


func test_flicker_between_views_never_fits() -> void:
	var m := _matcher()
	for step in 10:
		expect_eq(m.update(m.targets[step % 2], 0.2), -1, "step %d: switching views never fits" % step)


func test_losing_the_cup_ends_the_fit() -> void:
	var m := _matcher()
	for step in 4:
		m.update(m.targets[0], 0.2)
	expect_eq(m.fit, 0, "fits first")
	var gone := 0
	for step in 5:
		if m.update(PackedByteArray(), 0.2) == -1:
			gone = step + 1
			break
	expect(gone > 0 and gone <= 2, "a missing cup ends it within 2 frames (took %d)" % gone)


func test_moving_to_another_target_switches_after_its_hold() -> void:
	var m := _matcher()
	for step in 4:
		m.update(m.targets[0], 0.2)
	var switched_at := -1
	for step in 8:
		if m.update(m.targets[2], 0.2) == 2:
			switched_at = step
			break
	expect(switched_at >= 2, "the new view must hold too (switched at frame %d)" % switched_at)


func test_tracking_is_fast_enough_to_run_live() -> void:
	var model := _model()
	var image := _photo("right")
	var box := _box("right")
	ShapeCV.track(image, box, model) # warm up
	var start := Time.get_ticks_usec()
	for i in 5:
		ShapeCV.track(image, box, model)
	var ms := (Time.get_ticks_usec() - start) / 5000.0
	print("turn_to_fit: track() %.1f ms per frame on this machine" % ms)
	expect(ms < 40.0, "under 40 ms on a desktop (%.1f ms); the Quest is slower, measure there" % ms)


## A matcher with the three captured targets (left, right, toward).
func _matcher() -> FitMatcher:
	var m := FitMatcher.new()
	for view: String in ["left", "right", "toward"]:
		m.add_target(view, ShapeCV.target_from_mask(_sam(view), _box(view)).shape)
	return m
