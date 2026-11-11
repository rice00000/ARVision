extends TestCase
## Turn to fit, CV part (modules/cv/shape_cv.gd), on made-up pictures. Each test
## checks one step of the pipeline, then the last ones run it end to end on a
## drawn "cup" seen from three sides.
##   godot --headless --xr-mode off --fixed-fps 60 --path . res://tests/run.tscn -- --profile=test --only=shape_cv

const MAT := Color(0.12, 0.12, 0.12) # dark cloth
const CUP := Color(0.9, 0.88, 0.85)  # white mug


## A 160 × 120 camera-like picture: a mug drawn with rectangles on the mat.
## [param handle]: "left", "right" or "toward" (handle pointing at you: it hides
## behind the body, so the outline is a plain, slightly wider body).
func _cup_picture(handle: String, at := Vector2i(60, 30), scale := 1.0, mat := MAT, cup := CUP) -> Image:
	var image := Image.create(160, 120, false, Image.FORMAT_RGBA8)
	image.fill(mat)
	var s := func(v: int) -> int: return roundi(v * scale)
	var body := Rect2i(at, Vector2i(s.call(36), s.call(46)))
	if handle == "toward":
		body = Rect2i(at - Vector2i(s.call(3), 0), Vector2i(s.call(42), s.call(46)))
	image.fill_rect(body, cup)
	if handle != "toward":
		# a ring: outer square in cup colour, inner square back to mat = the opening
		var outer := Rect2i(Vector2i(body.end.x - s.call(2), at.y + s.call(10)), Vector2i(s.call(16), s.call(22)))
		if handle == "left":
			outer.position.x = body.position.x - s.call(14)
		image.fill_rect(outer, cup)
		image.fill_rect(outer.grow(-s.call(5)), mat)
		image.fill_rect(body, cup) # body drawn over the ring's inner edge
	return image


func _whole(image: Image) -> Rect2i:
	return Rect2i(Vector2i.ZERO, image.get_size())


func test_otsu_splits_two_levels() -> void:
	var gray := PackedByteArray()
	for i in 1000:
		gray.append(40 if i < 600 else 200)
	var t := ShapeCV.otsu(gray)
	expect(t >= 40 and t < 200, "threshold %d lies between the two levels" % t)


func test_mask_finds_the_object_whichever_is_brighter() -> void:
	var light_cup := ShapeCV.analyse(_cup_picture("right"), Rect2i(0, 0, 160, 120))
	var dark_cup := ShapeCV.analyse(_cup_picture("right", Vector2i(60, 30), 1.0, CUP, MAT), Rect2i(0, 0, 160, 120))
	expect(light_cup.ok, "light cup on dark mat found")
	expect(dark_cup.ok, "dark cup on light mat found")
	expect(light_cup.area < 0.4 and dark_cup.area < 0.4, "the object is the cup, not the mat (areas %.2f, %.2f)" % [light_cup.area, dark_cup.area])
	expect(ShapeCV.iou(light_cup.shape, dark_cup.shape) > 0.95, "same shape either way")


func test_biggest_blob_drops_specks_and_keeps_the_handle_hole() -> void:
	var image := _cup_picture("right")
	image.fill_rect(Rect2i(10, 100, 3, 3), CUP) # a speck of lint
	image.convert(Image.FORMAT_L8) # full size here, so pixel positions match the drawing
	var pixels := image.get_data()
	var m := ShapeCV.mask(pixels, 160, 120, ShapeCV.otsu(pixels))
	expect_eq(m[101 * 160 + 11], 1, "the speck is in the raw mask")
	var blob := ShapeCV.largest_blob(m, 160, 120)
	expect_eq(blob.mask[101 * 160 + 11], 0, "the speck is gone")
	expect_eq(blob.mask[50 * 160 + 80], 1, "the body stays")
	# the handle's opening: inside the ring on the right (ring x 94..110, y 40..62)
	expect_eq(blob.mask[51 * 160 + 102], 0, "the handle opening stays open")
	expect_eq(blob.mask[51 * 160 + 96], 1, "the handle itself is part of the cup")
	expect(not blob.touches_edge, "a centred cup doesn't touch the edge")


func test_a_cup_cut_off_by_the_crop_is_flagged() -> void:
	var image := _cup_picture("right", Vector2i(130, 30))
	var result := ShapeCV.analyse(image, _whole(image))
	expect(not result.ok, "not usable")
	expect_eq(result.why, "edge", "reason: touches the edge")


func test_empty_mat_finds_nothing() -> void:
	var image := Image.create(160, 120, false, Image.FORMAT_RGBA8)
	image.fill(MAT)
	var result := ShapeCV.analyse(image, _whole(image))
	expect(not result.ok, "nothing on the mat")
	expect_eq(result.why, "nothing", "reason: nothing")


func test_distance_and_position_dont_change_the_shape() -> void:
	var near := ShapeCV.analyse(_cup_picture("right", Vector2i(50, 20), 1.3), Rect2i(0, 0, 160, 120))
	var far := ShapeCV.analyse(_cup_picture("right", Vector2i(70, 40), 0.8), Rect2i(0, 0, 160, 120))
	var score := ShapeCV.iou(near.shape, far.shape)
	expect(score > 0.85, "same view, different size and place: IoU %.2f" % score)


func test_iou_self_is_one_and_mirror_is_lower() -> void:
	var right: PackedByteArray = ShapeCV.analyse(_cup_picture("right"), Rect2i(0, 0, 160, 120)).shape
	expect_eq(ShapeCV.iou(right, right), 1.0, "a shape matches itself")
	var mirror := ShapeCV.mirrored(right, ShapeCV.NORM_W, ShapeCV.NORM_H)
	expect(ShapeCV.iou(right, mirror) < 0.8, "its mirror image doesn't: %.2f" % ShapeCV.iou(right, mirror))


func test_three_views_are_told_apart() -> void:
	var views := ["left", "right", "toward"]
	var targets: Array[PackedByteArray] = []
	for view: String in views:
		targets.append(ShapeCV.analyse(_cup_picture(view), Rect2i(0, 0, 160, 120)).shape)
	# a fresh look at each view, a bit bigger and elsewhere in the picture
	for i in views.size():
		var live: PackedByteArray = ShapeCV.analyse(_cup_picture(views[i], Vector2i(55, 25), 1.15), Rect2i(0, 0, 160, 120)).shape
		var scores := targets.map(func(target: PackedByteArray) -> float: return ShapeCV.iou(live, target))
		var best := scores.find(scores.max())
		var sorted := scores.duplicate()
		sorted.sort()
		var margin: float = sorted[2] - sorted[1]
		expect_eq(views[best], views[i], "%s is recognised (scores %s)" % [views[i], str(scores)])
		expect(margin >= 0.08, "%s wins clearly: margin %.2f" % [views[i], margin])


func test_crop_box_is_clipped_to_the_picture() -> void:
	var image := _cup_picture("right")
	var gray := ShapeCV.small_gray(image, Rect2i(-20, -20, 100, 100))
	expect_eq(gray.get_size(), Vector2i(ShapeCV.SMALL, ShapeCV.SMALL), "always SMALL × SMALL")
