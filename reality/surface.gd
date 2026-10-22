class_name Surface
extends RefCounted
## A flat real surface: a table top, the floor, a wall. The frame's origin is the
## centre of the top face, +Y its normal; [member size] is the extent along X
## (width) and Z (depth). A scanned surface follows its anchor node, so it stays
## right when the headset recentres.

var kind: StringName
var size: Vector2
var transform: Transform3D:
	get:
		return _anchor.global_transform * _offset if _anchor else _offset

var _anchor: Node3D
var _offset: Transform3D


func _init(surface_kind: StringName, frame: Transform3D, extent: Vector2, anchor: Node3D = null) -> void:
	kind = surface_kind
	size = extent
	_anchor = anchor
	_offset = anchor.global_transform.affine_inverse() * frame if anchor else frame


## A world point on the top; [param u] and [param v] run -1..1 across width and depth.
func point(u: float, v: float) -> Vector3:
	return transform * Vector3(u * size.x * 0.5, 0.0, v * size.y * 0.5)


## Up to [param count] random points on the top, at least [param spacing] apart
## and [param margin] from the edges. Fewer when they do not fit.
func scatter(count: int, spacing: float, margin: float, rng: RandomNumberGenerator) -> Array[Vector3]:
	var half := (size * 0.5 - Vector2.ONE * margin).max(Vector2.ZERO)
	var points: Array[Vector3] = []
	for attempt in count * 60:
		if points.size() == count:
			break
		var candidate := transform * Vector3(rng.randf_range(-half.x, half.x), 0.0, rng.randf_range(-half.y, half.y))
		if points.all(func(other: Vector3) -> bool: return other.distance_to(candidate) >= spacing):
			points.append(candidate)
	return points
