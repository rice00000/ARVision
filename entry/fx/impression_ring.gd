class_name ImpressionRing
extends Node3D
## The hub's choices as a ring above the cauldron that steps to the front (Megan, Nov 17;
## SCENE_REVIEW_DECISIONS.md, Scene 7).
## * It never turns by itself: a moving target is a vision test in disguise (nystagmus, low vision),
##   and constant motion in the middle of the view is clutter.
## * One choice is in FRONT: toward the child, leaning out a little, full size, with the waiting halo
##   behind it. The others sit smaller round the ring.
## * [method press] a side one: the ring turns slowly until it is in front, then stops, with its sound
##   ([code]&"turned"[/code]). Press the front one: it's chosen ([code]&"chosen"[/code]; its sound and
##   pulse). A sealed one can't be brought to the front ([code]&"sealed"[/code]).
## * Every choice lights up softly while a hand ray aims at it or a hand comes near (polled from the
##   rig's pointers), so a child pointing at a side one sees it react.
## * No arrows and no swipe (a sideways sweep is the dots game's answer).
## [method HubGlow.quiet_all] also quiets every ring before a task starts.
##
## The hub (WorkshopController) owns the flow: it makes the ring with the impressions it offers, feeds
## [signal Events.selected] / [signal Events.touched] targets to [method press], and on &"chosen" summons.

signal turned(front: Impression)

const RADIUS := 0.26            # metres from the ring's middle to each choice
const ABOVE_RIM := 0.16         # the choices' bases over the cauldron's rim: they float above its mouth, not in front of it
const LEAN := 0.04              # the front one comes this much nearer the child
const SIDE_SCALE := 0.7
const TURN_SECONDS := 0.8
const NEAR_FROM := 0.25         # a hand this close starts to light a choice...
const NEAR_FULL := 0.08         # ...fully at this distance

## Every ring alive (for [method HubGlow.quiet_all]).
static var alive: Array[ImpressionRing] = []

var impressions: Array[Impression] = []
## Radians the ring is turned: impression i sits at angle i * step + offset; 0 = toward the child.
var offset := 0.0
var turning := false

var _step := TAU / 3.0
var _toward := Vector3.FORWARD   # flat direction from the ring's middle to the child
var _quiet := false
var _waiting := 1.0


## A ring of [param choices] round [param middle] (a point over the cauldron's mouth, at the choices'
## base height), its front toward [param eye], under [param parent].
static func make(parent: Node, choices: Array[Impression], middle: Vector3, eye: Vector3) -> ImpressionRing:
	var ring := ImpressionRing.new()
	ring.name = "impression_ring"
	parent.add_child(ring)
	ring.global_position = middle
	ring._toward = Vector3(eye.x - middle.x, 0.0, eye.z - middle.z).normalized()
	ring._step = TAU / maxf(3.0, choices.size())   # two choices: 0 and 120 degrees, never one hidden behind the other
	for impression in choices:
		if impression.get_parent() == null:
			ring.add_child(impression)
		ring.impressions.append(impression)
	ring.offset = 0.0
	ring._place()
	return ring


## The choice in front now.
func front() -> Impression:
	var best: Impression = null
	var best_angle := INF
	for i in impressions.size():
		var angle := absf(wrapf(i * _step + offset, -PI, PI))
		if angle < best_angle:
			best_angle = angle
			best = impressions[i]
	return best


## The choice whose target is [param target], or null.
func impression_for(target: Target) -> Impression:
	for impression in impressions:
		if impression.target == target:
			return impression
	return null


## The child pressed [param impression]: &"chosen" (it was in front), &"turned" (the ring brings it to
## the front), &"sealed" (not open yet: nothing happens) or &"busy" (still turning).
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


## Turns the ring (shortest way, eased, no overshoot) until [param impression] is in front.
func step_to(impression: Impression) -> void:
	var i := impressions.find(impression)
	if i < 0 or impression.sealed:
		return
	var target := offset - wrapf(i * _step + offset, -PI, PI)
	turning = true
	var tween := create_tween()
	tween.tween_method(func(o: float) -> void:
		offset = o
		_place(), offset, target, TURN_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	turning = false
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


## Puts every choice at its place round the ring: the front one full size and leaning toward the
## child, the rest smaller; all facing the child.
func _place() -> void:
	var side := _toward.cross(Vector3.UP)
	var leader := front()
	for i in impressions.size():
		var impression := impressions[i]
		if not is_instance_valid(impression):
			continue
		var angle := wrapf(i * _step + offset, -PI, PI)
		var frontness := clampf(1.0 - absf(angle) / (_step * 0.9), 0.0, 1.0)   # 1 in front, 0 a step away
		var at := global_position + (_toward * cos(angle) + side * sin(angle)) * RADIUS + _toward * LEAN * frontness
		impression.global_position = at
		impression.look_at(at + _toward, Vector3.UP, true)
		impression.scale = Vector3.ONE * lerpf(SIDE_SCALE, 1.0, frontness)
		impression.set_waiting(_waiting if impression == leader and not turning else 0.0)
