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
	var stack := PackedInt32Array()
	for start in m.size():
		if m[start] == 0 or label[start] != 0:
			continue
		next += 1
		var area := 0
		stack.append(start)
		label[start] = next
		while not stack.is_empty():
			var i: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			area += 1
			var x := i % width
			var y := i / width
			for n: int in [i - 1 if x > 0 else -1, i + 1 if x < width - 1 else -1,
					i - width if y > 0 else -1, i + width if y < height - 1 else -1]:
				if n >= 0 and m[n] == 1 and label[n] == 0:
					label[n] = next
					stack.append(n)
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
