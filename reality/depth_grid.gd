class_name DepthGrid
extends RefCounted
## One look at the room through the environment depth: [member size] x [member size]
## world points, row by row, [member valid] marking the pixels that saw something.
## Finds the real surface along a ray and the table top without the room scan.

## A ray gathers the points within this angle of it, degrees.
const CONE := 5.0
const MIN_HIT := 6
## Gathered points this far beyond the nearest are behind the hit surface, metres.
const SURFACE_DEPTH := 0.2
const RANGE := Vector2(0.25, 6.0)
## Table points: 0.15-0.9 m below the eyes, within 1 m around them, binned by height.
const BIN := 0.02
const MIN_TABLE := 40
## [method around] counts points this close to a height as on it, metres.
const LEVEL := 0.04
## The table's extent is measured between these shares of its area, then scaled
## back to the whole: stray points (an arm, a sleeve at the same height) do not
## stretch it. A depth pixel on a level top covers area growing with distance cubed
## (squared for the distance, once more for the slant).
const TABLE_SPAN := Vector2(0.1, 0.9)

var size: int
var points: PackedVector3Array
var valid: PackedByteArray


func _init(grid_size: int, grid_points: PackedVector3Array, grid_valid: PackedByteArray) -> void:
	size = grid_size
	points = grid_points
	valid = grid_valid


## Points that saw something.
func count() -> int:
	return valid.count(1)


## The first real surface along the ray from [param from]: {position, normal}, the
## normal facing [param from]. Empty when the depth saw nothing there.
func hit(from: Vector3, direction: Vector3) -> Dictionary:
	var cos_cone := cos(deg_to_rad(CONE))
	var near: Array[Vector2] = [] # (distance along the ray, index)
	for i in points.size():
		if not valid[i]:
			continue
		var distance := points[i].distance_to(from)
		var along := (points[i] - from).dot(direction)
		if distance > RANGE.x and distance < RANGE.y and along > distance * cos_cone:
			near.append(Vector2(along, i))
	if near.size() < MIN_HIT:
		return {}
	near.sort()
	var first := near[near.size() / 4].x # a quarter in, so a stray point does not count
	var centre := Vector3.ZERO
	var normal := Vector3.ZERO
	var used := 0
	for entry in near:
		if absf(entry.x - first) <= SURFACE_DEPTH:
			centre += points[int(entry.y)]
			normal += _normal_at(int(entry.y))
			used += 1
	centre /= used
	normal = normal.normalized() if normal.length() > 0.001 else -direction
	if normal.dot(direction) > 0.0:
		normal = -normal
	var facing := normal.dot(direction)
	# Where the ray meets the surface's plane; the points' centre when it grazes it.
	var position := from + direction * ((centre - from).dot(normal) / facing) if facing < -0.2 else centre
	return {position = position, normal = normal}


## The table top: {support} (points on the fullest level), plus {centre, size}
## once enough points agree. The size runs across and along [param forward]
## (horizontal), the way the child faces.
func table(eye: Vector3, forward: Vector3) -> Dictionary:
	var bins := {}
	for i in points.size():
		var point := points[i]
		var below := eye.y - point.y
		if not valid[i] or below < 0.15 or below > 0.9 or Vector2(point.x - eye.x, point.z - eye.z).length() > 1.0:
			continue
		var key := int(roundf(point.y / BIN))
		if not bins.has(key):
			bins[key] = PackedVector3Array()
		bins[key].append(point)
	var best := PackedVector3Array()
	for key: int in bins:
		var level: PackedVector3Array = bins[key] + bins.get(key + 1, PackedVector3Array()) # a plane spans bin edges
		if level.size() > best.size():
			best = level
	if best.size() < MIN_TABLE:
		return {support = best.size()}
	var right := forward.cross(Vector3.UP).normalized()
	var across: Array[Vector2] = [] # (position, area)
	var along: Array[Vector2] = []
	var heights := PackedFloat32Array()
	for point in best:
		var area := pow((point - eye).length(), 3.0)
		across.append(Vector2((point - eye).dot(right), area))
		along.append(Vector2((point - eye).dot(forward), area))
		heights.append(point.y)
	heights.sort()
	var width := _span(across)
	var depth := _span(along)
	var centre := eye + right * (width.x + width.y) * 0.5 + forward * (depth.x + depth.y) * 0.5
	centre.y = heights[heights.size() / 2]
	var whole := 1.0 / (TABLE_SPAN.y - TABLE_SPAN.x)
	return {support = best.size(), centre = centre,
		size = Vector2(clampf((width.y - width.x) * whole, 0.4, 1.2), clampf((depth.y - depth.x) * whole, 0.3, 0.8))}


## The positions at [constant TABLE_SPAN] of the total area; [param values] are (position, area).
static func _span(values: Array[Vector2]) -> Vector2:
	values.sort()
	var total := 0.0
	for value in values:
		total += value.y
	var span := Vector2(values[0].x, values[-1].x)
	var running := 0.0
	var low_done := false
	for value in values:
		running += value.y
		if not low_done and running >= total * TABLE_SPAN.x:
			span.x = value.x
			low_done = true
		if running >= total * TABLE_SPAN.y:
			span.y = value.x
			break
	return span


## Points around [param point] within [param radius] (horizontally): x those at its
## height (within [constant LEVEL]), y all of them at any height. A level surface
## there shows as many of the first; hands held in the air show the floor or the
## lap below instead (the depth leaves hands out).
func around(point: Vector3, radius: float) -> Vector2i:
	var found := Vector2i.ZERO
	for i in points.size():
		if valid[i] and Vector2(points[i].x - point.x, points[i].z - point.z).length() < radius:
			found.y += 1
			if absf(points[i].y - point.y) < LEVEL:
				found.x += 1
	return found


## The surface normal at a point from its four neighbours (unoriented), or zero
## at the edge, next to a hole, or across a depth jump.
func _normal_at(i: int) -> Vector3:
	var x := i % size
	var y := i / size
	if x == 0 or y == 0 or x == size - 1 or y == size - 1:
		return Vector3.ZERO
	var left := i - 1
	var right := i + 1
	var up := i - size
	var down := i + size
	if not (valid[left] and valid[right] and valid[up] and valid[down]):
		return Vector3.ZERO
	var across := points[right] - points[left]
	var along := points[down] - points[up]
	var ratio := across.length() / maxf(along.length(), 0.0001)
	if ratio > 3.0 or ratio < 1.0 / 3.0:
		return Vector3.ZERO
	return across.cross(along).normalized()
