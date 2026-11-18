extends Module
## A judged response, given two ways: a sound and a mark where it happened
## (tracked hands cannot vibrate). Never colour alone: good is two bright notes rising
## and a ring, bad a soft low wooden "oh-oh" and a cross, hint a glassy ping and a dot.
## A won level gets a harp-and-chime flourish. The sounds are in C major like the piano
## (tools/sound/design.py); takes alternate so a long session never repeats one note pair.

const SOUNDS := {
	good = [preload("sounds/good_1.ogg"), preload("sounds/good_2.ogg"), preload("sounds/good_3.ogg")],
	bad = [preload("sounds/bad_1.ogg"), preload("sounds/bad_2.ogg")],
	hint = [preload("sounds/hint_1.ogg"), preload("sounds/hint_2.ogg")],
}
const WIN := preload("sounds/win.ogg")
const COLOURS := {good = Color(0.3, 0.9, 0.4), bad = Color(0.95, 0.35, 0.3), hint = Color(1.0, 0.85, 0.3)}

var _take: Dictionary[StringName, int] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.feedback.connect(_on_feedback)
	Events.level_won.connect(_play_fanfare)
	Events.scene_changing.connect(func() -> void:
		for node in get_children():
			node.free())


func _play_fanfare(_task: StringName, _level: int, _stones: int) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = WIN
	player.bus = &"SFX"
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
	_mark(kind, at)


## A shape that pops up at [param at], faces the eyes and fades.
func _mark(kind: StringName, at: Vector3) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.albedo_color = COLOURS[kind]
	var mark := Node3D.new()
	if kind == &"good":
		var ring := TorusMesh.new()
		ring.inner_radius = 0.05
		ring.outer_radius = 0.065
		_add_mesh(mark, ring, material, Vector3(PI / 2.0, 0.0, 0.0))
	elif kind == &"bad":
		for angle in [PI / 4.0, -PI / 4.0]:
			var bar := BoxMesh.new()
			bar.size = Vector3(0.12, 0.022, 0.01)
			_add_mesh(mark, bar, material, Vector3(0.0, 0.0, angle))
	else:
		var dot := SphereMesh.new()
		dot.radius = 0.02
		dot.height = 0.04
		_add_mesh(mark, dot, material, Vector3.ZERO)
	add_child(mark)
	mark.global_position = at + Vector3.UP * 0.1
	mark.look_at(App.head().global_position)
	mark.scale = Vector3.ONE * 0.3
	var tween := mark.create_tween()
	tween.tween_property(mark, ^"scale", Vector3.ONE, 0.15)
	tween.tween_property(material, ^"albedo_color:a", 0.0, 0.6).set_delay(0.4)
	tween.tween_callback(mark.queue_free)


func _add_mesh(parent: Node3D, mesh: Mesh, material: Material, rotation: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.rotation = rotation
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

