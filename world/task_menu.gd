class_name TaskMenu
extends Node3D
## Level cards with a fixed window. Pinch an arrow or drag the scrollbar.

signal chosen(choice: Array)

## Metres ahead of the eyes, toward the place, and below them.
const DISTANCE := 0.58
const BELOW_EYES := 0.12
## Degrees the top leans away from the child.
const TILT := 30.0
const COLUMNS := 2
const VISIBLE_ROWS := 3
const CARD := Vector2(0.285, 0.066)
const COLUMN_PITCH := 0.315
const ROW_PITCH := 0.088
const HEADER_ROW := 0.088
const PANEL_PADDING := Vector2(0.03, 0.015)
const MENU_SCALE := 0.70
const SCROLL_GUTTER := 0.086
const SCROLL_ARROW := Vector2(0.06, 0.06)
## Metres of hand-ray travel for one row while holding the scrollbar.
const DRAG_STEP := 0.06
const PANEL_COLOR := Color("#18232e")
const CARD_COLOR := Color("#425a6c")
const RAIL_COLOR := Color("#2e4050")
const NEXT_COLOR := Color("#e5cc94")
const GLOW_COLOR := Color("#f4e3bc")
const TEXT_COLOR := Color("#f7f4ed")
const INK_COLOR := Color("#242b32")
const GOLD_COLOR := Color("#f3d28a")
const BREATH := 0.035
const LIFT := 0.012

var first_row := 0

var _place: Place
var _world: World
var _buttons: Dictionary[Target, Array] = {}
var _rows: Array[Array] = []
var _last_row := 0
var _rows_top := 0.0
var _open := false
var _scroll_up: UITarget
var _scroll_down: UITarget
var _scroll_thumb: UITarget
var _thumb_top := 0.0
var _thumb_bottom := 0.0
var _drag_hand: StringName
var _drag_y := 0.0
var _drag_row := 0
## The next level's face and glow, which breathe.
var _breathing: Array[Node3D] = []
var _time := 0.0
## The button under a hand ray, or null.
var _hovered: Target


func _init(where: Place, world: World, row: int) -> void:
	_place = where
	_world = world
	first_row = row
	name = "TaskMenu"


func _ready() -> void:
	visible = not get_tree().paused
	_build()
	scale = Vector3(1.0, 0.05, 1.0)
	var unfold := create_tween()
	unfold.tween_property(self, ^"scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	unfold.tween_callback(func() -> void:
		_open = true
		_update_rows())
	Events.selected.connect(_press)
	Events.button.connect(func(hand: StringName, action: StringName, pressed: bool) -> void:
		if hand == _drag_hand and action == &"trigger_click" and not pressed:
			_drag_hand = &"")


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		# Switching between modal menus keeps the world paused.
		visible = what == NOTIFICATION_UNPAUSED
		_drag_hand = &""
		_hover(null)
		_update_rows()


func _process(delta: float) -> void:
	_time += delta
	var breath := 1.0 + BREATH * sin(_time * TAU * 0.6)
	for node in _breathing:
		node.scale = Vector3(breath, breath, 1.0)
	if not _drag_hand.is_empty():
		var pointer := App.rig.pointer(_drag_hand)
		if not pointer.tracked():
			_drag_hand = &""
			return
		var hit: Variant = _ray_hit(pointer.global_position, -pointer.global_basis.z)
		if hit != null:
			var row: float = _drag_row + (_drag_y - hit.y) / DRAG_STEP
			if absf(row - first_row) > 0.6:
				_scroll_to(roundi(row))
	elif _open:
		_hover(_under_ray())


## The button aimed at by a tracked hand.
func _under_ray() -> Target:
	for side: StringName in [&"left", &"right"]:
		var target := App.rig.pointer(side).aimed
		if is_instance_valid(target) and _buttons.has(target) and target.collision_layer != 0:
			return target
	return null


func _hover(button: Target) -> void:
	if button == _hovered:
		return
	_lift(_hovered, false)
	_hovered = button
	_lift(button, true)


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
	_drag_hand = &""
	_hover(null)
	_update_rows()
	var tween := create_tween()
	tween.tween_property(self, ^"scale", Vector3(1.0, 0.05, 1.0), 0.2)
	tween.tween_callback(queue_free)
	await tween.finished


func _press(hand: StringName, target: Target, origin: Vector3, direction: Vector3) -> void:
	if not _open or not visible or not _drag_hand.is_empty() or target == null:
		return
	if target == _scroll_up:
		_scroll_to(first_row - 1)
	elif target == _scroll_down:
		_scroll_to(first_row + 1)
	elif target == _scroll_thumb:
		var hit: Variant = _ray_hit(origin, direction)
		if hit != null:
			_drag_hand = hand
			_drag_y = hit.y
			_drag_row = first_row
			_hover(null)
	elif _buttons.has(target) and target.collision_layer != 0:
		_open = false
		chosen.emit(_buttons[target])


func _ray_hit(origin: Vector3, direction: Vector3) -> Variant:
	var hit: Variant = Plane(global_basis.z, global_position).intersects_ray(origin, direction)
	return to_local(hit) if hit != null else null


func _scroll_to(row: int) -> void:
	row = clampi(row, 0, _last_row)
	if first_row != row:
		first_row = row
		_hover(null)
		_update_rows()


func _update_rows() -> void:
	var active := _open and visible
	for index in _rows.size():
		var row := index - first_row
		var shown := row >= 0 and row < VISIBLE_ROWS
		for item: Node3D in _rows[index]:
			item.visible = shown
			item.position.y = _rows_top - ROW_PITCH * (row + 0.5)
			if item is UITarget:
				item.collision_layer = Pointer.UI_LAYER if shown and active else 0
	if _last_row > 0:
		_scroll_thumb.position.y = lerpf(_thumb_top, _thumb_bottom, float(first_row) / _last_row)
		_scroll_thumb.collision_layer = Pointer.UI_LAYER if active else 0
		_set_arrow(_scroll_up, first_row > 0, active)
		_set_arrow(_scroll_down, first_row < _last_row, active)


func _set_arrow(arrow: UITarget, available: bool, active: bool) -> void:
	arrow.collision_layer = Pointer.UI_LAYER if available and active else 0
	var glyph := arrow.get_node(^"Glyph") as Label3D
	glyph.modulate = TEXT_COLOR if available else Color("#8093a0")


func _build() -> void:
	for task in _place.tasks:
		if _place.tasks.size() > 1:
			_rows.append([_label(task.title, 38)])
		var next := _world.current(task)
		for first in range(0, task.levels.size(), COLUMNS):
			var row: Array[Node3D] = []
			var count := mini(COLUMNS, task.levels.size() - first)
			for column in count:
				var level := task.levels[first + column]
				var button := _button(task, level, level == next)
				button.position.x = COLUMN_PITCH * (column - (count - 1) * 0.5)
				row.append(button)
			_rows.append(row)
	_last_row = maxi(0, _rows.size() - VISIBLE_ROWS)
	first_row = clampi(first_row, 0, _last_row)
	var gutter := SCROLL_GUTTER if _last_row > 0 else 0.0
	var width := CARD.x + COLUMN_PITCH + gutter
	var height := HEADER_ROW + mini(_rows.size(), VISIBLE_ROWS) * ROW_PITCH
	var back := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height) + PANEL_PADDING * 2.0
	quad.material = _flat(PANEL_COLOR, 0)
	back.mesh = quad
	back.position.z = -0.02
	add_child(back)
	var top := height * 0.5
	_rows_top = top - HEADER_ROW
	var menu_slot := Marker3D.new()
	menu_slot.position = Vector3(quad.size.x * 0.5 - 0.063, top - 0.03, back.position.z)
	menu_slot.scale = Vector3.ONE * MENU_SCALE
	menu_slot.add_to_group(App.PLAYER_MENU_SLOT)
	add_child(menu_slot)
	var header := _label(_place.title, 50)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.position = Vector3(-width * 0.5, top - HEADER_ROW * 0.5, 0.0)
	add_child(header)
	for row in _rows:
		for item: Node3D in row:
			item.position.x -= gutter * 0.5
			add_child(item)
	if _last_row > 0:
		_build_scroll(width * 0.5 - gutter * 0.5)
	_update_rows()


func _build_scroll(x: float) -> void:
	var up := _rows_top - ROW_PITCH * 0.5
	var down := _rows_top - ROW_PITCH * (VISIBLE_ROWS - 0.5)
	_scroll_up = _scroll_button(&"level_scroll_up", "▲", SCROLL_ARROW, Vector3(x, up, 0.0))
	_scroll_down = _scroll_button(&"level_scroll_down", "▼", SCROLL_ARROW, Vector3(x, down, 0.0))
	var track_height := up - down - SCROLL_ARROW.y - 0.022
	var track := MeshInstance3D.new()
	var rail := QuadMesh.new()
	rail.size = Vector2(0.036, track_height)
	rail.material = _flat(RAIL_COLOR, 1)
	track.mesh = rail
	track.position = Vector3(x, (up + down) * 0.5, -0.006)
	add_child(track)
	var thumb_height := maxf(0.046, track_height * VISIBLE_ROWS / _rows.size())
	_thumb_top = track.position.y + (track_height - thumb_height) * 0.5
	_thumb_bottom = track.position.y - (track_height - thumb_height) * 0.5
	_scroll_thumb = _scroll_button(&"level_scroll_thumb", "↕", Vector2(0.049, thumb_height), Vector3(x, _thumb_top, 0.0))


func _scroll_button(id: StringName, icon: String, size: Vector2, at: Vector3) -> UITarget:
	var button := _target(id, size)
	button.position = at
	button.add_child(_face(size, CARD_COLOR))
	var glyph := _label(icon, 42)
	glyph.name = "Glyph"
	glyph.position.z = 0.008
	button.add_child(glyph)
	add_child(button)
	return button


func _button(task: Task, level: TaskLevel, next: bool) -> Target:
	var progress := App.main.progress
	var done := progress.is_done(task, level)
	var button := _target(StringName("task_%s_%s" % [task.id, level.id]), CARD)
	_buttons[button] = [task, level]
	var look := Node3D.new()
	look.name = "Look"
	button.add_child(look)
	var face := _face(CARD, NEXT_COLOR if next else CARD_COLOR)
	look.add_child(face)
	if next:
		var glow := MeshInstance3D.new()
		glow.mesh = QuadMesh.new()
		(glow.mesh as QuadMesh).size = CARD + Vector2(0.014, 0.014)
		glow.material_override = _flat(GLOW_COLOR, 1)
		look.add_child(glow)
		_breathing.append_array([face, glow])
	var endless := level.plan.is_endless()
	var label := _label(level.title if endless else "%s L%d" % [level.title, task.project_number(level)], 36)
	label.name = "Title"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.position = Vector3(-CARD.x * 0.5 + 0.012, 0, 0.008)
	look.add_child(label)
	var stones := progress.reward(task, level)
	var reward := _label("∞" if endless else ("◆ %d" % stones if stones > 0 else ""), 36)
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


static func _target(id: StringName, size: Vector2) -> UITarget:
	var button := UITarget.new()
	button.id = id
	button.name = String(id)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(size.x, size.y, 0.02)
	button.add_child(shape)
	return button


static func _face(size: Vector2, colour: Color) -> MeshInstance3D:
	var face := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, size.y, 0.012)
	mesh.material = _flat(colour, 2)
	face.mesh = mesh
	return face


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
