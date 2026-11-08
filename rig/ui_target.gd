class_name UITarget
extends Target
## UI is aimed at and pinched. Its outline is shared by every menu and panel.

const GROUP := &"ui_targets"
signal hover_changed(on: bool)

## Persistent side entries show a ray only when aimed at, not throughout play.
var show_ray := true
var hovered := false
var _hands: Dictionary[StringName, bool] = {}
var _outline: Node3D
var _flash := 0.0


func _init() -> void:
	collision_layer = Pointer.UI_LAYER


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUP)
	var collider := get_child(0) as CollisionShape3D
	var size: Vector3
	if collider.shape is BoxShape3D:
		size = (collider.shape as BoxShape3D).size
	else:
		size = Vector3.ONE * (collider.shape as SphereShape3D).radius * 2.0
	_outline = Node3D.new()
	_outline.name = "Focus"
	_outline.position = collider.position + Vector3(0, 0, size.z * 0.5 + 0.004)
	_outline.visible = false
	add_child(_outline)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.render_priority = 100
	material.albedo_color = Color(1.0, 0.9, 0.45)
	material.no_depth_test = true
	for axis in 2:
		for sign_value in [-1, 1]:
			var edge := MeshInstance3D.new()
			var strip := BoxMesh.new()
			strip.size = Vector3(size.x + 0.012, 0.005, 0.003) if axis == 0 else Vector3(0.005, size.y + 0.012, 0.003)
			edge.mesh = strip
			edge.position = Vector3(0, sign_value * (size.y * 0.5 + 0.006), 0) if axis == 0 else Vector3(sign_value * (size.x * 0.5 + 0.006), 0, 0)
			edge.material_override = material
			_outline.add_child(edge)


func focus(hand: StringName, on: bool) -> void:
	if on: _hands[hand] = true
	else: _hands.erase(hand)
	var hot := not _hands.is_empty()
	if hot != hovered:
		hovered = hot
		hover_changed.emit(hot)


func confirm() -> void:
	_flash = 0.15
	Events.feedback.emit(&"hint", global_position)


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	_outline.visible = collision_layer != 0 and (hovered or _flash > 0.0)
	_outline.scale = Vector3.ONE * (1.08 if _flash > 0.0 else 1.0)
