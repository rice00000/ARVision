extends Node
## Pictures of the entry's four setup steps and the "All set" screen on the simulated room
## (no headset), to build/entry_shots/. Software rendering is fine:
##   xvfb-run -a godot --rendering-driver opengl3 --xr-mode off --path . res://tools/entry_shots.tscn -- --profile=test_capture

var _out := ProjectSettings.globalize_path("res://build/entry_shots")
var _entry: Entry


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1280, 800)
	Profile.wipe()
	var app: Node3D = load("res://main.tscn").instantiate()
	app.autostart = false
	add_child(app)
	await get_tree().process_frame
	_entry = app.get_node(^"Intro/Entry")
	_entry.run()
	await _until(func() -> bool: return _entry.find_child("entry_step_next", true, false) != null)
	await _pause(0.8)
	await _save("1_hands")
	Events.button.emit(&"right", &"trigger_click", true)   # a pinch
	await _pause(0.8)
	await _save("1b_hands_done")
	await _press(&"entry_step_next")
	await _until(func() -> bool: return _entry.find_child("entry_confirm_yes", true, false) != null)
	await _pause(0.8)
	await _save("2_table")
	await _press(&"entry_confirm_yes")
	await _until(func() -> bool: return _entry.find_child("entry_step_alt", true, false) != null)
	await _pause(0.8)
	await _save("3_reach")
	await _press(&"entry_step_alt")
	await _pause(1.4)
	await _save("4_sound_and_room")
	await _press(&"entry_step_next")
	await _until(func() -> bool: return _entry.find_child("entry_part_all", true, false) != null)
	await _pause(0.8)
	await _save("5_all_set")
	get_tree().quit()


func _press(id: StringName) -> void:
	_entry._on_target(_entry.find_child(String(id), true, false) as Target)
	await _pause(0.8)


func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _until(cond: Callable) -> void:
	var n := 0
	while not cond.call() and n < 900:
		await get_tree().process_frame
		n += 1


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))
	print("SHOT ", name)
