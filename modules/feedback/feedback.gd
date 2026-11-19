extends Module
## A sound where each response happened: two rising notes for success, a soft
## wooden "oh-oh" for a mistake, and a glassy ping for a hint.
## Mistakes also get a cross and hints a dot.
## A won level gets a flourish timed to the trophy clip. The sounds are in C major like the piano
## (tools/sound/design.py); takes alternate so a long session never repeats one note pair.

const SOUNDS := {
	good = [preload("sounds/good_1.ogg"), preload("sounds/good_2.ogg"), preload("sounds/good_3.ogg")],
	bad = [preload("sounds/bad_1.ogg"), preload("sounds/bad_2.ogg")],
	hint = [preload("sounds/hint_1.ogg"), preload("sounds/hint_2.ogg")],
}
const WIN := preload("sounds/win.ogg")
const COLOURS := {bad = Color(0.95, 0.35, 0.3), hint = Color(1.0, 0.85, 0.3)}
const OUTLINE := Color(0.08, 0.09, 0.12, 0.85)

var _take: Dictionary[StringName, int] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.feedback.connect(_on_feedback)
	Events.level_won.connect(_play_fanfare)
	Events.scene_changing.connect(func() -> void:
		for node in get_children():
			node.free())


func _play_fanfare(_task: StringName, _level: int, _stones: int) -> void:
	if not Events.celebrate:
		return
	var player := AudioStreamPlayer.new()
	player.stream = WIN
	player.bus = &"SFX"
	player.volume_db = -8.0 # Leave room for the reward announcement.
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _on_feedback(kind: StringName, at: Vector3) -> void:
	var takes: Array = SOUNDS[kind]
	_take[kind] = (_take.get(kind, randi()) + 1) % takes.size()
	var player := AudioStreamPlayer3D.new()
	player.stream = takes[_take[kind]]
	player.bus = &"SFX"
	player.unit_size = 1.0   # full level within a metre, falling off naturally beyond
	player.max_db = 0.0
	add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
	if kind != &"good":
		_mark(kind, at)


## A shape that pops up at [param at], faces the eyes and fades.
func _mark(kind: StringName, at: Vector3) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.albedo_color = COLOURS[kind]
	# A dark edge keeps the mark clear on any background: pale walls, bright passthrough.
	var edge := material.duplicate() as StandardMaterial3D
	edge.albedo_color = OUTLINE
	edge.render_priority = -1
	var mark := Node3D.new()
	if kind == &"bad":
		for angle in [PI / 4.0, -PI / 4.0]:
			var bar := BoxMesh.new()
			bar.size = Vector3(0.12, 0.022, 0.01)
			_add_mesh(mark, bar, material, Vector3(0.0, 0.0, angle))
			var behind := BoxMesh.new()
			behind.size = Vector3(0.136, 0.038, 0.01)
			_add_mesh(mark, behind, edge, Vector3(0.0, 0.0, angle)).position.z = -0.004
	else:
		var dot := SphereMesh.new()
		dot.radius = 0.02
		dot.height = 0.04
		_add_mesh(mark, dot, material, Vector3.ZERO)
		var behind := SphereMesh.new()
		behind.radius = 0.027
		behind.height = 0.054
		_add_mesh(mark, behind, edge, Vector3.ZERO).position.z = -0.004
	add_child(mark)
	mark.global_position = at + Vector3.UP * 0.1
	mark.look_at(App.head().global_position)
	var grown := Vector3.ONE * Vision.size_scale # bigger for a child who needs bigger things
	mark.scale = grown * 0.3
	var tween := mark.create_tween()
	tween.tween_property(mark, ^"scale", grown, 0.15)
	tween.tween_property(material, ^"albedo_color:a", 0.0, 0.6).set_delay(0.9)
	tween.parallel().tween_property(edge, ^"albedo_color:a", 0.0, 0.6).set_delay(0.9)
	tween.tween_callback(mark.queue_free)


func _add_mesh(parent: Node3D, mesh: Mesh, material: Material, rotation: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.rotation = rotation
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

