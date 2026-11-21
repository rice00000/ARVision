class_name WorkshopCauldronMenu
extends Node3D
## The cauldron's interaction and placement on the workshop table.

const TINT := Color(1.0, 0.86, 0.55)
const GAME_SCALE := 0.6
const DRAG_DISTANCE := 0.03
const DRAG_STEP := 0.01
const MAX_DRAG_SAMPLE := 0.05
const CLEARANCE := 0.018
const POT_RADIUS := EntryLayout.CAULDRON_WIDTH * GAME_SCALE * 0.5 + CLEARANCE

var target: Target
var engraving: Node3D
var radius: float
var glow := 0.0
var in_game := false
var _pot: Node3D
var _table_pose: Transform3D
var _table: Surface
var _activity: Node3D
var _reach := 0.0
var _eye := Vector2.ZERO
var _pot_height := 0.0
var _footprints: Array[Rect2] = []
var _parked := Vector2.INF
var _landing_ring: MeshInstance3D
var _hand := &""
var _hand_position := Vector2.ZERO
var _dragging := false
var _pressed_paused := false
var _mouth_local: Vector3
var _glow_light: StandardMaterial3D
var _glow_quad: MeshInstance3D
var _groove_light: StandardMaterial3D


func set_target_layer(layer: int) -> void:
	target.collision_layer = layer


func is_lit() -> bool:
	return glow > 0.003


func update_glow(want: float, delta: float) -> void:
	_groove_light.emission_energy_multiplier = glow * 0.8
	glow = move_toward(glow, want, delta * (3.0 if want > glow else 1.5))
	_glow_light.albedo_color.a = glow * 0.35
	_glow_quad.visible = is_lit()


func begin_game(activity: Node3D, reach: float) -> void:
	in_game = true
	_activity = activity
	_table = App.reality.work_surface()
	_eye = _table_point(App.head().global_position)
	_reach = reach
	if not _parked.is_finite():
		_parked = _table_point(_table_pose.origin)
	place_clear()
	set_target_layer(Pointer.SIDE_MENU_LAYER)


func end_game() -> void:
	_finish_pinch()
	in_game = false
	_activity = null
	_place(_table_pose)
	set_target_layer(0)


## Settle when the game builds its layout. A usable parking spot survives the next round.
func place_clear() -> void:
	_finish_pinch()
	var clear := _find_parking_spot()
	if clear.is_finite():
		_parked = clear
	_place_on_table(_parked)


## A stationary release confirms. Once the hand has dragged, release only parks the pot.
func pinch(hand: StringName, pressed: bool) -> bool:
	if pressed:
		if _hand == &"":
			_hand = hand
			_hand_position = _table_point(App.rig.pointer(hand).grip().origin)
			_pressed_paused = get_tree().paused
			set_physics_process(true)
		return false
	if _hand != hand:
		return false
	_update_pinch()
	if _hand == &"":
		return false
	var confirm := not _dragging
	if _landing_ring.visible:
		Events.play(&"place", global_position)
	_finish_pinch()
	return confirm


func _physics_process(_delta: float) -> void:
	_update_pinch()


func _update_pinch() -> void:
	var pointer := App.rig.pointer(_hand)
	if not pointer.tracked() or App.menu_layer() == Pointer.MENU_LAYER or get_tree().paused != _pressed_paused:
		_finish_pinch()
		return
	var hand_position := _table_point(pointer.grip().origin)
	var motion := hand_position - _hand_position
	if not _dragging:
		if motion.length_squared() < DRAG_DISTANCE * DRAG_DISTANCE:
			return
		_dragging = true
		motion -= motion.normalized() * DRAG_DISTANCE
	# Consume blocked hand movement too, so letting go or reversing cannot pull the pot forward.
	_hand_position = hand_position
	if _pressed_paused:
		return
	if not motion.is_zero_approx():
		_slide_on_table(motion.limit_length(MAX_DRAG_SAMPLE))
	_landing_ring.global_transform = Transform3D(_table.transform.basis, global_position + _table.transform.basis.y * 0.003)
	_landing_ring.show()


## Try small steps so a fast drag still stops at obstacles. Keep the free component at contact.
func _slide_on_table(motion: Vector2) -> void:
	_read_footprints()
	var steps := ceili(motion.length() / DRAG_STEP)
	var step := motion / steps
	for index in steps:
		var next := _parked + step
		if _fits(next):
			_parked = next
			continue
		for axis in 2:
			var slide := _parked
			slide[axis] += step[axis]
			if step[axis] != 0.0 and _fits(slide):
				_parked = slide
	_place_on_table(_parked)


func _finish_pinch() -> void:
	_hand = &""
	_dragging = false
	_landing_ring.hide()
	set_physics_process(false)


func _table_point(world: Vector3) -> Vector2:
	var local := _table.transform.affine_inverse() * world
	return Vector2(local.x, local.z)


func _table_world(spot: Vector2) -> Vector3:
	return _table.transform * Vector3(spot.x, 0, spot.y)


func _place_on_table(spot: Vector2) -> void:
	_place(Transform3D(_table_pose.basis.scaled(Vector3.ONE * GAME_SCALE), _table_world(spot)))


## Prefer the tabletop when parking at the start of a round.
func _find_parking_spot() -> Vector2:
	_read_footprints()
	var reachable := _eye + (_parked - _eye).limit_length(_reach)
	var half := _table.size * 0.5 - Vector2.ONE * POT_RADIUS
	var on_table := reachable.clamp(-half.max(Vector2.ZERO), half.max(Vector2.ZERO))
	var clear := Surface.nearest_free(on_table, _reach * 2.0,
		func(spot: Vector2) -> bool: return absf(spot.x) <= half.x and absf(spot.y) <= half.y and _fits(spot))
	return clear if clear.is_finite() else Surface.nearest_free(reachable, _reach * 2.0, _fits)


func _read_footprints() -> void:
	_footprints.clear()
	var from_world := _table.transform.affine_inverse()
	_add_footprints(App.stage, from_world)
	_add_footprints(_activity, from_world)
	if _pot != null:
		_add_footprints(_pot.get_parent(), from_world)


## Include the board and empty visual guides as well as the things the child picks up.
func _add_footprints(root: Node, from_world: Transform3D) -> void:
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree() or mesh.mesh == null or (_pot != null and _pot.is_ancestor_of(mesh)):
			continue
		var box := (from_world * mesh.global_transform) * mesh.get_aabb()
		if box.end.y >= -CLEARANCE and box.position.y <= _pot_height + CLEARANCE:
			_footprints.append(Rect2(box.position.x, box.position.z, box.size.x, box.size.z))


func _fits(spot: Vector2) -> bool:
	if spot.distance_to(_eye) > _reach:
		return false
	for footprint in _footprints:
		if spot.distance_squared_to(spot.clamp(footprint.position, footprint.end)) < POT_RADIUS * POT_RADIUS:
			return false
	return App.reality.is_free(_table_world(spot), POT_RADIUS)


func mouth_position() -> Vector3:
	return to_global(_mouth_local)


func _place(pose: Transform3D) -> void:
	global_transform = pose
	if _pot != null:
		_pot.global_transform = pose


func build(pot: Node3D, mouth: Vector3, eye: Vector3) -> void:
	_pot = pot
	global_transform = pot.global_transform if pot != null else Transform3D(Basis.IDENTITY, mouth)
	_table_pose = global_transform
	_mouth_local = to_local(mouth)
	var box := _bounds(pot) if pot != null else AABB(Vector3.ZERO, Vector3.UP * EntryLayout.CAULDRON_RIM)
	_pot_height = box.size.y * GAME_SCALE
	var width := 0.3
	if pot != null:
		width = maxf(0.2, (mouth.y - pot.global_position.y) * 2.0 + 0.1)
	radius = width * 0.5
	target = Target.sphere(&"hub_cauldron", radius)
	target.near_pinch = true
	add_child(target)
	target.global_position = (pot.global_position + mouth) * 0.5 if pot != null else mouth
	_glow_light = StandardMaterial3D.new()
	_glow_light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_light.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_light.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow_light.albedo_texture = Onion.soft_dot()
	_glow_light.albedo_color = Color(TINT, 0.0)
	_glow_light.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.24
	quad.material = _glow_light
	_glow_quad = MeshInstance3D.new()
	_glow_quad.name = "cauldron_glow"
	_glow_quad.mesh = quad
	_glow_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow_quad)
	_glow_quad.global_position = mouth + Vector3.UP * 0.01
	_glow_quad.rotation = Vector3(-PI * 0.5, 0.0, 0.0)   # lies on the brew
	_build_engraving(pot, mouth, eye, box)
	_build_landing_ring()
	set_physics_process(false)
	set_target_layer(0)


func _build_landing_ring() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = TINT
	var ring := TorusMesh.new()
	ring.inner_radius = POT_RADIUS - 0.005
	ring.outer_radius = POT_RADIUS
	ring.material = material
	_landing_ring = MeshInstance3D.new()
	_landing_ring.mesh = ring
	_landing_ring.top_level = true
	_landing_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_landing_ring)
	_landing_ring.hide()


## The engraving follows the pot as it moves.
func _build_engraving(pot: Node3D, mouth: Vector3, eye: Vector3, box: AABB) -> void:
	engraving = Node3D.new()
	engraving.name = "menu_engraving"
	var toward := Vector3(eye.x - mouth.x, 0.0, eye.z - mouth.z).normalized()
	var belly := mouth + Vector3.DOWN * 0.05
	var belly_radius := 0.06
	if pot != null:
		if box.size != Vector3.ZERO:
			# Measured without the legs and handles: the belly's middle is a little under the rim, and its radius
			# is the narrower of the pot's two widths (the handles stick out sideways).
			belly = Vector3(mouth.x, mouth.y - (mouth.y - box.position.y) * 0.32, mouth.z)   # the belly's widest band
			belly_radius = _surface_toward(pot, belly, toward, minf(box.size.x, box.size.z) * 0.5)
		pot.add_child(engraving)
	else:
		add_child(engraving)
	engraving.global_position = belly + toward * (belly_radius - 0.002)   # on the surface, cut in a little
	engraving.look_at(engraving.global_position + toward, Vector3.UP, true)
	_groove_light = StandardMaterial3D.new()
	_groove_light.albedo_color = Color(0.16, 0.13, 0.1)   # a dark cut in the pale pot
	_groove_light.roughness = 0.9
	_groove_light.emission_enabled = true
	_groove_light.emission = TINT
	_groove_light.emission_energy_multiplier = 0.0
	var size := clampf(belly_radius * 0.55, 0.022, 0.045)
	for row in 3:
		var groove := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = size * 0.11
		capsule.height = size
		groove.mesh = capsule
		groove.material_override = _groove_light
		groove.rotation.z = PI * 0.5   # lying across
		groove.scale = Vector3(1.0, 1.0, 0.45)   # cut into the surface, not standing on it
		groove.position = Vector3(0.0, (1 - row) * size * 0.36, 0.0)
		engraving.add_child(groove)


## How far the pot's own surface reaches from [param centre] along [param toward], at that height: its mesh points
## within a band around the line (the legs and handles stick out elsewhere). [param fallback] when none.
func _surface_toward(node: Node3D, centre: Vector3, toward: Vector3, fallback: float) -> float:
	var best := 0.0
	var side := toward.cross(Vector3.UP)
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		var faces := mesh.mesh.get_faces()
		var xf := mesh.global_transform
		for point in faces:
			var p := xf * point - centre
			if absf(p.y) < 0.015 and absf(p.dot(side)) < 0.02:
				best = maxf(best, p.dot(toward))
	return best if best > 0.01 else fallback


## The world box round every mesh under [param node].
func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		var b := mesh.global_transform * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _exit_tree() -> void:
	if is_instance_valid(_pot):
		if in_game:
			_pot.global_transform = _table_pose
		engraving.queue_free()
