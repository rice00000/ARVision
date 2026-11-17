class_name RevealFx
extends Node3D
## The reveal's light (Effects chat, Nov 16; Megan picked direction A and asked for walls and floor).
##
## A soft front of warm light leaves the socket and travels ON the table (cut off by its edges,
## which light up as it touches them). Where the Quest's room scan gave the floor and walls, the
## same front spills on over them: wider, fainter, slower-looking, never above [constant WALL_CAP]
## over the floor, and the floor under the table stays dark (the scan's flat planes cannot know a
## real table stands over the floor). Without a scan it is the table only. The workshop is shown by
## [method arrive]: it rises out of the bench from its base while a thin line of light rides its top,
## so it is drawn up from the table (it used to inflate from a point).
##
## Comfort rules (children, nystagmus, Megan's queasiness): nothing flashes (peak alpha 0.35 on the
## table, the room at most [member room_strength] of that), no camera change, the front only ever
## slows down (sine ease), and the room part is a wide soft band, not a sharp line, in the edge of
## the view where moving lines most easily feel like self-motion. GPU: one unshaded alpha plane per
## surface (about 6), a few ALU per pixel; no particles, no textures.

const FRONT := preload("res://entry/fx/ripple_front.gdshader")
const RISE := preload("res://entry/fx/rise_line.gdshader")

## How bright the walls and floor get, 0..1 of the table's light (0 = table only). One knob, for
## the staff tools later and for tuning on the headset.
static var room_strength := 0.0   # table only (Megan, Nov 17); 0.6 was the Nov 16 headset start
## Whether the reveal still shows Wei's shelf and the first things. v0.3: no, the shelf comes from the
## cauldron later. False since Scene 6 (Megan, Nov 17): the shelf pops out of the cauldron after the
## reveal (Entry._shelf_from_cauldron).
static var shows_workshop := false
## Room-scan kinds the light spills over (Meta's semantic labels, lower case).
const ROOM_KINDS: Array[StringName] = [&"floor", &"wall_face", &"wall"]
## Walls: no light higher than this over the floor (furniture in front of a wall is not in the scan).
const WALL_CAP := 0.9
## The room front goes no farther than this from the socket, metres.
const ROOM_FAR := 4.0
## The table's light starts fading this long after the table front has arrived.
const TABLE_LINGER := 0.4
const FADE_SECONDS := 1.4
const TINT := Color(1.0, 0.86, 0.55)

## The front on the table, and on the room (metres from the socket), as last stepped.
var table_radius := 0.0
var room_radius := 0.0
## How many surfaces the light is drawn on (1 = the table only).
var planes := 0

var _origin := Vector3.ZERO
var _reach := 1.0
var _extra := 0.0
var _seconds := 5.0
var _table_materials: Array[ShaderMaterial] = []
var _room_materials: Array[ShaderMaterial] = []
var _on_radius := Callable()
var _arriving := {}   # GeometryInstance3D -> its previous material_overlay
var _held: Array = []   # [body, its process mode], out of the physics world while something rises


## Starts the light from [param origin]: the table front reaches [param reach] metres in
## [param seconds] (a sine ease, as the old rings did); [param on_radius] (table_radius,
## room_radius) is called every frame so the caller shows what the front has reached.
func play(origin: Vector3, reach: float, seconds: float, on_radius: Callable) -> void:
	_origin = origin
	_reach = reach
	_seconds = seconds
	_on_radius = on_radius
	var table: Surface = App.reality.work_surface() if App.reality else null
	if table:
		_table_materials.append(_plane(table, &"table", null))
	if room_strength > 0.0 and App.reality:
		var floor_y := (table.transform.origin.y - 0.72) if table else origin.y - 0.72
		var floors := App.reality.surfaces(&"floor")
		if not floors.is_empty():
			floor_y = floors[0].transform.origin.y
		var far := reach
		for kind in ROOM_KINDS:
			for surface in App.reality.surfaces(kind):
				if surface == table:
					continue
				var material := _plane(surface, kind, table)
				if kind != &"floor":
					material.set_shader_parameter(&"cap_y", floor_y + WALL_CAP)
				_room_materials.append(material)
				far = maxf(far, _farthest(surface))
		_extra = clampf(far, reach, ROOM_FAR) - reach
	planes = _table_materials.size() + _room_materials.size()
	print("REVEAL fx: light on ", planes, " surfaces (", _room_materials.size(), " of the room), room reach ",
			snappedf(_reach + _extra, 0.01), " m")
	var total := _seconds * 1.3 + FADE_SECONDS
	var tween := create_tween()
	tween.tween_method(_step, 0.0, total, total)
	tween.tween_callback(queue_free)


## One frame of the light, [param t] seconds in.
func _step(t: float) -> void:
	table_radius = _reach * sin(PI * 0.5 * minf(t / _seconds, 1.0))
	room_radius = table_radius + _extra * smoothstep(0.35 * _seconds, 1.3 * _seconds, t)
	var table_fade := 1.0 - clampf((t - _seconds - TABLE_LINGER) / FADE_SECONDS, 0.0, 1.0)
	var room_fade := 1.0 - clampf((t - 1.3 * _seconds) / FADE_SECONDS, 0.0, 1.0) if _extra > 0.0 else table_fade
	for material in _table_materials:
		material.set_shader_parameter(&"radius", table_radius)
		material.set_shader_parameter(&"fade", table_fade)
	for material in _room_materials:
		material.set_shader_parameter(&"radius", room_radius)
		material.set_shader_parameter(&"fade", room_fade)
	if _on_radius.is_valid():
		_on_radius.call(table_radius, room_radius)


## A plane of light lying on [param surface]; the floor gets [param table]'s footprint left dark.
func _plane(surface: Surface, kind: StringName, table: Surface) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FRONT
	var is_table := kind == &"table"
	var room := room_strength
	material.set_shader_parameter(&"origin", _origin)
	material.set_shader_parameter(&"tint", TINT)
	material.set_shader_parameter(&"half_size", surface.size * 0.5)
	material.set_shader_parameter(&"band", 0.09 if is_table else 0.2)
	material.set_shader_parameter(&"strength", 0.35 if is_table else 0.3 * room)
	material.set_shader_parameter(&"afterglow", 0.10 if is_table else 0.05 * room)
	material.set_shader_parameter(&"edge_strength", 0.30 if is_table else 0.15 * room)
	material.set_shader_parameter(&"edge_width", 0.03 if is_table else 0.06)
	if not is_table:
		material.set_shader_parameter(&"far_from", _reach)
		material.set_shader_parameter(&"far_to", _reach + 2.0)
		material.set_shader_parameter(&"far_alpha", 0.45)
	if kind == &"floor" and table:
		material.set_shader_parameter(&"has_hole", true)
		material.set_shader_parameter(&"hole_inverse", Projection(table.transform.affine_inverse()))
		material.set_shader_parameter(&"hole_half", table.size * 0.5 + Vector2.ONE * 0.05)
	var mesh := PlaneMesh.new()
	mesh.size = surface.size
	mesh.material = material
	var plane := MeshInstance3D.new()
	plane.name = "reveal_light_%s" % kind
	plane.mesh = mesh
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plane)
	plane.global_transform = surface.transform.translated_local(Vector3.UP * (0.003 if is_table else 0.006))
	return material


## The farthest corner of [param surface] from the socket.
func _farthest(surface: Surface) -> float:
	var far := 0.0
	for u: float in [-1.0, 1.0]:
		for v: float in [-1.0, 1.0]:
			far = maxf(far, surface.point(u, v).distance_to(_origin))
	return far


## Shows [param detail] (hidden, scaled down by Entry) at its full size [param size], drawn up from
## the table: it rises out of the bench from its base (height only, never from a point) while a thin
## line of light rides its top edge. A detail with a "rise" (one of the first things) instead settles
## those last centimetres onto the bench, growing from 60 %. On the Quest (Mobile renderer) both also
## fade in; the Compatibility renderer (desktop fallback) ignores [member GeometryInstance3D.transparency].
func arrive(detail: Node3D, size: Vector3, seconds := 1.2) -> void:
	detail.visible = true
	detail.scale = size
	var shapes: Array[GeometryInstance3D] = []
	for node in detail.find_children("*", "GeometryInstance3D", true, false):
		shapes.append(node as GeometryInstance3D)
	if detail is GeometryInstance3D:
		shapes.append(detail as GeometryInstance3D)
	var box := _world_box(shapes)   # at full size, where it will stand
	var line := ShaderMaterial.new()
	line.shader = RISE
	line.set_shader_parameter(&"line_y", box.position.y)
	for shape in shapes:
		_arriving[shape] = shape.material_overlay
		shape.material_overlay = line
		shape.transparency = 1.0
	# Physics bodies (Wei's things) can't take the height-only scale while it rises (Jolt): they leave
	# the physics world meanwhile and come back when it has arrived.
	var held := hold_physics(detail)
	_held.append_array(held)
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(y: float) -> void: line.set_shader_parameter(&"line_y", y),
			box.position.y - 0.01, box.end.y + 0.01, seconds)
	for shape in shapes:
		tween.tween_property(shape, "transparency", 0.0, seconds * 0.8).set_ease(Tween.EASE_IN_OUT)
	if detail.has_meta(&"rise"):
		var home := detail.global_position
		detail.global_position = home + Vector3.UP * float(detail.get_meta(&"rise"))
		detail.scale = size * 0.6
		tween.tween_property(detail, "global_position", home, seconds)
		tween.tween_property(detail, "scale", size, seconds)
	else:
		detail.scale = Vector3(size.x, size.y * 0.02, size.z)
		tween.tween_property(detail, "scale", size, seconds)
	tween.chain().tween_method(func(f: float) -> void: line.set_shader_parameter(&"fade", f), 1.0, 0.0, 0.4)
	tween.chain().tween_callback(_settled.bind(shapes, held))


func _settled(shapes: Array[GeometryInstance3D], held: Array = []) -> void:
	release_physics(held)
	for entry in held:
		_held.erase(entry)
	for shape in shapes:
		if is_instance_valid(shape) and _arriving.has(shape):
			shape.material_overlay = _arriving[shape]
			shape.transparency = 0.0
			_arriving.erase(shape)


## Cut short (a jump button, a scene change): nothing is left half see-through or still lined.
func _exit_tree() -> void:
	_settled(Array(_arriving.keys(), TYPE_OBJECT, &"GeometryInstance3D", null))
	release_physics(_held)
	_held.clear()


static func _world_box(shapes: Array[GeometryInstance3D]) -> AABB:
	var box := AABB()
	var first := true
	for shape in shapes:
		var local := shape.get_aabb()
		if local.size == Vector3.ZERO:
			continue
		var world := shape.global_transform * local
		box = world if first else box.merge(world)
		first = false
	return box



## Takes every physics body under [param node] out of the physics world (it keeps its place in the
## tree): Jolt can't scale shapes by height only. Returns what [method release_physics] puts back.
static func hold_physics(node: Node) -> Array:
	var held := []
	for body: CollisionObject3D in node.find_children("*", "CollisionObject3D", true, false):
		if body.process_mode != Node.PROCESS_MODE_DISABLED:
			held.append([body, body.process_mode, body.disable_mode])
			body.disable_mode = CollisionObject3D.DISABLE_MODE_REMOVE
			body.process_mode = Node.PROCESS_MODE_DISABLED
	return held


static func release_physics(held: Array) -> void:
	for entry: Array in held:
		var body := entry[0] as CollisionObject3D
		if is_instance_valid(body):
			body.process_mode = entry[1]
			body.disable_mode = entry[2]
