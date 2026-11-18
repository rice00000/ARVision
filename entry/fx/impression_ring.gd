class_name ImpressionRing
extends Node3D
## The hub's menu: the cauldron's BUBBLE MENU (visual pass, Megan Nov 18; `claude/VISUAL_PASS_LOG.md`). The
## class keeps its old name and calls so the hub and the tests carry on.
##
## * **The cauldron is the menu.** The menu starts closed (invisible). The hub opens it ([method rise]) when the
##   child taps the cauldron (or the ☰ over it); it sinks back in ([method sink]) before a game, Wei's room or
##   the closing.
## * **Each choice rises in its own bubble** ([method Impression.add_bubble]): a frosted backing behind the
##   piece, which keeps its dark outline (figure-ground on any wall), a nearly clear shell, a pale rim, one
##   still highlight. No colour of its own, no shimmer, no wobble, no fog behind.
## * **Tasks: a still arc** within touch reach, up to [constant STILL_MAX] all in view and none moving (Megan:
##   B). The middle one is a little bigger. ONE press picks any; the chosen bubble pops. Past
##   [constant STILL_MAX] it turns into a carousel whose ends peek out (a press on a side one slides it in).
## * **Places: a lower row**, set a little back: the Virtual Workshop (Wei's room) as a little house in a smaller
##   bubble with a brass porthole rim ([method set_door]).
## * **Chosen:** the bubble pops into droplets with a pop sound; the game's name appears over it in big retro
##   letters with a chime ([ChosenTitle]).
## * **Buds** under a bubble show the game's next level as a silhouette ([method Impression.set_bud]).
## * **Rest:** after [constant REST_AFTER] s with no hand near, the bubbles shrink to [constant REST_SCALE] in
##   place (still pressable); a hand coming near wakes them in ~0.5 s.
## * [signal hovered] when a hand comes to a bubble: the hub says its name (a sound label).

signal turned(front: Impression)
## The child chose [param impression].
signal chosen(impression: Impression)
## A hand came to [param impression] (aimed at it or close): the hub says its name.
signal hovered(impression: Impression)

const STILL_MAX := 5            # up to this many tasks: a still arc, nothing slides
const STEP := 0.56              # radians between neighbours on the arc (bubbles never touch)
const RADIUS := 0.26            # metres from the arc's centre to each bubble
const ABOVE_RIM := 0.27         # the menu's middle over the cauldron's rim
const REACH := 0.44             # the menu's middle is pulled toward the child until it is this far from the eyes
const LEAN_MAX := 0.2           # ...but never more than this far forward of the cauldron's mouth
const FRONT_SCALE := 0.6        # the middle bubble (a piece is 12-16 cm, its bubble 22 cm, at scale 1)
const SIDE_SCALE := 0.5
const DOOR_SCALE := 0.42
const DOOR_BACK := 0.06         # the house sits this far BEHIND the games' front, out of a resting hand's way (Megan, Nov 18: "too easy to click"; it was 8 cm nearer)
const DOOR_BELOW := 0.14        # the places row: this far below the tasks
const TURN_SECONDS := 1.2       # a carousel step (only past STILL_MAX)
const RISE_SECONDS := 1.0       # a new bubble rising out of the brew into its place
const OPEN_SECONDS := 1.2       # the bubbles rising when the menu opens
const NEAR_FROM := 0.25         # a hand this close starts to light a bubble...
const NEAR_FULL := 0.08         # ...fully at this distance
const HOVER_AT := 0.6           # this lit: the bubble says its name (again only after the hand left it)
const WAKE_NEAR := 0.35         # a hand this close to the menu's middle wakes it (and keeps it awake)
const REST_AFTER := 20.0        # seconds with no hand near before the menu rests
const REST_SECONDS := 1.5
const WAKE_SECONDS := 0.5
const REST_SCALE := 0.7

## Every ring alive (for [method HubGlow.quiet_all]).
static var alive: Array[ImpressionRing] = []

var impressions: Array[Impression] = []
## The places row (Wei's room's door), or null.
var door: Impression
## Carousel steps turned (past STILL_MAX only): piece i sits at (i - offset) * STEP.
var offset := 0.0
var turning := false
## True while the menu is up (between [method rise] and [method sink]).
var opened := false
## 0 awake .. 1 resting.
var rest := 0.0

var _toward := Vector3.FORWARD   # flat direction from the menu toward the child
var _side := Vector3.RIGHT
var _quiet := false
var _waiting := 1.0
var _idle := 0.0
var _rest_tween: Tween
var _hovering: Dictionary = {}   # impression -> its name was said for this visit of the hand


## The menu facing [param eye], its tasks' middle at [param middle] ([method spot] gives the usual place),
## under [param parent]. [param _mouth]: kept for the old calls.
static func make(parent: Node, choices: Array[Impression], middle: Vector3, eye: Vector3, _mouth := Vector3.INF) -> ImpressionRing:
	var ring := ImpressionRing.new()
	ring.name = "impression_ring"
	parent.add_child(ring)
	ring.global_position = middle
	ring._toward = Vector3(eye.x - middle.x, 0.0, eye.z - middle.z).normalized()
	ring._side = ring._toward.cross(Vector3.UP).normalized()
	for impression in choices:
		ring._take(impression)
	ring.opened = true   # made open (the hub hides it and opens it with a tap)
	ring._place()
	return ring


## Where the menu's middle goes: over the cauldron's [param mouth], pulled toward the child at [param eye] so the
## bubbles sit within touch reach (REACH from the eyes), but never more than LEAN_MAX forward of the mouth.
static func spot(mouth: Vector3, eye: Vector3) -> Vector3:
	var over := mouth + Vector3.UP * ABOVE_RIM
	var toward := Vector3(eye.x - over.x, 0.0, eye.z - over.z).normalized()
	var lean := clampf(over.distance_to(eye) - REACH, 0.0, LEAN_MAX)
	return over + toward * lean


## The middle task (the carousel's front past STILL_MAX).
func front() -> Impression:
	if impressions.is_empty():
		return null
	if not _carousel():
		return impressions[(impressions.size() - 1) / 2]
	var best: Impression = null
	var best_angle := INF
	for i in impressions.size():
		var angle := absf(_angle(i))
		if angle < best_angle:
			best_angle = angle
			best = impressions[i]
	return best


## The bubble (task or door) whose target is [param target], or null.
func impression_for(target: Target) -> Impression:
	if door != null and is_instance_valid(door) and door.target == target:
		return door
	for impression in impressions:
		if impression.target == target:
			return impression
	return null


## The places row's door (Wei's room); null takes it away.
func set_door(impression: Impression) -> void:
	if door != null and is_instance_valid(door) and door != impression:
		door.queue_free()
	door = impression
	if door != null:
		_take(door, false)
	_place()


## The child pressed [param impression]: &"chosen" (it pops; [signal chosen] follows), &"sealed" (not open
## yet: the hub says "Soon") or &"busy" (still rising, sliding or closed).
func press(impression: Impression) -> StringName:
	if impression == null or (impression not in impressions and impression != door):
		return &""
	if impression.sealed:
		return &"sealed"
	if turning or not opened:
		return &"busy"
	_wake_now()
	_choose(impression)
	return &"chosen"


func _choose(impression: Impression) -> void:
	if _carousel() and impression != door and impression != front():
		await step_to(impression, false)
	impression.touched()
	impression.pop()
	# Its name over it, in big retro letters, with a chime (Megan, Nov 18).
	var top := impression.bubble.global_position + Vector3.UP * (Impression.BUBBLE_RADIUS * impression.scale.y + 0.015)
	ChosenTitle.show_over(get_parent(), Impression.title_for(impression.kind), top, App.head().global_position)
	await get_tree().create_timer(0.6).timeout   # the pop, then the name, then the game
	chosen.emit(impression)


## Slides the carousel (past STILL_MAX only; shortest way, eased) until [param impression] is in front.
func step_to(impression: Impression, with_sound := true) -> void:
	var i := impressions.find(impression)
	if i < 0 or impression.sealed or not _carousel():
		return
	var by := _wrapped(i - offset)
	turning = true
	var tween := create_tween()
	tween.tween_method(func(o: float) -> void:
		offset = o
		_place(), offset, offset + by, TURN_SECONDS * maxf(1.0, absf(by) * 0.8)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	offset = roundf(offset)
	turning = false
	_place()
	if with_sound:
		impression.sound()
	turned.emit(impression)


## A new game rises out of the brew (from [param from]) into the arc, the others easing aside to make room
## (one clear moment, ~1 s); its sound plays as it arrives. With the menu closed it simply joins.
func add(impression: Impression, from: Vector3) -> void:
	_take(impression)
	if not opened or not visible:
		if _carousel():
			offset = float(impressions.size() - 1)
		_place()
		return
	_wake_now()
	turning = true
	var starts: Array[Vector3] = []
	for piece in impressions:
		starts.append(piece.global_position if piece != impression else from)
	if _carousel():
		offset = float(impressions.size() - 1)
	_place()
	var ends: Array[Vector3] = []
	var sizes: Array[Vector3] = []
	for piece in impressions:
		ends.append(piece.global_position)
		sizes.append(piece.scale)
	var tween := create_tween()
	tween.tween_method(func(k: float) -> void:
		for i in impressions.size():
			impressions[i].global_position = starts[i].lerp(ends[i], k)
		impression.scale = sizes[sizes.size() - 1] * lerpf(0.2, 1.0, k), 0.0, 1.0, RISE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	turning = false
	_place()
	impression.sound()
	turned.emit(impression)


## Fades every halo; the menu stays and can be woken with [method wake].
func quiet(seconds := 0.8) -> void:
	_quiet = true
	var tween := create_tween()
	tween.tween_method(func(f: float) -> void:
		_waiting = f
		for impression in _all():
			impression.set_near(0.0)
		_place(), 1.0, 0.0, seconds)


## The menu closes: the bubbles sink back into the cauldron's [param mouth] and are gone (before a game, Wei's
## room, or the closing).
func sink(mouth: Vector3, seconds := 1.0) -> void:
	_quiet = true
	turning = true
	var pieces := _all()
	var starts: Array[Vector3] = []
	var sizes: Array[Vector3] = []
	for impression in pieces:
		starts.append(impression.global_position)
		sizes.append(impression.scale)
	var tween := create_tween()
	tween.tween_method(func(k: float) -> void:
		for i in pieces.size():
			if is_instance_valid(pieces[i]):
				pieces[i].global_position = starts[i].lerp(mouth, k)
				pieces[i].scale = sizes[i] * lerpf(1.0, 0.2, k)
				pieces[i].set_waiting(0.0)
				pieces[i].set_near(0.0), 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	visible = false
	opened = false
	turning = false


## The menu opens: the bubbles rise out of the cauldron's [param mouth] to their places (the child's tap on
## the cauldron; back after a game).
func rise(mouth: Vector3, seconds := OPEN_SECONDS) -> void:
	visible = true
	turning = true
	_quiet = false
	_waiting = 1.0
	_idle = 0.0
	rest = 0.0
	_hovering.clear()
	for impression in _all():
		impression.reset_bubble()
	_place()
	var pieces := _all()
	var ends: Array[Vector3] = []
	var sizes: Array[Vector3] = []
	for impression in pieces:
		ends.append(impression.global_position)
		sizes.append(impression.scale)
	var tween := create_tween()
	tween.tween_method(func(k: float) -> void:
		for i in pieces.size():
			if is_instance_valid(pieces[i]):
				pieces[i].global_position = mouth.lerp(ends[i], k)
				pieces[i].scale = sizes[i] * lerpf(0.2, 1.0, k)
				pieces[i].set_near(0.0), 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	opened = true
	turning = false
	wake()


## Lights the middle bubble again (after [method quiet]).
func wake() -> void:
	_quiet = false
	_waiting = 1.0
	_place()


## True while any bubble's halo is lit.
func is_lit() -> bool:
	return _all().any(func(i: Impression) -> bool:
		return i.is_visible_in_tree() and i._halo.visible and i._halo_light.albedo_color.a > 0.003)


func _enter_tree() -> void:
	alive.append(self)


func _exit_tree() -> void:
	alive.erase(self)


func _process(delta: float) -> void:
	if _quiet or not visible:
		return
	var pointers: Array[Pointer] = []
	if App.rig:
		for hand: StringName in [&"left", &"right"]:
			var pointer := App.rig.pointer(hand)
			if pointer:
				pointers.append(pointer)
	var hand_near := false
	for pointer in pointers:
		if pointer.global_position.distance_to(global_position) < WAKE_NEAR:
			hand_near = true
	for impression in _all():
		var near := 0.0
		for pointer in pointers:
			if pointer.aimed == impression.target:
				near = 1.0
			var gap := pointer.global_position.distance_to(impression.target.global_position)
			near = maxf(near, clampf(inverse_lerp(NEAR_FROM, NEAR_FULL, gap), 0.0, 1.0))
		if not impression.sealed:
			impression.set_near(near)
		# The sound label: once each time a hand comes to it (sealed ones too: "Soon").
		if near >= HOVER_AT and opened and not turning and not _hovering.get(impression, false):
			_hovering[impression] = true
			hovered.emit(impression)
		elif near < 0.15:
			_hovering.erase(impression)
		if near > 0.0:
			hand_near = true
	# Rest and wake (Megan, Nov 18): a hand coming near wakes it; ~20 s with none, it settles.
	if not opened or turning:
		_idle = 0.0
	elif hand_near:
		_wake_now()
	else:
		_idle += delta
		if _idle >= REST_AFTER and rest < 1.0 and (_rest_tween == null or not _rest_tween.is_running()):
			_rest_to(1.0, REST_SECONDS)


func _take(impression: Impression, task := true) -> void:
	if impression.get_parent() == null:
		add_child(impression)
	impression.add_bubble()
	if task and impression not in impressions:
		impressions.append(impression)


func _wake_now() -> void:
	_idle = 0.0
	if rest > 0.0 and (_rest_tween == null or not _rest_tween.is_running() or rest > 0.99):
		_rest_to(0.0, WAKE_SECONDS)


func _rest_to(to: float, seconds: float) -> void:
	if _rest_tween != null and _rest_tween.is_running():
		_rest_tween.kill()
	_rest_tween = create_tween()
	_rest_tween.tween_method(func(r: float) -> void:
		rest = r
		_place(), rest, to, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _all() -> Array[Impression]:
	var list: Array[Impression] = []
	for impression in impressions:
		if is_instance_valid(impression):
			list.append(impression)
	if door != null and is_instance_valid(door):
		list.append(door)
	return list


func _carousel() -> bool:
	return impressions.size() > STILL_MAX


func _wrapped(steps: float) -> float:
	var n := maxi(impressions.size(), 1)
	var w := fposmod(steps, float(n))
	return w - n if w > n * 0.5 else w


## Where piece [param i] sits on the arc: radians from straight toward the child.
func _angle(i: int) -> float:
	if not _carousel():
		return (i - (impressions.size() - 1) * 0.5) * STEP
	return _wrapped(i - offset) * STEP


## Every bubble at its place: the tasks on a still arc facing the child (the middle one a little bigger; past
## STILL_MAX the far ones peek in at the ends), the door below and a little nearer.
func _place() -> void:
	var shrink := lerpf(1.0, REST_SCALE, rest)
	var arc_middle := global_position - _toward * RADIUS
	var leader := front()
	var middle_angle := 0.0 if _carousel() or impressions.size() % 2 == 1 else STEP * 0.5
	var edge := STEP * (2.0 if _carousel() else 9.0)
	for i in impressions.size():
		var impression := impressions[i]
		if not is_instance_valid(impression):
			continue
		var angle := _angle(i)
		impression.visible = absf(angle) <= edge + 0.01
		var frontness := clampf(1.0 - (absf(angle) - middle_angle) / STEP, 0.0, 1.0)
		var peek := _carousel() and absf(angle) > STEP * 1.5   # the ends: smaller (there's more)
		var size := lerpf(SIDE_SCALE, FRONT_SCALE, frontness) * (0.75 if peek else 1.0) * shrink
		var at := arc_middle + (_toward * cos(angle) + _side * sin(angle)) * RADIUS \
				+ Vector3.DOWN * (absf(angle) * 0.02 + 0.03 * rest)
		impression.scale = Vector3.ONE * size
		impression.global_position = at - Vector3.UP * Impression.MIDDLE.y * size
		impression.look_at(impression.global_position + _toward, Vector3.UP, true)
		impression.scale = Vector3.ONE * size
		impression.set_waiting(_waiting * 0.6 if impression == leader and not turning and not _quiet else 0.0)
	if door != null and is_instance_valid(door):
		var size := DOOR_SCALE * shrink
		var at := global_position - _toward * DOOR_BACK + Vector3.DOWN * (DOOR_BELOW + 0.02 * rest)
		door.scale = Vector3.ONE * size
		door.global_position = at - Vector3.UP * Impression.MIDDLE.y * size
		door.look_at(door.global_position + _toward, Vector3.UP, true)
		door.scale = Vector3.ONE * size
