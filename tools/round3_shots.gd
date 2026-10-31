extends Node
## Layout chat, round 3: the teaching hand at three sizes over its targets (how much of each it
## covers from a seated child's eyes), and the subtitle in the first visit at Wei's setting and the
## proposed one. Pictures to build/round3/. Not part of the game.
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --xr-mode off --path . res://tools/round3_shots.tscn -- --profile=test_capture

## The real teaching hand is 23 cm long; the stand-in, pinch point to the back of the palm, about 12.5 cm.
const REAL_LENGTH := 0.23
const STANDIN_LENGTH := 0.125

var _out := ProjectSettings.globalize_path("res://build/round3")
var _entry: Entry


func _ready() -> void:
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
	app.autostart = true
	await _until(func() -> bool: return _entry.find_child("entry_part_touch", true, false) != null)
	await _pause(0.5)
	if "--part=sub" in OS.get_cmdline_user_args():
		await _subtitles()
		get_tree().quit()
		return
	await _save("0_dev_columns_left", Vector3(-0.05, 1.0, 0.0))
	await _save("0_dev_columns_right", Vector3(-0.05, -1.0, 0.0))
	var demo: Node3D = _entry.get("_demo").get("_figure")   # the hand sets its own node's basis each frame
	# The tap, over the cauldron's rim.
	_press(&"entry_part_touch")
	await _pause(4.5)   # the line, then the hand loops
	await _hand(demo, "tap", func() -> Vector3: return _entry.call("_rim_point"), 0.05)
	# The pinch, on the gear.
	_press(&"entry_part_pickup")
	await _pause(5.5)
	await _hand(demo, "pinch", func() -> Vector3: return (_entry.get("_gear") as Node3D).global_position + Vector3.UP * 0.047, 0.0525)
	# Lower and open, over the socket.
	for k: float in [0.4, 0.5, 0.6]:   # a fresh jump each time: after 14 s the reminder shows the pinch instead
		_press(&"entry_part_place")
		await _pause(1.5)
		await _hand(demo, "place", func() -> Vector3: return _entry.get("_socket_at"), 0.06, [k])
	get_tree().quit()


## The first visit: the subtitle at Wei's setting and the proposed one, looking at the things and at Onion.
func _subtitles() -> void:
	_press(&"entry_part_shelf")
	await _until(func() -> bool: return App.main.current_scene == &"first_visit" and not App.main.switching, 900)
	await _pause(3.0)
	var voice := App.module(&"Voice")
	var trial := App.session.trial as Node3D
	var things: Array = trial.get("_things") if trial != null else []
	var middle := Vector3.ZERO
	for thing: Node3D in things:
		middle += thing.global_position
	middle /= maxf(things.size(), 1)
	var onion: Node3D = App.main.get_node(^"Workshop").get("_onion")
	for setting: Array in [[25.0, 20.0, "now_25_20"], [36.0, 12.0, "proposed_36_12"]]:
		voice.above_gaze = setting[0]
		voice.above_horizon = setting[1]
		_look_at(middle)
		Events.say("The shapes on the shelf show where things go.")
		await _pause(0.4)
		await _save("sub_%s_looking_at_things" % setting[2])
		_look_at(onion.global_position)
		Events.say("The shapes on the shelf show where things go.")
		await _pause(0.4)
		await _save("sub_%s_looking_at_onion" % setting[2])


## Scales the hand to the real one at 0.4, 0.5, 0.6; over 3 s of its loop, the most and the mean it
## covers of a disc of [param radius] at [param target] seen from the eyes; a picture at the worst.
func _hand(demo: Node3D, name: String, target: Callable, radius: float, sizes := [0.4, 0.5, 0.6]) -> void:
	for k: float in sizes:
		demo.scale = Vector3.ONE * REAL_LENGTH * k / STANDIN_LENGTH
		_look_at(target.call())
		var worst := 0.0
		var sum := 0.0
		var n := 0
		var worst_frame := -1
		for frame in 30:
			await _pause(0.1)
			var cover := _cover(demo, target.call(), radius)
			sum += cover
			n += 1
			if cover > worst:
				worst = cover
				worst_frame = frame
		print("HAND %s scale %.1f (%d cm long): covers at most %d%%, on average %d%% of the target" % [name, k, roundi(REAL_LENGTH * k * 100), roundi(worst * 100), roundi(sum / n * 100)])
		# Again to the worst moment (the loop repeats about every 3 s), for the picture.
		for frame in 40:
			await _pause(0.05)
			if _cover(demo, target.call(), radius) >= worst - 0.02:
				break
		await _save("hand_%s_%.1f" % [name, k])
	demo.scale = Vector3.ONE


## How much of the disc at [param at] (radius [param radius], flat) the hand's meshes hide from the eyes.
func _cover(demo: Node3D, at: Vector3, radius: float) -> float:
	if not demo.is_visible_in_tree():
		return 0.0
	var eye := App.head().global_position
	var faces: Array[PackedVector3Array] = []
	for mesh: MeshInstance3D in demo.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var local := mesh.mesh.get_faces()
		var world := PackedVector3Array()
		for p in local:
			world.append(mesh.global_transform * p)
		faces.append(world)
	var hidden := 0
	var total := 0
	for ring in 4:
		var r := radius * ring / 3.0
		var count := 1 if ring == 0 else ring * 8
		for i in count:
			var a := i * TAU / count
			var p := at + Vector3(cos(a) * r, 0.0, sin(a) * r)
			total += 1
			var dir := p - eye
			var hit := false
			for tri in faces:
				for t in range(0, tri.size(), 3):
					var x: Variant = Geometry3D.segment_intersects_triangle(eye, p - dir.normalized() * 0.003, tri[t], tri[t + 1], tri[t + 2])
					if x != null:
						hit = true
						break
				if hit:
					break
			if hit:
				hidden += 1
	return float(hidden) / total


func _look_at(at: Vector3) -> void:
	var d := at - App.head().global_position
	var flat := Vector2(d.x, d.z).length()
	App.rig.head.rotation = Vector3(atan2(d.y, flat), atan2(-d.x, -d.z), 0.0)


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


func _save(name: String, look := Vector3.INF) -> void:
	if look != Vector3.INF:
		App.rig.head.rotation = look
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))
	print("SHOT ", name)
