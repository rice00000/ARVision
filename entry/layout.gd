class_name EntryLayout
extends RefCounted
## The zone map of the opening and the shelf scene: WHERE everything stands, computed in one
## place from the measured table, the head and the child's reach (setup step 3). Every thing
## that stands on or over the table, and every panel that floats in view, gets a named [Zone]:
## its footprint seen from above (a circle, a turned rectangle or a slice of a ring around the
## eyes), its heights, the phases it is there in and who uses it.
##
## [method overlaps] reports any two zones that overlap (on the table, or in view for things that
## float in front of the eyes), with names and how much. The Entry asks this for every spot; the
## test (tests/entry_layout_test.gd) runs it for many tables and reaches; [EntryZoneOverlay]
## draws the zones on the table.
##
## No nodes, no scene: plain numbers in, spots out. Seen from the child: "left" is the child's left.

# --- The child --------------------------------------------------------------

## A seated child's view, degrees (wide, high), and how far down they look at the table.
const VIEW_WIDE := 110.0
const VIEW_HIGH := 90.0
const LOOK_DOWN := 40.0
## Easy reach when it was not measured, and the range a measured one is kept in, metres from the eyes.
const REACH_USUAL := 0.6
const REACH_MIN := 0.45
const REACH_MAX := 0.75
## The hands work this far in front of the eyes at the nearest (the chest is in the way closer in),
## this wide each side of straight ahead, and this high over the table, metres / degrees.
const HANDS_NEAR := 0.2
const HANDS_SIDE := 55.0
const HANDS_HIGH := 0.3

# --- Things (sizes match entry.gd and Wei's tidy trial) ---------------------

const CAULDRON_WIDTH := 0.22
const CAULDRON_RIM := 0.12
## Onion's size with its halo, metres across, and its body alone (measured: 6.3 x 6.7 cm, 11 cm tall,
## plus 2 mm), which is what the teaching hand must stay clear of.
const ONION := 0.13
const ONION_BODY := 0.036
const ONION_HEIGHT := 0.11
## The table panel (width, thickness, depth) and the room a hand needs over the socket.
## The socket's footprint (entry.gd PANEL): no plate any more (round 6), a recessed ring (r 6.8 cm) with the little cog
## turning just behind it: 14.4 x 18.8 cm, flat (2 mm). The node's middle is between them; the socket is SOCKET_Z toward the child.
const PANEL := Vector3(0.144, 0.002, 0.188)
const SOCKET_Z := 0.026
## The socket's hole (entry.gd SOCKET_RADIUS), metres; the brass ring is 8 mm wider.
const SOCKET_RADIUS := 0.06
const HAND_ROOM := 0.15
## The gear at playing size (radius) where it lands, plus room for the fingers around it.
const GEAR_RADIUS := 0.0525
const FINGERS := 0.03
## Wei's bench and shelf, in his frame (x across, -z ahead), metres.
const BENCH_HALF := 0.27
const BENCH_NEAR := 0.105
const BENCH_FAR := 0.405
const SHELF_HALF := 0.186
const SHELF_NEAR := 0.31
const SHELF_FAR := 0.41
const SHELF_HIGH := 0.319
const THINGS_HALF := 0.27
const THINGS_NEAR := 0.09
const THINGS_FAR := 0.33
const BENCH_HIGHEST := 0.28
const BENCH_LOWEST := 0.42
## How far back the shelf may stand (Wei's push), metres. At least PUSH_MIN, so his things never lie
## closer to the eyes than the hands can work (HANDS_NEAR) nor wider than the view (his bench is
## 54 cm wide); at most PUSH_MAX.
const PUSH_MIN := 0.1
const PUSH_MAX := 0.3
## The play set's back before the push (SHELF_AHEAD 0.31 + DEPTH 0.09).
const SHELF_BACK := 0.40
const SHELF_PUSH := 0.22

# --- Where things stand ------------------------------------------------------

## The cauldron: this many degrees left of straight ahead, this far from the eyes (or 75% of the reach).
const CAULDRON_ANGLE := 30.0
const CAULDRON_DISTANCE := 0.5
## Kept this far in from the table's edges, metres.
const TABLE_MARGIN := 0.12
## The least gap between two things on the table, metres; between something only looked at (moved
## aside after the reveal) and the rest, LOOKED_GAP.
const GAP := 0.03
const LOOKED_GAP := 0.02
## Floating panels for the grown-up: they stand this far from the eyes.
const SETUP_DISTANCE := 0.55
const SETUP_SIZE := Vector2(0.46, 0.38)   # the plate and its buttons below
const DEV_DISTANCE := 0.5

## When a zone is there: setup; the opening up to the gear seated; the reveal (the ripple shows the
## bench and shelf, Onion still aside); the shelf scene. "All set" and the dev jumps come back
## between parts, so the setup panel counts for the opening and the reveal too.
const SETUP := 1
const OPENING := 2
const REVEAL := 4
const SHELF := 8
const ALWAYS := 15
## The gear's hop (entry.gd _emerge_gear): its middle rises 6 cm over the straight line from just over the
## rim (5 cm above it) to where it lands; a ball this big holds the gear (0.6 scale: 10.5 cm wide, 4.7 tall).
const ARC_HEIGHT := 0.06
const ARC_RADIUS := 0.058
const ARC_OVER_RIM := 0.05
const GEAR_MIDDLE := 0.0235
## Parts of the opening where one teaching-hand gesture shows (with Onion at a known spot):
## the tap (Tap), the pinch (Pick up), the lowering over the socket (Set in).
const TAP := 16
const PICKUP := 32
const SETIN := 64
## The gear's flight out of the cauldron (the Gear part).
const ARC := 128
const GESTURES := TAP | PICKUP | SETIN | ARC

## The teaching hand's reach (entry/demo_hand.gd), MEASURED in the scene at DemoHand.HAND_SCALE 0.6 from
## the skeleton's bones over a whole loop, relative to the point it works on (the rim point, the gear's
## middle, the socket): to the child's RIGHT, AWAY from the child, and UP, metres (low, high). The
## index fingertip is the anchor, so the hand's body lies to the child's right and a little toward
## them. The hand scales with DemoHand.HAND_SCALE (taken here about the anchor). FINGER is added
## all round for the flesh around the bones; HAND_CLEAR is the least gap Onion keeps from it.
const HAND_TAP := {right = Vector2(0.0, 0.136), away = Vector2(-0.104, 0.028), up = Vector2(0.012, 0.234)}
const HAND_PINCH := {right = Vector2(-0.013, 0.171), away = Vector2(-0.08, 0.088), up = Vector2(-0.026, 0.128)}
const HAND_PLACE := {right = Vector2(-0.01, 0.147), away = Vector2(-0.073, 0.088), up = Vector2(-0.028, 0.178)}
const HAND_MEASURED_AT := 0.6
const FINGER := 0.012
const HAND_CLEAR := 0.01
## During the invitation in the reveal Onion floats this share of the way toward the shapes (the middle of the things
## on the bench) and back; the layout shortens it if the full share would put Onion in the shelf's, the things' or
## the bench's way.
const INVITE_FRACTION := 0.3
## Onion's offset beside the mouth (a tap's wait), metres flat from the mouth's middle: it was 7 cm to
## the child's left and a little toward them (the story chat's); the layout keeps it unless the
## hand would touch it.
const BESIDE_MOUTH := 0.13
const BESIDE_MOUTH_TURN := -0.85
const PEEK_UP := 0.06
const LIFT_UP := 0.1

## A thing on the table must not overlap another; a panel (for the grown-up) must not overlap
## anything in view nor the hands' room; an area (the hands' room) only counts against panels.
enum Kind { THING, PANEL, AREA, HAND }


class Zone:
	var name: StringName
	var kind := Kind.THING
	## The volume: &"circle" (a cylinder), &"rect" (a box, turned by [member yaw]) and &"ring" (a slice
	## of a ring round [member centre], the hands' room) are prisms: a footprint from [member centre].y
	## up [member height]. &"capsule" is a vertical capsule ([member radius] round a vertical line, [member
	## height] in all: Onion's body). &"path" is a swept sphere ([member radius] along [member path]: the
	## gear's flight). All are real 3D volumes: [method EntryLayout.volume_gap].
	var shape := &"circle"
	var centre := Vector3.ZERO       # middle of its footprint; y is its bottom
	var radius := 0.0                # circle; ring: outer
	var inner := 0.0                 # ring: inner radius
	var half := Vector2.ZERO         # rect: half width (x), half depth (z)
	var yaw := 0.0                   # rect: turn about up, radians; ring: the middle direction
	var spread := 0.0                # ring: half its angle, radians
	var height := 0.0                # top above [member centre].y
	var path := PackedVector3Array()   # path: the middle line of the swept sphere (world points)
	var phases := ALWAYS
	var user := ""                   # who uses it, in words
	## The least gap it keeps from other things on the table, metres.
	var keeps := GAP
	## Room added all round for THING pairs only (Onion's halo beyond its body), metres.
	var space := 0.0
	## Zones this one may overlap on purpose (things on the bench, the gear in its socket).
	var may_overlap: Array[StringName] = []

	func top() -> float:
		return centre.y + height

	## A prism: a footprint extruded up (circle, rect, ring), not a capsule or a swept path.
	func is_prism() -> bool:
		return shape == &"circle" or shape == &"rect" or shape == &"ring"

	## The middle line(s) of a capsule or path as [[from, to], ...]: one vertical segment for a capsule,
	## a point (a zero-length segment) every few cm along a path.
	func segments() -> Array:
		var all := []
		if shape == &"capsule":
			all.append([Vector3(centre.x, centre.y + radius, centre.z), Vector3(centre.x, centre.y + maxf(height - radius, radius), centre.z)])
		elif shape == &"path":
			for i in path.size() - 1:
				var steps := maxi(1, ceili(path[i].distance_to(path[i + 1]) / 0.02))
				for k in steps + 1:
					var at := path[i].lerp(path[i + 1], k / float(steps))
					all.append([at, at])
		return all

	## The footprint seen from above, (x, z) points, counter-clockwise or not.
	func outline() -> PackedVector2Array:
		var points := PackedVector2Array()
		match shape:
			&"path":
				for at in path:
					for i in 8:
						var a := i * TAU / 8.0
						points.append(Vector2(at.x + cos(a) * radius, at.z + sin(a) * radius))
			&"circle", &"capsule":
				for i in 24:
					var a := i * TAU / 24.0
					points.append(Vector2(centre.x + cos(a) * radius, centre.z + sin(a) * radius))
			&"rect":
				var across := Vector2(cos(yaw), -sin(yaw))   # local +x, turned
				var along := Vector2(sin(yaw), cos(yaw))     # local +z, turned
				var middle := Vector2(centre.x, centre.z)
				for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
					points.append(middle + across * corner.x * half.x + along * corner.y * half.y)
			&"ring":
				var steps := 16
				for i in steps + 1:
					var a := yaw - spread + 2.0 * spread * i / steps
					points.append(Vector2(centre.x, centre.z) + _dir(a) * radius)
				for i in steps + 1:
					var a := yaw + spread - 2.0 * spread * i / steps
					points.append(Vector2(centre.x, centre.z) + _dir(a) * inner)
		return points

	## Its corners in 3D: the footprint at its bottom and at its top (a path: round every point).
	func corners() -> Array[Vector3]:
		var all: Array[Vector3] = []
		if shape == &"path":
			for at in path:
				for i in 8:
					var a := i * TAU / 8.0
					all.append(at + Vector3(cos(a) * radius, radius, sin(a) * radius))
					all.append(at + Vector3(cos(a) * radius, -radius, sin(a) * radius))
			return all
		for p in outline():
			all.append(Vector3(p.x, centre.y, p.y))
			all.append(Vector3(p.x, top(), p.y))
		return all

	static func _dir(a: float) -> Vector2:
		# A yaw of 0 points along -z (Godot's forward); positive turns to the left.
		return Vector2(-sin(a), -cos(a))


# --- Onion's ? and ! marks (entry/onion_actions.gd reads these) --------------------------

## How tall the mark looks from the child's eyes, degrees (whatever Onion's distance): about 6
## degrees is a 5-6 cm glyph at 0.5 m, big enough for a child who sees poorly, small beside Onion.
const MARK_DEGREES := 6.0
## The gap between the top of Onion and the bottom of the mark, metres.
const MARK_ABOVE := 0.035
## The glyph's height on screen as a share of font_size * pixel_size (the bold fallback font).
const MARK_GLYPH := 0.72
const MARK_FONT_SIZE := 160
## Outline width as a share of the font size: thick enough to separate it from any room.
const MARK_OUTLINE := 0.22
## Colours. Style 0 (the story's first option): sage with a cream outline: only 2.7:1 between
## them, and a cream outline vanishes against a white wall. Style 1 (default): cream with a DARK
## sage outline: 7.7:1 between them, about 7:1 against a white wall and 9:1 against a dark room.
const MARK_SAGE := Color(0.45, 0.62, 0.48)
const MARK_CREAM := Color(0.97, 0.94, 0.85)
const MARK_DARK_SAGE := Color(0.2, 0.32, 0.22)
const MARK_STYLE := 1
## Seconds: fade in, grow (with a little overshoot), stay, fade out. Brief, no flashing.
const MARK_IN := 0.15
const MARK_GROW := 0.22
const MARK_STAY := 0.9
const MARK_OUT := 0.35


## The mark's pixel size for Onion [param distance] metres from the eyes, so it looks MARK_DEGREES tall.
static func mark_pixel_size(distance: float) -> float:
	var tall := 2.0 * distance * tan(deg_to_rad(MARK_DEGREES) * 0.5)
	return tall / (MARK_FONT_SIZE * MARK_GLYPH)


## How far above Onion's middle the mark's middle goes, for Onion [param onion_height] tall.
static func mark_lift(onion_height: float, pixel_size: float) -> float:
	return onion_height * 0.5 + MARK_ABOVE + MARK_FONT_SIZE * pixel_size * MARK_GLYPH * 0.5


## Fill and outline for [param style] (0 or 1).
static func mark_colours(style: int) -> Array[Color]:
	var colours: Array[Color] = []
	if style == 0:
		colours.append_array([MARK_SAGE, MARK_CREAM])
	else:
		colours.append_array([MARK_CREAM, MARK_DARK_SAGE])
	return colours


# --- Inputs -------------------------------------------------------------------

## The eyes at the start (after setup), and straight ahead from the seat, flat.
var eye := Vector3(0, 1.2, 0)
var ahead := Vector3.FORWARD
## The confirmed table (a real one, or the pretend patch), its size (x across, y deep).
var table := Transform3D(Basis.IDENTITY, Vector3(0, 0.72, -0.75))
var table_size := Vector2(1.2, 0.7)
var real_table := true
## The reach measured in setup step 3, metres from the eyes; 0 when it was not measured.
var reach := 0.0

# --- Results (after [method plan]) ---------------------------------------------

## Off (Megan, round 5): the panel and the gear NEVER move at the reveal. The layout finds a spot for the
## panel (and the cauldron, which is gone after the ripple) that is clear of the bench, the shelf and the
## things from the start. On: the old way, they glide to a clear spot at the reveal (Entry._make_way).
const MAKE_WAY := false   # legacy name: the default is now chosen by plan() (see [member panel_fixed])

var push := SHELF_PUSH
var cauldron_distance := CAULDRON_DISTANCE
var rim := CAULDRON_RIM
var shelf_angle := 0.0          # degrees right of straight ahead
var bench := Transform3D.IDENTITY   # Wei's bench frame: at the eyes' height, facing the shelf
var bench_below := 0.42
## The opening: the cauldron, the panel (its middle, on the table; its front +z faces the child),
## the socket, where the gear lands, where Onion waits while it comes out.
var cauldron := Vector3.ZERO
var mechanism := Vector3.ZERO
var mechanism_yaw := 0.0
var socket := Vector3.ZERO
var gear_rest := Vector3.ZERO
var onion_aside := Vector3.ZERO
## From the reveal on (the same spots as the opening's when they are clear of the bench).
var cauldron_after := Vector3.ZERO
var mechanism_after := Vector3.ZERO
var mechanism_yaw_after := 0.0
var socket_after := Vector3.ZERO
var onion_aside_after := Vector3.ZERO
## Where Onion waits beside the mouth during the tap (offset from the mouth's middle, flat, then the
## spot itself at its height), and the lifted spots: Onion's set-in spot raised, in the opening and
## after the reveal.
var onion_mouth_offset := Vector3.ZERO
var onion_mouth := Vector3.ZERO
var onion_lifted := Vector3.ZERO
var onion_lifted_after := Vector3.ZERO
## Where Onion stands while the child sets the gear in: BESIDE the socket (and the same beside the moved
## panel, when the panel glides at the reveal), and the lifted spots above it.
var onion_socket := Vector3.ZERO
var onion_socket_after := Vector3.ZERO
## The reveal: where Onion drifts to after "Welcome" (beside the cauldron's place, lifted), where it floats toward
## the shapes for the invitation, and the share of the way that is (INVITE_FRACTION, or less if that is in the way).
var onion_reveal := Vector3.ZERO
var onion_invite := Vector3.ZERO
var invite_fraction := INVITE_FRACTION
## Onion in the shelf scene, beyond the shelf's end on the cauldron's side.
var onion_rest := Vector3.ZERO
var zones: Array[Zone] = []


## The usual sim room: eyes at 1.2 m, a 1.2 x 0.7 m table 0.48 m below, centred 0.75 m ahead.
static func usual() -> EntryLayout:
	return EntryLayout.new()


## How far back the shelf stands for a measured [param reach] (0: not measured): its back at 90%
## of the reach, kept between PUSH_MIN and PUSH_MAX.
static func shelf_push(measured: float) -> float:
	return clampf(measured * 0.9 - SHELF_BACK, PUSH_MIN, PUSH_MAX) if measured > 0.0 else SHELF_PUSH


## How far out the cauldron goes for a measured [param reach] (0: not measured).
static func cauldron_out(measured: float) -> float:
	return clampf(measured * 0.75, 0.35, 0.6) if measured > 0.0 else CAULDRON_DISTANCE


## The reach used: measured and kept in range, else the usual.
func reach_used() -> float:
	return clampf(reach, REACH_MIN, REACH_MAX) if reach > 0.0 else REACH_USUAL


## The gear's hop out of the cauldron goes over the panel (only when nothing else fits).
func hops_over_panel() -> bool:
	return _arc_cost(gear_rest, _rect(&"plate", mechanism, _panel_half(), mechanism_yaw, 0.0)) >= HOP_OVER_PANEL


## The cauldron moves when the room is revealed.
func cauldron_moves() -> bool:
	return not cauldron_after.is_equal_approx(cauldron)


func mechanism_moves() -> bool:
	return not mechanism_after.is_equal_approx(mechanism)


## Works out every spot and every zone. Call again after changing an input. The panel (with the gear's
## landing spot) and the cauldron are placed TOGETHER with the shelf. First the FIXED plan (Megan: the panel
## and the gear never move at the reveal): for each shelf angle (straight ahead to the right) and each
## cauldron place the panel goes where it is clear of the bench, shelf, things, cauldron and landing spot and
## its socket is in reach, scored by overlaps, things out of reach or view, and how far the shelf turns. If
## that cannot be clean on this table (it often cannot: see DEV_NOTES), the same search is run with the panel
## allowed to glide aside at the reveal ([member make_way]) and kept only if it is clean and the fixed one is
## not ([member panel_fixed] tells which).
func plan() -> EntryLayout:
	ahead = Vector3(ahead.x, 0.0, ahead.z).normalized()
	push = shelf_push(reach)
	cauldron_distance = cauldron_out(reach)
	var fixed := _plan(false)
	panel_fixed = true
	if fixed < -0.001:
		var kept := {cauldron = cauldron, angle = shelf_angle, mechanism = mechanism}
		var glide := _plan(true)
		if glide > fixed + 0.5:
			panel_fixed = false
		else:   # the fixed plan stays: put it back
			make_way = false
			cauldron = kept.cauldron
			shelf_angle = kept.angle
			bench = bench_frame(shelf_angle)
			mechanism = kept.mechanism
			_finish()
	return self


## One search, the panel fixed ([param way] false) or gliding ([param way] true). Returns its score
## (0: clean). Leaves the best plan in place.
func _plan(way: bool) -> float:
	make_way = way
	var angles: Array = [0.0] if not real_table else SHELF_ANGLES
	var candidates := []
	for out: float in [cauldron_distance, reach_used() + 0.09]:
		if not candidates.is_empty() and _best_quick(candidates) > -3.0:
			break   # the nearer cauldron already works: no need to try the farther one
		for bearing_left: float in CAULDRON_BEARINGS:
			cauldron = _cauldron_spot(out, -bearing_left)
			for angle: float in angles:
				shelf_angle = angle
				bench = bench_frame(angle)
				_place_mechanism()
				var cauldron_view := absf(bearing_left) + rad_to_deg(atan2(CAULDRON_WIDTH * 0.5, out)) - VIEW_WIDE * 0.5
				var quick := _mech_score - maxf(cauldron_view, 0.0) * 0.3 - angle * 0.02 - absf(bearing_left - CAULDRON_ANGLE) * 0.01
				candidates.append({q = quick, cauldron = cauldron, angle = angle, mechanism = mechanism})
	candidates.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.q > y.q)
	var best := {}
	var best_score := -INF
	for c in candidates.slice(0, 4):   # only the best few get the full (slow) check
		cauldron = c.cauldron
		shelf_angle = c.angle
		bench = bench_frame(shelf_angle)
		mechanism = c.mechanism
		_finish()
		var score := _problems()
		if score - shelf_angle * 0.02 > best_score:
			best_score = score - shelf_angle * 0.02
			best = c
	cauldron = best.cauldron
	shelf_angle = best.angle
	bench = bench_frame(shelf_angle)
	mechanism = best.mechanism
	_finish()
	return _problems()


func _best_quick(candidates: Array) -> float:
	var best := -INF
	for c: Dictionary in candidates:
		best = maxf(best, c.q)
	return best


## The panel stays where it is through the reveal and the first visit (the plan found a clear spot for it);
## false: this table has no such spot, the panel glides aside at the reveal (Entry._make_way).
var panel_fixed := true
## While planning: let the panel glide aside at the reveal (false: it must be clear of the bench from the start).
var make_way := false
var _mech_score := 0.0


## The shelf may turn this many degrees to the right of straight ahead (Wei's table point moves there), and
## the cauldron may stand this many degrees to the left (the usual CAULDRON_ANGLE first).
## How much farther than the EASY reach the socket may be (5 cm: the measured reach is what feels easy, not the
## limit; the gear is set in once).
static var socket_stretch := 0.05
const SHELF_ANGLES := [0.0, 10.0, 20.0, 30.0]
const CAULDRON_BEARINGS := [30.0, 0.0, -20.0, 50.0]


## Minus how bad the plan is: overlaps, things out of view or out of reach (0: none).
func _problems() -> float:
	var bad := 0.0
	for o in overlaps():
		bad += 10.0 + (o.amount * 100.0 if o.how == "on the table" else o.amount)
	for o in out_of_view():
		bad += 5.0 + o.degrees
	for o in out_of_reach():
		bad += 5.0 + o.metres * 100.0
	if hops_over_panel():
		bad += 4.0
	return -bad


## The cauldron's real height: the top at [param spot] (from depth) and its rim [param height]
## (measured on the model). Moves everything standing on the table up or down with it.
func set_cauldron(spot: Vector3, height: float) -> void:
	var lift := spot.y - cauldron.y
	cauldron.y += lift
	mechanism.y += lift
	rim = height
	_finish()


## Everything that follows from the cauldron, the panel and the bench.
func _finish() -> void:
	mechanism_yaw = _facing(mechanism)
	socket = _socket_of(mechanism, mechanism_yaw)
	gear_rest = _gear_rest_for(mechanism)
	onion_aside = _onion_aside(cauldron, mechanism)
	cauldron_after = cauldron
	mechanism_after = mechanism
	if make_way:   # the cauldron never moves (it sinks away); only the socket slides, on its own track (Entry._make_way)
		var plate := _rect(&"probe", mechanism, _panel_half(), mechanism_yaw, HAND_ROOM)
		var pot := _circle(&"pot", cauldron_after, CAULDRON_WIDTH * 0.5, rim)
		if not _clear_of_bench(plate, LOOKED_GAP) or gap(plate, pot) < LOOKED_GAP:
			mechanism_after = _clear_spot(mechanism, plate, [pot])
	cauldron_after.y = cauldron.y
	mechanism_after.y = mechanism.y
	mechanism_yaw_after = _facing(mechanism_after)
	socket_after = _socket_of(mechanism_after, mechanism_yaw_after)
	onion_aside_after = _onion_aside(cauldron_after, mechanism_after)
	onion_socket = _onion_beside_socket(mechanism, mechanism_yaw, socket)
	onion_socket_after = _onion_beside_socket(mechanism_after, mechanism_yaw_after, socket_after)
	onion_reveal = onion_aside_after + Vector3.UP * LIFT_UP
	_plan_invitation()
	onion_lifted = onion_socket + Vector3.UP * LIFT_UP
	onion_lifted_after = onion_socket_after + Vector3.UP * LIFT_UP
	onion_mouth_offset = _onion_mouth_offset()
	onion_mouth = _mouth_point() + Vector3.UP * PEEK_UP + onion_mouth_offset
	onion_rest = _onion_rest()
	zones = _zones()


func _facing(p: Vector3) -> float:
	return atan2(eye.x - p.x, eye.z - p.z)


func _socket_of(p: Vector3, yaw: float) -> Vector3:
	return p + Basis(Vector3.UP, yaw) * Vector3(0, PANEL.y, SOCKET_Z)


func _panel_half() -> Vector2:
	return Vector2(PANEL.x, PANEL.z) * 0.5


## The table top's height.
func table_y() -> float:
	return table.origin.y


## A direction [param degrees] right of straight ahead (negative: left).
func toward(degrees: float) -> Vector3:
	return ahead.rotated(Vector3.UP, -deg_to_rad(degrees))


## Wei's bench frame if the shelf faced [param angle] degrees right: at the eyes, pushed back by
## [member push], facing the shelf. Its top is [member bench_below] below.
func bench_frame(angle: float) -> Transform3D:
	var facing := toward(angle)
	bench_below = clampf(eye.y - table_y() - 0.01, BENCH_HIGHEST, BENCH_LOWEST)
	return Transform3D(Basis.looking_at(facing), eye + facing * push)


## Where on the bench frame [param point] lies: x across, -z ahead.
func on_bench(point: Vector3, frame := bench) -> Vector3:
	return frame.affine_inverse() * point


## Seen from above, metres from the eyes.
func away(point: Vector3) -> float:
	return Vector2(point.x - eye.x, point.z - eye.z).length()


## Degrees right of straight ahead (negative: left), seen from above.
func bearing(point: Vector3) -> float:
	var flat := Vector3(point.x - eye.x, 0.0, point.z - eye.z)
	return -rad_to_deg(ahead.signed_angle_to(flat.normalized(), Vector3.UP))


func _on_table(point: Vector3, margin: float) -> Vector3:
	var local := table.affine_inverse() * point
	var half := (table_size * 0.5 - Vector2.ONE * margin).max(Vector2.ZERO)
	local.x = clampf(local.x, -half.x, half.x)
	local.z = clampf(local.z, -half.y, half.y)
	local.y = 0.0
	return table * local


func _inside_table(point: Vector3, margin: float) -> bool:
	var local := table.affine_inverse() * point
	return absf(local.x) <= table_size.x * 0.5 - margin and absf(local.z) <= table_size.y * 0.5 - margin


func _on_the_table(z: Zone) -> bool:
	for q in z.outline():
		if not _inside_table(Vector3(q.x, table_y(), q.y), 0.01):
			return false
	return true


## The cauldron: CAULDRON_ANGLE left, [member cauldron_distance] out, on the table and
## [constant TABLE_MARGIN] in from its edges (the pretend table too).
func _cauldron_spot(out := cauldron_distance, bearing_deg := -CAULDRON_ANGLE) -> Vector3:
	var spot := _on_table(eye + toward(bearing_deg) * out, TABLE_MARGIN)
	spot.y = table_y()
	return spot


## The shelf's angle: Wei's things and shelf in view (his bench is wide and starts close to the
## eyes, so it can only turn a little), clear of the cauldron if it can, nearest straight ahead.
## Only with a real table (the pretend one keeps it straight ahead).
func _shelf_angle() -> float:
	if not real_table:
		return 0.0
	var pot := _circle(&"probe", cauldron, CAULDRON_WIDTH * 0.5, 0.0)
	var best := 0.0
	var best_score := -INF
	for angle in range(-10, 35, 5):
		bench = bench_frame(angle)
		var view := 0.0
		for z in [_things_zone(), _shelf_zone()]:
			var box := in_view(z)
			view += maxf(maxf(-VIEW_WIDE * 0.5 - box.position.x, box.end.x - VIEW_WIDE * 0.5), 0.0)
		var clash := maxf(-gap(_bench_zone(), pot), 0.0) + maxf(-gap(_things_zone(), pot), 0.0)
		var score := -view * 2.0 - (2.0 if view > 0.0 else 0.0) - clash * (5.0 if make_way else 50.0) - absf(angle) * 0.02
		if score > best_score:
			best_score = score
			best = angle
	return best


func _bench_zone(phases := REVEAL | SHELF) -> Zone:
	var middle := bench * Vector3(0, 0, -(BENCH_NEAR + BENCH_FAR) * 0.5)
	var top := eye.y - bench_below
	middle.y = minf(table_y(), top - 0.012)
	var z := _rect(&"bench", middle, Vector2(BENCH_HALF, (BENCH_FAR - BENCH_NEAR) * 0.5), _yaw_of(bench), top - middle.y, phases, "Wei's bench: the things lie on it")
	z.may_overlap = [&"shelf", &"things"]
	return z


func _shelf_zone(phases := REVEAL | SHELF) -> Zone:
	var middle := bench * Vector3(0, -bench_below, -(SHELF_NEAR + SHELF_FAR) * 0.5)
	var z := _rect(&"shelf", middle, Vector2(SHELF_HALF, (SHELF_FAR - SHELF_NEAR) * 0.5), _yaw_of(bench), SHELF_HIGH, phases, "the cubbies with the shapes")
	z.may_overlap = [&"bench", &"things"]   # Wei's: the things lie just in front of it
	return z


func _things_zone(phases := SHELF) -> Zone:
	var middle := bench * Vector3(0, -bench_below, -(THINGS_NEAR + THINGS_FAR) * 0.5)
	var z := _rect(&"things", middle, Vector2(THINGS_HALF, (THINGS_FAR - THINGS_NEAR) * 0.5), _yaw_of(bench), HAND_ROOM, phases, "the things to tidy, and the hands picking them up")
	z.may_overlap = [&"bench", &"shelf"]
	return z


## True when [param z] stands clear of the bench, the shelf and the things.
func _clear_of_bench(z: Zone, keep := GAP) -> bool:
	return gap(z, _bench_zone()) >= keep and gap(z, _shelf_zone()) >= keep and gap(z, _things_zone()) >= keep


## The panel in the opening: on the table, socket in easy reach, in view, clear of the cauldron;
## near the middle and near the cauldron (a short carry). A spot that is also clear of the bench
## wins if there is one (then nothing has to move at the reveal).
func _place_mechanism() -> void:
	var ctx := {
		hands = reach_used(),
		pot = _circle(&"pot", cauldron, CAULDRON_WIDTH * 0.5, 0.0),
		bench_zones = [_bench_zone(), _shelf_zone(), _things_zone()],
		beside = _circle(&"beside", cauldron + _onion_mouth_offset(), ONION * 0.5, 0.0),   # where Onion waits for the tap
		best_score = -INF, best_at = Vector3.ZERO, best_angle = 0, best_distance = 0.0,
	}
	for angle in range(-60, 65, 10):   # coarse first, then a closer look round the best
		for distance: float in [0.32, 0.42, 0.52, 0.62, 0.72, 0.82]:
			_try_panel(angle, distance, ctx)
	if ctx.best_score > -INF:
		var angle0: int = ctx.best_angle
		var distance0: float = ctx.best_distance
		for da in [-10, -5, 0, 5, 10]:
			for dd: float in [-0.1, -0.05, 0.0, 0.05, 0.1]:
				if da != 0 or dd != 0.0:
					_try_panel(angle0 + da, distance0 + dd, ctx)
	if ctx.best_score == -INF:   # a very small table: the middle of it
		mechanism = _on_table(eye + ahead * 0.42, 0.0)
		ctx.best_score = -100.0
	else:
		mechanism = ctx.best_at
	_mech_score = ctx.best_score
	mechanism.y = cauldron.y


## Scores a panel at [param angle] degrees, [param distance] m out (higher is better) and keeps it in [param ctx]
## if it is the best so far: on the table, the socket in reach, in view, clear of the cauldron, Onion's tap
## spot, the bench (when fixed) and with room for the gear to land.
func _try_panel(angle: int, distance: float, ctx: Dictionary) -> void:
	var hands: float = ctx.hands
	if distance - SOCKET_Z > hands + 0.12 + socket_stretch:
		return   # far out of reach: never worth the time
	var p := eye + toward(angle) * distance
	p.y = table_y()
	var plate := _rect(&"plate", p, _panel_half(), _facing(p), 0.0)
	if not _on_the_table(plate):
		return   # it lies on the table, not hanging off its edge
	var view := absf(angle) + rad_to_deg(atan2(PANEL.x * 0.5, distance)) - VIEW_WIDE * 0.5
	var score := -maxf(view, 0.0) * 0.2
	var clear := minf(gap(plate, ctx.pot), gap(plate, ctx.beside))
	var bench_clear := INF
	for z: Zone in ctx.bench_zones:
		bench_clear = minf(bench_clear, gap(plate, z))
	if not make_way:   # it stays through the reveal and the first visit: clear of the bench too
		clear = minf(clear, bench_clear)
	if distance - SOCKET_Z > hands + 0.02 + socket_stretch:   # the socket must be in easy reach
		score -= 15.0 + (distance - SOCKET_Z - hands) * 20.0
	score += 0.5 if make_way and bench_clear >= LOOKED_GAP else 0.0
	score -= absf(angle) * 0.004 + absf(distance - 0.42) * 0.5 + p.distance_to(cauldron) * 0.5
	score += 0.0 if clear >= GAP else -30.0 + clear
	if clear >= GAP and score > ctx.best_score:   # only now the gear's landing spot (the slow part)
		var spot := _gear_rest_for(p)
		var landing := _circle(&"landing", spot, GEAR_RADIUS + FINGERS, 0.0)
		var room := minf(minf(gap(landing, plate), gap(landing, ctx.pot)), gap(landing, ctx.beside))
		if not make_way:
			room = minf(room, minf(gap(landing, ctx.bench_zones[0]), gap(landing, ctx.bench_zones[2])))
		score -= _arc_cost(spot, plate)
		if away(spot) - GEAR_RADIUS - FINGERS > hands + 0.02:   # the gear's near side must be in reach
			score -= 15.0 + (away(spot) - hands) * 20.0
		score += 0.0 if room >= GAP else -30.0 + room
	if score > ctx.best_score:
		ctx.best_score = score
		ctx.best_at = p
		ctx.best_angle = angle
		ctx.best_distance = distance


## A clear spot for [param z] (a zone standing at [param from]) from the reveal on: on the table,
## in view, clear of the bench, the shelf, the things and [param others], nearest where it was,
## and if it must, out of reach (it is only looked at then).
func _clear_spot(from: Vector3, z: Zone, others: Array) -> Vector3:
	var best := from
	var best_score := -INF
	var saved := z.centre
	for angle in range(-55, 60, 5):
		for step in 25:
			var distance := 0.35 + step * 0.025
			var p := eye + toward(angle) * distance
			p.y = from.y
			z.centre = p
			if z.shape == &"rect":
				z.yaw = _facing(p)
			if not _on_the_table(z):
				continue
			var clear := minf(gap(z, _bench_zone()), minf(gap(z, _shelf_zone()), gap(z, _things_zone())))
			for other: Zone in others:
				clear = minf(clear, gap(z, other))
			var view := in_view(z)
			var outside := maxf(maxf(-VIEW_WIDE * 0.5 - view.position.x, view.end.x - VIEW_WIDE * 0.5), 0.0)
			var score := (0.0 if clear >= LOOKED_GAP else -10.0 + clear) - outside * 0.1 - Vector2(p.x - from.x, p.z - from.z).length()
			if score > best_score:
				best_score = score
				best = p
	z.centre = saved
	return best


## Where the gear lands: on the table, in view and in reach, clear of the cauldron and the panel;
## near the socket (a short carry) and not far from the cauldron (it arcs out of it).
func _gear_rest_for(panel: Vector3, steps := 16) -> Vector3:
	var plate := _rect(&"plate", panel, _panel_half(), _facing(panel), 0.0)
	var pot := _circle(&"pot", cauldron, CAULDRON_WIDTH * 0.5, 0.0)
	var landing := _circle(&"landing", cauldron, GEAR_RADIUS + FINGERS, 0.0)
	var hands := reach_used()
	var best := cauldron
	var best_score := -INF
	var plate_socket := _socket_of(panel, _facing(panel))
	var spread := 100.0 / steps
	for i in steps + 1:
		var angle := -50.0 + i * spread
		for distance: float in [0.26, 0.31, 0.36, 0.41, 0.46, 0.51, 0.56, 0.61]:
			var spot := eye + toward(angle) * distance
			spot.y = cauldron.y
			landing.centre = spot
			var clear := minf(gap(landing, plate), gap(landing, pot))
			var score := (0.0 if clear >= GAP else -10.0 + clear)
			if not _inside_table(spot, GEAR_RADIUS):
				score -= 20.0
			var side := absf(angle) + rad_to_deg(atan2(GEAR_RADIUS + FINGERS, distance)) - VIEW_WIDE * 0.5
			if side > 0.0:
				score -= 5.0 + side
			if distance > hands - 0.03:
				score -= 5.0 + (distance - hands) * 20.0
			score -= Vector2(spot.x - plate_socket.x, spot.z - plate_socket.z).length()
			score -= _arc_cost(spot, plate)
			if score > best_score:
				best_score = score
				best = spot
	return Vector3(best.x, cauldron.y, best.z)


## What the gear's flight out of the cauldron to [param spot] costs: more than 30 cm is long (it is
## a little hop), and flying over the panel [param plate] (over the socket, before the child has
## even picked it up) is not allowed.
const HOP_OVER_PANEL := 3.0


func _arc_cost(spot: Vector3, plate: Zone) -> float:
	var from := Vector2(cauldron.x, cauldron.z)
	var to := Vector2(spot.x, spot.z)
	var cost := maxf(from.distance_to(to) - 0.3, 0.0) * 1.0
	var outline := plate.outline()
	for i in outline.size():
		if Geometry2D.segment_intersects_segment(from, to, outline[i], outline[(i + 1) % outline.size()]) != null:
			return cost + HOP_OVER_PANEL
	# It does not cross the panel; the ball (the gear, 5.8 cm) must also keep clear of its edge.
	var point := Zone.new()
	var near := INF
	for k in 6:
		var at := from.lerp(to, k / 5.0)
		point.centre = Vector3(at.x, 0.0, at.y)
		near = minf(near, gap(point, plate))
	return cost + maxf(ARC_RADIUS + GAP - near, 0.0) * 30.0


## Onion while the gear comes out: beside [param pot], above the rim, in view, clear of [param panel]
## and of the gear's landing spot, as far from the panel as that allows, a little toward the child.
func _onion_aside(pot: Vector3, panel: Vector3) -> Vector3:
	var plate := _rect(&"plate", panel, _panel_half(), _facing(panel), 0.0)
	var landing := _circle(&"landing", gear_rest, GEAR_RADIUS + FINGERS, 0.0)
	var to_panel := Vector3(panel.x - pot.x, 0.0, panel.z - pot.z).normalized()
	var to_child := Vector3(eye.x - pot.x, 0.0, eye.z - pot.z).normalized()
	var best := pot
	var best_score := -INF
	for step in 16:
		var dir := Vector3(sin(step * TAU / 16.0), 0.0, cos(step * TAU / 16.0))
		var spot := pot + dir * (CAULDRON_WIDTH * 0.5 + ONION * 0.5 + GAP + 0.01)
		spot.y = pot.y + rim + ONION * 0.5 + 0.04
		var me := _circle(&"me", spot, ONION * 0.5, 0.0)
		var clear := minf(gap(me, plate), gap(me, landing))
		var box := in_view(_circle(&"me", spot - Vector3.UP * ONION * 0.5, ONION * 0.5, ONION))
		var outside := maxf(maxf(-VIEW_WIDE * 0.5 - box.position.x, box.end.x - VIEW_WIDE * 0.5), 0.0)
		var score := (0.0 if clear >= GAP else -10.0 + clear) - outside - dir.dot(to_panel) * 0.5 + dir.dot(to_child) * 0.2
		if score > best_score:
			best_score = score
			best = spot
	return best


## The middle of the things on the bench, at table height: where Onion looks and floats toward in the reveal.
func things_centre() -> Vector3:
	var middle := bench * Vector3(0, -bench_below, -(THINGS_NEAR + THINGS_FAR) * 0.5)
	return middle


## Onion's float toward the shapes: as far as INVITE_FRACTION of the way from [member onion_reveal] to the things'
## middle, but never closer than its body and halo allow to the bench, shelf and things (as 3D volumes).
func _plan_invitation() -> void:
	var target := things_centre()
	var goal := Vector3(target.x, onion_reveal.y, target.z)
	var things := _things_zone()
	things.height = 0.1   # the things themselves (not the hands' room above them: no hands are at work in the reveal)
	var others: Array[Zone] = [_bench_zone(), _shelf_zone(), things]
	invite_fraction = INVITE_FRACTION
	while invite_fraction > 0.0:
		var spot := onion_reveal.lerp(goal, invite_fraction)
		var body := _onion(&"probe", spot, REVEAL, "")
		var clear := true
		for other in others:
			# along the whole float, not just where it ends
			for k in 5:
				body.centre = onion_reveal.lerp(spot, k / 4.0) - Vector3.UP * ONION_HEIGHT * 0.5
				if volume_gap(body, other) < minf(other.keeps, GAP) + body.space:
					clear = false
		if clear:
			break
		invite_fraction = maxf(invite_fraction - 0.05, 0.0)
	onion_invite = onion_reveal.lerp(goal, invite_fraction)


## The middle of the cauldron's opening (the brew), 1.3 cm below the rim (measured).
func _mouth_point() -> Vector3:
	return cauldron + Vector3.UP * (rim - 0.013)


## The front of the cauldron's rim, where a tap goes (as Entry._rim_point).
func rim_point() -> Vector3:
	var to_child := Vector3(eye.x - cauldron.x, 0.0, eye.z - cauldron.z).normalized()
	return cauldron + Vector3.UP * rim + to_child * (CAULDRON_WIDTH * 0.35)


## The teaching hand's zone for [param gesture] (&"tap", &"pinch", &"place") working at [param anchor]:
## the box its bones sweep (EntryLayout.HAND_*) plus the flesh, turned as the child sees it from the
## eyes, its heights above the anchor. [param phase] when it shows.
func hand_zone(gesture: StringName, anchor: Vector3) -> Zone:
	var reach: Dictionary = {tap = HAND_TAP, pinch = HAND_PINCH, place = HAND_PLACE}[gesture]
	var k: float = DemoHand.HAND_SCALE / HAND_MEASURED_AT
	var right: Vector2 = (reach.right as Vector2) * k
	var along: Vector2 = (reach.away as Vector2) * k   # away from the child
	var up: Vector2 = (reach.up as Vector2) * k
	var yaw := _facing(anchor)
	var middle := Vector3(anchor.x, 0.0, anchor.z) + Basis(Vector3.UP, yaw) * Vector3((right.x + right.y) * 0.5, 0.0, -(along.x + along.y) * 0.5)
	middle.y = anchor.y + up.x
	var phase: int = {tap = TAP, pinch = PICKUP, place = SETIN}[gesture]
	var z := _rect(StringName("hand_" + String(gesture)), middle, Vector2((right.y - right.x) * 0.5 + FINGER, (along.y - along.x) * 0.5 + FINGER), yaw, up.y - up.x, OPENING | phase, "the teaching hand's sweep: Onion stays clear")
	z.kind = Kind.HAND
	return z


## Onion beside the mouth during the tap: the story chat's offset (BESIDE_MOUTH to the child's left,
## a little toward them) unless the hand would come within HAND_CLEAR of Onion's body; then the
## nearest clear spot round the mouth.
func _onion_mouth_offset() -> Vector3:
	var to_child := Vector3(eye.x - cauldron.x, 0.0, eye.z - cauldron.z).normalized()
	var wanted := to_child.rotated(Vector3.UP, BESIDE_MOUTH_TURN) * BESIDE_MOUTH
	var hand := hand_zone(&"tap", rim_point())
	var best := wanted
	var best_score := -INF
	for step in 25:   # step 0: as wanted
		for r: float in [BESIDE_MOUTH, BESIDE_MOUTH + 0.01, BESIDE_MOUTH + 0.02, BESIDE_MOUTH - 0.01]:
			var off := wanted if step == 0 and r == BESIDE_MOUTH else to_child.rotated(Vector3.UP, (step - 1) * TAU / 24.0) * r
			var body := _circle(&"body", cauldron + off, ONION_BODY, 0.0)
			var clear := gap(body, hand) - HAND_CLEAR
			var score := (0.0 if clear >= 0.0 else -10.0 + clear) - (off - wanted).length() * 5.0
			if score > best_score:
				best_score = score
				best = off
	return best


## Onion BESIDE the socket of the panel at [param plate] (turned [param yaw], socket at [param at]): the
## nearest spot to the socket, 11 to 26 cm out, that is clear of the panel's plate, the gear's landing
## spot, the cauldron, the teaching hand's lowering (the hand's body lies to the child's right, so Onion
## ends on the left or behind), the bench, shelf and things, and in view; a little toward the child
## preferred; at about 9 cm above the table.
func _onion_beside_socket(plate: Vector3, yaw: float, at: Vector3) -> Vector3:
	var plate_zone := _rect(&"plate", plate, _panel_half(), yaw, HAND_ROOM)
	var landing := _circle(&"landing", gear_rest, GEAR_RADIUS + FINGERS, HAND_ROOM)
	var pot := _circle(&"pot", cauldron, CAULDRON_WIDTH * 0.5, rim)
	var hand := hand_zone(&"place", at + Vector3.UP * 0.014)
	var zones_near: Array[Zone] = [_bench_zone(), _shelf_zone(), _things_zone()]
	var y := table_y() + 0.09 + ONION_HEIGHT * 0.5
	var best := at + Vector3.UP * 0.12
	var best_score := -INF
	for step in 24:
		for r: float in [0.11, 0.14, 0.17, 0.20, 0.23, 0.26]:
			var dir := Vector3(sin(step * TAU / 24.0), 0.0, cos(step * TAU / 24.0))
			var spot := Vector3(at.x, y, at.z) + dir * r
			var me := _circle(&"me", Vector3(spot.x, 0.0, spot.z), ONION * 0.5, 0.0)
			var clear := minf(gap(me, plate_zone), minf(gap(me, landing), gap(me, pot)))
			for z in zones_near:
				clear = minf(clear, gap(me, z))
			var body := Zone.new()
			body.shape = &"capsule"
			body.centre = spot - Vector3.UP * ONION_HEIGHT * 0.5
			body.radius = ONION_BODY
			body.height = ONION_HEIGHT
			var hand_clear := volume_gap(body, hand) - HAND_CLEAR
			var box := in_view(_circle(&"me", Vector3(spot.x, table_y(), spot.z), ONION * 0.5, ONION_HEIGHT + 0.09))
			var outside := maxf(maxf(-VIEW_WIDE * 0.5 - box.position.x, box.end.x - VIEW_WIDE * 0.5), 0.0)
			var score := (0.0 if clear >= GAP else -10.0 + clear) + (0.0 if hand_clear >= 0.0 else -10.0 + hand_clear) - outside * 0.5 - r * 4.0
			score -= absf(spot.y - y) * 0.0 + (dir.dot(Vector3(eye.x - at.x, 0.0, eye.z - at.z).normalized()) * -0.1)   # toward the child a touch
			if score > best_score:
				best_score = score
				best = spot
	return best


## Onion in the shelf scene: just beyond the shelf's end on the cauldron's side, high up beside the
## shelf, as far back as the shelf: never over a cubby, the things or the panel. If that is taken,
## up over the cauldron.
func _onion_rest() -> Vector3:
	var side := -1.0 if on_bench(cauldron_after).x < 0.0 else 1.0
	var others: Array[Zone] = [_bench_zone(), _shelf_zone(), _things_zone()]
	var spot := bench * Vector3(side * (SHELF_HALF + ONION * 0.5 + GAP + 0.04), -bench_below + SHELF_HIGH * 0.85, -(SHELF_NEAR + SHELF_FAR) * 0.5)
	for out: float in [0.04, 0.08, 0.12, 0.16]:   # a little farther along, and higher, until it is clear in 3D
		for high: float in [0.85, 1.0, 1.15]:
			var candidate := bench * Vector3(side * (SHELF_HALF + ONION * 0.5 + GAP + out), -bench_below + SHELF_HIGH * high, -(SHELF_NEAR + SHELF_FAR) * 0.5)
			var body := _onion(&"me", candidate, SHELF, "")
			var free := true
			for other in others:
				if volume_gap(body, other) < other.keeps + body.space:
					free = false
			if free:
				return candidate
			spot = candidate
	return spot


static func _yaw_of(frame: Transform3D) -> float:
	# The frame looks along -z; its yaw is that of +z, the direction back toward the eyes.
	var back := frame.basis.z
	return atan2(back.x, back.z)


# --- Zones ---------------------------------------------------------------------

func _zones() -> Array[Zone]:
	var all: Array[Zone] = []
	var after := REVEAL | SHELF
	# The cauldron is there for the opening only; it sinks away right after the ripple. While the ripple
	# passes (REVEAL) it may still stand where the bench grows in: see [method ripple_overlaps], which
	# lists that (information, not an error: a second or two, then it is gone).
	var c_phases := OPENING
	all.append(_circle(&"cauldron", cauldron, CAULDRON_WIDTH * 0.5, rim + 0.09, c_phases, "Onion peeks out, the child taps it"))
	if cauldron_moves():
		var moved := _circle(&"cauldron_after", cauldron_after, CAULDRON_WIDTH * 0.5, rim + 0.09, REVEAL, "the cauldron, moved aside for the bench (gone after the ripple)")
		moved.keeps = LOOKED_GAP
		all.append(moved)
	var m_phases := OPENING if mechanism_moves() else OPENING | after
	all.append(_rect(&"panel", mechanism, _panel_half(), mechanism_yaw, HAND_ROOM, m_phases, "the child sets the gear into the socket"))
	if mechanism_moves():
		var moved := _rect(&"panel_after", mechanism_after, _panel_half(), mechanism_yaw_after, 0.06, after, "the mechanism, turning, moved aside for the bench")
		moved.keeps = LOOKED_GAP
		all.append(moved)
	all.append(_circle(&"gear_landing", gear_rest, GEAR_RADIUS + FINGERS, HAND_ROOM, OPENING, "the gear lands; the child picks it up"))
	var ring := _circle(&"socket", socket, SOCKET_RADIUS + 0.008, 0.012, m_phases, "the socket's brass ring")
	ring.may_overlap = [&"panel"]
	all.append(ring)
	if mechanism_moves():
		var ring_after := _circle(&"socket_after", socket_after, SOCKET_RADIUS + 0.008, 0.012, after, "the socket's brass ring, moved")
		ring_after.may_overlap = [&"panel_after"]
		ring_after.keeps = LOOKED_GAP
		all.append(ring_after)
	all.append(_onion(&"onion_aside", onion_aside, OPENING | PICKUP | ARC, "Onion waits while the gear comes out and while the child picks it up"))
	all.append(_onion(&"onion_socket", onion_socket, OPENING | SETIN, "Onion beside the socket while the child sets the gear in"))
	all.append(_onion(&"onion_lifted", onion_lifted, OPENING, "Onion rises after the seating"))
	all.append(_onion(&"onion_lifted_after", onion_lifted_after, REVEAL, "Onion lifted, turned to the revealed room"))
	all.append(_onion(&"onion_reveal", onion_reveal, REVEAL, "Onion drifts here after the ripple and \"Welcome\""))
	all.append(_onion(&"onion_invite", onion_invite, REVEAL, "Onion floats toward the shapes for the invitation"))
	var beside := _onion(&"onion_mouth", onion_mouth, OPENING | TAP, "Onion beside the mouth while the tap is shown")
	beside.may_overlap = [&"cauldron"]
	all.append(beside)
	var arc := gear_arc_zone()
	arc.may_overlap = [&"cauldron", &"gear_landing", &"cauldron_after"]
	all.append(arc)
	all.append(hand_zone(&"tap", rim_point()))
	all.append(hand_zone(&"pinch", gear_rest + Vector3.UP * 0.0235))
	all.append(hand_zone(&"place", socket + Vector3.UP * 0.014))
	all.append(_onion(&"onion_rest", onion_rest, SHELF, "Onion waits in the shelf scene"))
	all.append(_bench_zone())
	all.append(_shelf_zone())
	all.append(_things_zone())

	var hands := Zone.new()
	hands.name = &"hands"
	hands.kind = Kind.AREA
	hands.shape = &"ring"
	hands.centre = Vector3(eye.x, table_y(), eye.z)
	hands.inner = HANDS_NEAR
	hands.radius = reach_used()
	hands.yaw = atan2(-ahead.x, -ahead.z)
	hands.spread = deg_to_rad(HANDS_SIDE)
	hands.height = minf(HANDS_HIGH, eye.y - table_y() - 0.12)   # never up to the eyes at a high table
	hands.phases = OPENING | after
	hands.user = "the child's hands at work"
	all.append(hands)

	all.append(_panel_zone(&"setup_panel", setup_panel_at() - eye, SETUP_SIZE, setup_panel_at().y, SETUP | OPENING | REVEAL, "the setup panel and Start (the grown-up)"))
	for column in dev_columns():
		all.append(_panel_zone(column.name, column.at - eye, column.size, column.at.y, ALWAYS, "dev buttons"))
	return all


## The DEV columns: {name, at (middle), size (wide, high)}. The jumps (two columns of four, the pop
## sound under them) on the left; Restart, Exit and Zones on the right: out beyond the 110-degree view
## the child plays in (the grown-up turns the head to them), above the table and the hands, in reach.
func dev_columns() -> Array[Dictionary]:
	var head := Transform3D(Basis.looking_at(ahead), eye)
	var jumps := dev_spot(head, false)
	var right := dev_spot(head, true)
	return [{name = &"dev_jumps", at = jumps + Vector3.UP * 0.01, size = Vector2(DEV_JUMP_WIDE * 2.0 + 0.03, 0.36)},
			{name = &"dev_restart_exit", at = right + Vector3.DOWN * 0.04, size = Vector2(0.24, 0.29)}]


## Degrees each side of straight ahead the DEV columns stand, how far out, and their middle above
## the eyes. The jump buttons: DEV_JUMP_WIDE wide, DEV_JUMP_ROW apart, four to a column.
const DEV_ANGLE := 70.0
const DEV_LIFT := 0.0
const DEV_JUMP_WIDE := 0.11
const DEV_JUMP_ROW := 0.055
const DEV_JUMP_ROWS := 4


## The middle of a DEV column for [param head] (as at the start): the right one (Restart, Exit,
## Zones) or the left one (the jumps).
static func dev_spot(head: Transform3D, right: bool) -> Vector3:
	var flat := Vector3(-head.basis.z.x, 0.0, -head.basis.z.z).normalized()
	return head.origin + flat.rotated(Vector3.UP, deg_to_rad(-DEV_ANGLE if right else DEV_ANGLE)) * DEV_DISTANCE + Vector3.UP * DEV_LIFT


## Where jump button [param i] goes: two columns of DEV_JUMP_ROWS, in story order down the left
## column, then down the right one.
static func dev_jump_spot(head: Transform3D, i: int) -> Vector3:
	var middle := dev_spot(head, false)
	var across := _across(head, middle)
	var column := i / DEV_JUMP_ROWS
	var row := i % DEV_JUMP_ROWS
	return middle + across * (column - 0.5) * (DEV_JUMP_WIDE + 0.012) + Vector3.UP * (0.11 - row * DEV_JUMP_ROW)


## The "DEV · jump to" words, over the jump columns.
static func dev_jump_label(head: Transform3D) -> Vector3:
	return dev_spot(head, false) + Vector3.UP * 0.165


## The pop sound A/C button, under the jump columns.
static func dev_pop_spot(head: Transform3D) -> Vector3:
	return dev_spot(head, false) + Vector3.UP * (0.11 - DEV_JUMP_ROWS * DEV_JUMP_ROW - 0.012)


## Restart, Exit, Zones: one under the other on the right; Restart and Exit 15 cm apart, so a stray
## press meant for one never lands on the other.
static func dev_right_spot(head: Transform3D, i: int) -> Vector3:
	return dev_spot(head, true) + Vector3.UP * [0.075, -0.075, -0.16][i]


## Across, to the head's right, for something at [param at] facing the head.
static func _across(head: Transform3D, at: Vector3) -> Vector3:
	var to := Vector3(at.x - head.origin.x, 0.0, at.z - head.origin.z).normalized()
	return to.cross(Vector3.UP).normalized()


## The setup panel stands [constant SETUP_DISTANCE] ahead of [param head], this much above the eyes:
## high enough that its foot (the buttons) stays above the shelf and the table things in view.
const SETUP_LIFT := 0.12


static func setup_spot(head: Transform3D) -> Vector3:
	var flat := Vector3(-head.basis.z.x, 0.0, -head.basis.z.z).normalized()
	return head.origin + flat * SETUP_DISTANCE + Vector3.UP * SETUP_LIFT


func setup_panel_at() -> Vector3:
	return setup_spot(Transform3D(Basis.looking_at(ahead), eye))


func _panel_zone(name: StringName, offset: Vector3, size: Vector2, middle_y: float, phases: int, user: String) -> Zone:
	var flat := Vector3(offset.x, 0.0, offset.z)
	var zone := _rect(name, Vector3(eye.x + flat.x, middle_y - size.y * 0.5, eye.z + flat.z), Vector2(size.x * 0.5, 0.01),
			atan2(-flat.x, -flat.z), size.y, phases, user)
	zone.kind = Kind.PANEL
	return zone


## Onion's body as a vertical capsule centred on [param at] (where its holder floats), with its halo as
## room all round (the table things keep their distance from the halo, the hand only from the body).
func _onion(name: StringName, at: Vector3, phases: int, user: String) -> Zone:
	var z := Zone.new()
	z.name = name
	z.shape = &"capsule"
	z.centre = at - Vector3.UP * ONION_HEIGHT * 0.5
	z.radius = ONION_BODY
	z.height = ONION_HEIGHT
	z.space = ONION * 0.5 - ONION_BODY
	z.phases = phases
	z.user = user
	return z


## The gear's flight out of the cauldron: a ball (the gear) swept from just over the rim along its hop to
## where it lands (entry.gd _emerge_gear / _gear_arc), as a volume.
func gear_arc_zone() -> Zone:
	var z := Zone.new()
	z.name = &"gear_arc"
	z.shape = &"path"
	z.radius = ARC_RADIUS
	var mouth := _mouth_point()
	var start := Vector3(mouth.x, cauldron.y + rim + ARC_OVER_RIM, mouth.z)
	var landing := Vector3(gear_rest.x, cauldron.y, gear_rest.z)
	for i in 11:
		var k := i / 10.0
		z.path.append(start.lerp(landing, k) + Vector3.UP * (ARC_HEIGHT * 4.0 * k * (1.0 - k) + GEAR_MIDDLE))
	z.phases = OPENING | ARC
	z.user = "the gear's hop out of the cauldron"
	return z


func _circle(name: StringName, at: Vector3, r: float, height: float, phases := ALWAYS, user := "") -> Zone:
	var zone := Zone.new()
	zone.name = name
	zone.shape = &"circle"
	zone.centre = at
	zone.radius = r
	zone.height = height
	zone.phases = phases
	zone.user = user
	return zone


func _rect(name: StringName, at: Vector3, half: Vector2, yaw: float, height: float, phases := ALWAYS, user := "") -> Zone:
	var zone := Zone.new()
	zone.name = name
	zone.shape = &"rect"
	zone.centre = at
	zone.half = half
	zone.yaw = yaw
	zone.height = height
	zone.phases = phases
	zone.user = user
	return zone


func zone(name: StringName) -> Zone:
	for z in zones:
		if z.name == name:
			return z
	return null


# --- Overlaps --------------------------------------------------------------------

## The gap between two footprints seen from above, metres; negative: they overlap by that much
## (the narrower side of the shared part). Heights are not looked at here.
static func gap(a: Zone, b: Zone) -> float:
	if a.shape == &"capsule" or b.shape == &"capsule":   # seen from above a capsule is a circle
		var flat_a := a
		var flat_b := b
		if a.shape == &"capsule":
			flat_a = Zone.new()
			flat_a.centre = a.centre
			flat_a.radius = a.radius
		if b.shape == &"capsule":
			flat_b = Zone.new()
			flat_b.centre = b.centre
			flat_b.radius = b.radius
		return gap(flat_a, flat_b)
	if a.shape == &"rect" and b.shape == &"rect":
		return _rect_rect(a, b)
	if a.shape == &"circle" and b.shape == &"circle":
		return Vector2(a.centre.x - b.centre.x, a.centre.z - b.centre.z).length() - a.radius - b.radius
	if a.shape == &"circle" and b.shape == &"rect":
		return _circle_rect(a, b)
	if a.shape == &"rect" and b.shape == &"circle":
		return _circle_rect(b, a)
	var pa := a.outline()
	var pb := b.outline()
	var shared := Geometry2D.intersect_polygons(pa, pb)
	if not shared.is_empty():
		var deepest := 0.0
		for piece: PackedVector2Array in shared:
			# How thick the shared part is: twice its area over its edge (a strip w x d gives about d).
			var area := 0.0
			var edge := 0.0
			for i in piece.size():
				var p := piece[i]
				var q := piece[(i + 1) % piece.size()]
				area += p.cross(q) * 0.5
				edge += p.distance_to(q)
			deepest = maxf(deepest, 2.0 * absf(area) / maxf(edge, 0.0001))
		if deepest > 0.0005:
			return -deepest
	if Geometry2D.is_point_in_polygon(pa[0], pb) or Geometry2D.is_point_in_polygon(pb[0], pa):
		return -0.01
	var nearest := INF
	for i in pa.size():
		for j in pb.size():
			var p := Geometry2D.get_closest_points_between_segments(pa[i], pa[(i + 1) % pa.size()], pb[j], pb[(j + 1) % pb.size()])
			nearest = minf(nearest, p[0].distance_to(p[1]))
	return nearest


## Two turned rectangles: the largest separation along their four axes (separating axes), or minus the
## shallowest overlap. Exact for overlaps and side-to-side gaps; at a corner-to-corner gap it is a little
## less than the true distance (so a touch stricter, never looser).
static func _rect_rect(a: Zone, b: Zone) -> float:
	var ua := Vector2(cos(a.yaw), -sin(a.yaw))
	var va := Vector2(sin(a.yaw), cos(a.yaw))
	var ub := Vector2(cos(b.yaw), -sin(b.yaw))
	var vb := Vector2(sin(b.yaw), cos(b.yaw))
	var d := Vector2(b.centre.x - a.centre.x, b.centre.z - a.centre.z)
	var best := -INF
	for axis: Vector2 in [ua, va, ub, vb]:
		var ra := a.half.x * absf(ua.dot(axis)) + a.half.y * absf(va.dot(axis))
		var rb := b.half.x * absf(ub.dot(axis)) + b.half.y * absf(vb.dot(axis))
		best = maxf(best, absf(d.dot(axis)) - ra - rb)
	return best


## Circle [param c] and turned rectangle [param r]: their gap, or minus how deep they overlap.
static func _circle_rect(c: Zone, r: Zone) -> float:
	var d := Vector2(c.centre.x - r.centre.x, c.centre.z - r.centre.z)
	var local := Vector2(d.x * cos(r.yaw) - d.y * sin(r.yaw), d.x * sin(r.yaw) + d.y * cos(r.yaw))
	var out := Vector2(absf(local.x) - r.half.x, absf(local.y) - r.half.y)
	if out.x > 0.0 or out.y > 0.0:
		return out.max(Vector2.ZERO).length() - c.radius
	return maxf(out.x, out.y) - c.radius   # the middle is inside: how far in, plus the radius


## How far apart two zones are as REAL 3D volumes, metres; negative: they intersect, by how deep (the
## least way out). Prisms (cylinders, boxes) and capsules and swept paths are all handled exactly (a
## path as many small spheres). This is what [method overlaps] uses.
static func volume_gap(a: Zone, b: Zone) -> float:
	if a.is_prism() and b.is_prism():
		return _combine(gap(a, b), _y_gap(a.centre.y, a.top(), b.centre.y, b.top()))
	if a.is_prism():
		return volume_gap(b, a)
	var best := INF
	for seg: Array in a.segments():
		var lo := minf((seg[0] as Vector3).y, (seg[1] as Vector3).y)
		var hi := maxf((seg[0] as Vector3).y, (seg[1] as Vector3).y)
		var at := Vector2((seg[0] as Vector3).x, (seg[0] as Vector3).z)
		if b.is_prism():
			var point := Zone.new()
			point.centre = Vector3(at.x, 0.0, at.y)
			var h := gap(point, b)
			best = minf(best, _combine(h, _y_gap(lo, hi, b.centre.y, b.top())) - a.radius)
		else:
			for other: Array in b.segments():
				var o_lo := minf((other[0] as Vector3).y, (other[1] as Vector3).y)
				var o_hi := maxf((other[0] as Vector3).y, (other[1] as Vector3).y)
				var h := at.distance_to(Vector2((other[0] as Vector3).x, (other[0] as Vector3).z))
				best = minf(best, _combine(h, _y_gap(lo, hi, o_lo, o_hi)) - a.radius - b.radius)
	return best


## The gap between two vertical intervals, negative: how deep they overlap.
static func _y_gap(a0: float, a1: float, b0: float, b1: float) -> float:
	return maxf(a0, b0) - minf(a1, b1)


## Two separations at right angles (across and up): both positive, the straight distance; one positive,
## that one; both negative, the shallower overlap.
static func _combine(h: float, v: float) -> float:
	if h > 0.0 or v > 0.0:
		return sqrt(maxf(h, 0.0) * maxf(h, 0.0) + maxf(v, 0.0) * maxf(v, 0.0))
	return maxf(h, v)


## Seen from [param from], the box of directions [param zone] covers: Rect2(degrees right, degrees up).
func in_view(zone: Zone, from := eye) -> Rect2:
	var box := Rect2()
	var first := true
	for corner in zone.corners():
		var d := corner - from
		var flat := Vector3(d.x, 0.0, d.z)
		var right := -rad_to_deg(ahead.signed_angle_to(flat.normalized(), Vector3.UP))
		var up := rad_to_deg(atan2(d.y, flat.length()))
		if first:
			box = Rect2(right, up, 0, 0)
			first = false
		else:
			box = box.expand(Vector2(right, up))
	return box


## Every pair of zones that overlap when both are there, as 3D VOLUMES: [{a, b, how, amount}], amount in
## metres (the table things, Onion's body, the teaching hand's sweep, the gear's flight: how much too
## close, or how deep inside) or degrees (a panel in view). Empty: all clear. [method overlaps_flat] is the
## same on the footprints only (heights ignored).
func overlaps() -> Array[Dictionary]:
	return _overlaps(true)


## The same seen from above only: heights are ignored (a quicker, stricter fallback).
func overlaps_flat() -> Array[Dictionary]:
	return _overlaps(false)


func _overlaps(volumes: bool) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for i in zones.size():
		for j in range(i + 1, zones.size()):
			var a := zones[i]
			var b := zones[j]
			if a.phases & b.phases == 0 or b.name in a.may_overlap or a.name in b.may_overlap:
				continue
			if a.phases & GESTURES != 0 and b.phases & GESTURES != 0 and a.phases & b.phases & GESTURES == 0:
				continue   # Onion's tap spot and the gear's flight never happen at the same time
			if String(a.name).begins_with("onion") and String(b.name).begins_with("onion"):
				continue   # Onion stands in one place at a time
			if a.kind == Kind.HAND or b.kind == Kind.HAND:
				var h := a if a.kind == Kind.HAND else b
				var o := b if a.kind == Kind.HAND else a
				if h.phases & o.phases & GESTURES == 0 or not String(o.name).begins_with("onion"):
					continue   # the hand meets only Onion, and only while that gesture shows
				var clear := _gap_of(o, h, volumes)
				if clear < HAND_CLEAR:
					found.append({a = h.name, b = o.name, how = "on the table", amount = HAND_CLEAR - clear})
				continue
			if a.kind == Kind.AREA and b.kind == Kind.AREA:
				continue
			if (a.kind == Kind.AREA and b.kind == Kind.THING) or (a.kind == Kind.THING and b.kind == Kind.AREA):
				continue   # things are meant to be in the hands' room
			if a.kind == Kind.PANEL or b.kind == Kind.PANEL:
				var view := _view_overlap(a, b)
				if view > 0.0:
					found.append({a = a.name, b = b.name, how = "in view", amount = view})
					continue
			if a.kind == Kind.PANEL or b.kind == Kind.PANEL:
				if not volumes:
					continue
			var needed := minf(a.keeps, b.keeps) + a.space + b.space if a.kind == Kind.THING and b.kind == Kind.THING else 0.0
			var between := _gap_of(a, b, volumes)
			if between < needed:
				found.append({a = a.name, b = b.name, how = "on the table", amount = needed - between})
	return found


## The gap between [param a] and [param b]: as 3D volumes, or (flat) on their footprints.
func _gap_of(a: Zone, b: Zone, volumes: bool) -> float:
	if volumes:
		return volume_gap(a, b)
	return gap(a, b)


## How many degrees two zones overlap in view (the smaller of across and up), 0 if they don't.
func _view_overlap(a: Zone, b: Zone) -> float:
	var shared := in_view(a).intersection(in_view(b))
	return minf(shared.size.x, shared.size.y) if shared.has_area() else 0.0


## Things the child needs that fall outside a seated view looking [constant LOOK_DOWN] down toward
## the middle of the play: [{name, how}]. The shelf, its bench and things, and Onion beside it are not
## counted when the shelf stands to the side (Onion leads the child there and the child turns to it, as in
## Wei's World: "turn to face a place"): they only have to be in view when the child faces them, which is
## always so; how far the shelf had to turn is a cost of the plan instead.
func out_of_view() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for z in zones:
		if z.kind != Kind.THING or z.name in [&"bench", &"shelf", &"things", &"onion_rest"]:
			continue
		var box := in_view(z)
		if box.position.x < -VIEW_WIDE * 0.5 or box.end.x > VIEW_WIDE * 0.5:
			found.append({name = z.name, how = "%d to %d degrees across" % [roundi(box.position.x), roundi(box.end.x)],
					degrees = maxf(-VIEW_WIDE * 0.5 - box.position.x, box.end.x - VIEW_WIDE * 0.5)})
		elif box.position.y < -LOOK_DOWN - VIEW_HIGH * 0.5 or box.end.y > -LOOK_DOWN + VIEW_HIGH * 0.5:
			found.append({name = z.name, how = "%d to %d degrees up" % [roundi(box.position.y), roundi(box.end.y)],
					degrees = maxf(-LOOK_DOWN - VIEW_HIGH * 0.5 - box.position.y, box.end.y - (-LOOK_DOWN + VIEW_HIGH * 0.5))})
	return found


## Things the child must reach that lie beyond the reach (their nearest edge): [{name, how}].
func out_of_reach() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for name: StringName in [&"cauldron", &"panel", &"gear_landing", &"things"]:
		var z := zone(name)
		var nearest := INF
		for p in z.outline():
			nearest = minf(nearest, Vector2(p.x - eye.x, p.y - eye.z).length())
		if name == &"panel":
			nearest = away(socket)   # the gear goes into the socket: that is what must be in reach
		if nearest > reach_used() + 0.02 + (socket_stretch if name == &"panel" else 0.0):
			found.append({name = name, how = "%d cm out, reach %d cm" % [roundi(nearest * 100.0), roundi(reach_used() * 100.0)],
					metres = nearest - reach_used() - 0.02})
	return found


## The subtitle as Wei's Voice puts it ([param above_gaze] degrees over the gaze, at most
## [param above_horizon] up, [param distance] m out, about 54 x 6 cm), looking at [param at].
func subtitle_zone(at: Vector3, above_gaze := 25.0, above_horizon := 20.0, distance := 0.75) -> Zone:
	var d := at - eye
	var flat := Vector3(d.x, 0.0, d.z).normalized()
	var pitch := rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length()))
	var up := deg_to_rad(minf(above_horizon, pitch + above_gaze))
	var middle := eye + (flat * cos(up) + Vector3.UP * sin(up)) * distance
	var zone := _rect(&"subtitle", Vector3(middle.x, middle.y - 0.03, middle.z), Vector2(0.27, 0.01), atan2(-flat.x, -flat.z), 0.06, SHELF, "Onion's subtitles")
	zone.kind = Kind.PANEL
	return zone


## What the subtitle covers in view while the child looks at each thing of the shelf scene:
## [{looking_at, covers, amount (degrees)}].
func subtitle_covers(above_gaze := 25.0) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for looking: StringName in [&"things", &"shelf", &"panel"]:
		var target := zone(looking)
		var at := target.centre + Vector3.UP * minf(target.height, 0.1) * 0.5
		var sub := subtitle_zone(at, above_gaze)
		for name: StringName in [&"shelf", &"things", &"panel", &"cauldron", &"onion_rest"]:
			var amount := _view_overlap(sub, zone(name))
			if amount > 0.5:
				found.append({looking_at = looking, covers = name, amount = amount})
	return found


## What the cauldron still touches while the ripple grows the bench, shelf and things in (it sinks away
## right after): [{b, amount}] in metres. Information only: [method overlaps] does not count it.
func ripple_overlaps() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var pot := Zone.new()
	pot.shape = &"circle"
	pot.centre = cauldron_after   # where it stands when the ripple starts (glided aside, or not moved)
	pot.radius = CAULDRON_WIDTH * 0.5
	pot.height = rim
	for other: Zone in [_bench_zone(), _shelf_zone(), _things_zone()]:
		var between := volume_gap(pot, other)
		if between < GAP:
			found.append({b = other.name, amount = GAP - between})
	return found


## One line per overlap, for Output and the tests.
func report() -> String:
	var lines: Array[String] = []
	for o in overlaps():
		var unit := "cm" if o.how == "on the table" else "degrees"
		var amount: float = o.amount * (100.0 if unit == "cm" else 1.0)
		lines.append("%s overlaps %s %s by %.1f %s" % [o.a, o.b, o.how, amount, unit])
	for o in out_of_view():
		lines.append("%s is out of view: %s" % [o.name, o.how])
	for o in out_of_reach():
		lines.append("%s is out of reach: %s" % [o.name, o.how])
	return "\n".join(lines)


## The usual layout's numbers, for Output.
func summary() -> String:
	var where := func(p: Vector3) -> String: return "%d cm at %d deg" % [roundi(away(p) * 100), roundi(bearing(p))]
	return "reach %d cm, push %d cm, shelf %d deg right; cauldron %s%s; panel %s%s; gear lands %s" % [
		roundi(reach_used() * 100), roundi(push * 100), roundi(shelf_angle),
		where.call(cauldron), (" then " + where.call(cauldron_after)) if cauldron_moves() else "",
		where.call(mechanism), (" then " + where.call(mechanism_after)) if mechanism_moves() else "", where.call(gear_rest)] \
		+ (" (it hops over the panel: little table in reach)" if hops_over_panel() else "") \
		+ (" [panel stays put]" if panel_fixed else " [panel glides at the reveal: no clear fixed spot on this table]")
