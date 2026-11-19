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
## * **Sound:** [method rise] and [method sink] play the brew's own (Sounds `brew_rise`, `brew_sink`), the sink's
##   gulp timed to the bubbles meeting the brew whatever the duration.
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
const RADIUS := 0.26            # the arc's old radius: STEP * RADIUS is the spacing between neighbours along the arc
const ABOVE_RIM := 0.27         # the menu's middle over the cauldron's rim
const REACH := 0.44             # the menu's middle is pulled toward the child until it is this far from the eyes
const LEAN_MAX := 0.2           # ...but never more than this far forward of the cauldron's mouth
const FRONT_SCALE := 0.6        # the middle bubble (a piece is 12-16 cm, its bubble 22 cm, at scale 1)
const SIDE_SCALE := 0.5
const DOOR_SCALE := 0.42
const DOOR_BACK := 0.06         # the house sits this far BEHIND the games' front, out of a resting hand's way (Megan, Nov 18: "too easy to click"; it was 8 cm nearer)
const DOOR_BELOW := 0.17        # the places row: this far below the tasks (0.14 touched the arc's ends with 4 games)
const PLACE_GAP := 0.17         # metres between the places' middles (gaps at least half a bubble: no crowding)
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
## Following the child (Megan, Nov 18: "menu should follow user"). The menu turns around the cauldron to face
## them and its bubbles tilt toward their eyes, but calmly (nystagmus: nothing drifting under the eyes): only
## once they have moved FOLLOW_TURN around the cauldron or FOLLOW_MOVE metres, never while a hand is near a
## bubble, and as one slow glide.
const FOLLOW_TURN := deg_to_rad(20.0)
const FOLLOW_MOVE := 0.3
const FOLLOW_SECONDS := 0.8

## Every ring alive (for [method HubGlow.quiet_all]).
static var alive: Array[ImpressionRing] = []

var impressions: Array[Impression] = []
## The places row's house (the Virtual Workshop), or null.
var door: Impression
## The places row, left to right (design chat, Nov 18): ? · house · ✕, or just the house.
var places: Array[Impression] = []
## The piece that sits straight ahead (biggest), or -1 for the arc's own middle. A game's own row puts its
## recommended level there (design chat, Nov 18).
var centre := -1
## Carousel steps turned (past STILL_MAX only): piece i sits at (i - offset) * STEP.
var offset := 0.0
var turning := false
## True while the menu is up (between [method rise] and [method sink]).
var opened := false
## 0 awake .. 1 resting.
var rest := 0.0

## The cauldron's mouth the menu sits over (INF: a menu placed by hand, which doesn't follow).
var mouth := Vector3.INF
var _eye := Vector3.INF          # the eyes the bubbles face (moves only with a follow glide)
var _follow: Tween
var _toward := Vector3.FORWARD   # flat direction from the menu toward the child
var _side := Vector3.RIGHT
var _quiet := false
var _waiting := 1.0
var _idle := 0.0
var _rest_tween: Tween
var _sounds: Sounds
## The one bubble lit now (aimed at or a hand near; Nov 19: lit means a pinch takes it), or null.
var lit: Impression
var _hovering: Dictionary = {}   # impression -> its name was said for this visit of the hand


## The menu facing [param eye], its tasks' middle at [param middle] ([method spot] gives the usual place),
## under [param parent]. [param _mouth]: kept for the old calls.
static func make(parent: Node, choices: Array[Impression], middle: Vector3, eye: Vector3, mouth_at := Vector3.INF) -> ImpressionRing:
	var ring := ImpressionRing.new()
	ring.name = "impression_ring"
	parent.add_child(ring)
	ring.global_position = middle
	ring._toward = Vector3(eye.x - middle.x, 0.0, eye.z - middle.z).normalized()
	ring._side = ring._toward.cross(Vector3.UP).normalized()
	ring.mouth = mouth_at
	ring._eye = eye
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


## Faces the menu to the child's eyes at [param eye] at once: over the mouth, leaning toward them.
func aim(eye: Vector3) -> void:
	if mouth != Vector3.INF:
		global_position = spot(mouth, eye)
	var flat := Vector3(eye.x - global_position.x, 0.0, eye.z - global_position.z)
	if flat.length() > 0.01:
		_toward = flat.normalized()
		_side = _toward.cross(Vector3.UP).normalized()
	_eye = eye


## True when the child at [param eye] has moved far enough from the eyes the menu faces to follow them.
func _strayed(eye: Vector3) -> bool:
	if _eye == Vector3.INF:
		return true
	var pivot := mouth if mouth != Vector3.INF else global_position
	var was := Vector2(_eye.x - pivot.x, _eye.z - pivot.z)
	var now := Vector2(eye.x - pivot.x, eye.z - pivot.z)
	if was.length() > 0.05 and now.length() > 0.05 and absf(was.angle_to(now)) > FOLLOW_TURN:
		return true
	return eye.distance_to(_eye) > FOLLOW_MOVE


## One slow glide to face [param eye]: round the cauldron the short way (never through it).
func _follow_to(eye: Vector3) -> void:
	if _follow != null and _follow.is_running():
		return
	var pivot := mouth if mouth != Vector3.INF else global_position
	var from := _eye
	var a0 := Vector2(from.x - pivot.x, from.z - pivot.z)
	var a1 := Vector2(eye.x - pivot.x, eye.z - pivot.z)
	var turn := a0.angle_to(a1)
	_follow = create_tween()
	_follow.tween_method(func(k: float) -> void:
		var flat := a0.rotated(turn * k).normalized() * lerpf(a0.length(), a1.length(), k)
		aim(Vector3(pivot.x + flat.x, lerpf(from.y, eye.y, k), pivot.z + flat.y))
		_place(), 0.0, 1.0, FOLLOW_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


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


## The open game nearest the arc's middle: where the waiting glow and the teaching hand go (never a locked one).
func leader() -> Impression:
	var best: Impression = null
	var best_angle := INF
	for i in impressions.size():
		var piece := impressions[i]
		if not is_instance_valid(piece) or piece.sealed:
			continue
		if absf(_angle(i)) < best_angle:
			best_angle = absf(_angle(i))
			best = piece
	return best if best != null else front()


## The bubble (task or place) whose target is [param target], or null.
func impression_for(target: Target) -> Impression:
	for place in places:
		if is_instance_valid(place) and place.target == target:
			return place
	if door != null and is_instance_valid(door) and door.target == target:
		return door
	for impression in impressions:
		if impression.target == target:
			return impression
	return null


## The places row's house alone (the Virtual Workshop); null takes it away.
func set_door(impression: Impression) -> void:
	set_places([impression] as Array[Impression] if impression != null else [] as Array[Impression], impression)


## The places row, left to right ([param row]), with [param house] the Virtual Workshop among them.
func set_places(row: Array[Impression], house: Impression) -> void:
	for old in places:
		if is_instance_valid(old) and old not in row:
			old.queue_free()
	places = row
	door = house
	for place in places:
		_take(place, false)
	_place()


## The place of [param kind] in the row (&"help", &"house", &"finish"), or null.
func place_of(kind: StringName) -> Impression:
	for place in places:
		if is_instance_valid(place) and place.kind == kind:
			return place
	return null


## The child pressed [param impression]: &"chosen" (it pops; [signal chosen] follows), &"sealed" (not open
## yet: the hub says "Soon") or &"busy" (still rising, sliding or closed).
func press(impression: Impression) -> StringName:
	if impression == null or (impression not in impressions and impression not in places):
		return &""
	if impression.sealed:
		return &"sealed"
	if turning or not opened:
		return &"busy"
	_wake_now()
	_choose(impression)
	return &"chosen"


func _choose(impression: Impression) -> void:
	if _carousel() and impression not in places and impression != front():
		await step_to(impression, false)
	impression.touched()
	impression.pop()
	# Its name over it, in big retro letters, with a chime (Megan, Nov 18).
	var top := impression.bubble.global_position + Vector3.UP * (Impression.BUBBLE_RADIUS * impression.scale.y + 0.015)
	ChosenTitle.show_over(get_parent(), impression.label(), top, App.head().global_position)
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
	_sound(&"brew_sink", mouth, maxf(0.0, seconds - Sounds.BREW_LAND))   # its gulp as they meet the brew
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
	if App.rig and App.head() != null:
		aim(App.head().global_position)   # open facing where the child is now, not where they were
	_place()
	var pieces := _all()
	var ends: Array[Vector3] = []
	var sizes: Array[Vector3] = []
	for impression in pieces:
		ends.append(impression.global_position)
		sizes.append(impression.scale)
	_sound(&"brew_rise", mouth)
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


## Plays [param key] at [param at] after [param delay] s.
func _sound(key: StringName, at: Vector3, delay := 0.0) -> void:
	if _sounds == null:
		_sounds = Sounds.new()
		add_child(_sounds)
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	_sounds.play(key, at)


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
	var nears := {}
	var nearest: Impression = null   # the hover cue lights one bubble only, the nearest (the others are ~15 cm away)
	for impression in _all():
		var near := 0.0
		for pointer in pointers:
			if pointer.aimed == impression.target:
				near = 1.0
			var gap := pointer.global_position.distance_to(impression.target.global_position)
			near = maxf(near, clampf(inverse_lerp(NEAR_FROM, NEAR_FULL, gap), 0.0, 1.0))
		nears[impression] = near
		if near > 0.0 and not impression.sealed and (nearest == null or near > nears[nearest]):
			nearest = impression
	lit = nearest if opened and not turning else null
	for impression in _all():
		var near: float = nears[impression]
		if not impression.sealed:
			var cue := near if impression == nearest else 0.0
			impression.set_near(cue)
			_swell(impression, cue if opened and not turning else 0.0, delta)
		# The sound label: once each time a hand comes to it (sealed ones too: "Soon").
		if near >= HOVER_AT and opened and not turning and not _hovering.get(impression, false):
			_hovering[impression] = true
			hovered.emit(impression)
		elif near < 0.15:
			_hovering.erase(impression)
		if near > 0.0:
			hand_near = true
	# Follow the child (only when calm: open, still, no hand near).
	if opened and not turning and not hand_near and App.rig and App.head() != null:
		var eye := App.head().global_position
		if _strayed(eye):
			_follow_to(eye)
	# Rest and wake (Megan, Nov 18): a hand coming near wakes it; ~20 s with none, it settles.
	if not opened or turning:
		_idle = 0.0
	elif hand_near:
		_wake_now()
	else:
		_idle += delta
		if _idle >= REST_AFTER and rest < 1.0 and (_rest_tween == null or not _rest_tween.is_running()):
			_rest_to(1.0, REST_SECONDS)


## Eases [param impression]'s hover swell toward [param want] (~0.15 s) and resizes it round its middle.
func _swell(impression: Impression, want: float, delta: float) -> void:
	var was := impression.swell
	impression.swell = move_toward(was, want, delta / 0.15)
	if is_equal_approx(was, impression.swell) or impression.base_size <= 0.0:
		return
	var middle := impression.global_transform * Impression.MIDDLE
	impression.scale = Vector3.ONE * impression.base_size * (1.0 + Impression.HOVER_SWELL * impression.swell)
	impression.global_position += middle - impression.global_transform * Impression.MIDDLE   # it grows round its middle


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
	for place in places:
		if is_instance_valid(place):
			list.append(place)
	return list


func _carousel() -> bool:
	return impressions.size() > STILL_MAX


func _wrapped(steps: float) -> float:
	var n := maxi(impressions.size(), 1)
	var w := fposmod(steps, float(n))
	return w - n if w > n * 0.5 else w


## Where piece [param i] sits on the arc: radians from straight toward the child.
func _angle(i: int) -> float:
	if centre >= 0 and not _carousel():
		return (i - centre) * STEP
	if not _carousel():
		return (i - (impressions.size() - 1) * 0.5) * STEP
	return _wrapped(i - offset) * STEP


## Every bubble at its place: the tasks on a still arc round the child's eyes (the middle one a little bigger; past
## STILL_MAX the far ones peek in at the ends), the places row below on the same kind of curve.
func _place() -> void:
	var shrink := lerpf(1.0, REST_SCALE, rest)
	# The games curve round the child too, like the places row (Megan, Nov 18 4:32): every game the same distance
	# from the eyes and at one height. (The arc used to bend away round the cauldron: the ends were ~10 cm further
	# and lower, and the shelf on the far left was hard to reach.) Neighbours keep their spacing along the arc.
	var games_centre := Vector3(_eye.x, global_position.y, _eye.z) if _eye != Vector3.INF else global_position + _toward * 0.45
	var games_reach := maxf(games_centre.distance_to(global_position), 0.2)
	var leader := leader()
	var middle_angle := 0.0 if _carousel() or centre >= 0 or impressions.size() % 2 == 1 else STEP * 0.5
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
		# The first game on the child's left (they read left to right): -_side is the child's right.
		var round_eyes := angle * RADIUS / games_reach   # the same spacing along the arc as before
		var at := games_centre + (-_toward * cos(round_eyes) - _side * sin(round_eyes)) * games_reach \
				+ Vector3.DOWN * 0.03 * rest
		impression.base_size = size
		impression.scale = Vector3.ONE * size
		impression.global_position = at - Vector3.UP * Impression.MIDDLE.y * size
		_face(impression)
		impression.scale = Vector3.ONE * size * (1.0 + Impression.HOVER_SWELL * impression.swell)
		impression.set_waiting(_waiting * 0.6 if impression == leader and not turning and not _quiet else 0.0)
	var size := DOOR_SCALE * shrink
	var row := places.filter(func(p: Impression) -> bool: return is_instance_valid(p))
	# The places row curves round the child (Megan, Nov 18 11:21): every place the same distance from the eyes, so
	# none looks bigger. Its middle sits DOOR_BACK behind the arc's front.
	var middle := global_position - _toward * DOOR_BACK
	var centre_at := Vector3(_eye.x, middle.y, _eye.z) if _eye != Vector3.INF else middle + _toward * 0.45
	var reach := maxf(centre_at.distance_to(middle), 0.2)
	var place_step := PLACE_GAP / reach
	for i in row.size():
		var place: Impression = row[i]
		var angle := (i - (row.size() - 1) * 0.5) * place_step   # left to right as the child sees it
		var at := centre_at + (-_toward * cos(angle) - _side * sin(angle)) * reach \
				+ Vector3.DOWN * (DOOR_BELOW + 0.02 * rest)
		place.base_size = size
		place.scale = Vector3.ONE * size
		place.global_position = at - Vector3.UP * Impression.MIDDLE.y * size
		_face(place)
		place.scale = Vector3.ONE * size * (1.0 + Impression.HOVER_SWELL * place.swell)


## Turns a bubble to the child's eyes (tilted up or down to them too), or flat toward them without eyes.
func _face(piece: Impression) -> void:
	var to := _eye - piece.global_position if _eye != Vector3.INF else _toward
	if to.length() < 0.01 or absf(to.normalized().dot(Vector3.UP)) > 0.98:
		to = _toward
	piece.look_at(piece.global_position + to, Vector3.UP, true)
