class_name ReplayButton
extends Target
## After a session: a glowing ball with "Play again" over it. Point at it and
## pinch, or touch it, and [signal pressed] goes out.

signal pressed

const RADIUS := 0.08


func _init() -> void:
	id = &"play_again"
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	(shape.shape as SphereShape3D).radius = RADIUS
	add_child(shape)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.8, 0.3)
	var ball := MeshInstance3D.new()
	ball.mesh = SphereMesh.new()
	(ball.mesh as SphereMesh).radius = RADIUS * 0.6
	(ball.mesh as SphereMesh).height = RADIUS * 1.2
	ball.material_override = material
	add_child(ball)
	var label := Label3D.new()
	label.text = "Play again"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.0015
	label.position = Vector3.UP * (RADIUS + 0.04)
	add_child(label)


func _ready() -> void:
	Events.selected.connect(_on_selected)
	Events.touched.connect(_on_touched)


func _on_selected(_hand: StringName, target: Target, _origin: Vector3, _direction: Vector3) -> void:
	_on_touched(_hand, target)


func _on_touched(_hand: StringName, target: Target) -> void:
	if target == self and not get_tree().paused:
		pressed.emit()
