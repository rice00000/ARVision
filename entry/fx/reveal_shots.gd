class_name RevealShots
extends Node
## Frames DURING the reveal (no headset), seated child's view, to build/fx/:
## one picture every [code]--step[/code] seconds from the reveal's start, plus a contact sheet input.
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --xr-mode off --path . \
##       res://entry/fx/reveal_shots.tscn -- --profile=test_capture [--prefix=before] [--step=0.75]
##       [--walls: the simulated room's walls as if scanned] [--table-only]

var _out := ProjectSettings.globalize_path("res://build/fx")
var _prefix := "now"
var _step := 0.75
var _entry: Entry
var _walls := false
var _from := 0.0
var _pitch := -0.55
var _fov := 80.0
var _to := 8.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prefix="):
			_prefix = arg.trim_prefix("--prefix=")
		if arg.begins_with("--step="):
			_step = float(arg.trim_prefix("--step="))
		if arg.begins_with("--from="):
			_from = float(arg.trim_prefix("--from="))
		if arg.begins_with("--to="):
			_to = float(arg.trim_prefix("--to="))
		if arg.begins_with("--pitch="):
			_pitch = float(arg.trim_prefix("--pitch="))
		if arg.begins_with("--fov="):
			_fov = float(arg.trim_prefix("--fov="))
		if arg == "--walls":
			_walls = true
		if arg == "--table-only":
			RevealFx.room_strength = 0.0
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1280, 800)
	Profile.wipe()
	var app: Node3D = load("res://main.tscn").instantiate()
	app.autostart = false
	add_child(app)
	await get_tree().process_frame
	(App.rig.head as Camera3D).fov = 80.0
	_entry = app.get_node(^"Intro/Entry")
	_entry.run()
	await _until(func() -> bool: return _entry.zones_available())
	await _pause(0.8)
	App.rig.head.rotation = Vector3(_pitch, 0.0, 0.0)
	(App.rig.head as Camera3D).fov = _fov
	if _walls:   # as if the Quest's room scan had them
		for wall in RevealShots.sim_walls():
			App.reality.add_surface(wall)
	_entry.jump_to(&"reveal")
	var t := _from
	var i := 0
	if _from > 0.0:
		await _pause(_from)
	while t <= _to:
		await _save("%02d_t%.2f" % [i, t])
		await _pause(_step)
		t += _step
		i += 1
	get_tree().quit()


func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _until(cond: Callable, frames := 900) -> void:
	var n := 0
	while not cond.call() and n < frames:
		await get_tree().process_frame
		n += 1


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(_prefix + "_" + name + ".png"))
	print("SHOT ", _prefix, "_", name)


## The simulated room's walls as a room scan would give them ("wall_face", +Y into the room), from
## the wall bodies of the sim room (it only marks the floor and the table itself).
static func sim_walls() -> Array[Surface]:
	var walls: Array[Surface] = []
	var tree := Engine.get_main_loop() as SceneTree
	for body: Node in tree.root.find_children("*Wall", "StaticBody3D", true, false):
		var shape := body.get_node_or_null(^"Shape") as CollisionShape3D
		if shape == null or not shape.shape is BoxShape3D:
			continue
		var size := (shape.shape as BoxShape3D).size
		var centre := (shape as Node3D).global_position
		var thin := 0 if size.x < size.z else 2
		var normal := Vector3.ZERO
		normal[thin] = -signf(centre[thin] - App.head().global_position[thin])
		var along := Vector3(0, 0, 1) if thin == 0 else Vector3(1, 0, 0)
		var basis := Basis(along, normal, along.cross(normal))
		var extent := Vector2(size[2 - thin], size.y)
		walls.append(Surface.new(&"wall_face", Transform3D(basis, centre + normal * size[thin] * 0.5), extent))
	return walls
