class_name Main
extends Node3D
## Boots the app. Picks the Reality: the Quest's passthrough, or the simulated
## room when the headset has no passthrough, there is no headset, or
## `-- --sim` is given. Without XR it creates the synthetic hands (SimInput)
## and lets the mouse drive them (DesktopDriver).
##
## One activity scene at a time; the room, rig and modules stay across switches.

const SCENES := {
	&"intro": {title = "Intro", path = "res://scenes/intro.tscn"},
	&"find_object": {title = "Find the object", path = "res://scenes/find_object.tscn"},
	&"first_visit": {title = "First visit (Onion)", path = "res://scenes/first_visit.tscn"},
	&"global_motion": {title = "Global motion", path = "res://scenes/global_motion.tscn"},
}

@export var sim_room: PackedScene
@export_enum("intro", "find_object", "global_motion") var initial_scene: String = "intro"
@export var plan: SessionPlan
@export var autostart := true

var current_scene: StringName
var switching := false
var _scene: Node
var _fade := StandardMaterial3D.new()


func _enter_tree() -> void:
	App.main = self
	App.session = null
	App.world = null


func _ready() -> void:
	App.stage = $Stage
	var reality: Reality
	if App.has_passthrough() and not "--sim" in OS.get_cmdline_user_args():
		reality = PassthroughReality.new()
	else:
		reality = SimReality.new()
		reality.room = sim_room
	reality.name = "Reality"
	App.reality = reality
	add_child(reality)
	if App.xr == null:
		App.sim_input = SimInput.new(App.rig)
		add_child(DesktopDriver.new())
	_build_fade()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--plan="):
			plan = load(arg.trim_prefix("--plan="))
	_load_scene(&"find_object" if plan else StringName(initial_scene))


## Switch after the input event has reached all listeners. Interrupted rounds
## are abandoned, never scored. The brief fade also works inside the headset.
func change_scene(id: StringName, fade := true) -> void:
	if switching or id == current_scene:
		return
	switching = true
	App.hold_pause(&"scene", true)
	if fade:   # the opening hands over to its first visit without a black blink (Megan's scene one)
		await _fade_to(1.0, 0.18)
	Save.write()
	var previous := current_scene
	_clear_scene()
	plan = null
	App.reality.apply_view(View.new())
	_load_scene(id)
	Events.report(&"scene_changed", {from = previous, to = id})
	if fade:
		await _fade_to(0.0, 0.22)
	App.hold_pause(&"scene", false)
	switching = false


## Another save was opened: rebuild the current scene on the new files.
func restart(between: Callable) -> void:
	_clear_scene()
	between.call()
	App.reality.apply_view(View.new())
	_load_scene(current_scene)


func _load_scene(id: StringName) -> void:
	current_scene = id
	_scene = load(SCENES[id].path).instantiate()
	if plan:
		_scene.get_node(^"Session").plan = plan
	add_child(_scene)
	if autostart:
		_start_scene.call_deferred()


func _start_scene() -> void:
	if plan:
		App.session.run()
	elif current_scene == &"intro":
		_scene.get_node(^"Entry").run()
	elif current_scene == &"first_visit":
		_scene.get_node(^"Visit").run()
	else:
		App.world.run()


func _clear_scene() -> void:
	Events.scene_changing.emit()
	var trial := App.session.trial
	_scene.free() # stop the awaiting Session / World / Entry before ending a round
	App.session = null
	App.world = null
	if trial:
		trial.abandon()
	for node in App.stage.get_children():
		node.free()


func _build_fade() -> void:
	_fade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fade.cull_mode = BaseMaterial3D.CULL_FRONT
	_fade.no_depth_test = true
	_fade.render_priority = 127
	_fade.albedo_color = Color(0, 0, 0, 0)
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	sphere.material = _fade
	var cover := MeshInstance3D.new()
	cover.name = "SceneFade"
	cover.mesh = sphere
	cover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	App.head().add_child(cover)


func _fade_to(alpha: float, seconds: float) -> Signal:
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade, ^"albedo_color:a", alpha, seconds).set_trans(Tween.TRANS_SINE)
	return tween.finished


func _exit_tree() -> void:
	App.hold_pause(&"scene", false)
	if App.sim_input:
		App.sim_input.release()
		App.sim_input = null
