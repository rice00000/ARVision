class_name MotionChoice
extends Node3D
## The choice of "motion", a clear STATIONARY target that stands next to Wei's shelf-level choices (the
## [TaskMenu]): a round disc, bigger than a level's square button, with a still cluster of dots on it (the dots
## game, as a picture; nothing on it moves, so it never competes with the real dots). It is chosen only by a
## DELIBERATE press: a pinch aimed at it, a fingertip touching it, or a click (desktop). Looking at it, holding
## a hand near it or resting a finger on it never chooses it: there is no gaze and no dwell anywhere in here.
## It reads out nothing and never moves; a fingertip coming close lifts it a little toward the hand, as the menu's
## buttons are lifted, so the child sees what is under the hand.
##
## Use: add it, [method place_beside] the menu, [method open] it when the choices are offered, wait for
## [signal chosen], and [method close] it when the child chooses anything else (the menu's own [signal TaskMenu.chosen]).
## The target is a [Target] named "motion_choice"; tests and the research log can tell it from the menu's buttons.

## The child pressed it (once per [method open]).
signal chosen

const ID := &"motion_choice"
## The disc's radius and what presses it (a little more generous than it looks), metres.
const RADIUS := 0.05
const REACH := 0.06
## A fingertip over the disc and at most this far in front of it lifts it; it stays lifted until the tip is farther.
const HOVER_NEAR := 0.07
const HOVER_FAR := 0.1
const LIFT := 0.012

var _target: Target
var _look: Node3D
var _open := false
var _hovered := false


func _ready() -> void:
	name = "MotionChoice"
	_build()
	visible = false
	Events.selected.connect(_on_selected)
	Events.touched.connect(func(_hand: StringName, target: Target) -> void: _press(target))


## Stands it to the right of [param menu] (same height, same way it faces), clear of the menu's own [param half_width].
func place_beside(menu: Node3D, half_width: float, gap := 0.05) -> void:
	var at := menu.global_transform
	global_transform = Transform3D(at.basis, at.origin + at.basis.x * (half_width + gap + RADIUS))


## Shows it and lets it be pressed.
func open() -> void:
	visible = true
	scale = Vector3.ONE * 0.05
	var grow := create_tween()
	grow.tween_property(self, ^"scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	grow.tween_callback(func() -> void: _open = true)


## Takes it away (another choice was made, or the time for choosing is over).
func close() -> void:
	_open = false
	var fold := create_tween()
	fold.tween_property(self, ^"scale", Vector3.ONE * 0.05, 0.2)
	fold.tween_callback(func() -> void: visible = false)


func is_open() -> bool:
	return _open


func _process(_delta: float) -> void:
	if _open and not get_tree().paused:
		_hover(_under_tip())


## Whether a fingertip is over the disc and close in front of it (the one lifted keeps its hold out to HOVER_FAR).
func _under_tip() -> bool:
	if App.rig == null:
		return false
	for side: StringName in [&"left", &"right"]:
		var pointer := App.rig.pointer(side)
		if not pointer.tracked():
			continue
		var tip := to_local(pointer.tip())
		var reach := HOVER_FAR if _hovered else HOVER_NEAR
		if Vector2(tip.x, tip.y).length() <= RADIUS and tip.z > -0.02 and tip.z <= reach:
			return true
	return false


func _hover(over: bool) -> void:
	if over != _hovered:
		_hovered = over
		_look.position.z = LIFT if over else 0.0   # the touch box stays put: lifting it never makes a touch


func _on_selected(_hand: StringName, target: Target, origin: Vector3, direction: Vector3) -> void:
	if target == _target:
		_press(target)
		return
	if target != null or not _open or App.xr != null or direction.length() < 0.001:
		return
	# A desktop mouse hand can start beyond the target and point away from it: the line through the hand counts
	# (as for the cauldron), but only if nothing else was hit.
	if (global_position - origin).cross(direction.normalized()).length() <= REACH:
		_press(_target)


func _press(target: Target) -> void:
	if not _open or target != _target or get_tree().paused:
		return
	_open = false
	Events.feedback.emit(&"good", _target.global_position)
	chosen.emit()


func _build() -> void:
	_target = Target.new()   # a thin disc, like the menu's thin boxes: a hand held in front of it to hover touches nothing
	_target.id = ID
	_target.name = String(ID)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = REACH
	cylinder.height = 0.03
	shape.shape = cylinder
	shape.rotation.x = PI / 2.0
	_target.add_child(shape)
	add_child(_target)
	_look = Node3D.new()
	_look.name = "Look"
	_target.add_child(_look)
	var dark := _flat(Color(0.08, 0.09, 0.12), 0)
	var disc := MeshInstance3D.new()
	var plate := CylinderMesh.new()
	plate.top_radius = RADIUS
	plate.bottom_radius = RADIUS
	plate.height = 0.012
	plate.material = dark
	disc.mesh = plate
	disc.rotation.x = PI / 2.0   # its flat face toward the child
	_look.add_child(disc)
	var rim := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = RADIUS - 0.004
	ring.outer_radius = RADIUS + 0.004
	ring.material = _flat(Color(0.95, 0.92, 0.8), 1)
	rim.mesh = ring
	rim.rotation.x = PI / 2.0
	_look.add_child(rim)
	# The dots: a still snapshot of a cloud, in the dots' own colour (bigger than a child's wrist would hide).
	var dot := SphereMesh.new()
	dot.radius = 0.0045
	dot.height = 0.009
	dot.radial_segments = 8
	dot.rings = 4
	dot.material = _flat(Color(0.75, 0.95, 1.0), 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11   # the same picture every time
	for i in 22:
		var spot := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * (RADIUS - 0.012)
		var piece := MeshInstance3D.new()
		piece.mesh = dot
		piece.position = Vector3(spot.x, spot.y, 0.01)
		_look.add_child(piece)


func _flat(colour: Color, priority: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	material.render_priority = priority
	return material
