class_name Cabinet
extends Node3D
## The treasure cabinet: one shelf per task of the adventure, one slot per
## level. A level done the first time puts its treasure in its slot: what the
## child found in its last round, or a gem for a task with nothing to find. An
## empty slot shows a dim dot, so the child sees what is still to win.
##
## It stands to the left of the place the child is at, a little below the eyes
## and farther than the menu, facing the child; it moves only when the child
## turns to another place. Nothing on it moves after it arrives, and it can't
## be pressed.

const SLOT := 0.08
const TREASURE := 0.05
## Degrees left of the place, metres from the eyes, metres below them.
const SIDE := 45.0
const AWAY := 0.8
const BELOW := 0.1
## Seconds before a new treasure shows in its slot: time for it to fly there.
const ARRIVE := 1.8

var _world: World
## "<task id>:<level>" -> the slot's node.
var _slots: Dictionary[String, Node3D] = {}


func _init(world: World) -> void:
	_world = world
	name = "Cabinet"
	visible = false


func _ready() -> void:
	var tasks: Array[Task] = []
	for where in _world.adventure.places:
		tasks.append_array(where.tasks)
	var most: int = tasks.map(func(task: Task) -> int: return task.levels.size()).max()
	var size := Vector2(SLOT * most + 0.04, SLOT * tasks.size() + 0.1)
	_box(Vector3(size.x, size.y, 0.01), Vector3(0.0, 0.0, -0.03), Color(0.35, 0.22, 0.12))
	var title := Label3D.new()
	title.text = "Treasures"
	title.pixel_size = 0.0004
	title.font_size = 44
	title.outline_size = 8
	title.position = Vector3(0.0, size.y * 0.5 - 0.03, 0.0)
	add_child(title)
	for row in tasks.size():
		var y := size.y * 0.5 - 0.06 - SLOT * (row + 0.5)
		_box(Vector3(size.x - 0.02, 0.008, 0.05), Vector3(0.0, y - TREASURE * 0.5 - 0.004, -0.005), Color(0.55, 0.36, 0.2))
		var task := tasks[row]
		for level in task.levels.size():
			var slot := Node3D.new()
			slot.name = "%s_%d" % [task.id, level + 1]
			slot.position = Vector3(SLOT * (level - (task.levels.size() - 1) * 0.5), y, 0.0)
			add_child(slot)
			_slots[World.key(task, level)] = slot
			var key := World.key(task, level)
			if _world.treasures.has(key):
				_show(slot, _world.treasures[key])
			else:
				_dot(slot)


## Stands it to the left of the place in direction [param ahead] (level) from [param eye].
func place_beside(eye: Vector3, ahead: Vector3) -> void:
	var at := eye + ahead.rotated(Vector3.UP, deg_to_rad(SIDE)) * AWAY + Vector3.DOWN * BELOW
	global_transform = Transform3D(Basis.looking_at(Vector3(at.x - eye.x, 0.0, at.z - eye.z)), at)
	visible = true


## Where the treasure of [param task] at [param level] sits.
func slot_position(task: Task, level: int) -> Vector3:
	return _slots[World.key(task, level)].global_position


## Puts [param treasure] ({shape, colour}) in its slot after [constant ARRIVE] seconds.
func receive(task: Task, level: int, treasure: Dictionary) -> void:
	var slot := _slots[World.key(task, level)]
	await get_tree().create_timer(ARRIVE, false).timeout
	for child in slot.get_children():
		child.free()
	var shown := _show(slot, treasure)
	shown.scale = Vector3.ONE * 0.3
	shown.create_tween().tween_property(shown, ^"scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A mesh of [param treasure] ({shape, colour}), [param size] high, centred on its origin.
static func make(treasure: Dictionary, size: float) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.html(treasure.colour)
	var mesh := MeshInstance3D.new()
	mesh.name = "Treasure"
	mesh.mesh = Shapes.mesh(StringName(treasure.shape), size)
	mesh.material_override = material
	if treasure.shape == "ring":
		mesh.rotation.x = PI / 2.0 # stood up, so it shows its hole
	return mesh


func _show(slot: Node3D, treasure: Dictionary) -> MeshInstance3D:
	var shown := make(treasure, TREASURE)
	slot.add_child(shown)
	return shown


func _dot(slot: Node3D) -> void:
	var dot := MeshInstance3D.new()
	dot.name = "Empty"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.012
	disc.bottom_radius = 0.012
	disc.height = 0.002
	dot.mesh = disc
	dot.material_override = _flat(Color(0.2, 0.13, 0.08))
	dot.position.y = -TREASURE * 0.5
	slot.add_child(dot)


func _box(size: Vector3, at: Vector3, colour: Color) -> void:
	var box := BoxMesh.new()
	box.size = size
	var part := MeshInstance3D.new()
	part.mesh = box
	part.material_override = _flat(colour)
	part.position = at
	add_child(part)


static func _flat(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	return material
