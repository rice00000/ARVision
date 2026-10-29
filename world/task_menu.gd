class_name TaskMenu
extends Node3D
## A place's tasks, unfolded in reach between the child and the place: one row
## per task, its title and one big button per level. It leans back like a
## console on the table, so reaching a near row never brushes a far one. Touch a button, or point
## and pinch. Open levels show their number; a done level carries a gold medal;
## a locked one is grey, sunk back and shows a dash, and only says it is locked.
## Never colour alone. Drawn over everything, so nothing virtual or simulated
## hides part of it (on a Quest real things never do).
##
## Buttons are Targets named "task_<task id>_<level>" (level from 1).

signal chosen(choice: Array)

## Metres ahead of the eyes, toward the place, and below them: a seated child's reach.
const DISTANCE := 0.4
const BELOW_EYES := 0.12
## Degrees the top leans away from the child.
const TILT := 30.0
const BUTTON := 0.06
const GAP := 0.09
const ROW := 0.085
const TITLE_WIDTH := 0.2

var _place: Place
var _world: World
var _buttons: Dictionary[Target, Array] = {}
var _open := false


func _init(where: Place, world: World) -> void:
	_place = where
	_world = world
	name = "TaskMenu"


func _ready() -> void:
	_build()
	scale = Vector3(1.0, 0.05, 1.0)
	var unfold := create_tween()
	unfold.tween_property(self, ^"scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	unfold.tween_callback(func() -> void: _open = true)
	Events.selected.connect(func(_hand: StringName, target: Target, _origin: Vector3, _direction: Vector3) -> void:
		_press(target))
	Events.touched.connect(func(_hand: StringName, target: Target) -> void: _press(target))


## Stands the menu in front of the eyes at [param eye], toward [param ahead] (level).
func place_at(eye: Vector3, ahead: Vector3) -> void:
	var upright := Basis.looking_at(ahead)
	global_transform = Transform3D(upright.rotated(upright.x, -deg_to_rad(TILT)),
		eye + ahead * DISTANCE + Vector3.DOWN * BELOW_EYES)


## Folds up and goes.
func fold() -> void:
	_open = false
	var tween := create_tween()
	tween.tween_property(self, ^"scale", Vector3(1.0, 0.05, 1.0), 0.2)
	tween.tween_callback(queue_free)
	await tween.finished


func _press(target: Target) -> void:
	if not _open or not _buttons.has(target) or get_tree().paused:
		return
	var task: Task = _buttons[target][0]
	var level: int = _buttons[target][1]
	if not _world.can_play(task, level):
		Events.feedback.emit(&"bad", target.global_position)
		Events.say("That one is still locked.")
		return
	_open = false
	Events.feedback.emit(&"good", target.global_position)
	chosen.emit([task, level])


func _build() -> void:
	var rows := _place.tasks.size()
	var width := TITLE_WIDTH + GAP * 2 + 0.02
	var height := ROW * (rows + 1)
	for layer in [[0.012, Color(0.85, 0.85, 0.8), -1], [0.0, Color(0.08, 0.09, 0.12), 0]]: # a light rim, dark or light behind
		var back := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(width, height) + Vector2.ONE * layer[0] * 2.0
		quad.material = _flat(layer[1], layer[2])
		back.mesh = quad
		back.position = Vector3(0.0, 0.0, -0.02)
		add_child(back)
	var top := height * 0.5 - ROW * 0.5
	var header := _label(_place.title, 44)
	header.position = Vector3(0.0, top, 0.0)
	add_child(header)
	for row in rows:
		var task := _place.tasks[row]
		var y := top - ROW * (row + 1)
		var title := _label(task.title, 44)
		title.position = Vector3(-width * 0.5 + 0.01, y, 0.0)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title.modulate = Color.WHITE if _world.is_unlocked(task) else Color(0.6, 0.6, 0.6)
		add_child(title)
		for level in task.levels.size():
			var button := _button(task, level)
			button.position = Vector3(-width * 0.5 + TITLE_WIDTH + GAP * (level + 0.5), y, 0.0)
			add_child(button)


func _button(task: Task, level: int) -> Target:
	var open := _world.can_play(task, level)
	var button := Target.new()
	button.id = StringName("task_%s_%d" % [task.id, level + 1])
	button.name = String(button.id)
	_buttons[button] = [task, level]
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(BUTTON, BUTTON, 0.02)
	button.add_child(shape)
	var face := MeshInstance3D.new()
	face.mesh = BoxMesh.new()
	(face.mesh as BoxMesh).size = Vector3(BUTTON, BUTTON, 0.012 if open else 0.004)
	(face.mesh as BoxMesh).material = _flat(Color(0.3, 0.45, 0.85) if open else Color(0.25, 0.25, 0.27), 1)
	face.position.z = 0.0 if open else -0.01
	button.add_child(face)
	var label := _label(str(level + 1) if open else "-", 72)
	label.position.z = 0.008
	button.add_child(label)
	if _world.is_done(task, level):
		var medal := MeshInstance3D.new()
		medal.mesh = SphereMesh.new()
		(medal.mesh as SphereMesh).radius = 0.012
		(medal.mesh as SphereMesh).height = 0.024
		medal.material_override = _flat(Color(1.0, 0.8, 0.25), 3)
		medal.position = Vector3(BUTTON * 0.4, BUTTON * 0.4, 0.012)
		button.add_child(medal)
	return button


static func _label(text: String, size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.0004
	label.outline_size = 8
	label.no_depth_test = true
	label.render_priority = 3
	label.outline_render_priority = 2
	return label


## An unlit colour drawn over everything, after lower [param priority].
static func _flat(colour: Color, priority: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	material.no_depth_test = true
	material.render_priority = priority
	return material
