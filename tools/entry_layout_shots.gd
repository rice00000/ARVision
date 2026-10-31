extends Node
## Pictures of the layout (no headset), from a seated child's eyes looking about 40 degrees down at
## the table, to build/layout/: setup with the dev columns, the opening (gear landed, Onion aside),
## after the reveal, and the shelf scene with the task menu and a subtitle. With the zone map on
## where the opening has one ("Zones"). Software rendering is fine:
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --xr-mode off --path . \
##       res://tools/entry_layout_shots.tscn -- --profile=test_capture [--prefix=name] [--zones]

var _out := ProjectSettings.globalize_path("res://build/layout")
var _prefix := "now"
var _zones := false
var _entry: Entry


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prefix="):
			_prefix = arg.trim_prefix("--prefix=")
		if arg == "--zones":
			_zones = true
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1280, 800)
	Profile.wipe()
	var app: Node3D = load("res://main.tscn").instantiate()
	app.autostart = false
	add_child(app)
	await get_tree().process_frame
	(App.rig.head as Camera3D).fov = 80.0   # about 110 degrees across at this size, like the Quest
	_entry = app.get_node(^"Intro/Entry")
	_entry.run()
	app.autostart = true   # the shelf scene starts itself after the hand-over
	await _until(func() -> bool: return _entry.find_child("entry_part_emerge", true, false) != null)
	await _pause(0.8)
	_look(-0.12)
	await _save("1_setup_head_level")
	_look(0.0, true)
	await _save("1b_setup_wide")
	_look(-0.7)
	_press(&"entry_part_emerge")
	await _pause(0.6)
	_toggle()
	await _pause(2.9)
	await _save("2_opening_gear_landed")
	await _until(func() -> bool: return _entry.find_child("entry_part_all", true, false) != null)
	await _pause(0.6)
	await _save("3_opening_docked_all_set")
	_press(&"entry_part_ripple")
	await _pause(7.5)
	await _save("4_revealed")
	_toggle()
	await _pause(0.3)
	await _save("4b_revealed_no_zones")
	await _until(func() -> bool: return _entry.find_child("entry_part_all", true, false) != null)
	_press(&"entry_part_shelf")
	await _until(func() -> bool: return App.main.current_scene == &"find_object" and not App.main.switching, 600)
	await _pause(2.5)
	_look(-0.7)
	await _save("5_shelf_scene_greeting")
	await _until(func() -> bool: return App.world != null and App.world.menu != null, 900)
	await _pause(1.2)
	await _save("6_shelf_scene_menu")
	_look(-0.7, false, 0.35)
	await _save("6b_shelf_scene_menu_turned")
	get_tree().quit()


## Head pitch (radians, negative down); [param wide] turns left then is ignored; [param yaw] turns right.
func _look(pitch: float, wide := false, yaw := 0.0) -> void:
	(App.rig.head as Camera3D).fov = 100.0 if wide else 80.0
	App.rig.head.rotation = Vector3(pitch, -yaw, 0.0)


func _toggle() -> void:
	if _zones and _entry.has_method(&"_toggle_zones"):
		_entry._toggle_zones()


func _press(id: StringName) -> void:
	var target := _entry.find_child(String(id), true, false) as Target
	if target != null:
		_entry._on_target(target)


func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _until(cond: Callable, frames := 900) -> void:
	var n := 0
	while not cond.call() and n < frames:
		await get_tree().process_frame
		n += 1


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(_prefix + "_" + name + ".png"))
	print("SHOT ", _prefix, "_", name)
