class_name ImpressionRing
extends Node3D
## The hub's choices above the cauldron as a CAROUSEL ARC that steps to the front (Megan, Nov 17;
## SCENE_REVIEW_DECISIONS.md, Scene 7; her reference: a visionOS-style carousel).
## * It never moves by itself: a moving target is a vision test in disguise (nystagmus, low vision),
##   and constant motion in the middle of the view is clutter.
## * One choice is in FRONT: full size, leaning a little toward the child, with the waiting halo behind
##   it. The others sit to its sides at half size ([constant SIDE_SCALE], never smaller: ~7-8 cm still
##   reads easily at 70 cm), a little further back and turned in toward the middle, well apart, so
##   nothing is hidden behind the front one or the cauldron.
## * [method press] a side one: the arc slides until it is in front, then stops, with its sound
##   ([code]&"turned"[/code]). Press the front one: it's chosen ([code]&"chosen"[/code]; its sound and
##   pulse). ([code]&"sealed"[/code] is kept for a sealed impression, though "hidden, not sealed" means
##   the hub shows only choices that can be pressed.)
## * [method add]: a new choice rises out of the cauldron into the arc and comes to the front (the dots
##   after the first shelf; Turn to fit when it can run).
## * Every choice lights softly while a hand ray aims at it or a hand comes near (polled from the rig's
##   pointers), so a child pointing at a side one sees it react.
## * No arrows and no swipe (a sideways sweep is the dots game's answer).
## [method HubGlow.quiet_all] also quiets every ring before a task starts.
##
## The hub (WorkshopController) owns the flow: it makes the arc with the impressions it offers, feeds
## [signal Events.selected] / [signal Events.touched] targets to [method press], and on &"chosen" summons.

signal turned(front: Impression)

const SPACING := [0.0, 0.17, 0.29]   # metres sideways from the front, by places away from it
const BACK := 0.05              # each place away sits this much further back
const TURN_IN := 35.0           # degrees a side choice is turned toward the middle
const ABOVE_RIM := 0.08         # the choices' bases over the cauldron's rim: they float above its mouth, not in front of it
const LEAN := 0.04              # the front one comes this much nearer the child
const SIDE_SCALE := 0.5
const TURN_SECONDS := 0.8       # one place; each further place adds 0.3 s
const RISE_SECONDS := 1.0
const NEAR_FROM := 0.25         # a hand this close starts to light a choice...
const NEAR_FULL := 0.08         # ...fully at this distance

## Every ring alive (for [method HubGlow.quiet_all]).
static var alive: Array[ImpressionRing] = []

var impressions: Array[Impression] = []
## Which place is in front, as a (fractional while sliding) index into [member impressions].
var front_at := 0.0
var turning := false

var _toward := Vector3.FORWARD   # flat direction from the arc's middle to the child
var _quiet := false
var _waiting := 1.0


## An arc of [param choices] over [param middle] (a point over the cauldron's mouth, at the choices'
## base height), facing [param eye], under [param parent]; [param front] is the one in front.
static func make(parent: Node, choices: Array[Impression], middle: Vector3, eye: Vector3, front := 0) -> ImpressionRing:
	var ring := ImpressionRing.new()
	ring.name = "impression_ring"
	parent.add_child(ring)
	ring.global_position = middle
	ring._toward = Vector3(eye.x - middle.x, 0.0, eye.z - middle.z).normalized()
	for impression in choices:
		if impression.get_parent() == null:
			ring.add_child(impression)
		ring.impressions.append(impression)
	ring.front_at = clampi(front, 0, maxi(0, choices.size() - 1))
	ring._place()
	return ring


## The choice in front now.
func front() -> Impression:
	if impressions.is_empty():
		return null
	return impressions[clampi(roundi(front_at), 0, impressions.size() - 1)]


## The choice whose target is [param target], or null.
func impression_for(target: Target) -> Impression:
	for impression in impressions:
		if impression.target == target:
			return impression
	return null


## The child pressed [param impression]: &"chosen" (it was in front), &"turned" (the arc brings it to
## the front), &"sealed" (not open: nothing happens) or &"busy" (still moving).
func press(impression: Impression) -> StringName:
	if impression == null or impression not in impressions:
		return &""
	if impression.sealed:
		return &"sealed"
	if turning:
		return &"busy"
	if impression == front():
		impression.touched()
		return &"chosen"
	step_to(impression)
	return &"turned"


## Slides the arc (eased, no overshoot) until [param impression] is in front.
func step_to(impression: Impression) -> void:
	var i := impressions.find(impression)
	if i < 0 or impression.sealed:
		return
	turning = true
	var places := absf(i - front_at)
	var tween := create_tween()
	tween.tween_method(func(f: float) -> void:
		front_at = f
		_place(), front_at, float(i), TURN_SECONDS + 0.3 * maxf(0.0, places - 1.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	turning = false
	impression.sound()
	turned.emit(impression)


## A new choice rises out of the cauldron (from [param from], e.g. its mouth) into the arc, at the end of
## the row, and the arc brings it to the front; its sound plays as it arrives.
func add(impression: Impression, from: Vector3) -> void:
	if impression.get_parent() == null:
		add_child(impression)
	impressions.append(impression)
	turning = true
	var start := impression.global_transform
	start.origin = from
	var rise := create_tween()
	var i := impressions.size() - 1
	var begin := front_at
	rise.tween_method(func(k: float) -> void:
		front_at = lerpf(begin, float(i), k)
		_place()
		impression.global_position = from.lerp(impression.global_position, k)
		impression.scale *= lerpf(0.3, 1.0, k), 0.0, 1.0, RISE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await rise.finished
	turning = false
	_place()
	impression.sound()
	turned.emit(impression)


## Fades every halo out (before a task); the ring stays and can be woken with [method wake].
func quiet(seconds := 0.8) -> void:
	_quiet = true
	var tween := create_tween()
	tween.tween_method(func(f: float) -> void:
		_waiting = f
		for impression in impressions:
			if is_instance_valid(impression):
				impression.set_near(0.0)
		_place(), _waiting, 0.0, seconds)


## Lights the front one again (back at the hub after a task).
func wake() -> void:
	_quiet = false
	_waiting = 1.0
	_place()


## True while any choice in the ring is lit.
func is_lit() -> bool:
	return impressions.any(func(i: Impression) -> bool:
		return is_instance_valid(i) and i.visible and i._halo.visible and i._halo_light.albedo_color.a > 0.003)


func _enter_tree() -> void:
	alive.append(self)


func _exit_tree() -> void:
	alive.erase(self)


func _process(_delta: float) -> void:
	if _quiet:
		return
	var pointers: Array[Pointer] = []
	if App.rig:
		for side: StringName in [&"left", &"right"]:
			var pointer := App.rig.pointer(side)
			if pointer:
				pointers.append(pointer)
	for impression in impressions:
		if not is_instance_valid(impression) or impression.sealed:
			continue
		var near := 0.0
		for pointer in pointers:
			if pointer.aimed == impression.target:
				near = 1.0
			var gap := pointer.global_position.distance_to(impression.target.global_position)
			near = maxf(near, clampf(inverse_lerp(NEAR_FROM, NEAR_FULL, gap), 0.0, 1.0))
		impression.set_near(near)


## Puts every choice at its place on the arc: the front one full size and leaning toward the child; the
## others half size, to its sides, a little further back and turned in toward the middle.
func _place() -> void:
	var side := _toward.cross(Vector3.UP)   # the child's left (the child faces -_toward): the row runs left to right as seen
	var leader := front()
	for i in impressions.size():
		var impression := impressions[i]
		if not is_instance_valid(impression):
			continue
		var rel := float(i) - front_at          # places from the front: < 0 left, > 0 right (as the child sees it)
		var away := absf(rel)
		var across := _spacing(away) * signf(rel)
		var nearness := clampf(1.0 - away, 0.0, 1.0)   # 1 in front, 0 a place away
		var at := global_position - side * across - _toward * BACK * away + _toward * LEAN * nearness
		impression.global_position = at
		var facing := _toward.rotated(Vector3.UP, deg_to_rad(TURN_IN) * clampf(rel, -1.0, 1.0))
		impression.look_at(at + facing, Vector3.UP, true)
		impression.scale = Vector3.ONE * lerpf(SIDE_SCALE, 1.0, nearness)
		impression.set_waiting(_waiting if impression == leader and not turning else 0.0)


static func _spacing(away: float) -> float:
	var whole := mini(int(away), SPACING.size() - 2)
	return lerpf(SPACING[whole], SPACING[whole + 1], away - whole) if away < SPACING.size() - 1 else SPACING[-1] + (away - (SPACING.size() - 1)) * 0.12
