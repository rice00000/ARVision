class_name TableFinder
extends RefCounted
## The table top in the live depth (no room scan), kept honest. A table is
## believed once AGREE of the last LOOKS looks put its top within TOLERANCE
## metres of one height; from then on every look that sees its place checks it,
## and DOUBTS looks in a row that see something else there drop it, so the next
## looks find it again. That puts right a table found from a bad pose: a Quest
## that is off (on the table, being handed over) still reports the head as
## tracked, from a placeholder pose, and its depth then shows a "table" in the air.

const LOOKS := 5
const AGREE := 4
const TOLERANCE := 0.03
## A rescan must also agree on the centre before it can move the table.
const RESCAN_SPAN := 0.12
const RESCAN_PATCH := 0.15
const RESCAN_POINTS := 12
const HEIGHT_JITTER := 0.01
## Looks in a row that see the table's place but not its top before it is dropped.
const DOUBTS := 4
## A look checks the points this far (horizontally) around the table's centre...
const CHECK_RADIUS := 0.3
## ...when it sees at least this many there...
const CHECK_SEEN := 30
## ...and doubts the table when fewer than this share are at its height
## (things on it and arms resting on it keep the share well above).
const CHECK_SHARE := 0.15

## The table believed now: {centre, size, forward (horizontal)}; empty while none.
var table := {}
## Points on the fullest level in the last look while searching.
var support := 0

var _looks: Array[Dictionary] = []
var _doubts := 0


## One look from [param eye] (the head's pose): &"found" when a table is believed
## from now, &"lost" when the believed one was dropped, else &"".
func look(grid: DepthGrid, eye: Transform3D, reference: Surface = null) -> StringName:
	if not table.is_empty():
		return &"lost" if _doubted(grid) else &""
	var forward := -reference.transform.basis.z if reference else -eye.basis.z
	forward = Vector3(forward.x, 0.0, forward.z).normalized()
	var seen := grid.table(eye.origin, forward)
	support = seen.support
	_looks.append(seen)
	if _looks.size() > LOOKS:
		_looks.pop_front()
	var agreed := agreeing(_looks, AGREE, TOLERANCE, RESCAN_SPAN if reference else INF)
	if agreed.is_empty():
		return &""
	var centre: Vector3 = agreed.centre
	if reference:
		if not seen.has("centre") or not _near(seen.centre, centre, TOLERANCE, RESCAN_SPAN):
			return &""
		var previous := reference.transform.origin
		var patch := Vector3(previous.x, centre.y, previous.z)
		var observed := grid.around(patch, RESCAN_PATCH)
		if observed.y < RESCAN_POINTS:
			return &"" # an unseen patch cannot justify a sideways move
		if observed.x >= RESCAN_POINTS:
			centre = patch # the old spot is still on the top; the visible edges can change
		if absf(centre.y - previous.y) < HEIGHT_JITTER:
			centre.y = previous.y
	hold(centre, agreed.size, forward)
	return &"found"


func reset() -> void:
	table.clear()
	_looks.clear()
	_doubts = 0
	support = 0


## Believes a table found some other way (the hands on it); checked like the depth's.
func hold(centre: Vector3, size: Vector2, forward: Vector3) -> void:
	table = {centre = centre, size = size, forward = forward}
	_looks.clear()
	_doubts = 0


func _doubted(grid: DepthGrid) -> bool:
	var seen := grid.around(table.centre, CHECK_RADIUS)
	if seen.y >= CHECK_SEEN:
		_doubts = _doubts + 1 if seen.x < seen.y * CHECK_SHARE else 0
	if _doubts < DOUBTS:
		return false
	table = {}
	_doubts = 0
	return true


## The table most of [param looks] agree on: the one with the most points among
## at least [param needed] whose tops lie within [param tolerance] metres of it.
static func agreeing(looks: Array[Dictionary], needed: int, tolerance: float, span := INF) -> Dictionary:
	var best := {}
	for candidate in looks:
		if not candidate.has("centre"):
			continue
		var near := looks.filter(func(other: Dictionary) -> bool:
			return other.has("centre") and _near(other.centre, candidate.centre, tolerance, span))
		if near.size() >= needed and (best.is_empty() or candidate.support > best.support):
			best = candidate
	return best


static func _near(a: Vector3, b: Vector3, height: float, span: float) -> bool:
	return absf(a.y - b.y) <= height and Vector2(a.x - b.x, a.z - b.z).length() <= span
