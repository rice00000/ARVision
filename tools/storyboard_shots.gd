extends Node
## The storyboard: one picture per moment of the child's path through scene one, in PLAY mode (what the
## child sees, no DEV labels), to build/storyboard/, plus build/storyboard/shots.json (name, part, the
## line being said). The coordinator chat turns them into the storyboard page. Software rendering is fine:
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --xr-mode off --path . \
##       res://tools/storyboard_shots.tscn -- --profile=test_capture --mode=play

var _out := ProjectSettings.globalize_path("res://build/storyboard")
var _entry: Entry
var _part := "setup"
var _n := 0
var _shots: Array[Dictionary] = []
var _last_line := ""


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1280, 800)
	Profile.wipe()
	var app: Node3D = load("res://main.tscn").instantiate()
	app.autostart = false
	add_child(app)
	await get_tree().process_frame
	(App.rig.head as Camera3D).fov = 80.0   # about 110 degrees across at this size, like the Quest
	Events.said.connect(_on_said)
	_entry = app.get_node(^"Intro/Entry")
	_entry.skip_setup = false
	_entry.run()
	app.autostart = true
	await _until(func() -> bool: return _entry.zones_available())
	var from_shelf := "--from=shelf" in OS.get_cmdline_user_args()
	if from_shelf:
		_n = int(OS.get_environment("STORYBOARD_FROM")) if OS.get_environment("STORYBOARD_FROM") != "" else 17
	await _pause(1.0)
	_look(-0.12)
	if not from_shelf: await _shot("the grown-up's setup (step 1: hands)")
	_look(-0.7)
	for step in [] if from_shelf else [[&"hello", 17.0], [&"touch", 5.0], [&"emerge", 7.0], [&"pickup", 8.0], [&"place", 7.0], [&"reveal", 9.0]]:
		_part = String(step[0])
		_entry.jump_to(step[0])
		await _pause(1.2)
		await _shot("start of " + _part)
		await _pause(step[1])
	_part = "shelf"
	_look(-0.6)
	_entry.jump_to(&"shelf")   # a jump plays only its own part: hand over to the first visit explicitly
	await _pause(4.0)
	await _until(func() -> bool: return App.main.current_scene == &"first_visit" and not App.main.switching, 600)
	await _pause(12.0)
	await _shot("first visit: the shelf level running")
	# The shelf's end: straight to the motion route (DEV jump), which opens with the choice.
	_part = "choice"
	var visit := App.main.get_node_or_null(^"FirstVisit")
	_entry = null
	FirstVisit.start_with = &"motion"
	App.main.change_scene(&"first_visit")
	await _until(func() -> bool: return App.main.current_scene == &"first_visit" and not App.main.switching, 600)
	await _until(func() -> bool: return _choice() != null, 900)
	await _pause(1.0)
	_look(-0.6)
	await _shot("the choice: More shapes or the dots")
	_part = "motion demo"
	var choice := _choice()
	if choice: choice.chosen.emit()
	await _pause(3.0)
	_look(-0.2)
	await _shot("after choosing the dots")
	await _pause(12.0)
	_part = "motion rounds"
	await _shot("the motion rounds")
	await _pause(6.0)
	await _shot("the motion rounds (later)")
	var f := FileAccess.open(_out.path_join("shots.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(_shots, "  "))
	f.close()
	get_tree().quit()


func _choice() -> MotionChoice:
	var found := get_tree().root.find_children("*", "MotionChoice", true, false)
	return found[0] if not found.is_empty() else null


func _on_said(text: String) -> void:
	_last_line = text
	await _pause(0.7)   # the subtitle is up
	if _last_line == text:
		await _shot("says: " + text, text)


func _look(pitch: float) -> void:
	App.rig.head.rotation = Vector3(pitch, 0.0, 0.0)


func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _until(cond: Callable, frames := 900) -> void:
	var n := 0
	while not cond.call() and n < frames:
		await get_tree().process_frame
		n += 1


func _shot(what: String, line := "") -> void:
	await RenderingServer.frame_post_draw
	_n += 1
	var name := "%02d_%s.png" % [_n, _part.replace(" ", "_")]
	get_viewport().get_texture().get_image().save_png(_out.path_join(name))
	_shots.append({file = name, part = _part, what = what, line = line})
	print("SHOT ", name, " ", what)
