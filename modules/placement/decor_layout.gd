extends Module
## XRVision decor layout, adapted to tracked pinch and seated reach.
## Saved transforms are room-local. A failed move rolls back; no lost items.

const TURN_STEP := PI / 4.0
const REACH_GAIN := 3.0
var layouts: Dictionary = {}
var current_room := &"room_sun"
var editing := false
var _displaying := false
var held: Target
var _hand: StringName
var _start_grip := Transform3D.IDENTITY
var _start_pose := Transform3D.IDENTITY
var _root := Node3D.new()
var _mark := Label3D.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root)
	_mark.font_size = 90
	_mark.pixel_size = 0.001
	_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mark.visible = false
	add_child(_mark)
	Events.home_toggled.connect(_toggle)
	Events.room_changed.connect(_room_changed)
	Events.furniture_requested.connect(take_out)
	Events.furniture_editing.connect(_edit)
	Events.furniture_store_requested.connect(store_held)
	Events.selected.connect(_select)
	Events.button.connect(_button)
	Events.hand_tracking.connect(func(side: StringName, tracked: bool) -> void:
		if held and side == _hand and not tracked: _release(false))
	Events.facilitator_toggled.connect(func(open: bool) -> void:
		if open and held: _release(false))


func items() -> Array[Node]:
	return _root.get_children()


func _toggle(open: bool) -> void:
	if open:
		current_room = App.module(&"Rooms").selected
		_displaying = true
		_root.global_transform = App.reality.room_frame
		_render()
	else:
		_edit(false)
		_capture()
		_clear()
		_displaying = false


func _edit(active: bool) -> void:
	if held: _release(false)
	editing = active
	for node: Target in items():
		node.collision_layer = Pointer.MENU_LAYER if active else 0


func _room_changed(id: StringName) -> void:
	if held: _release(false)
	_capture()
	current_room = id
	_clear()
	if App.reality and App.reality.home_room:
		_render()


func take_out(id: StringName) -> void:
	var inventory := App.module(&"Inventory")
	var item := ItemDef.find(id)
	if not editing or inventory == null or item == null or item.kind != ItemDef.Kind.FURNITURE or inventory.count(id) == 0:
		return
	var node := _spawn(id, Transform3D.IDENTITY)
	var found := false
	for z in [-1.0, -1.7, 0.8, 1.5]:
		for x in [0.0, -1.2, 1.2]:
			node.position = Vector3(x, 0.8 if not item.snap_to_floor else 0.0, z)
			if _valid(node):
				found = true
				break
		if found: break
	if not found:
		node.free()
		Events.say("There is no space here. Put something away first.")
		return
	inventory.take(id)
	_capture()
	Events.report(&"furniture_taken_out", {item = id, room = current_room, position = node.position})
	Events.say("Pinch the furniture, move your hand, then let go. Touch the box to put it away.")


func _spawn(id: StringName, pose: Transform3D) -> Target:
	var node := Target.new()
	node.id = id
	node.set_meta(&"item_id", id)
	node.collision_layer = Pointer.MENU_LAYER if editing else 0
	var visual: Node3D = ItemDef.find(id).scene.instantiate()
	node.add_child(visual)
	_root.add_child(node)
	var bounds := local_bounds(visual)
	node.set_meta(&"bounds", bounds)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(bounds.size.x, maxf(bounds.size.y, 0.6), maxf(bounds.size.z, 0.08))
	shape.position = Vector3(bounds.get_center().x, maxf(bounds.end.y, 0.6) * 0.5, bounds.get_center().z)
	node.add_child(shape)
	node.transform = pose
	return node


func _select(hand: StringName, target: Target, _origin: Vector3, _direction: Vector3) -> void:
	if not editing or target == null or target.get_parent() != _root or held:
		return
	held = target
	_hand = hand
	_start_grip = App.rig.pointer(hand).grip()
	_start_pose = held.transform
	_mark.visible = true
	Events.feedback.emit(&"hint", held.global_position)


func _process(_delta: float) -> void:
	if not held: return
	var grip := App.rig.pointer(_hand).grip()
	var offset := _root.global_basis.inverse() * (grip.origin - _start_grip.origin) * REACH_GAIN
	held.position = _start_pose.origin + Vector3(offset.x, 0, offset.z)
	if not ItemDef.find(held.id).snap_to_floor:
		held.position.y = clampf(_start_pose.origin.y + offset.y, 0.4, 1.8)
	var turn := grip.basis.get_euler().y - _start_grip.basis.get_euler().y
	held.rotation.y = snappedf(_start_pose.basis.get_euler().y + turn, TURN_STEP)
	var valid := _valid(held)
	_mark.text = "✓" if valid else "×"
	_mark.modulate = Color(1, 0.85, 0.3) if valid else Color(1, 0.35, 0.2)
	var bounds: AABB = held.get_meta(&"bounds")
	_mark.global_position = held.global_position + Vector3.UP * (bounds.end.y + 0.12)


func _button(hand: StringName, action: StringName, pressed: bool) -> void:
	if held and hand == _hand and action == &"trigger_click" and not pressed:
		_release(_valid(held))


func _release(commit: bool) -> void:
	if not commit:
		held.transform = _start_pose
		Events.say("That place is full. Try an empty space.")
	else:
		Events.report(&"furniture_placed", {item = held.id, room = current_room, position = held.position})
	Events.feedback.emit(&"good" if commit else &"hint", held.global_position)
	held = null
	_mark.visible = false
	_capture()


func store_held() -> void:
	if held == null: return
	var inventory := App.module(&"Inventory")
	if inventory == null: return
	var id := held.id
	held.free()
	held = null
	_mark.visible = false
	inventory.add(id)
	_capture()
	Events.report(&"furniture_put_away", {item = id, room = current_room})
	Events.say("Back in your box.")


func _valid(node: Target) -> bool:
	var box: AABB = node.transform * (node.get_meta(&"bounds") as AABB)
	var half := App.reality.room_size * 0.5 - Vector2.ONE * 0.12
	if box.position.x < -half.x or box.end.x > half.x or box.position.z < -half.y or box.end.z > half.y:
		return false
	# Keep the seated child's central space clear.
	if box.grow(0.25).has_point(Vector3(0, box.get_center().y, 0)):
		return false
	for other: Target in items():
		if other != node and box.intersects(other.transform * (other.get_meta(&"bounds") as AABB)):
			return false
	return true


func _capture() -> void:
	if not _displaying: return
	var saved: Array = []
	for node: Target in items():
		saved.append([node.id, _start_pose if node == held else node.transform])
	layouts[current_room] = saved


func _clear() -> void:
	for node in items(): node.free()


func _render() -> void:
	_clear()
	for entry: Array in layouts.get(current_room, []):
		_spawn(entry[0], entry[1])


func save_state() -> Dictionary:
	_capture()
	return {layouts = layouts.duplicate(true)}


func load_state(data: Dictionary) -> void:
	held = null
	_mark.visible = false
	_displaying = false
	_clear()
	layouts = data.get("layouts", {}).duplicate(true)
	if App.reality and App.reality.home_room:
		_displaying = true
		_render()


static func local_bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var local := node.global_transform.affine_inverse() * mesh.global_transform * mesh.mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	return box
