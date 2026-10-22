extends Module
## The facilitator's panel, hidden from the child: left Menu opens and closes
## it (desktop: M), and play pauses while it is open. Point and pull the
## trigger to press a button.
##
##   Easier / Harder   pin the level 0.1 lower / higher for the rest of the session
##   Auto level        back to the child's staircase
##   Next view         the next view preset, until the next block starts
##   Skip block        drop the running round unscored and move on

const BUTTONS := [
	[&"fac_easier", "Easier"], [&"fac_harder", "Harder"],
	[&"fac_auto", "Auto level"], [&"fac_view", "Next view"],
	[&"fac_skip", "Skip block"], [&"fac_close", "Close"],
]

## Presets "Next view" cycles through.
@export var views: Array[View] = []

var is_open := false

var _panel := Node3D.new()
var _status := Label3D.new()
var _view_index := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Events.button.connect(func(hand: StringName, action: StringName, pressed: bool) -> void:
		if hand == &"left" and action == &"menu_button" and pressed:
			toggle())
	Events.selected.connect(_on_selected)


func _exit_tree() -> void:
	if is_open:
		App.hold_pause(&"facilitator", false) # the panel goes with this node
	else:
		_panel.free()


func toggle() -> void:
	is_open = not is_open
	if is_open:
		var eye := App.head().global_transform
		var forward := Vector3(-eye.basis.z.x, 0.0, -eye.basis.z.z).normalized()
		add_child(_panel)
		_panel.global_transform = Transform3D(Basis.looking_at(forward), eye.origin + forward * 0.55 + Vector3.DOWN * 0.12)
		_refresh()
	else:
		remove_child(_panel)
	App.hold_pause(&"facilitator", is_open)
	Events.facilitator_toggled.emit(is_open)


func _on_selected(_hand: StringName, target: Target, _origin: Vector3, _direction: Vector3) -> void:
	if not is_open or target == null or target.get_parent() != _panel:
		return
	Events.report(&"facilitator", {button = target.id})
	match target.id:
		&"fac_easier":
			App.session.nudge(-0.1)
		&"fac_harder":
			App.session.nudge(0.1)
		&"fac_auto":
			App.session.unpin()
		&"fac_view":
			_view_index = (_view_index + 1) % views.size()
			App.reality.apply_view(views[_view_index])
		&"fac_skip":
			App.session.skip_block()
		&"fac_close":
			toggle()
			return
	_refresh()


func _refresh() -> void:
	var session := App.session
	if session.block == null:
		_status.text = "No block running"
		return
	_status.text = "Block %d / %d: %s\nLevel %.2f %s\nView: %s" % [session.block_index + 1,
		session.plan.blocks.size(), session.block.trial.title, session.level(),
		"(pinned)" if not is_nan(session.pinned) else "(auto)", App.reality.view.title]


func _build() -> void:
	_panel.name = "FacilitatorPanel"
	var back := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.36, 0.34)
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color(0.08, 0.09, 0.12)
	quad.material = dark
	back.mesh = quad
	back.position = Vector3(0.0, 0.02, -0.012)
	_panel.add_child(back)
	_status.position = Vector3(0.0, 0.14, 0.0)
	_status.pixel_size = 0.0004
	_status.font_size = 40
	_panel.add_child(_status)
	var face := StandardMaterial3D.new()
	face.albedo_color = Color(0.25, 0.3, 0.42)
	for i in BUTTONS.size():
		var button := Target.new()
		button.id = BUTTONS[i][0]
		button.name = String(button.id)
		button.position = Vector3(-0.085 + 0.17 * (i % 2), 0.06 - 0.075 * floori(i / 2.0), 0.0)
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		(shape.shape as BoxShape3D).size = Vector3(0.15, 0.06, 0.02)
		button.add_child(shape)
		var mesh := MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		(mesh.mesh as BoxMesh).size = Vector3(0.15, 0.06, 0.01)
		(mesh.mesh as BoxMesh).material = face
		button.add_child(mesh)
		var label := Label3D.new()
		label.text = BUTTONS[i][1]
		label.pixel_size = 0.0004
		label.font_size = 48
		label.position.z = 0.006
		button.add_child(label)
		_panel.add_child(button)
