extends Trial
## Tidy up: the alchemist's things fell off the shelf. Every
## cubby shows what belongs in it on a sticker: a black shadow, a black outline,
## a shadow of its size, or a shadow in its colour. The child pinches a thing,
## carries it to a sticker and lets go. The right thing
## clicks in; a wrong one does not fit and goes back to the bench. The round is
## done when everything is back. Trains matching shape, size and colour, and
## placing by sight (vision for action).
##
## No table needed: a small virtual bench with the shelf on its back edge stands
## in front of the child, in easy reach, facing the work surface (the real table,
## else straight ahead), level with its top when that is within reach so hands
## never go through a real table. It stays put for the whole block; the things
## lie on its front half.
##
## Axes: things (how many fell, driven; six shapes bring look-alikes: an egg
## beside the ball, a drum beside the block), size (metres), match (0 shape,
## 1 size: one shape in different sizes, 2 colour: one shape in different colours,
## coloured stickers), outline (1: the stickers show only the edge), clutter
## (how many junk bits lie jumbled among the things: sticks, coins, scraps that
## fit no sticker and cannot be picked; any clutter also scatters the things at
## random over the bench, so the child must pick them out of the mess).
## Hints: 1 the thing hops and its sticker wiggles, 2 its cubby shines and the
## guide says so. Help stays on for the things after it, until the round is done.

const SHAPE := 0
const SIZE := 1
const COLOUR := 2

const SHAPES: Array[StringName] = [&"ball", &"block", &"cone", &"ring", &"gem"]
const LOOK_ALIKES: Array[StringName] = [&"egg", &"drum"]
const COLOURS: Array[Color] = [Color(0.95, 0.3, 0.25), Color(0.25, 0.55, 0.95), Color(0.98, 0.8, 0.2),
	Color(0.35, 0.8, 0.4), Color(0.75, 0.4, 0.9), Color(0.95, 0.55, 0.2)]
const COLOUR_NAMES: Array[String] = ["red", "blue", "yellow", "green", "purple", "orange"]
## Sizes of a size round, times the size axis, smallest first: each a quarter bigger than the last.
const SIZES: Array[float] = [0.55, 0.69, 0.86, 1.08, 1.35]
const SIZE_NAMES: Array[String] = ["tiny", "small", "middle", "big", "huge"]

## How far farther along the table the whole play set (shelf, things, mess) stands than
## its own distances below say, metres: they are measured from the eyes, which puts it right
## in front of the player. 0 is Wei's original. The opening sets it, and it stays for the
## shelf scene, so the opening's shelf and the real one stand in the same place.
static var push := 0.0
## While Onion leads the first visit it speaks for the shelf: the instruction, the first "fits" and the end.
static var onion_voice := false
## Layout chat (round 5): the opening already showed the first round's things with the shelf. If non-zero,
## the NEXT round's random numbers start from this seed (so it makes the same things in the same places), and
## the flag clears itself. 0: random, as always.
static var seed_next := 0
## The NEXT round's things are simply there at their places (they were already shown), not dropping in; clears
## itself after one round. True: they drop in with a bounce, as always.
static var things_arrive := true

## The bench, metres from the eyes: the shelf's front; the bench top below the
## eyes, the work surface's height kept within this range.
const SHELF_AHEAD := 0.31
const BENCH_HIGHEST := 0.28
const BENCH_LOWEST := 0.42
## A cubby: width, height (taller, so the board above hides no sticker from eyes
## looking down), depth; the shelf has COLUMNS x ROWS of them. Its card stands
## CARD_IN in front of the back, tilted back to face the eyes, so a sticker shows
## its shape unsquashed.
const CELL := 0.12
const CELL_HIGH := 0.14
const DEPTH := 0.09
const CARD_IN := 0.04
const COLUMNS := 3
const ROWS := 2
const BOARD := 0.012
const PLINTH := 0.015
## Where the things lie: metres ahead of the eyes (nearest, farthest), and across.
const THINGS_NEAR := 0.16
const THINGS_FAR := 0.27
const THINGS_WIDE := 0.48
## A thing released within SNAP of a sticker is put there.
const SNAP := 0.05
## Ignore brief pinch dropouts while the hand moves.
const RELEASE_DELAY := 0.12
## After putting a thing, that hand takes nothing for this long: it passes over the others on the way back.
const TAKE_PAUSE := 0.6
## How much wider the outline sticker's edge is than the thing, times its size.
const OUTLINE := 0.2
## Where things and junk may lie on a cluttered bench (ahead of the eyes), and
## how far apart their centres stay.
const MESSY_NEAR := 0.13
const MESSY_FAR := 0.29
const MESSY_GAP := 0.05

const WOOD := Color(0.55, 0.36, 0.2)
const CARD := Color(0.93, 0.91, 0.86)
const INK := Color(0.06, 0.06, 0.06)
const SHINE := Color(1.0, 0.85, 0.3)

var _rng := RandomNumberGenerator.new()
## Where the bench stands for this block: the eyes at the first round, facing the work surface.
var _frame: Transform3D
var _shelf: Node3D
## Metres the bench top lies below [member _frame].
var _below := 0.0
var _match := SHAPE
var _outline := false
## Per cubby (COLUMNS x ROWS, bottom row first): its card's frame in the
## bench's frame and its material, what its sticker shows ("" = no sticker),
## where its thing hangs, whether that is in.
var _card_at: Array[Transform3D] = []
var _cards: Array[StandardMaterial3D] = []
var _cell_key: Array[String] = []
var _cell_point: Array[Vector3] = []
var _filled: Array[bool] = []
var _stickers: Array[Node3D] = []
## This round's things, in the order help goes through them.
var _things: Array[Target] = []
var _key: Dictionary[Target, String] = {}
var _size: Dictionary[Target, float] = {}
var _home: Dictionary[Target, Vector3] = {}
## Thing -> its cubby, once it is in.
var _placed: Dictionary[Target, int] = {}
## Hand -> its thing and the thing's transform relative to the pinch at pickup.
var _carried: Dictionary[StringName, Target] = {}
var _grip_offset: Dictionary[StringName, Transform3D] = {}
## Hand -> when a released pinch becomes a deliberate let-go.
var _release_at: Dictionary[StringName, float] = {}
## Hand -> [method Trial.seconds] from which it may take a thing again.
var _free_at: Dictionary[StringName, float] = {}
var _puts: Array[Dictionary] = []
var _moves: Dictionary[Target, Tween] = {}
var _hop: Tween
var _hopping: Target
var _wiggle: Tween
var _junk: Array[Node3D] = []


func _setup(round_condition: TrialCondition) -> void:
	_clear()
	_rng.randomize()
	var seeded := seed_next != 0
	if seeded:
		_rng.seed = seed_next
		seed(seed_next)   # the shuffles below use the global generator
		seed_next = 0
	round_condition.set_value(&"seed", _rng.seed)
	var arrive := things_arrive
	things_arrive = true
	if _shelf == null:
		_build_shelf()
	_match = int(round_condition.value(&"match", SHAPE))
	_outline = round_condition.value(&"outline", 0.0) > 0.5
	var looks := _looks(roundi(round_condition.value(&"things", 3.0)), round_condition.value(&"size", 0.06))
	var cells := range(COLUMNS * ROWS)
	cells.shuffle()
	for i in looks.size():
		var cell: int = cells[i]
		_cell_key[cell] = looks[i].key
		_cell_point[cell] = _frame * (_card_at[cell] * Vector3(0.0, 0.0, _extent(looks[i].shape, looks[i].size).z * 0.5 + 0.004))
		_sticker(cell, looks[i])
	var clutter := roundi(round_condition.value(&"clutter", 0.0))
	var spots := _spots(looks.size()) if clutter == 0 else _messy_spots(looks.size() + clutter)
	for i in clutter:
		_add_junk(spots[looks.size() + i])
	for i in looks.size():
		var thing := _make_thing(looks[i], "thing_%d_%s" % [i, looks[i].key])
		add_child(thing)
		_home[thing] = spots[i] + _frame.basis.y * _extent(looks[i].shape, looks[i].size).y * 0.5
		if arrive:
			thing.global_transform = Transform3D(_frame.basis, _home[thing] + _frame.basis.y * 0.12)
			_move(thing, _home[thing], 0.5).set_trans(Tween.TRANS_BOUNCE)
		else:
			thing.global_transform = Transform3D(_frame.basis, _home[thing])
	if seeded:
		randomize()   # back to chance for everything else
	round_condition.set_value(&"stickers", ",".join(_cell_key))
	if not onion_voice:
		match _match:
			SIZE:
				say("Put each one on the shadow of its size!")
			COLOUR:
				say("Put each one on its colour!")
			_:
				say("Put each thing back on its outline!" if _outline else "Put each thing back on its shadow!")


## Where [param count] things lie on the bench: a jumbled zigzag across it, near and far in turn,
## so they never touch whatever their sizes.
func _spots(count: int) -> Array[Vector3]:
	var spots: Array[Vector3] = []
	var step := THINGS_WIDE / count
	var middle := (THINGS_NEAR + THINGS_FAR) * 0.5
	var zig := (THINGS_FAR - THINGS_NEAR) * 0.5 - 0.015
	for i in count:
		var x := (i + 0.5) * step - THINGS_WIDE * 0.5 + _rng.randf_range(-0.012, 0.012)
		var z := middle + (zig if i % 2 == 0 else -zig) + _rng.randf_range(-0.012, 0.012)
		spots.append(_frame * Vector3(x, -_below, -z))
	spots.shuffle()
	return spots


## [param count] random spots over the bench, [constant MESSY_GAP] apart where they fit.
func _messy_spots(count: int) -> Array[Vector3]:
	var local: Array[Vector3] = []
	for i in count:
		var best := Vector3.ZERO
		for attempt in 30:
			best = Vector3(_rng.randf_range(-THINGS_WIDE * 0.5, THINGS_WIDE * 0.5), -_below, -_rng.randf_range(MESSY_NEAR, MESSY_FAR))
			if local.all(func(other: Vector3) -> bool: return other.distance_to(best) >= MESSY_GAP):
				break
		local.append(best)
	var spots: Array[Vector3] = []
	for spot in local:
		spots.append(_frame * spot)
	return spots


## One bit of junk lying at [param at]: a stick, a coin or a scrap, any colour, turned any way.
func _add_junk(at: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	match _rng.randi_range(0, 2):
		0:
			var stick := CylinderMesh.new()
			stick.top_radius = 0.006
			stick.bottom_radius = 0.006
			stick.height = _rng.randf_range(0.07, 0.12)
			mesh.mesh = stick
			mesh.rotation = Vector3(PI / 2.0, 0.0, 0.0)
		1:
			var coin := CylinderMesh.new()
			coin.top_radius = _rng.randf_range(0.018, 0.03)
			coin.bottom_radius = coin.top_radius
			coin.height = 0.008
			mesh.mesh = coin
		_:
			var scrap := BoxMesh.new()
			scrap.size = Vector3(_rng.randf_range(0.03, 0.06), 0.01, _rng.randf_range(0.02, 0.04))
			mesh.mesh = scrap
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOURS[_rng.randi_range(0, COLOURS.size() - 1)].lerp(WOOD, _rng.randf_range(0.0, 0.5))
	mesh.material_override = material
	var holder := Node3D.new()
	holder.name = "Junk_%d" % _junk.size()
	holder.add_child(mesh)
	add_child(holder)
	holder.global_transform = Transform3D(_frame.basis.rotated(_frame.basis.y, _rng.randf() * TAU), at + _frame.basis.y * 0.006)
	_junk.append(holder)


## What fell this round: {key, shape, size, colour}, at most one per sticker the shelf can show.
func _looks(count: int, size: float) -> Array[Dictionary]:
	var looks: Array[Dictionary] = []
	var shape: StringName = SHAPES[_rng.randi_range(0, SHAPES.size() - 1)]
	var colours := range(COLOURS.size())
	colours.shuffle()
	match _match:
		SIZE:
			count = mini(count, SIZES.size())
			var colour := COLOURS[colours[0]]
			for i in count: # well apart: smallest and largest always, the rest between
				var step := roundi(float(i) * (SIZES.size() - 1) / maxf(count - 1, 1))
				looks.append({key = "%s_%s" % [shape, SIZE_NAMES[step]], shape = shape, size = size * SIZES[step], colour = colour})
		COLOUR:
			count = mini(count, COLOURS.size())
			for i in count:
				looks.append({key = "%s_%s" % [shape, COLOUR_NAMES[colours[i]]], shape = shape, size = size, colour = COLOURS[colours[i]]})
		_:
			var shapes := SHAPES.duplicate()
			shapes.shuffle()
			if count > SHAPES.size(): # the look-alikes and what they look like, then any others
				shapes.assign([&"ball", &"block"] + LOOK_ALIKES + shapes.filter(func(other: StringName) -> bool:
					return not other in [&"ball", &"block"]))
			for i in mini(count, COLUMNS * ROWS):
				looks.append({key = String(shapes[i]), shape = shapes[i], size = size, colour = COLOURS[colours[i % colours.size()]]})
	return looks


func _on_button(hand: StringName, action: StringName, pressed: bool) -> void:
	if action != &"trigger_click":
		return
	if not pressed:
		if _carried.has(hand):
			_carried[hand].global_transform = App.rig.pointer(hand).grip() * _grip_offset[hand]
			_release_at[hand] = seconds() + RELEASE_DELAY
		return
	_release_at.erase(hand)
	if _carried.has(hand) or seconds() < _free_at.get(hand, 0.0):
		return
	var pointer := App.rig.pointer(hand)
	if not pointer.tracked():
		return
	var pinch := pointer.grip().origin
	var nearest: Target
	for thing in _things:
		if _placed.has(thing) or thing in _carried.values():
			continue
		if pinch.distance_to(thing.global_position) > _size[thing] * 0.7 + 0.02:
			continue
		if nearest == null or pinch.distance_to(thing.global_position) < pinch.distance_to(nearest.global_position):
			nearest = thing
	if nearest:
		_take(hand, nearest)


## Keep the contact point: a thing never jumps to the centre of the hand.
func _take(hand: StringName, thing: Target) -> void:
	if _moves.has(thing):
		_moves[thing].kill()
		_moves.erase(thing)
	if _hopping == thing:
		_hop.kill()
		_hopping = null
	_carried[hand] = thing
	_grip_offset[hand] = App.rig.pointer(hand).grip().affine_inverse() * thing.global_transform
	Events.report(&"taken", {thing = _key[thing], hand = hand})


func _physics_process(_delta: float) -> void:
	if not is_running():
		return
	for hand: StringName in _carried.keys():
		var thing := _carried[hand]
		var pointer := App.rig.pointer(hand)
		if not pointer.tracked():
			_return(hand)
			continue
		if not _release_at.has(hand):
			thing.global_transform = pointer.grip() * _grip_offset[hand]
		if seconds() >= _release_at.get(hand, INF):
			var cell := _cell_at(thing.global_position)
			if cell >= 0:
				_put(hand, cell)
			else:
				_return(hand)


func _on_tracking(hand: StringName, tracked: bool) -> void:
	if not tracked and _carried.has(hand):
		_return(hand)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		for hand: StringName in _carried.keys():
			_return(hand)


## Away from a sticker, on tracking loss or pause: put it back without scoring.
func _return(hand: StringName) -> void:
	var thing := _carried[hand]
	_let_go(hand)
	_move(thing, _home[thing], 0.25)


func _let_go(hand: StringName) -> void:
	_carried.erase(hand)
	_grip_offset.erase(hand)
	_release_at.erase(hand)
	_free_at[hand] = seconds() + TAKE_PAUSE


## The free cubby with a sticker nearest [param point], within [constant SNAP]; -1 for none.
func _cell_at(point: Vector3) -> int:
	var nearest := -1
	for cell in _cell_key.size():
		if _cell_key[cell].is_empty() or _filled[cell] or point.distance_to(_cell_point[cell]) > SNAP:
			continue
		if nearest < 0 or point.distance_to(_cell_point[cell]) < point.distance_to(_cell_point[nearest]):
			nearest = cell
	return nearest


## [param hand] lets go of its thing at [param cell]: it clicks in, or it does not fit and goes back.
func _put(hand: StringName, cell: int) -> void:
	var thing: Target = _carried[hand]
	_let_go(hand)
	var right := _cell_key[cell] == _key[thing]
	pick(_cell_key[cell], _key[thing])
	_puts.append({thing = _key[thing], slot = _cell_key[cell], correct = right, seconds = snappedf(seconds(), 0.01)})
	Events.report(&"put", _puts.back())
	if not right:
		judge(&"bad", thing.global_position)
		_move(thing, _home[thing], 0.35)
		count_try()
		match _match:
			SIZE:
				say("That's not its size. Look again!")
			COLOUR:
				say("That's not its colour. Look again!")
			_:
				say("That's not its shape. Look again!")
		return
	_placed[thing] = cell
	_filled[cell] = true
	_move(thing, _cell_point[cell], 0.15)
	judge(&"good", _cell_point[cell])
	_unhint()
	if _placed.size() == _things.size():
		if not onion_voice:
			say("All tidy! Everything is back home.")
		finish(true, {puts = _puts.duplicate()})
		return
	if not onion_voice:
		say("It fits!")
	_arm_hint() # a thing put back is progress
	if hint_level > 0:
		_show_hint(hint_level)


func _hint(level: int) -> void:
	_show_hint(level)
	if level >= 2:
		say("Look! Its spot is shining.")
	judge(&"hint", _cell_point[_cell_of(_focus())])


## The thing help is about: one in a hand, else the first not yet in.
func _focus() -> Target:
	if not _carried.is_empty():
		return _carried.values()[0]
	for thing in _things:
		if not _placed.has(thing):
			return thing
	return null


## The free cubby whose sticker shows [param thing].
func _cell_of(thing: Target) -> int:
	for cell in _cell_key.size():
		if _cell_key[cell] == _key[thing] and not _filled[cell]:
			return cell
	return -1


func _show_hint(level: int) -> void:
	_unhint()
	var thing := _focus()
	var cell := _cell_of(thing)
	_wiggle = create_tween().set_loops()
	_wiggle.tween_property(_stickers[cell], ^"rotation:z", 0.2, 0.2).set_trans(Tween.TRANS_SINE)
	_wiggle.tween_property(_stickers[cell], ^"rotation:z", -0.2, 0.4).set_trans(Tween.TRANS_SINE)
	_wiggle.tween_property(_stickers[cell], ^"rotation:z", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
	if not thing in _carried.values():
		_hopping = thing
		_hop = create_tween().set_loops()
		_hop.tween_property(thing, ^"global_position", _home[thing] + _frame.basis.y * 0.04, 0.25)
		_hop.tween_property(thing, ^"global_position", _home[thing], 0.25)
	if level >= 2:
		_cards[cell].albedo_color = SHINE
		var material: StandardMaterial3D = thing.get_meta(&"material")
		material.emission_enabled = true
		material.emission = material.albedo_color
		material.emission_energy_multiplier = 1.5


## Stops every hint: stickers still, cubbies and things unlit, a hopping thing back down.
func _unhint() -> void:
	if _wiggle:
		_wiggle.kill()
		_wiggle = null
	if _hop:
		_hop.kill()
		_hop = null
	if _hopping:
		_hopping.global_position = _home[_hopping]
		_hopping = null
	for sticker in _stickers:
		if sticker:
			sticker.rotation.z = 0.0
	for card in _cards:
		card.albedo_color = CARD
	for thing in _things:
		(thing.get_meta(&"material") as StandardMaterial3D).emission_enabled = false


func _teardown() -> void:
	_unhint()
	_carried.clear()
	_grip_offset.clear()
	_release_at.clear()


func focus_point() -> Vector3:
	return _frame * Vector3(0.0, -_below + 0.1, -SHELF_AHEAD)


## The round as the simulated child sees it: things, cubbies and what their stickers show.
func layout() -> Dictionary:
	var things := []
	for thing in _things:
		var hand: StringName = _carried.find_key(thing) if thing in _carried.values() else &""
		things.append({id = thing.id, key = _key[thing], centre = thing.global_position, size = _size[thing],
			home = _home[thing], placed = _placed.has(thing), carried = hand})
	var cells := []
	for cell in _cell_key.size():
		cells.append({id = "cell_%d" % cell, key = _cell_key[cell], position = _cell_point[cell], filled = _filled[cell],
			card = _frame * _card_at[cell].origin})
	return {match = _match, outline = _outline, things = things, cells = cells, snap = SNAP, release_delay = RELEASE_DELAY}


func _clear() -> void:
	_unhint()
	for thing in _things:
		thing.queue_free()
	_things.clear()
	for junk in _junk:
		junk.queue_free()
	_junk.clear()
	_key.clear()
	_size.clear()
	_home.clear()
	_placed.clear()
	_carried.clear()
	_grip_offset.clear()
	_release_at.clear()
	_free_at.clear()
	_moves.clear()
	_puts.clear()
	for cell in _stickers.size():
		if _stickers[cell]:
			_stickers[cell].queue_free()
			_stickers[cell] = null
		_cell_key[cell] = ""
		_filled[cell] = false
		_cell_point[cell] = _frame * _card_at[cell].origin


## Moves [param thing] to [param to] in [param seconds]; the tween, to shape it.
func _move(thing: Target, to: Vector3, seconds: float) -> Tween:
	if _moves.has(thing):
		_moves[thing].kill()
	var tween := create_tween()
	tween.tween_property(thing, ^"global_transform", Transform3D(_frame.basis, to), seconds)
	tween.finished.connect(func() -> void: _moves.erase(thing))
	_moves[thing] = tween
	return tween


# -- building -------------------------------------------------------------------

## The bench and the shelf, once per block, facing the work surface from the eyes.
func _build_shelf() -> void:
	var eye := App.head().global_position
	var toward := App.reality.work_surface().transform.origin - eye
	var ahead := Vector3(toward.x, 0.0, toward.z).normalized()
	_frame = Transform3D(Basis.looking_at(ahead), eye + ahead * push)
	_below = clampf(-toward.y - 0.01, BENCH_HIGHEST, BENCH_LOWEST) # just above a real table
	_shelf = Node3D.new()
	_shelf.name = "Shelf"
	add_child(_shelf)
	_shelf.global_transform = _frame
	var wide := COLUMNS * CELL + BOARD
	var high := PLINTH + ROWS * (CELL_HIGH + BOARD)
	var back := -(SHELF_AHEAD + DEPTH)
	var near := THINGS_NEAR - 0.05
	_box(Vector3(THINGS_WIDE + 0.06, 0.012, -back - near + 0.01), Vector3(0.0, -_below - 0.006, (back - near) * 0.5), WOOD.lightened(0.15))
	_box(Vector3(wide, high, 0.01), Vector3(0.0, -_below + high * 0.5, back - 0.005), WOOD)
	for row in ROWS + 1:
		var y := -_below + PLINTH + row * (CELL_HIGH + BOARD) - BOARD * 0.5
		_box(Vector3(wide, BOARD, DEPTH), Vector3(0.0, y, back + DEPTH * 0.5), WOOD)
	for column in COLUMNS + 1:
		var x := (column - COLUMNS * 0.5) * CELL
		_box(Vector3(BOARD, high - PLINTH, DEPTH), Vector3(x, -_below + PLINTH + (high - PLINTH) * 0.5, back + DEPTH * 0.5), WOOD)
	_box(Vector3(wide, PLINTH, DEPTH), Vector3(0.0, -_below + PLINTH * 0.5, back + DEPTH * 0.5), WOOD.darkened(0.2))
	for cell in COLUMNS * ROWS:
		var centre := Vector3((cell % COLUMNS - (COLUMNS - 1) * 0.5) * CELL,
			-_below + PLINTH + (cell / COLUMNS) * (CELL_HIGH + BOARD) + CELL_HIGH * 0.5, back + CARD_IN)
		_card_at.append(Transform3D(Basis(Vector3.RIGHT, -atan2(-centre.y, -centre.z)), centre))
		var card := MeshInstance3D.new()
		card.name = "Card_%d" % cell
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * (CELL - BOARD - 0.01)
		card.mesh = quad
		var material := _flat(CARD)
		card.material_override = material
		card.transform = _card_at[cell]
		_shelf.add_child(card)
		_cards.append(material)
		_cell_key.append("")
		_cell_point.append(_frame * centre)
		_filled.append(false)
		_stickers.append(null)


## The sticker of [param look] in the middle of [param cell]'s card, behind where the thing
## hangs: from the child it shows the thing's outline as seen from the front.
func _sticker(cell: int, look: Dictionary) -> void:
	var sticker := Node3D.new()
	sticker.name = "Sticker"
	_shelf.add_child(sticker)
	sticker.transform = _card_at[cell].translated_local(Vector3(0.0, 0.0, 0.002))
	var ink: Color = look.colour if _match == COLOUR else INK
	sticker.add_child(_flat_copy(look.shape, look.size, 1.0 + OUTLINE if _outline else 1.0, ink, 0.0))
	if _outline:
		sticker.add_child(_flat_copy(look.shape, look.size, 1.0, CARD, 0.001))
		if look.shape == &"ring": # a bigger copy outlines only the outer edge: draw the hole's too
			var hole := TorusMesh.new()
			hole.outer_radius = look.size * 0.28
			hole.inner_radius = hole.outer_radius - look.size * OUTLINE * 0.4
			var edge := MeshInstance3D.new()
			edge.mesh = hole
			edge.material_override = _flat(ink)
			edge.rotation.x = PI / 2.0
			edge.scale = Vector3(1.0, 0.02, 1.0)
			edge.position.z = 0.002
			sticker.add_child(edge)
	_stickers[cell] = sticker


## [param shape] squashed flat against the card, [param scale] times [param size], [param ahead] in front.
func _flat_copy(shape: StringName, size: float, scale: float, colour: Color, ahead: float) -> Node3D:
	var flat := Node3D.new()
	flat.scale = Vector3(scale, scale, 0.02)
	flat.position.z = ahead
	var mesh := _mesh(shape, size)
	mesh.material_override = _flat(colour)
	flat.add_child(mesh)
	return flat


func _make_thing(look: Dictionary, thing_id: String) -> Target:
	var thing := Target.sphere(StringName(thing_id), look.size * 0.7)
	var material := StandardMaterial3D.new()
	material.albedo_color = look.colour
	thing.set_meta(&"material", material)
	var mesh := _mesh(look.shape, look.size)
	mesh.material_override = material
	thing.add_child(mesh)
	_things.append(thing)
	_key[thing] = look.key
	_size[thing] = look.size
	return thing


## [param shape] as it stands on the shelf: a ring stands up, so its hole faces the child.
static func _mesh(shape: StringName, size: float) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = Shapes.mesh(shape, size)
	if shape == &"ring":
		mesh.rotation.x = PI / 2.0
	return mesh


## How big [param shape] is as it stands: width, height, depth.
static func _extent(shape: StringName, size: float) -> Vector3:
	var mesh := _mesh(shape, size)
	var extent := (mesh.transform * mesh.mesh.get_aabb()).size
	mesh.free()
	return extent


func _box(size: Vector3, at: Vector3, colour: Color) -> void:
	var box := BoxMesh.new()
	box.size = size
	var part := MeshInstance3D.new()
	part.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	part.material_override = material
	part.position = at
	_shelf.add_child(part)


static func _flat(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	return material
