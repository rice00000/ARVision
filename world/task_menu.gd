class_name TaskMenu
extends Node3D
## The place's level cards, opened in front of a seated player. Point and pinch.
## The next card glows and breathes. Completed cards carry a medal.

signal chosen(choice: Array)

## Metres ahead of the eyes, toward the place, and below them.
const DISTANCE := 0.58
const BELOW_EYES := 0.12
## Degrees the top leans away from the child.
const TILT := 30.0
const COLUMNS := 2
const CARD := Vector2(0.285, 0.066)
const COLUMN_PITCH := 0.315
const ROW_PITCH := 0.088
const TITLE_ROW := 0.056
const PANEL_PADDING := Vector2(0.046, 0.015)
const PANEL_COLOR := Color("#18232e")
const CARD_COLOR := Color("#425a6c")
const NEXT_COLOR := Color("#e5cc94")
const GLOW_COLOR := Color("#f4e3bc")
const TEXT_COLOR := Color("#f7f4ed")
const INK_COLOR := Color("#242b32")
const GOLD_COLOR := Color("#f3d28a")
const BREATH := 0.035
const LIFT := 0.012

var _place: Place
var _world: World
var _buttons: Dictionary[Target, Array] = {}
var _open := false
## The next level's face and glow, which breathe.
var _breathing: Array[Node3D] = []
var _time := 0.0
## The button under a hand ray, or null.
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


func _process(delta: float) -> void:
	_time += delta
	var breath := 1.0 + BREATH * sin(_time * TAU * 0.6)
	for node in _breathing:
		node.scale = Vector3(breath, breath, 1.0)
	if _open and not get_tree().paused:
		_hover(_under_ray())


## The button aimed at by a tracked hand.
func _under_ray() -> Target:
	for side: StringName in [&"left", &"right"]:
		var target := App.rig.pointer(side).aimed
		if is_instance_valid(target) and _buttons.has(target):
			return target
	return null


func _hover(button: Target) -> void:
	if button == _hovered:
		return
	_lift(_hovered, false)
	_hovered = button
	if button == null:
		return
	_lift(button, true)
	var task: Task = _buttons[button][0]
	var level: TaskLevel = _buttons[button][1]
	var stones := App.main.progress.reward(task, level)
	var reward := "%d magic stones." % stones if stones != 1 else "One magic stone."
	Events.say("%s. Level %d. %s" % [level.title, task.project_number(level), reward])


## Lifts the aimed button while its ray hit box stays put.
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
	var level: TaskLevel = _buttons[target][1]
	_open = false
	chosen.emit([task, level])


func _build() -> void:
	var width := CARD.x + COLUMN_PITCH
	var height := TITLE_ROW + 0.016
	for task in _place.tasks:
		height += TITLE_ROW + ceili(task.levels.size() / float(COLUMNS)) * ROW_PITCH
	var back := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height) + PANEL_PADDING * 2.0
	quad.material = _flat(PANEL_COLOR, 0)
	back.mesh = quad
	back.position.z = -0.02
	add_child(back)
	var top := height * 0.5
	var header := _label(_place.title, 50)
	header.position.y = top - TITLE_ROW * 0.5
	add_child(header)
	top -= TITLE_ROW
	for task in _place.tasks:
		var title := _label(task.title, 38)
		title.position.y = top - TITLE_ROW * 0.5
		add_child(title)
		top -= TITLE_ROW
		var next := _world.current(task)
		for index in task.levels.size():
			var button := _button(task, task.levels[index], task.levels[index] == next)
			var row := floori(index / float(COLUMNS))
			var in_row := mini(COLUMNS, task.levels.size() - row * COLUMNS)
			button.position = Vector3(COLUMN_PITCH * (index % COLUMNS - (in_row - 1) * 0.5),
				top - ROW_PITCH * (row + 0.5), 0)
			add_child(button)
		top -= ceili(task.levels.size() / float(COLUMNS)) * ROW_PITCH


func _button(task: Task, level: TaskLevel, next: bool) -> Target:
	var progress := App.main.progress
	var done := progress.is_done(task, level)
	var button := UITarget.new()
	button.id = StringName("task_%s_%s" % [task.id, level.id])
	button.name = String(button.id)
	_buttons[button] = [task, level]
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(CARD.x, CARD.y, 0.02)
	button.add_child(shape)
	var look := Node3D.new()
	look.name = "Look"
	button.add_child(look)
	var face := MeshInstance3D.new()
	face.mesh = BoxMesh.new()
	(face.mesh as BoxMesh).size = Vector3(CARD.x, CARD.y, 0.012)
	(face.mesh as BoxMesh).material = _flat(NEXT_COLOR if next else CARD_COLOR, 2)
	look.add_child(face)
	if next:
		var glow := MeshInstance3D.new()
		glow.mesh = QuadMesh.new()
		(glow.mesh as QuadMesh).size = CARD + Vector2(0.014, 0.014)
		glow.material_override = _flat(GLOW_COLOR, 1)
		look.add_child(glow)
		_breathing.append_array([face, glow])
	var label := _label("%s L%d" % [level.title, task.project_number(level)], 36)
	label.name = "Title"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.position = Vector3(-CARD.x * 0.5 + 0.012, 0, 0.008)
	look.add_child(label)
	var reward := _label("◆ %d" % progress.reward(task, level), 36)
	reward.name = "Reward"
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reward.position = Vector3(CARD.x * 0.5 - 0.012, 0, 0.008)
	reward.modulate = GOLD_COLOR
	look.add_child(reward)
	if next:
		for text in [label, reward]:
			text.modulate = INK_COLOR
			text.outline_size = 0
	if done:
		var medal := MeshInstance3D.new()
		medal.mesh = SphereMesh.new()
		(medal.mesh as SphereMesh).radius = 0.005
		(medal.mesh as SphereMesh).height = 0.01
		medal.material_override = _flat(GOLD_COLOR, 5)
		medal.position = Vector3(CARD.x * 0.5 - 0.012, CARD.y * 0.5 - 0.012, 0.012)
		look.add_child(medal)
	return button


static func _label(text: String, size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.0005
	label.modulate = TEXT_COLOR
	label.outline_size = 5
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
