class_name ImpressionRing
extends Node3D
## The hub's games above the cauldron: a RING on the cauldron's smoke (Megan, Nov 17; SCENE_REVIEW_DECISIONS
## Scene 7). The cauldron's job is the games only (shelf, dots, cup); the workshop's own controls (Finish
## visit, Home, Back to the workshop) are the gear's.
## * A soft stew-coloured fog rises from the mouth and sits still behind the ring: a plain, calm background
##   for the choices in front of the busy real room (figure-ground for low vision). It never swirls.
## * The ring never turns by itself (a moving target is a vision test in disguise; motion in the middle of
##   the view is clutter). It turns only when a side choice is pressed.
## * ONE press picks any choice: a side one is rotated to the front (eased, no overshoot) and then chosen;
##   the front one is chosen at once. Chosen = its sound, a short pulse, then [signal chosen].
## * The front choice is full size, leaning a little toward the child, with the halo behind it; the others
##   sit round the ring at [constant SIDE_SCALE]. Every choice lights softly while a hand ray aims at it or
##   a hand comes near.
## * [method add]: a new game rises out of the cauldron into the ring and turns to the front ("hidden, not
##   sealed": the dots after the first shelf, Turn to fit when it can run).
## * No arrows and no swipe (a sideways sweep is the dots game's answer).
## [method HubGlow.quiet_all] also quiets every ring (halo and fog) before a game starts.

signal turned(front: Impression)
## The child chose [param impression] (after any turn bringing it to the front).
signal chosen(impression: Impression)

const RADIUS := 0.2             # metres from the ring's middle to each choice
const ABOVE_RIM := 0.16         # the choices' bases over the cauldron's rim: above it, not in front of its body
const LEAN := 0.04              # the front one comes this much nearer the child
const SIDE_SCALE := 0.7
const TURN_SECONDS := 0.8       # a third of a turn; a longer turn takes a little longer
const RISE_SECONDS := 1.0
const NEAR_FROM := 0.25         # a hand this close starts to light a choice...
const NEAR_FULL := 0.08         # ...fully at this distance
const FOG := Color(0.62, 0.78, 0.55)   # the stew's sage
const FOG_ALPHA := 0.8

## Every ring alive (for [method HubGlow.quiet_all]).
static var alive: Array[ImpressionRing] = []

var impressions: Array[Impression] = []
## Radians the ring is turned: choice i sits at i * step + offset; 0 = toward the child.
var offset := 0.0
var turning := false

var _step := TAU / 3.0
var _toward := Vector3.FORWARD   # flat direction from the ring's middle to the child
var _quiet := false
var _waiting := 1.0
var _fog: MeshInstance3D
var _fog_light: StandardMaterial3D
var _column_light: StandardMaterial3D


## A ring of [param choices] over [param middle] (a point over the cauldron's mouth, at the choices' base
## height), facing [param eye], on fog rising from [param mouth] (the cauldron's mouth; INF = no column),
## under [param parent].
static func make(parent: Node, choices: Array[Impression], middle: Vector3, eye: Vector3, mouth := Vector3.INF) -> ImpressionRing:
	var ring := ImpressionRing.new()
	ring.name = "impression_ring"
	parent.add_child(ring)
	ring.global_position = middle
	ring._toward = Vector3(eye.x - middle.x, 0.0, eye.z - middle.z).normalized()
	ring._make_fog(mouth)
	for impression in choices:
		if impression.get_parent() == null:
			ring.add_child(impression)
		ring.impressions.append(impression)
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


## The child pressed [param impression]: &"chosen" ([signal chosen] follows, after a turn bringing it to
## the front if it wasn't), &"sealed" (not open: nothing happens) or &"busy" (still turning or rising).
func press(impression: Impression) -> StringName:
	if impression == null or impression not in impressions:
		return &""
	if impression.sealed:
		return &"sealed"
	if turning:
		return &"busy"
	_choose(impression)
	return &"chosen"


func _choose(impression: Impression) -> void:
	if impression != front():
		await step_to(impression, false)
	impression.touched()
	await get_tree().create_timer(0.35).timeout   # the pressed moment: its sound and pulse, then the game
	chosen.emit(impression)


## Turns the ring (shortest way, eased, no overshoot) until [param impression] is in front.
func step_to(impression: Impression, with_sound := true) -> void:
	var i := impressions.find(impression)
	if i < 0 or impression.sealed:
		return
	var by := -wrapf(i * _step + offset, -PI, PI)
	turning = true
	var tween := create_tween()
	tween.tween_method(func(o: float) -> void:
		offset = o
		_place(), offset, offset + by, TURN_SECONDS * maxf(1.0, absf(by) / _step * 0.8)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	turning = false
	if with_sound:
		impression.sound()
	turned.emit(impression)


## A new game rises out of the cauldron (from [param from], e.g. its mouth) into the ring, which turns it
## to the front; its sound plays as it arrives.
func add(impression: Impression, from: Vector3) -> void:
	if impression.get_parent() == null:
		add_child(impression)
	impressions.append(impression)
	var i := impressions.size() - 1
	var by := -wrapf(i * _step + offset, -PI, PI)
	var begin := offset
	turning = true
	var rise := create_tween()
	rise.tween_method(func(k: float) -> void:
		offset = begin + by * k
		_place()
		impression.global_position = from.lerp(impression.global_position, k)
		impression.scale *= lerpf(0.3, 1.0, k), 0.0, 1.0, RISE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await rise.finished
	turning = false
	_place()
	impression.sound()
	turned.emit(impression)


## Fades every halo and the fog out (before a game); the ring stays and can be woken with [method wake].
func quiet(seconds := 0.8) -> void:
	_quiet = true
	var tween := create_tween()
	tween.tween_method(func(f: float) -> void:
		_waiting = f
		for impression in impressions:
			if is_instance_valid(impression):
				impression.set_near(0.0)
		_fog_light.albedo_color.a = FOG_ALPHA * f
		_column_light.albedo_color.a = FOG_ALPHA * 0.7 * f
		_place(), _waiting, 0.0, seconds)


## The closing (Scene 10, Megan Nov 17): the ring and its fog sink quietly into the cauldron's [param mouth]
## and are gone, before Onion's first goodbye line.
func sink(mouth: Vector3, seconds := 1.2) -> void:
	_quiet = true
	turning = true
	var starts: Array[Vector3] = []
	for impression in impressions:
		starts.append(impression.global_position if is_instance_valid(impression) else mouth)
	var tween := create_tween()
	tween.tween_method(func(k: float) -> void:
		for i in impressions.size():
			var impression := impressions[i]
			if is_instance_valid(impression):
				impression.global_position = starts[i].lerp(mouth, k)
				impression.scale = Vector3.ONE * lerpf(1.0, 0.2, k)
				impression.set_waiting(0.0)
				impression.set_near(0.0)
		_fog_light.albedo_color.a = FOG_ALPHA * (1.0 - k)
		_column_light.albedo_color.a = FOG_ALPHA * 0.7 * (1.0 - k), 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	visible = false


## Lights the front one and the fog again (back at the hub after a game).
func wake() -> void:
	_quiet = false
	_waiting = 1.0
	_fog_light.albedo_color.a = FOG_ALPHA
	_column_light.albedo_color.a = FOG_ALPHA * 0.7
	_place()


## True while anything of the ring is lit (a halo or the fog).
func is_lit() -> bool:
	if _fog_light.albedo_color.a > 0.003:
		return true
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


## Every choice at its place round the ring: the front one full size and leaning toward the child, the
## rest smaller; all facing the child.
func _place() -> void:
	var side := _toward.cross(Vector3.UP)
	var leader := front()
	for i in impressions.size():
		var impression := impressions[i]
		if not is_instance_valid(impression):
			continue
		var angle := wrapf(i * _step + offset, -PI, PI)
		var frontness := clampf(1.0 - absf(angle) / (_step * 0.9), 0.0, 1.0)
		var at := global_position + (_toward * cos(angle) + side * sin(angle)) * RADIUS + _toward * LEAN * frontness
		impression.global_position = at
		impression.look_at(at + _toward, Vector3.UP, true)
		impression.scale = Vector3.ONE * lerpf(SIDE_SCALE, 1.0, frontness)
		impression.set_waiting(_waiting if impression == leader and not turning else 0.0)


## The stew's fog: one large soft cloud behind the ring's middle and a soft column down to the mouth.
## Billboards with depth test (the choices in front draw over them); still: nothing in them moves.
func _make_fog(mouth: Vector3) -> void:
	_fog_light = _soft(FOG_ALPHA)
	_fog = _quad(Vector2(0.95, 0.75), _fog_light)
	_fog.name = "fog"
	_fog.position = -_toward * (RADIUS + 0.08) + Vector3.UP * 0.1   # behind the back choice too
	_column_light = _soft(FOG_ALPHA * 0.7 if mouth != Vector3.INF else 0.0)
	var column := _quad(Vector2(0.26, 0.34), _column_light)
	column.name = "fog_column"
	column.position = -_toward * RADIUS * 0.3 + Vector3.DOWN * 0.04 if mouth == Vector3.INF else (mouth - global_position) + Vector3.UP * 0.12 - _toward * 0.02


func _soft(alpha: float) -> StandardMaterial3D:
	var light := StandardMaterial3D.new()
	light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	light.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	light.albedo_texture = Onion.soft_dot()
	light.albedo_color = Color(FOG, alpha)
	return light


func _quad(size: Vector2, light: StandardMaterial3D) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	mesh.material = light
	var quad := MeshInstance3D.new()
	quad.mesh = mesh
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(quad)
	return quad
