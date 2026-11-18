extends Module
## Pets bought in the shop. Each earns magic stones from training time (never
## from time in the menu or the room) and lives in the room, where it comes to a
## palm held up, hops onto it, and rests on a free cushion. See [Pet].

const CELL := 0.2
const SIDES: Array[StringName] = [&"left", &"right"]
const CALL_SECONDS := 0.36
const REARM_SECONDS := 0.16
const RELEASE_SECONDS := 0.12
const TRACKING_GRACE := 0.16
const OFFER_UP := 0.52
const KEEP_UP := 0.25
const OFFER_AHEAD := 0.24
const KEEP_AHEAD := 0.15
const OFFER_DRIFT := 0.085
const RETRACT_DISTANCE := 0.14
const MAX_POSE_STEP := 0.22
const HINT_AFTER := 6.0
const DELIVERY_SPOTS := [Vector3(-0.28, 0, -0.74), Vector3(0.28, 0, -0.74),
	Vector3(-0.70, 0, -0.60), Vector3(0.70, 0, -0.60)]
const FLOOR_ANGLES := [0.0, PI / 4.0, -PI / 4.0, PI / 2.0, -PI / 2.0]


class Offer:
	var origin := Vector3.INF
	var held := 0.0
	var missing := 0.0
	var needs_release := false
	var neutral := 0.0

	func reset_dwell() -> void:
		origin = Vector3.INF
		held = 0.0
		missing = 0.0


var is_open := false
var _root := Node3D.new()
var _saved: Dictionary = {}
var _room_page := false
var _offers: Dictionary[StringName, Offer] = {&"left": Offer.new(), &"right": Offer.new()}
var _guest: Pet
var _hand: StringName
var _reach_axis := Vector3.ZERO
var _reach_max := 0.0
var _last_palm := Vector3.ZERO
var _palm_at := Vector3.ZERO
var _missing_for := 0.0
var _changed_for := 0.0
var _steady_for := 0.0
var _hinted := false
var _open_for := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	add_child(_root)
	Events.home_toggled.connect(_toggle)
	Events.furniture_editing.connect(_room_page_changed)
	Events.room_changed.connect(func(_id: StringName) -> void: _enter.call_deferred())
	Events.inventory_changed.connect(_sync)
	Events.selected.connect(_take_stone)


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
			if pet == _guest: _stop_gesture(false)
			pet.free()
	for item in ItemDef.all(ItemDef.Kind.PET):
		if inventory.count(item.id) > 0 and not _root.has_node(String(item.id)):
			var pet := Pet.new()
			_root.add_child(pet)
			pet.setup(item.id, self, _saved.get(String(item.id), {}))
			if is_open:
				pet.enter_room(free_spot())
				Events.play(&"appear", pet.global_position)


func _toggle(open: bool) -> void:
	is_open = open
	_root.visible = open
	_open_for = 0.0
	if open:
		_enter()
	else:
		_room_page = false
		_stop_gesture(false)
		for pet in pets(): pet.leave_room()


func _enter() -> void:
	if not is_open: return
	_stop_gesture(false)
	_root.global_transform = App.reality.room_frame
	for pet in pets():
		pet.leave_room()
		pet.enter_room(free_spot())


## The furniture editing signal also identifies the main room page, even
## with Decor unplugged. The shop and bag show the room behind their panels.
func _room_page_changed(active: bool) -> void:
	if _room_page == active: return
	_room_page = active
	_stop_gesture(true)


func _process(delta: float) -> void:
	var owned := pets()
	if not get_tree().paused and App.session and App.session.running:
		for pet in owned: pet.train(delta)
	if not _room_page or owned.is_empty(): return
	_open_for += delta
	var decor := App.module(&"Decor")
	if decor and decor.held:
		_stop_gesture(true)
	elif _guest:
		_follow_hand(delta)
	else:
		_find_offer(owned, delta)
	if not _hinted and _open_for >= HINT_AFTER:
		_hinted = true
		Events.say("Hold out your hand with the palm up. Your pet will come to you.")


func _forward() -> Vector3:
	var forward := -App.head().global_basis.z.slide(Vector3.UP)
	return forward.normalized() if forward.length_squared() > 0.01 else -_root.global_basis.z


func _find_offer(owned: Array[Pet], delta: float) -> void:
	var eye := App.head().global_position
	var forward := _forward()
	for side in SIDES:
		var offer := _offers[side]
		var pointer := App.rig.pointer(side)
		var palm := pointer.palm()
		if not palm.origin.is_finite():
			offer.neutral = 0.0
			offer.missing += delta
			if offer.missing > TRACKING_GRACE: offer.reset_dwell()
			continue
		offer.missing = 0.0
		var reach := palm.origin - eye
		var ahead := reach.dot(forward)
		if offer.needs_release:
			var neutral := palm.basis.z.y < KEEP_UP or ahead < KEEP_AHEAD or not (reach.y >= -0.80 and reach.y <= -0.05)
			offer.neutral = offer.neutral + delta if neutral else 0.0
			offer.needs_release = offer.neutral < REARM_SECONDS
			continue
		if not _eligible(palm, reach, forward, ahead) or pointer.hand_closed() or pointer.aimed is UITarget:
			offer.reset_dwell()
			continue
		if not offer.origin.is_finite() or offer.origin.distance_to(palm.origin) > OFFER_DRIFT:
			offer.origin = palm.origin
			offer.held = 0.0
		offer.held += delta
		if offer.held >= CALL_SECONDS and _invite(owned, side, palm.origin, reach):
			return


func _eligible(palm: Transform3D, reach: Vector3, forward: Vector3, ahead: float) -> bool:
	var height := _root.to_local(palm.origin).y
	return palm.basis.z.y >= OFFER_UP and ahead >= OFFER_AHEAD and ahead <= 0.74 \
		and absf(reach.dot(forward.cross(Vector3.UP))) <= 0.46 \
		and reach.y >= -0.72 and reach.y <= -0.12 and height >= 0.16 and height <= 1.02


func _invite(owned: Array[Pet], side: StringName, at: Vector3, reach: Vector3) -> bool:
	var at_in_room := _root.to_local(at)
	var floor := hop_floor(at_in_room)
	if not floor.is_finite(): return false
	var nearest: Pet
	var best := INF
	for pet in owned:
		if not pet.is_grounded(): continue
		var distance := pet.position.distance_squared_to(floor)
		if nearest == null or (pet.has_stone and not nearest.has_stone) or (pet.has_stone == nearest.has_stone and distance < best):
			nearest = pet
			best = distance
	if nearest == null: return false
	_guest = nearest
	_hand = side
	App.rig.pointer(side).ui_available = false
	_reach_axis = reach.slide(Vector3.UP).normalized()
	_reach_max = reach.dot(_reach_axis)
	_last_palm = at
	_palm_at = at
	_missing_for = 0.0
	_changed_for = 0.0
	_steady_for = 0.0
	_hinted = true
	_guest.approach_hand(side, at_in_room, floor)
	Events.feedback.emit(&"hint", _guest.global_position + Vector3.UP * Pet.BODY)
	Events.report(&"pets_called", {pet = _guest.id, hand = side})
	return true


func _follow_hand(delta: float) -> void:
	var pointer := App.rig.pointer(_hand)
	var palm := pointer.palm()
	if not palm.origin.is_finite() or _last_palm.distance_to(palm.origin) > MAX_POSE_STEP:
		_missing_for += delta
		_steady_for = 0.0
		if _missing_for >= TRACKING_GRACE:
			_stop_gesture(true)
		else:
			_guest.follow_hand(_root.to_local(_palm_at), false)
		return
	_missing_for = 0.0
	var reach := palm.origin - App.head().global_position
	var out := reach.dot(_reach_axis)
	var height := _root.to_local(palm.origin).y
	# Keep the direction from the offer when the child turns to follow the pet.
	var holding := palm.basis.z.y >= KEEP_UP and not pointer.hand_closed() \
		and out >= maxf(KEEP_AHEAD, _reach_max - RETRACT_DISTANCE) \
		and reach.y >= -0.80 and reach.y <= -0.05 and reach.slide(Vector3.UP).length() < 0.82 \
		and height >= 0.14 and height <= 1.08
	_last_palm = palm.origin
	if holding:
		_changed_for = 0.0
		_reach_max = maxf(out, _reach_max)
		var next := _palm_at.lerp(palm.origin, 1.0 - exp(-24.0 * delta))
		_steady_for = _steady_for + delta if next.distance_to(_palm_at) <= 0.32 * delta else 0.0
		_palm_at = next
	else:
		_changed_for += delta
		_steady_for = 0.0
		if _changed_for >= RELEASE_SECONDS:
			_stop_gesture(true)
			return
	_guest.follow_hand(_root.to_local(_palm_at), _steady_for >= 0.08)


## A hand already being offered when a gesture or panel ends has to come back
## to rest before it can invite another pet.
func _stop_gesture(drop: bool) -> void:
	if _guest and drop: _guest.release_hand()
	_guest = null
	if _hand != &"": App.rig.pointer(_hand).ui_available = true
	var eye := App.head().global_position
	var forward := _forward()
	for side in SIDES:
		var offer := _offers[side]
		offer.reset_dwell()
		offer.neutral = 0.0
		var palm := App.rig.pointer(side).palm()
		if side == _hand or (palm.origin.is_finite() and palm.basis.z.y >= KEEP_UP \
				and (palm.origin - eye).dot(forward) >= KEEP_AHEAD and palm.origin.y < eye.y - 0.05):
			offer.needs_release = true
	_hand = &""


## Resolve the ray and a pinch against the stone as one interaction.
func _take_stone(hand: StringName, target: Target, _origin: Vector3, _direction: Vector3) -> void:
	if not _room_page or target is UITarget: return
	var owned := pets()
	if target != null:
		for pet in owned:
			if target == pet.stone and pet.can_give(hand):
				pet.give()
				return
		return
	var at := App.rig.pointer(hand).grip().origin
	var nearest: Pet
	var distance := 0.12
	for pet in owned:
		var away := at.distance_to(pet.stone.global_position)
		if pet.can_give(hand) and away < distance:
			nearest = pet
			distance = away
	if nearest: nearest.give()


# -- the room, for the pets (all in the room's frame) --------------------------

## A clear launch or landing a short step outward from the palm. Test the
## route across the floor plan too, so a jump cannot take a shortcut through furniture.
func hop_floor(palm: Vector3) -> Vector3:
	var below := Vector3(palm.x, 0.0, palm.z)
	var outward := below.normalized() if below.length_squared() > 0.01 else Vector3.FORWARD
	var furniture := _furniture_boxes()
	for angle: float in FLOOR_ANGLES:
		var spot := below + outward.rotated(Vector3.UP, angle) * 0.32
		if _in_room(spot) and not _seat_box().has_point(spot) and _clear_hop(spot, below, furniture):
			return spot
	return Vector3.INF


func _clear_hop(spot: Vector3, below: Vector3, furniture: Array[AABB]) -> bool:
	for box in furniture:
		if box.intersects_segment(spot, below) != null: return false
	return true


func can_hop(spot: Vector3, palm: Vector3) -> bool:
	return _clear_hop(spot, palm.slide(Vector3.UP), _furniture_boxes())


## A pet delivering by itself waits on the floor, visible from the seat.
func delivery_floor(pet: Pet) -> Vector3:
	var preferred: Vector3 = DELIVERY_SPOTS[pets().find(pet)]
	return floor_near(preferred, pet)


func floor_near(preferred: Vector3, pet: Pet) -> Vector3:
	var boxes := _obstacles()
	for other in pets():
		if other != pet and other.is_grounded():
			boxes.append(AABB(other.position - Vector3(0.22, 1, 0.22), Vector3(0.44, 2, 0.44)))
	for radius: float in [0.0, 0.28, 0.52, 0.84]:
		for step in (1 if radius == 0.0 else 8):
			var at := preferred + Vector3.FORWARD.rotated(Vector3.UP, step * TAU / 8.0) * radius
			if _in_room(at) and not boxes.any(func(box: AABB) -> bool: return box.has_point(at)):
				return at
	return Vector3.INF


func _in_room(at: Vector3) -> bool:
	var half := App.reality.room_size * 0.5 - Vector2.ONE * 0.22
	return absf(at.x) < half.x and absf(at.z) < half.y


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
	if cells.is_empty(): return path
	for i in range(1, cells.size() - 1):
		path.append(Vector3(cells[i].x, 0.0, cells[i].y))
	path.append(to)
	return path


func _cell(grid: AStarGrid2D, at: Vector3) -> Vector2i:
	var cell := Vector2i(((Vector2(at.x, at.z) - grid.offset) / CELL).round())
	return cell.clamp(Vector2i.ZERO, grid.region.size - Vector2i.ONE)


func _seat_box() -> AABB:
	return AABB(Vector3(-0.30, -1.0, -0.30), Vector3(0.60, 2.0, 0.60))


## What a pet walks around: the seated child and standing furniture.
func _obstacles() -> Array[AABB]:
	var boxes := _furniture_boxes()
	boxes.append(_seat_box())
	return boxes


func _furniture_boxes() -> Array[AABB]:
	var boxes: Array[AABB] = []
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
	if is_open: _stop_gesture(false)
	for pet in pets(): pet.free()
	_sync()
