extends Module
## Pets bought in the shop. Each earns magic stones from training time (never
## from time in the menu or the room) and lives in the room, where it comes to a
## palm held up, likes being petted and rests on a free cushion. See [Pet].

const CELL := 0.2
## Seconds a palm is held up before the pets come.
const CALL_SECONDS := 0.5
## The stool beside the seated child, in the room's frame.
const STOOL := Vector3(0.25, 0.0, -0.32)
const HINT_AFTER := 6.0

var is_open := false
var _root := Node3D.new()
var _stool := MeshInstance3D.new()
var _on_stool: Pet
var _saved: Dictionary = {}
var _palm_for := 0.0
var _called := false
var _hinted := false
var _open_for := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	add_child(_root)
	_stool.mesh = CylinderMesh.new()
	(_stool.mesh as CylinderMesh).top_radius = 0.17
	(_stool.mesh as CylinderMesh).bottom_radius = 0.14
	_stool.material_override = HomeUI.material(HomeUI.CREAM)
	_root.add_child(_stool)
	Events.home_toggled.connect(_toggle)
	Events.room_changed.connect(func(_id: StringName) -> void:
		if is_open: _enter.call_deferred())
	Events.inventory_changed.connect(_sync)
	Events.selected.connect(func(_hand: StringName, target: Target, _origin: Vector3, _direction: Vector3) -> void:
		for pet in pets():
			if target == pet.stone and pet.has_stone: pet.give())
	Events.button.connect(_pinch)


func pets() -> Array[Pet]:
	var all: Array[Pet] = []
	for node in _root.get_children():
		if node is Pet: all.append(node)
	return all


## One Pet per pet owned.
func _sync() -> void:
	var inventory := App.module(&"Inventory")
	if inventory == null: return   # unplugged: nothing can be owned
	for pet in pets():
		if inventory.count(pet.id) == 0:
			release_stool(pet)
			pet.free()
	for item in ItemDef.all(ItemDef.Kind.PET):
		if inventory.count(item.id) > 0 and not _root.has_node(String(item.id)):
			var pet := Pet.new()
			_root.add_child(pet)
			pet.setup(item.id, self, _saved.get(String(item.id), {}))
			if is_open: pet.enter_room(free_spot())
	_stool.visible = not pets().is_empty()


func _toggle(open: bool) -> void:
	is_open = open
	_root.visible = open
	_open_for = 0.0
	_on_stool = null
	if open:
		_enter()
	else:
		for pet in pets(): pet.leave_room()


func _enter() -> void:
	_root.global_transform = App.reality.room_frame
	var top := clampf(_root.to_local(App.head().global_position).y - 0.6, 0.25, 0.9)
	(_stool.mesh as CylinderMesh).height = top
	_stool.position = STOOL + Vector3.UP * top * 0.5
	_on_stool = null
	for pet in pets():
		pet.leave_room()
		pet.enter_room(free_spot())


func _process(delta: float) -> void:
	if not get_tree().paused and App.session and App.session.running:
		for pet in pets(): pet.train(delta)
	if not is_open or pets().is_empty(): return
	_open_for += delta
	var up := false
	for side: StringName in [&"left", &"right"]:
		var pointer := App.rig.pointer(side)
		var reach := pointer.global_position - App.head().global_position
		if pointer.palm_up() and Vector2(reach.x, reach.z).length() > 0.2:
			up = true
	_palm_for = _palm_for + delta if up else 0.0
	_called = _called and up
	if _palm_for >= CALL_SECONDS and not _called:
		_called = true
		_hinted = true
		for pet in pets(): pet.call_over()
		Events.feedback.emit(&"hint", _root.to_global(stool_top()))
		Events.report(&"pets_called")
	if not _hinted and _open_for >= HINT_AFTER:
		_hinted = true
		Events.say("Hold out your hand with the palm up. Your pet will come to you.")


## A pinch right at a stone takes it, like the ray does from afar.
func _pinch(hand: StringName, action: StringName, pressed: bool) -> void:
	if not is_open or action != &"trigger_click" or not pressed: return
	var at := App.rig.pointer(hand).grip().origin
	for pet in pets():
		if pet.has_stone and at.distance_to(pet.stone.global_position) < 0.12: pet.give()


# -- the room, for the pets (all in the room's frame) --------------------------

func seat() -> Vector3:
	return Vector3.ZERO


func stool_foot() -> Vector3:
	return STOOL + Vector3(0.0, 0.0, -0.32)


func stool_top() -> Vector3:
	return STOOL + Vector3.UP * (_stool.mesh as CylinderMesh).height


func beside_stool() -> Vector3:
	return STOOL + Vector3(-0.6, 0.0, -0.25)


func claim_stool(pet: Pet) -> bool:
	if _on_stool == null: _on_stool = pet
	return _on_stool == pet


func release_stool(pet: Pet) -> void:
	if _on_stool == pet: _on_stool = null


## Where each cushion in the room is.
func cushions() -> Array[Vector3]:
	var spots: Array[Vector3] = []
	var decor := App.module(&"Decor")
	if decor:
		for node: Target in decor.items():
			if node.id == &"cushion" and node != decor.held: spots.append(node.position)
	return spots


## A cushion no other pet is resting on, or null.
func free_cushion(pet: Pet) -> Variant:
	for spot in cushions():
		var taken := false
		for other in pets():
			taken = taken or (other != pet and other.rests_at(spot))
		if not taken: return spot
	return null


## A place on the floor clear of furniture and of the child.
func free_spot() -> Vector3:
	var half := App.reality.room_size * 0.5 - Vector2.ONE * 0.4
	var boxes := _obstacles()
	var spot := Vector3.ZERO
	for attempt in 20:
		spot = Vector3(randf_range(-half.x, half.x), 0.0, randf_range(-half.y, half.y))
		if not boxes.any(func(box: AABB) -> bool: return box.has_point(spot)): break
	return spot


## The way from [param from] to [param to] around the furniture, [param to] last.
func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var size := App.reality.room_size
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, Vector2i((size / CELL).round()))
	grid.cell_size = Vector2.ONE * CELL
	grid.offset = -size * 0.5 + Vector2.ONE * CELL * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var start := _cell(grid, from)
	var end := _cell(grid, to)
	for box in _obstacles():
		for x in range(grid.region.size.x):
			for y in range(grid.region.size.y):
				var cell := Vector2i(x, y)
				var at := grid.get_point_position(cell)
				if cell != start and cell != end and box.has_point(Vector3(at.x, 0.0, at.y)):
					grid.set_point_solid(cell)
	var path := PackedVector3Array()
	var cells := grid.get_point_path(start, end)
	for i in range(1, cells.size() - 1):
		path.append(Vector3(cells[i].x, 0.0, cells[i].y))
	path.append(to)
	return path


func _cell(grid: AStarGrid2D, at: Vector3) -> Vector2i:
	var cell := Vector2i(((Vector2(at.x, at.z) - grid.offset) / CELL).round())
	return cell.clamp(Vector2i.ZERO, grid.region.size - Vector2i.ONE)


## What a pet walks around: the seated child, the stool and furniture standing
## on the floor (not rugs and cushions), each flattened onto the floor.
func _obstacles() -> Array[AABB]:
	var boxes: Array[AABB] = [AABB(Vector3(-0.3, -1, -0.3), Vector3(0.6, 2, 0.6)),
		AABB(STOOL - Vector3(0.2, 1, 0.2), Vector3(0.4, 2, 0.4))]
	var decor := App.module(&"Decor")
	if decor:
		for node: Target in decor.items():
			var box: AABB = node.transform * (node.get_meta(&"bounds") as AABB)
			if box.position.y < 0.3 and box.end.y > 0.2:
				box = box.grow(0.12)
				boxes.append(AABB(Vector3(box.position.x, -1, box.position.z), Vector3(box.size.x, 2, box.size.z)))
	return boxes


func save_state() -> Dictionary:
	var state := {}
	for pet in pets(): state[String(pet.id)] = pet.to_save()
	return {pets = state}


func load_state(data: Dictionary) -> void:
	_saved = data.get("pets", {})
	for pet in pets(): pet.free()
	_on_stool = null
	_sync()
