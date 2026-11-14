class_name ButterflySwarm
extends MultiMeshInstance3D
## All the butterflies of a round, drawn in one call (butterfly.gdshader beats
## the wings). Each flies round [member centre] (the child's eyes) at its own
## height: [member spin] +1 anticlockwise seen from above, -1 clockwise. Its
## aim turns it off the circle (0 along it, PI back the other way); a pull
## keeps it within [member band] of [member radius]. A butterfly can be thrown
## aside ([method dodge]), carried into the net ([method catch_in]) and let go
## ([method release]).

enum { FLYING, TO_NET, IN_NET, FREE, GONE }

const SPECIES: Array[StringName] = [&"monarch", &"morpho", &"brimstone", &"swallowtail", &"rose"]
const WINGSPAN := 0.1
## Radians a second a butterfly turns towards a new aim.
const TURN := 2.5
const DODGE_SECONDS := 0.7
const TO_NET_SECONDS := 0.3
const FREE_SECONDS := 2.4
const IN_NET_SCALE := 0.7

var centre := Vector3.ZERO
var radius := 0.72
var band := 0.15
## How fast they fly (m/s); [member slow] scales it (help).
var speed := 0.2
var slow := 1.0

var _state := PackedInt32Array()
var _species := PackedInt32Array()
var _pos := PackedVector3Array()
var _facing := PackedVector3Array()
var _height := PackedFloat32Array()
var _spin := PackedFloat32Array()
var _aim := PackedFloat32Array()
var _aim_to := PackedFloat32Array()
var _flutter := PackedFloat32Array()
var _dodge := PackedVector3Array()
var _dodge_left := PackedFloat32Array()
## In the net: the spot in the net's frame. Let go: the way out.
var _spot := PackedVector3Array()
var _clock := PackedFloat32Array()
var _net: Node3D
var _buffer := PackedFloat32Array()
## A release waiting: towards, flying, seconds left.
var _release: Array = []


func _init() -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = _butterfly_mesh()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Starts over with nobody, round [param at].
func reset(at: Vector3) -> void:
	centre = at
	for array: Variant in [_state, _species, _pos, _facing, _height, _spin, _aim, _aim_to, _flutter, _dodge,
			_dodge_left, _spot, _clock]:
		array.resize(0)
	multimesh.instance_count = 0
	custom_aabb = AABB(Vector3.ONE * -(radius + band + 1.0), Vector3.ONE * (radius + band + 1.0) * 2.0)


## Adds one at [param angle] round the circle (radians from +X, anticlockwise from above), [param height] from the eyes.
func add(species: int, angle: float, height: float, spin: float, aim := 0.0) -> void:
	_state.append(FLYING)
	_species.append(species)
	_pos.append(centre + Vector3(cos(angle), 0.0, -sin(angle)) * radius + Vector3.UP * height)
	_facing.append(Vector3.FORWARD)
	_height.append(height)
	_spin.append(spin)
	_aim.append(aim)
	_aim_to.append(aim)
	_flutter.append(randf() * TAU)
	_dodge.append(Vector3.ZERO)
	_dodge_left.append(0.0)
	_spot.append(Vector3.ZERO)
	_clock.append(0.0)


## Call after the last [method add].
func show_all() -> void:
	multimesh.instance_count = _state.size()
	_buffer.resize(_state.size() * 16)
	for i in _state.size():
		_buffer[i * 16 + 12] = float(_species[i]) / 8.0
		_buffer[i * 16 + 13] = randf()
		_buffer[i * 16 + 14] = randf_range(0.5, 0.7) # 5-7 beats a second
	step(0.0)


func size() -> int:
	return _state.size()


func flying(i: int) -> bool:
	return _state[i] == FLYING


func flying_count() -> int:
	return _state.count(FLYING)


## Where it is now, a dodge included.
func position_of(i: int) -> Vector3:
	return _pos[i] + _dodge[i] * sin(PI * _dodge_left[i] / DODGE_SECONDS)


func species_of(i: int) -> StringName:
	return SPECIES[_species[i]]


## Where it is flying now, level (m/s).
func heading(i: int) -> Vector3:
	return _direction(i) * speed * slow


## The way along the circle at [param at] for [param spin], level and unit length.
func along(at: Vector3, spin: float) -> Vector3:
	var out := Vector3(at.x - centre.x, 0.0, at.z - centre.z).normalized()
	return out.cross(Vector3.UP) * -spin


## Turns it, smoothly, to fly [param spin] round the circle with [param aim] off it.
func steer(i: int, spin: float, aim: float) -> void:
	_spin[i] = spin
	_aim_to[i] = aim


## Darts away from [param from] for a moment, then flies on.
func dodge(i: int, from: Vector3) -> void:
	var away := _pos[i] - from
	away.y = absf(away.y) + 0.05
	_dodge[i] = away.normalized() * 0.14
	_dodge_left[i] = DODGE_SECONDS


## Flies into the bag of [param net] and stays there, fluttering at [param spot] (the net's frame).
func catch_in(i: int, net: Node3D, spot: Vector3) -> void:
	_net = net
	_dodge_left[i] = 0.0
	_state[i] = TO_NET
	_spot[i] = spot
	_clock[i] = 0.0


## Every one in the net (and with [param flying], every one still flying) flies up and away towards
## [param towards] (level), then is gone; [param after] seconds from now.
func release(towards: Vector3, flying := false, after := 0.0) -> void:
	if after > 0.0:
		_release = [towards, flying, after]
		return
	for i in _state.size():
		if _state[i] in [TO_NET, IN_NET] or flying and _state[i] == FLYING:
			_state[i] = FREE
			_clock[i] = 0.0
			_spot[i] = (towards.rotated(Vector3.UP, randf_range(-0.8, 0.8)) * 0.8 + Vector3.UP * 0.6) / FREE_SECONDS


func step(delta: float) -> void:
	if not _release.is_empty():
		_release[2] -= delta
		if _release[2] <= 0.0:
			var waiting := _release
			_release = []
			release(waiting[0], waiting[1])
	for i in _state.size():
		_clock[i] += delta
		var scale := 1.0
		match _state[i]:
			FLYING:
				_fly(i, delta)
			TO_NET:
				var weight := minf(1.0, _clock[i] / TO_NET_SECONDS)
				_pos[i] = _pos[i].lerp(_net.global_transform * _spot[i], weight)
				scale = lerpf(1.0, IN_NET_SCALE, weight)
				if weight >= 1.0:
					_state[i] = IN_NET
			IN_NET:
				var t := _clock[i] * 6.0
				_pos[i] = _net.global_transform * (_spot[i] + Vector3(sin(t * 0.31), sin(t * 0.23), cos(t * 0.27)) * 0.015)
				_facing[i] = _facing[i].rotated(Vector3.UP, delta * 0.4)
				scale = IN_NET_SCALE
			FREE:
				_pos[i] += _spot[i] * delta
				_facing[i] = _spot[i].normalized()
				scale = IN_NET_SCALE * clampf(1.0 - (_clock[i] - 0.6) / (FREE_SECONDS - 0.6), 0.0, 1.0)
				if _clock[i] >= FREE_SECONDS:
					_state[i] = GONE
			GONE:
				scale = 0.0
		_write(i, scale)
	multimesh.buffer = _buffer


func _direction(i: int) -> Vector3:
	var out := Vector3(_pos[i].x - centre.x, 0.0, _pos[i].z - centre.z)
	var off := out.length() - radius
	out = out.normalized()
	var way := out.cross(Vector3.UP) * -_spin[i]
	var direction := way * cos(_aim[i]) + out * sin(_aim[i])
	return (direction - out * clampf(off / band, -2.0, 2.0) * 0.6).normalized()


func _fly(i: int, delta: float) -> void:
	_aim[i] = rotate_toward(_aim[i], _aim_to[i], TURN * delta)
	var velocity := _direction(i) * speed * slow
	_flutter[i] += delta * 2.3
	var flutter := sin(_flutter[i]) * 0.035
	var level := centre.y + _height[i]
	_pos[i] += velocity * delta
	_pos[i].y = level + flutter
	_dodge_left[i] = maxf(0.0, _dodge_left[i] - delta)
	if velocity.length_squared() > 0.0:
		_facing[i] = _facing[i].slerp(velocity.normalized(), minf(1.0, delta * 8.0)) if delta > 0.0 else velocity.normalized()


func _write(i: int, scale: float) -> void:
	var basis := Basis.looking_at(_facing[i], Vector3.UP).scaled(Vector3.ONE * scale) if scale > 0.0 else Basis().scaled(Vector3.ZERO)
	var local := global_transform.affine_inverse() * Transform3D(basis, position_of(i))
	var b := local.basis
	var o := i * 16
	_buffer[o] = b.x.x
	_buffer[o + 1] = b.y.x
	_buffer[o + 2] = b.z.x
	_buffer[o + 3] = local.origin.x
	_buffer[o + 4] = b.x.y
	_buffer[o + 5] = b.y.y
	_buffer[o + 6] = b.z.y
	_buffer[o + 7] = local.origin.y
	_buffer[o + 8] = b.x.z
	_buffer[o + 9] = b.y.z
	_buffer[o + 10] = b.z.z
	_buffer[o + 11] = local.origin.z


## One butterfly: a thin body along Z and two wing quads out to the sides (UV2 x: -1 left, 0 body, 1 right).
static func _butterfly_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := WINGSPAN * 0.5
	var depth := WINGSPAN * 0.62
	for side: float in [-1.0, 1.0]:
		# UV x: 0 at the body, 1 at the tip; y: 0 at the front (-Z).
		var corners := [Vector3(0.0, 0.0, -depth * 0.5), Vector3(side * half, 0.0, -depth * 0.5),
			Vector3(side * half, 0.0, depth * 0.5), Vector3(0.0, 0.0, depth * 0.5)]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for k: int in [0, 1, 2, 0, 2, 3]:
			tool.set_uv2(Vector2(side, 0.0))
			tool.set_uv(uvs[k])
			tool.add_vertex(corners[k])
	var length := 0.045
	var width := 0.004
	for quad: Array in [[Vector3(-width, 0.0, -length * 0.5), Vector3(width, 0.0, -length * 0.5), Vector3(width, 0.0, length * 0.5), Vector3(-width, 0.0, length * 0.5)],
			[Vector3(0.0, -width, -length * 0.5), Vector3(0.0, width, -length * 0.5), Vector3(0.0, width, length * 0.5), Vector3(0.0, -width, length * 0.5)]]:
		for k: int in [0, 1, 2, 0, 2, 3]:
			tool.set_uv2(Vector2.ZERO)
			tool.set_uv(Vector2.ZERO)
			tool.add_vertex(quad[k])
	var mesh := tool.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://trials/butterfly/butterfly.gdshader")
	mesh.surface_set_material(0, material)
	return mesh
