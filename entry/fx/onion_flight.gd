class_name OnionFlight
extends Node
## Onion's welcome flight into the child's room, the first time only (Megan, Nov 18, Scene 12): Onion swoops
## in from the far side of the room, makes one joyful loop facing the child, glides down to its spot beside
## the room's panel and lands with a squash and a bounce. A special moment of excitement, not Onion's normal
## way of moving. The child's view never moves; nothing comes straight at the child (the path passes in
## front, to the right, ~0.9 m away), and the loop stays low, under the room's panel. A short trail of warm
## specks makes the path easy to follow (low vision). The room works the whole time.
## Use: [code]await OnionFlight.welcome(onion, land_at)[/code]; it returns when Onion has landed.

signal landed

const SWOOP_SECONDS := 1.0
const LOOP_SECONDS := 1.5
const GLIDE_SECONDS := 0.85
const LOOP_RADIUS := 0.2
## Where the loop is, from the eyes: this far ahead, to the right, and below (under the room's panel).
const LOOP_AT := Vector3(0.3, -0.42, 0.75)    # right, up, ahead: its top stays under the panel
## Where Onion comes from: far ahead and a little left, a little high.
const START_AT := Vector3(-0.55, 0.3, 2.1)
const BANK := 0.35                            # radians, leaning into the loop
const STRETCH := 0.16                         # along the path at full speed
## Onion is a little bigger while it flies (11 cm is small at ~0.8 m, for low vision), back to 1 on landing.
const FLYING_SIZE := 1.35
const TRAIL_COLOUR := Color(1.0, 0.86, 0.55)

var _onion: Onion
var _path := PackedVector3Array()
var _times := PackedFloat32Array()             # the time each path point is reached
var _clock := 0.0
var _trail: CPUParticles3D
var _done := false


## Flies [param onion] from the far side of the room to [param land_at] (world). Awaitable.
static func welcome(onion: Onion, land_at: Vector3) -> void:
	var flight := OnionFlight.new()
	flight.name = "OnionFlight"
	flight.process_mode = Node.PROCESS_MODE_ALWAYS   # the room pauses the game
	onion.add_child(flight)
	flight._start(onion, land_at)
	await flight.landed


## True while [param onion] is still flying in.
static func flying(onion: Onion) -> bool:
	return onion != null and onion.get_node_or_null(^"OnionFlight") != null


func _start(onion: Onion, land_at: Vector3) -> void:
	_onion = onion
	var head := App.head().global_transform
	var ahead := Vector3(-head.basis.z.x, 0.0, -head.basis.z.z).normalized()
	var right := ahead.cross(Vector3.UP).normalized()
	var eye := head.origin
	var from := eye + right * START_AT.x + Vector3.UP * START_AT.y + ahead * START_AT.z
	var centre := eye + right * LOOP_AT.x + Vector3.UP * LOOP_AT.y + ahead * LOOP_AT.z
	var bottom := centre + Vector3.DOWN * LOOP_RADIUS
	# The swoop: down from far off to the bottom of the loop, curving in from the left.
	var bend := from.lerp(bottom, 0.5) + Vector3.DOWN * 0.15 - right * 0.15
	for i in 24:
		var t := i / 24.0
		_add(_bezier(from, bend, bottom, _ease(t)), SWOOP_SECONDS * t)
	# One loop facing the child, anticlockwise as seen (up the right side, over the top, down the left),
	# a little slower over the top, the way a real loop carries.
	for i in 48:
		var u := i / 48.0
		var a := -PI * 0.5 + TAU * (u - sin(TAU * u) * 0.06)
		_add(centre + right * cos(a) * LOOP_RADIUS + Vector3.UP * sin(a) * LOOP_RADIUS + ahead * sin(a) * 0.05,
			SWOOP_SECONDS + LOOP_SECONDS * u)
	# The glide: from the bottom of the loop up and over to the landing spot, slowing to a stop.
	var lift := bottom.lerp(land_at, 0.5) + Vector3.UP * 0.12
	for i in 25:
		var t := i / 24.0
		_add(_bezier(bottom, lift, land_at, _ease_out(t)), SWOOP_SECONDS + LOOP_SECONDS + GLIDE_SECONDS * t)
	_onion.global_position = from
	_onion.scale = Vector3.ONE * 0.3
	create_tween().tween_property(_onion, ^"scale", Vector3.ONE * FLYING_SIZE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Events.play(&"appear", from)
	_trail = _make_trail()
	_onion.get_parent().add_child(_trail)
	_trail.global_position = from


func _add(at: Vector3, time: float) -> void:
	_path.append(at)
	_times.append(time)


func _process(delta: float) -> void:
	if _done or not is_instance_valid(_onion):
		return
	var last := _clock
	_clock += delta
	if last < SWOOP_SECONDS and _clock >= SWOOP_SECONDS:
		Events.play(&"swish", _onion.global_position)   # into the loop
	if last < SWOOP_SECONDS + LOOP_SECONDS and _clock >= SWOOP_SECONDS + LOOP_SECONDS:
		Events.play(&"swish", _onion.global_position)   # and out of it
	var end := _times[_times.size() - 1]
	if _clock >= end:
		_land()
		return
	var here := _at(_clock)
	var soon := _at(minf(_clock + 0.12, end))
	var velocity := (soon - here) / 0.12
	_onion.global_position = here
	_onion.attend(soon + velocity * 0.2)   # looks where it's going
	if is_instance_valid(_trail):
		_trail.global_position = here
	# Lean into the loop; stretch a little along the path at speed.
	var in_loop := _clock > SWOOP_SECONDS and _clock < SWOOP_SECONDS + LOOP_SECONDS
	_onion.tilt = move_toward(_onion.tilt, BANK if in_loop else 0.0, delta * 1.5)
	var speed := clampf(velocity.length() / 1.6, 0.0, 1.0)
	if _clock > 0.35:
		_onion.scale = Vector3(1.0 - STRETCH * 0.5 * speed, 1.0 + STRETCH * speed, 1.0 - STRETCH * 0.5 * speed) * lerpf(FLYING_SIZE, 1.0, clampf((_clock - SWOOP_SECONDS - LOOP_SECONDS) / GLIDE_SECONDS, 0.0, 1.0))


func _at(time: float) -> Vector3:
	var i := _times.bsearch(time)
	if i <= 0:
		return _path[0]
	if i >= _path.size():
		return _path[_path.size() - 1]
	var t := (time - _times[i - 1]) / maxf(_times[i] - _times[i - 1], 0.0001)
	return _path[i - 1].lerp(_path[i], t)


## The landing: a squash, one small bounce, settle, and turn to the child.
func _land() -> void:
	_done = true
	var at := _path[_path.size() - 1]
	_onion.global_position = at
	_onion.tilt = 0.0
	_onion.attend(null)
	Events.play(&"hop", at)
	if is_instance_valid(_trail):
		_trail.emitting = false
		get_tree().create_timer(0.8, true, false, true).timeout.connect(_trail.queue_free)
	var hop := create_tween()
	hop.tween_property(_onion, ^"scale", Vector3(1.2, 0.78, 1.2), 0.09)
	hop.tween_property(_onion, ^"scale", Vector3(0.92, 1.12, 0.92), 0.12)
	hop.parallel().tween_property(_onion, ^"global_position", at + Vector3.UP * 0.035, 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	hop.tween_property(_onion, ^"scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hop.parallel().tween_property(_onion, ^"global_position", at, 0.16).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	await hop.finished
	_onion.cheer()
	landed.emit()
	queue_free()


func _exit_tree() -> void:
	if not _done:
		_done = true
		if is_instance_valid(_trail):
			_trail.queue_free()
		landed.emit()   # stopped early (the child left the room): nobody waits forever


func _make_trail() -> CPUParticles3D:
	var trail := CPUParticles3D.new()
	trail.name = "OnionTrail"
	trail.process_mode = Node.PROCESS_MODE_ALWAYS
	trail.amount = 50
	trail.lifetime = 0.8
	trail.local_coords = false
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.012
	trail.direction = Vector3.UP
	trail.spread = 180.0
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 0.02
	trail.gravity = Vector3.ZERO
	trail.scale_amount_min = 0.7
	trail.scale_amount_max = 1.2
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	ramp.colors = PackedColorArray([Color(TRAIL_COLOUR, 0.0), Color(TRAIL_COLOUR, 0.9), Color(TRAIL_COLOUR, 0.0)])
	trail.color_ramp = ramp
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = Onion.soft_dot()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.026
	quad.material = mat
	trail.mesh = quad
	return trail


static func _bezier(a: Vector3, b: Vector3, c: Vector3, t: float) -> Vector3:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)


static func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


static func _ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)
