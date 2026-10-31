class_name EntryMotionLayout
extends RefCounted
## Chat C: where the motion route's things stand. Pure geometry (no scene), built on the zone map of an
## [EntryLayout] that has been planned for the table.
##
## The dots are Wei's cloud (trials/motion/motion.tres, motion_trial.gd): a box [constant DOTS_HALF] round a
## centre [constant DOTS_DISTANCE] ahead of the eyes at EYE height (the trial's in_front() with no drop), its
## near face at least [constant DOTS_NEAR] from the eyes. Those numbers are copied here; if Wei changes them,
## change them here (the layout test checks them against motion.tres).
##
## Megan's decision: the dots do not come out of the cauldron (gone after the reveal). A compact group rises
## from behind/below the table's far edge into the open space beyond the table, as one group, and settles in
## the cloud's box. [method entrance] is that path; [method dots_zone] the box they then fill.

const DOTS_HALF := Vector3(0.8, 0.5, 0.8)
const DOTS_DISTANCE := 2.2
const DOTS_NEAR := 0.6
## The group is this wide/tall (a ball) while it rises, metres, before it spreads to the whole cloud.
const GROUP_RADIUS := 0.18
## How far behind the table's far edge, and how far below the table top, the group starts. Hidden by the table.
const START_BEHIND := 0.2
const START_BELOW := 0.3
## Seconds of the rise (the swoosh lasts about as long).
const RISE_SECONDS := 1.4

## Subtitles (Voice): [member above_horizon] degrees over the horizon, [member distance] ahead.
const SUBTITLE_ELEVATION := 20.0
const SUBTITLE_DISTANCE := 0.75

## The scene marker (DEV): head-locked, this many degrees left of straight ahead and up, this far from the eyes.
const MARKER_YAW := 34.0
const MARKER_PITCH := 18.0
const MARKER_DISTANCE := 0.75

## Onion's spot while the dots play must keep at least this many degrees of view from the dots' box.
const ONION_VIEW_GAP := 4.0
## And no farther sideways than this, degrees: the headset's view is about 55 degrees each way.
const ONION_MOST_SIDEWAYS := 50.0

var layout: EntryLayout


func _init(planned: EntryLayout) -> void:
	layout = planned


# --- The dots --------------------------------------------------------------------

## The cloud's middle, at the eyes' height, where Wei's trial puts it.
func dots_centre() -> Vector3:
	var flat := Vector3(layout.ahead.x, 0.0, layout.ahead.z).normalized()
	return layout.eye + flat * maxf(DOTS_DISTANCE, DOTS_HALF.z + DOTS_NEAR)


## The box the dots fill, as a zone (so the layout's 3D checks work on it).
func dots_zone() -> EntryLayout.Zone:
	var centre := dots_centre()
	var flat := Vector3(layout.ahead.x, 0.0, layout.ahead.z).normalized()
	var zone := layout._rect(&"dots", centre - Vector3.UP * DOTS_HALF.y, Vector2(DOTS_HALF.x, DOTS_HALF.z),
			atan2(-flat.x, -flat.z) + PI, DOTS_HALF.y * 2.0, EntryLayout.ALWAYS, "the dots, while the motion game plays")
	return zone


## How far the cloud's nearest face is from the eyes, metres (Wei's rule: at least DOTS_NEAR).
func dots_near_face() -> float:
	return layout.eye.distance_to(dots_centre()) - DOTS_HALF.z


## The table's far edge, metres from the eyes along the view direction.
func table_far_edge() -> float:
	var flat := Vector3(layout.ahead.x, 0.0, layout.ahead.z).normalized()
	var across := flat.cross(Vector3.UP)
	var best := 0.0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var corner: Vector3 = layout.table * Vector3(sx * layout.table_size.x * 0.5, 0.0, sz * layout.table_size.y * 0.5)
			best = maxf(best, (corner - layout.eye).dot(flat))
	return best


## True when the table's far edge reaches into the cloud (a deep table): the dots would then be partly
## inside the table, because Wei's cloud sits at eye height whatever the table is. Metres of overlap (0 = clear).
func table_into_dots() -> float:
	return maxf(0.0, table_far_edge() - dots_near_face())


## Where the group comes from and goes: start hidden behind/below the far edge, rise past it, ease into
## the cloud's middle. [param points] points, from the start to the middle. The whole path is clear of the
## shelf, Onion and the subtitles by construction (it starts beyond the table's far edge).
func entrance(points := 9) -> PackedVector3Array:
	var flat := Vector3(layout.ahead.x, 0.0, layout.ahead.z).normalized()
	var top := layout.table.origin.y
	var start := layout.eye + flat * (table_far_edge() + START_BEHIND)
	start.y = top - START_BELOW
	var end := dots_centre()
	var path := PackedVector3Array()
	for i in points:
		var t := float(i) / float(points - 1)
		var p := start.lerp(end, t)
		p.y = lerpf(start.y, end.y, 1.0 - pow(1.0 - t, 2.0))   # rises fast, then eases in
		path.append(p)
	return path


## The entrance as a swept zone (a ball of GROUP_RADIUS along the path) for the overlap checks.
func entrance_zone() -> EntryLayout.Zone:
	var zone := EntryLayout.Zone.new()
	zone.name = &"dots_entrance"
	zone.shape = &"path"
	zone.radius = GROUP_RADIUS
	zone.path = entrance()
	zone.phases = EntryLayout.ALWAYS
	zone.user = "the dots rise from behind the table's far edge"
	return zone


# --- What must stay clear of them --------------------------------------------------

## Degrees between the line of sight to [param point] and the nearest edge of the dots' box seen from the
## eyes (negative: the point is in front of the dots, covering some). Onion's size is [param radius].
func view_gap(point: Vector3, radius := 0.1) -> float:
	var to := point - layout.eye
	var flat := Vector3(layout.ahead.x, 0.0, layout.ahead.z).normalized()
	var across := flat.cross(Vector3.UP)
	var spread := rad_to_deg(asin(clampf(radius / maxf(to.length(), 0.01), 0.0, 1.0)))
	var yaw := rad_to_deg(absf(atan2(to.dot(across), to.dot(flat))))
	var pitch := rad_to_deg(absf(atan2(to.y, Vector2(to.x, to.z).length())))
	var near := maxf(dots_near_face(), 0.1)
	var over_yaw := yaw - rad_to_deg(atan(DOTS_HALF.x / near))   # the NEAR face: the largest the box looks
	var over_pitch := pitch - rad_to_deg(atan(DOTS_HALF.y / near))
	var gap := maxf(over_yaw, over_pitch) if (over_yaw < 0.0 and over_pitch < 0.0) \
			else Vector2(maxf(over_yaw, 0.0), maxf(over_pitch, 0.0)).length()
	return gap - spread


## Onion's spot while the dots play: the shelf scene's resting spot if it stays out of the dots' way, else
## the nearest clear spot to it along the shelf's end, out of the dots' view by [constant ONION_VIEW_GAP]
## degrees. The report says how far it is from the dots.
func onion_spot() -> Dictionary:
	var rest := layout.onion_rest
	var best := rest
	var best_gap := view_gap(rest, EntryLayout.ONION * 0.5)
	if best_gap >= ONION_VIEW_GAP:
		return {at = rest, gap = best_gap, moved = false}
	var others: Array[EntryLayout.Zone] = [layout._bench_zone(), layout._shelf_zone(), layout._things_zone()]
	for side in [-1.0, 1.0]:
		for out: float in [0.0, 0.04, 0.08, 0.12, 0.16, 0.2, 0.26, 0.32, 0.4, 0.5, 0.6]:
			for high: float in [0.05, 0.25, 0.45, 0.65, 0.85, 1.0, 1.15, 1.3]:
				var candidate: Vector3 = layout.bench * Vector3(side * (EntryLayout.SHELF_HALF + EntryLayout.ONION * 0.5 + EntryLayout.GAP + out),
						-layout.bench_below + EntryLayout.SHELF_HIGH * high, -(EntryLayout.SHELF_NEAR + EntryLayout.SHELF_FAR) * 0.5)
				var body := layout._onion(&"me", candidate, EntryLayout.SHELF, "")
				var free := true
				for other in others:
					if EntryLayout.volume_gap(body, other) < other.keeps + body.space:
						free = false
				var gap := view_gap(candidate, EntryLayout.ONION * 0.5)
				if absf(_yaw_of(candidate)) > ONION_MOST_SIDEWAYS:
					continue
				# The nearest clear spot to the resting one (the least Onion has to move).
				if free and gap >= ONION_VIEW_GAP and (best_gap < ONION_VIEW_GAP or candidate.distance_to(rest) < best.distance_to(rest)):
					best = candidate
					best_gap = gap
	return {at = best, gap = best_gap, moved = best != rest}


## Degrees left (negative) or right of straight ahead.
func _yaw_of(point: Vector3) -> float:
	var to := point - layout.eye
	var flat := Vector3(layout.ahead.x, 0.0, layout.ahead.z).normalized()
	return rad_to_deg(atan2(to.dot(flat.cross(Vector3.UP)), to.dot(flat)))


## The subtitle's place against the dots: the line is [constant SUBTITLE_DISTANCE] ahead at
## [param elevation] degrees (Voice's above_horizon; the proposal was 12). Degrees of view between it and
## the dots' box (negative: it covers dots).
func subtitle_gap(elevation := SUBTITLE_ELEVATION) -> float:
	var flat := Vector3(layout.ahead.x, 0.0, layout.ahead.z).normalized()
	var e := deg_to_rad(elevation)
	var at := layout.eye + (flat * cos(e) + Vector3.UP * sin(e)) * SUBTITLE_DISTANCE
	return view_gap(at, 0.08)


# --- The choice (the shelf is gone by then) ------------------------------------------------

const CHOICE_WIDE := 0.15
const CHOICE_APART := 0.18
const CHOICE_LIFT := 0.03

## Where choice target [param i] of [param n] stands: a row on the table straight ahead, comfortably inside the reach
## (a little nearer than the reach), lying just above the table top, facing the child. Clear of the dots' entrance
## (which is beyond the far edge) by construction.
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


# --- The DEV marker and the coherence control -------------------------------------------

## Where the scene marker (a Label3D) stands for [param head]: head-locked, top left, off the middle of the view.
static func marker_spot(head: Transform3D) -> Vector3:
	var flat := Vector3(-head.basis.z.x, 0.0, -head.basis.z.z).normalized()
	var dir := flat.rotated(Vector3.UP, deg_to_rad(MARKER_YAW))
	var tilt := deg_to_rad(MARKER_PITCH)
	return head.origin + (dir * cos(tilt) + Vector3.UP * sin(tilt)) * MARKER_DISTANCE


## The coherence control hangs under the DEV jump panel at the child's left: the readout, a row of presets
## (90 70 50 30 15 percent, [constant COHERENCE_PRESETS]), and the -5 / +5 row. [param row]: 0 readout, 1 presets, 2 steps.
const COHERENCE_PRESETS := [90, 70, 50, 30, 15]
const COHERENCE_PRESET_WIDE := 0.068
const COHERENCE_STEP_WIDE := 0.11

static func coherence_row(head: Transform3D, row: int) -> Vector3:
	return EntryLayout.dev_spot(head, false) + Vector3.UP * (-0.255 - 0.055 * row)


static func coherence_spot(head: Transform3D, row: int, column: int, columns: int, wide: float) -> Vector3:
	var middle := coherence_row(head, row)
	var across := EntryLayout._across(head, middle)
	return middle + across * (column - (columns - 1) * 0.5) * (wide + 0.008)


## The level (0 easy .. 1 hard) that shows [param percent] coherence, by Wei's axis (90 % at 0, 15 % at 1).
static func level_for(percent: float) -> float:
	return clampf((0.9 - percent / 100.0) / (0.9 - 0.15), 0.0, 1.0)


static func percent_for(level: float) -> float:
	return lerpf(90.0, 15.0, clampf(level, 0.0, 1.0))
