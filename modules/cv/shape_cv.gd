class_name ShapeCV
extends RefCounted
## Turn to fit: the computer vision, as pure functions. No scene, no camera, no
## state, so it can be tested on made-up shapes and on frames recorded on the Quest,
## and later moved to a background thread without changes.
##
## The pipeline, one camera frame to one shape:
##   [method small_gray]   crop the camera image around the cup, shrink it, keep brightness
##   [method otsu]         pick the brightness that best splits "cup" from "mat"
##   [method mask]         every pixel becomes 1 (cup) or 0 (mat)
##   [method largest_blob] keep only the biggest connected piece (drops specks)
##   [method normalise]    resize that piece to a fixed size, so distance and position don't matter
##   [method iou]          compare two shapes: 1.0 = identical, 0.0 = no overlap
## [method analyse] runs them all in order.
##
## A "mask" here is a PackedByteArray with one byte per pixel, row by row from the
## top left: 1 = object, 0 = background. Its width and height are passed alongside.

## The crop is shrunk to SMALL × SMALL pixels before any GDScript loop runs over it.
const SMALL := 80
## Every shape is normalised into a NORM_W × NORM_H box before comparing.
const NORM_W := 64
const NORM_H := 48
## A blob smaller than this share of the crop is not a cup (noise, or nothing there).
const MIN_AREA := 0.02


## Step 1. Cuts [param box] out of [param image] (pixels), turns it into brightness
## only (0..255, one byte per pixel) and shrinks it to [param size] × [param size].
## The heavy work here runs inside the engine (C++), not in GDScript.
static func small_gray(image: Image, box: Rect2i, size := SMALL) -> Image:
	var inside := box.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var crop := image.get_region(inside)
	crop.convert(Image.FORMAT_L8) # brightness, weighted like the eye (green counts most)
	crop.resize(size, size, Image.INTERPOLATE_BILINEAR) # shrinking also averages away noise
	return crop


## Step 2. Otsu's method: tries every threshold 0..255 and returns the one that
## makes the two groups (darker, brighter) most different from each other
## (largest "between-class variance"). Works when the picture is two kinds of thing,
## like a light cup on a dark mat. Pixels brighter than the result are one group.
static func otsu(gray: PackedByteArray) -> int:
	var histogram := PackedInt32Array()
	histogram.resize(256)
	for value in gray:
		histogram[value] += 1
	var total := gray.size()
	var sum_all := 0.0
	for level in 256:
		sum_all += level * histogram[level]
	var count_dark := 0
	var sum_dark := 0.0
	var best := 0.0
	var threshold := 127
	for level in 256:
		count_dark += histogram[level]
		if count_dark == 0:
			continue
		var count_bright := total - count_dark
		if count_bright == 0:
			break
		sum_dark += level * histogram[level]
		var mean_dark := sum_dark / count_dark
		var mean_bright := (sum_all - sum_dark) / count_bright
		var between := float(count_dark) * count_bright * (mean_dark - mean_bright) * (mean_dark - mean_bright)
		if between > best:
			best = between
			threshold = level
	return threshold


## Step 3. Splits the pixels at [param threshold]. Which side is the cup? The mat
## fills the crop's border, so whichever side owns most of the border is the mat,
## and the other side is the object. So it works for a light cup on a dark mat and
## for a dark cup on a light mat.
static func mask(gray: PackedByteArray, width: int, height: int, threshold: int) -> PackedByteArray:
	var bright_on_border := 0
	var border := 0
	for x in width:
		for y: int in [0, height - 1]:
			border += 1
			bright_on_border += int(gray[y * width + x] > threshold)
	for y in range(1, height - 1):
		for x: int in [0, width - 1]:
			border += 1
			bright_on_border += int(gray[y * width + x] > threshold)
	var object_is_bright := bright_on_border * 2 < border
	var out := PackedByteArray()
	out.resize(gray.size())
	for i in gray.size():
		out[i] = int((gray[i] > threshold) == object_is_bright)
	return out


## Step 4. Keeps only the biggest connected piece of the mask (pixels joined by
## their left, right, up or down neighbour), so specks and stray bits are dropped.
## Holes inside it, like the opening of a handle, stay 0 because they are mat.
## Returns: mask (the piece only), area (pixels), box (Rect2i around it), and
## touches_edge (true when the piece reaches the crop's border: the cup is not
## centred, or the "object" is really the table edge).
static func largest_blob(m: PackedByteArray, width: int, height: int) -> Dictionary:
	var label := PackedInt32Array()
	label.resize(m.size()) # 0 = not visited yet
	var best_label := 0
	var best_area := 0
	var next := 0
	# the to-do list, made once at full size (a list that grows and shrinks for every
	# pixel was the slowest part: Nov 15 timing)
	var stack := PackedInt32Array()
	stack.resize(m.size())
	for start in m.size():
		if m[start] == 0 or label[start] != 0:
			continue
		next += 1
		var area := 0
		var top := 0
		stack[top] = start
		top += 1
		label[start] = next
		while top > 0:
			top -= 1
			var i: int = stack[top]
			area += 1
			var x := i % width
			# the four neighbours: left, right, up, down (each only if inside the picture)
			if x > 0 and m[i - 1] == 1 and label[i - 1] == 0:
				label[i - 1] = next
				stack[top] = i - 1
				top += 1
			if x < width - 1 and m[i + 1] == 1 and label[i + 1] == 0:
				label[i + 1] = next
				stack[top] = i + 1
				top += 1
			if i >= width and m[i - width] == 1 and label[i - width] == 0:
				label[i - width] = next
				stack[top] = i - width
				top += 1
			if i < m.size() - width and m[i + width] == 1 and label[i + width] == 0:
				label[i + width] = next
				stack[top] = i + width
				top += 1
		if area > best_area:
			best_area = area
			best_label = next
	var out := PackedByteArray()
	out.resize(m.size())
	var lo := Vector2i(width, height)
	var hi := Vector2i(-1, -1)
	for i in m.size():
		if best_label != 0 and label[i] == best_label:
			out[i] = 1
			var p := Vector2i(i % width, i / width)
			lo = Vector2i(mini(lo.x, p.x), mini(lo.y, p.y))
			hi = Vector2i(maxi(hi.x, p.x), maxi(hi.y, p.y))
	if best_area == 0:
		return {mask = out, area = 0, box = Rect2i(), touches_edge = false}
	var box := Rect2i(lo, hi - lo + Vector2i.ONE)
	var touches := lo.x == 0 or lo.y == 0 or hi.x == width - 1 or hi.y == height - 1
	return {mask = out, area = best_area, box = box, touches_edge = touches}


## Step 5. Copies the piece inside [param box] into a NORM_W × NORM_H mask: scaled
## so it is as tall as the box allows (or as wide, if it is a wide shape), keeping
## its width-to-height ratio, and centred. Now a cup seen from 40 cm and from 60 cm,
## or a bit to the left, gives the same shape. The ratio is kept on purpose: a cup
## with its handle sideways is wider than one with the handle toward you.
static func normalise(m: PackedByteArray, width: int, box: Rect2i) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(NORM_W * NORM_H)
	if box.size.x == 0 or box.size.y == 0:
		return out
	var scale := minf(float(NORM_H) / box.size.y, float(NORM_W) / box.size.x)
	var offset := Vector2((NORM_W - box.size.x * scale) * 0.5, (NORM_H - box.size.y * scale) * 0.5)
	for y in NORM_H:
		for x in NORM_W:
			# which source pixel lands here (nearest neighbour, pixel centres)
			var sx := floori((x + 0.5 - offset.x) / scale)
			var sy := floori((y + 0.5 - offset.y) / scale)
			if sx < 0 or sy < 0 or sx >= box.size.x or sy >= box.size.y:
				continue
			out[y * NORM_W + x] = m[(box.position.y + sy) * width + box.position.x + sx]
	return out


## Step 6. Intersection over union: pixels that are 1 in both, divided by pixels
## that are 1 in either. 1.0 = the same shape, 0.0 = no overlap at all.
static func iou(a: PackedByteArray, b: PackedByteArray) -> float:
	var both := 0
	var either := 0
	for i in a.size():
		both += a[i] & b[i]
		either += a[i] | b[i]
	return float(both) / either if either > 0 else 0.0


## The mask flipped left to right (to check mirror-image look-alikes).
static func mirrored(m: PackedByteArray, width: int, height: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(m.size())
	for y in height:
		for x in width:
			out[y * width + x] = m[y * width + width - 1 - x]
	return out


## All steps for one frame. [param box] is the crop in camera pixels.
## Returns a Dictionary:
##   ok          true when a usable shape was found
##   why         when not ok: "nothing" (no blob big enough) or "edge" (touches the crop's border)
##   threshold   Otsu's brightness cut-off
##   small       the SMALL × SMALL blob mask (for the panel)
##   shape       the NORM_W × NORM_H normalised mask (for comparing)
##   area        blob share of the crop, 0..1
static func analyse(image: Image, box: Rect2i) -> Dictionary:
	var gray := small_gray(image, box)
	var pixels := gray.get_data()
	var w := gray.get_width()
	var h := gray.get_height()
	var threshold := otsu(pixels)
	var blob := largest_blob(mask(pixels, w, h, threshold), w, h)
	var area := float(blob.area) / (w * h)
	var result := {ok = false, why = "", threshold = threshold, small = blob.mask, shape = PackedByteArray(), area = area}
	if area < MIN_AREA:
		result.why = "nothing"
		return result
	if blob.touches_edge:
		result.why = "edge"
		return result
	result.shape = normalise(blob.mask, w, blob.box)
	result.ok = true
	return result


## A mask as a picture (white = object), [param width] wide, for a panel or a saved file.
static func to_image(m: PackedByteArray, width: int, height: int) -> Image:
	var bytes := PackedByteArray()
	bytes.resize(m.size())
	for i in m.size():
		bytes[i] = 255 * m[i]
	return Image.create_from_data(width, height, false, Image.FORMAT_L8, bytes)


# --- v2 (Nov 15): live tracking by the cup's own colours ------------------------------
# Brightness alone (above) fails on a real table: anything else in the crop joins the
# "cup". Instead, at capture we learn which colours belong to THIS cup (from SAM's exact
# outline) and which belong to its surroundings. Live, every pixel inside YOLO's box asks
# "is my colour more cup than surroundings?". Cheap (one table lookup per pixel), and it
# works for patterned cups, because a pattern is just more cup colours.
# Benchmarked in claude/CV_SEGMENTATION_BENCH.md: ~1 ms per frame, 0.92-0.97 vs SAM.

## Colours are sorted into BINS_H × BINS_S × BINS_V boxes (hue, saturation, value).
const BINS_H := 18
const BINS_S := 8
const BINS_V := 8
## The tracked area is shrunk so its longer side is at most this many pixels.
const TRACK_SIZE := 96


## [param box] grown by [param by] (0.1 = 10 % on every side), kept inside [param size].
static func grow(box: Rect2i, by: float, size: Vector2i) -> Rect2i:
	var pad := Vector2i(roundi(box.size.x * by), roundi(box.size.y * by))
	return Rect2i(box.position - pad, box.size + pad * 2).intersection(Rect2i(Vector2i.ZERO, size))


## Which colour box a pixel falls in (0 .. BINS_H*BINS_S*BINS_V - 1).
static func colour_bin(c: Color) -> int:
	var h := mini(int(c.h * BINS_H), BINS_H - 1)
	var s := mini(int(c.s * BINS_S), BINS_S - 1)
	var v := mini(int(c.v * BINS_V), BINS_V - 1)
	return (h * BINS_S + s) * BINS_V + v


## The area around [param box] (grown by [param by]), shrunk so its longer side is at most
## TRACK_SIZE. Returns the area (camera pixels) and the scale used. Targets and live frames
## both go through this, so their shapes are drawn with the same pixel size.
static func track_area(box: Rect2i, by: float, size: Vector2i) -> Dictionary:
	var area := grow(box, by, size)
	var scale := minf(1.0, float(TRACK_SIZE) / maxi(1, maxi(area.size.x, area.size.y)))
	return {area = area, size = Vector2i(maxi(1, roundi(area.size.x * scale)), maxi(1, roundi(area.size.y * scale)))}


## Capture, part 1: learn the cup's colours. [param image] is the camera frame,
## [param cup] SAM's outline for it (same size, white = cup), [param box] YOLO's box.
## Returns, for every possible colour, the chance that a pixel of that colour is cup (0..1),
## as a table (see [method colour_table]).
static func learn_colours(image: Image, cup: Image, box: Rect2i) -> PackedFloat32Array:
	var t := track_area(box, 0.25, image.get_size()) # a wider ring, to see more surroundings
	var pic := image.get_region(t.area)
	pic.convert(Image.FORMAT_RGB8)
	pic.resize(t.size.x, t.size.y, Image.INTERPOLATE_BILINEAR)
	var m := cup.get_region(t.area)
	m.convert(Image.FORMAT_L8)
	m.resize(t.size.x, t.size.y, Image.INTERPOLATE_NEAREST)
	var bins := BINS_H * BINS_S * BINS_V
	var on_cup := PackedFloat32Array()
	var around := PackedFloat32Array()
	on_cup.resize(bins)
	around.resize(bins)
	var px := pic.get_data()
	var mk := m.get_data()
	for i in mk.size():
		var b := colour_bin(Color8(px[3 * i], px[3 * i + 1], px[3 * i + 2]))
		if mk[i] > 127:
			on_cup[b] += 1.0
		else:
			around[b] += 1.0
	# turn counts into shares, then into "chance this colour is cup"; +0.5 so an unseen
	# colour comes out at 0.5 (undecided) instead of dividing by zero
	var cup_total := 0.0
	var around_total := 0.0
	for b in bins:
		cup_total += on_cup[b]
		around_total += around[b]
	var model := PackedFloat32Array()
	model.resize(bins)
	for b in bins:
		var p_cup := (on_cup[b] + 0.5) / (cup_total + 0.5 * bins)
		var p_around := (around[b] + 0.5) / (around_total + 0.5 * bins)
		model[b] = p_cup / (p_cup + p_around)
	return colour_table(model)


## The colour boxes, unrolled into a table with one entry per possible colour (each of
## red, green, blue cut to 32 levels: 32 × 32 × 32 = 32,768 entries). Built once at capture,
## so live tracking needs no colour maths: a pixel's entry is found straight from its bytes
## (see [method table_index]). This made the lookup ~6× faster (Nov 15 timing).
static func colour_table(model: PackedFloat32Array) -> PackedFloat32Array:
	var table := PackedFloat32Array()
	table.resize(32768)
	for i in table.size():
		# the middle of this colour's little cube of 8 × 8 × 8 shades
		var c := Color8(((i >> 10) & 31) * 8 + 4, ((i >> 5) & 31) * 8 + 4, (i & 31) * 8 + 4)
		table[i] = model[colour_bin(c)]
	return table


## Where a pixel's colour sits in [method colour_table]: the top 5 bits of red, green, blue.
static func table_index(r: int, g: int, b: int) -> int:
	return ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3)


## Live: find the cup inside [param box] (YOLO's) by colour, using the table from
## [method learn_colours]. Returns the same kind of
## Dictionary as [method analyse]: ok, why, small (blob mask), width, height, shape, area.
static func track(image: Image, box: Rect2i, model: PackedFloat32Array) -> Dictionary:
	var t := track_area(box, 0.10, image.get_size())
	var w: int = t.size.x
	var h: int = t.size.y
	var pic := image.get_region(t.area)
	pic.convert(Image.FORMAT_RGB8)
	pic.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var px := pic.get_data()
	# each pixel's chance of being cup, as a grey picture (0 = surroundings, 255 = cup)
	var chance := PackedByteArray()
	chance.resize(w * h)
	for i in chance.size():
		chance[i] = int(255.0 * model[table_index(px[3 * i], px[3 * i + 1], px[3 * i + 2])])
	# neighbours vote (removes single-pixel speckle): shrinking to half and back is a
	# blur, and the engine does it in C++ (~100× faster than a GDScript 3×3 loop)
	var votes := Image.create_from_data(w, h, false, Image.FORMAT_L8, chance)
	votes.resize(maxi(1, w / 2), maxi(1, h / 2), Image.INTERPOLATE_BILINEAR)
	votes.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var voted := votes.get_data()
	var m := PackedByteArray()
	m.resize(voted.size())
	for i in voted.size():
		m[i] = int(voted[i] > 127)
	return _shape_result(m, w, h)


## Capture, part 2: a target shape from SAM's outline, drawn at the same pixel size as
## [method track] uses, so live shapes and targets compare fairly.
static func target_from_mask(cup: Image, box: Rect2i) -> Dictionary:
	var t := track_area(box, 0.10, cup.get_size())
	var m := cup.get_region(t.area)
	m.convert(Image.FORMAT_L8)
	m.resize(t.size.x, t.size.y, Image.INTERPOLATE_NEAREST)
	var bytes := m.get_data()
	var out := PackedByteArray()
	out.resize(bytes.size())
	for i in bytes.size():
		out[i] = int(bytes[i] > 127)
	return _shape_result(out, t.size.x, t.size.y)


static func _shape_result(m: PackedByteArray, w: int, h: int) -> Dictionary:
	var blob := largest_blob(m, w, h)
	var area := float(blob.area) / (w * h)
	var result := {ok = false, why = "", small = blob.mask, width = w, height = h, shape = PackedByteArray(), area = area}
	if area < MIN_AREA:
		result.why = "nothing"
		return result
	result.shape = normalise(blob.mask, w, blob.box)
	result.ok = true
	return result


## 3 × 3 average (each pixel becomes the mean of itself and its neighbours).
static func _blur3(values: PackedFloat32Array, w: int, h: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(values.size())
	for y in h:
		for x in w:
			var sum := 0.0
			var n := 0
			for dy in range(-1, 2):
				var yy := y + dy
				if yy < 0 or yy >= h:
					continue
				for dx in range(-1, 2):
					var xx := x + dx
					if xx < 0 or xx >= w:
						continue
					sum += values[yy * w + xx]
					n += 1
			out[y * w + x] = sum / n
	return out


## The contour of a mask: object pixels with a background neighbour (left, right, up or
## down) or on the picture's edge. [param thickness] > 1 widens the line, for a panel
## seen at low acuity (CV_HANDOFF's outline ladder). Same layout as the mask.
static func outline(m: PackedByteArray, width: int, height: int, thickness := 1) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(m.size())
	for i in m.size():
		if m[i] == 0:
			continue
		var x := i % width
		var y := i / width
		if x == 0 or y == 0 or x == width - 1 or y == height - 1 \
				or m[i - 1] == 0 or m[i + 1] == 0 or m[i - width] == 0 or m[i + width] == 0:
			out[i] = 1
	for pass_index in thickness - 1: # grow the line by one pixel per pass
		var grown := out.duplicate()
		for i in out.size():
			if out[i] == 1:
				var x := i % width
				if x > 0: grown[i - 1] = 1
				if x < width - 1: grown[i + 1] = 1
				if i >= width: grown[i - width] = 1
				if i < out.size() - width: grown[i + width] = 1
		out = grown
	return out
