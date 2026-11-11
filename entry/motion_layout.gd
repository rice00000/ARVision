class_name EntryMotionLayout
extends RefCounted
## Places the story choices and keeps Onion clear of the motion cloud.

const ONION_VIEW_GAP := 4.0
const ONION_MOST_SIDEWAYS := 50.0

var layout: EntryLayout
var _half: Vector3
var _near_face: float


func _init(planned: EntryLayout, condition: TrialCondition) -> void:
	layout = planned
	_half = MotionCloud.half_size(condition)
	_near_face = MotionCloud.distance(condition) - _half.z


const CHOICE_WIDE := 0.15
const CHOICE_APART := 0.18
const CHOICE_LIFT := 0.03

## Where choice target [param i] of [param n] stands: a row on the table straight ahead, comfortably inside the reach
## (a little nearer than the reach), lying just above the table top, facing the child.
func choice_spot(i: int, n: int) -> Vector3:
	var flat := Vector3(layout.ahead.x, 0.0, layout.ahead.z).normalized()
	var across := flat.cross(Vector3.UP)
	var out := minf(layout.reach_used() - 0.08, 0.55)
	var at := layout.eye + flat * out + across * (i - (n - 1) * 0.5) * CHOICE_APART
	at.y = layout.table_y() + CHOICE_LIFT
	return at


## Onion while the choice is open and the dots play, with no shelf: beside the row, a little up, out of the dots' view.
func onion_without_shelf(n: int) -> Dictionary:
	var flat := Vector3(layout.ahead.x, 0.0, layout.ahead.z).normalized()
	var across := flat.cross(Vector3.UP)
	var last := choice_spot(0, n)
	var best := {at = last, gap = -INF}
	for out: float in [0.16, 0.2, 0.26, 0.32]:
		for up: float in [0.16, 0.1, 0.05]:
			var at := last - across * out + Vector3.UP * up
			var gap := view_gap(at, EntryLayout.ONION * 0.5)
			if absf(_yaw_of(at)) <= ONION_MOST_SIDEWAYS and gap > best.gap:
				best = {at = at, gap = gap}
			if gap >= ONION_VIEW_GAP and absf(_yaw_of(at)) <= ONION_MOST_SIDEWAYS:
				return {at = at, gap = gap}
	return best


## Angular clearance between Onion and the nearest face of the cloud.
func view_gap(point: Vector3, radius: float) -> float:
	var to := point - layout.eye
	var spread := rad_to_deg(asin(clampf(radius / to.length(), 0.0, 1.0)))
	var pitch := rad_to_deg(absf(atan2(to.y, Vector2(to.x, to.z).length())))
	var over_yaw := absf(_yaw_of(point)) - rad_to_deg(atan(_half.x / _near_face))
	var over_pitch := pitch - rad_to_deg(atan(_half.y / _near_face))
	var gap := maxf(over_yaw, over_pitch) if over_yaw < 0.0 and over_pitch < 0.0 \
			else Vector2(maxf(over_yaw, 0.0), maxf(over_pitch, 0.0)).length()
	return gap - spread


## Degrees left (negative) or right of straight ahead.
func _yaw_of(point: Vector3) -> float:
	var to := point - layout.eye
	var flat := Vector3(layout.ahead.x, 0.0, layout.ahead.z).normalized()
	return rad_to_deg(atan2(to.dot(flat.cross(Vector3.UP)), to.dot(flat)))


const COHERENCE_PRESETS := [90, 70, 50, 30, 15]
const COHERENCE_PRESET_WIDE := 0.068
const COHERENCE_STEP_WIDE := 0.11

## Place the coherence controls to the child's left.
const DEV_ANCHOR_ANGLE := 70.0
const DEV_ANCHOR_DISTANCE := 0.5


static func dev_anchor(head: Transform3D) -> Vector3:
	var flat := Vector3(-head.basis.z.x, 0.0, -head.basis.z.z).normalized()
	return head.origin + flat.rotated(Vector3.UP, deg_to_rad(DEV_ANCHOR_ANGLE)) * DEV_ANCHOR_DISTANCE


static func coherence_row(head: Transform3D, row: int) -> Vector3:
	return dev_anchor(head) + Vector3.UP * (-0.255 - 0.055 * row)


static func coherence_spot(head: Transform3D, row: int, column: int, columns: int, wide: float) -> Vector3:
	var middle := coherence_row(head, row)
	var to := Vector3(middle.x - head.origin.x, 0.0, middle.z - head.origin.z).normalized()
	var across := to.cross(Vector3.UP).normalized()
	return middle + across * (column - (columns - 1) * 0.5) * (wide + 0.008)
