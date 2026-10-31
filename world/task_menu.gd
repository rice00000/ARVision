class_name TaskMenu
extends Node3D
## A place's tasks, unfolded in reach between the child and the place: per
## task its title, and under it one big button per level. It leans back like a
## console on the table, so reaching a near row never brushes a far one. Touch a button, or point
## and pinch. Three kinds of button, never told apart by colour alone:
## the current level (first not done) is bigger, yellow, and breathes inside a glow; a done
## level is blue and carries a gold medal; any other is blue. Every level is open. A fingertip coming close lifts a button
## toward it and the guide reads it out ("Level 2. A new one!"), so a child who
## cannot read the numbers yet still knows what is under the hand.
## Drawn over everything, so nothing virtual or simulated hides part of it (on a
## Quest real things never do).
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
## The next level's button is this much bigger, and breathes by [constant BREATH].
const NEXT_SIZE := 1.25
const BREATH := 0.08
## A fingertip over a button and at most [constant HOVER_NEAR] metres in front of
## it hovers it; it stays hovered until the tip is [constant HOVER_FAR] away.
const HOVER_NEAR := 0.07
const HOVER_FAR := 0.1
const LIFT := 0.012

var _place: Place
var _world: World
var _buttons: Dictionary[Target, Array] = {}
var _open := false
## The next level's face and glow, which breathe.
var _breathing: Array[Node3D] = []
var _time := 0.0
## The button under a fingertip, or null.
var _hovered: Target


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


func _process(delta: float) -> void:
	_time += delta
	var breath := 1.0 + BREATH * sin(_time * TAU * 0.6)
	for node in _breathing:
		node.scale = Vector3(breath, breath, 1.0)
	if _open and not get_tree().paused:
		_hover(_under_tip())


## The button a fingertip is over, nearest first; the one hovered now keeps
## its hold out to [constant HOVER_FAR].
func _under_tip() -> Target:
	var best: Target
	var best_depth := INF
	for side: StringName in [&"left", &"right"]:
		var pointer := App.rig.pointer(side)
		if not pointer.tracked():
			continue
		var tip := to_local(pointer.tip())
		for button: Target in _buttons:
			var reach := HOVER_FAR if button == _hovered else HOVER_NEAR
			var off := tip - Vector3(button.position.x, button.position.y, 0.0)
			if absf(off.x) <= GAP * 0.5 and absf(off.y) <= ROW * 0.5 and off.z > -0.02 and off.z <= reach and off.z < best_depth:
				best = button
				best_depth = off.z
	return best


func _hover(button: Target) -> void:
	if button == _hovered:
		return
	_lift(_hovered, false)
	_hovered = button
	if button == null:
		return
	_lift(button, true)
	var task: Task = _buttons[button][0]
	var level: int = _buttons[button][1]
	if _world.is_done(task, level):
		Events.say("Level %d. Done!" % (level + 1))
	else:
		Events.say("Level %d. A new one!" % (level + 1))


## Lifts what [param button] looks like toward the hand; its touch box stays put,
## so lifting never makes a touch.
func _lift(button: Target, up: bool) -> void:
	if button:
		(button.get_node(^"Look") as Node3D).position.z = LIFT if up else 0.0


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
	if target != _hovered: # pressed without hovering (point and pinch): taken as read, never read out after the press
		_lift(_hovered, false)
		_hovered = target
		_lift(target, true)
	var task: Task = _buttons[target][0]
	var level: int = _buttons[target][1]
	_open = false
	Events.feedback.emit(&"good", target.global_position)
	chosen.emit([task, level])


func _build() -> void:
	var rows := _place.tasks.size()
	var most := _place.tasks.map(func(task: Task) -> int: return task.levels.size()).max() as int
	var width := maxf(TITLE_WIDTH, GAP * most) + 0.02
	var height := ROW * (rows * 2 + 1)
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
		var y := top - ROW * (row * 2 + 1)
		var title := _label(task.title, 44)
		title.position = Vector3(0.0, y, 0.0)
		add_child(title)
		for level in task.levels.size():
			var button := _button(task, level)
			button.position = Vector3(GAP * (level - (task.levels.size() - 1) * 0.5), y - ROW, 0.0)
			add_child(button)


func _button(task: Task, level: int) -> Target:
	var done := _world.is_done(task, level)
	var next := level == _world.current(task)
	var size := BUTTON * (NEXT_SIZE if next else 1.0)
	var button := Target.new()
	button.id = StringName("task_%s_%d" % [task.id, level + 1])
	button.name = String(button.id)
	_buttons[button] = [task, level]
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(size, size, 0.02)
	button.add_child(shape)
	var look := Node3D.new()
	look.name = "Look"
	button.add_child(look)
	var face := MeshInstance3D.new()
	face.mesh = BoxMesh.new()
	(face.mesh as BoxMesh).size = Vector3(size, size, 0.012)
	(face.mesh as BoxMesh).material = _flat(Color(1.0, 0.78, 0.2) if next else Color(0.3, 0.45, 0.85), 2)
	look.add_child(face)
	if next:
		var glow := MeshInstance3D.new()
		glow.mesh = QuadMesh.new()
		(glow.mesh as QuadMesh).size = Vector2.ONE * size * 1.3
		glow.material_override = _flat(Color(1.0, 0.92, 0.55), 1)
		look.add_child(glow)
		_breathing.append_array([face, glow])
	var label := _label(str(level + 1), 84 if next else 72)
	label.position.z = 0.008
	if next: # dark on yellow
		label.modulate = Color(0.1, 0.1, 0.15)
		label.outline_modulate = Color(1.0, 0.95, 0.8)
	look.add_child(label)
	if done:
		var medal := MeshInstance3D.new()
		medal.mesh = SphereMesh.new()
		(medal.mesh as SphereMesh).radius = 0.012
		(medal.mesh as SphereMesh).height = 0.024
		medal.material_override = _flat(Color(1.0, 0.8, 0.25), 5)
		medal.position = Vector3(BUTTON * 0.4, BUTTON * 0.4, 0.012)
		look.add_child(medal)
	return button


static func _label(text: String, size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.0004
	label.outline_size = 8
	label.no_depth_test = true
	label.render_priority = 4
	label.outline_render_priority = 3
	return label


## An unlit colour drawn over everything, after lower [param priority].
static func _flat(colour: Color, priority: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	material.no_depth_test = true
	material.render_priority = priority
	return material
