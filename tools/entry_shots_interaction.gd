extends Node
## Pictures of the interaction part (no headset): the teaching hand's three gestures, the gear
## carried over the socket with its outline, and the gear docked. Run like entry_shots2:
## xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --xr-mode off --path . res://tools/entry_shots_interaction.tscn -- --profile=test_capture
var _out := ProjectSettings.globalize_path("res://build/interaction")

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1280, 800)
	Profile.wipe()
	var app: Node3D = load("res://main.tscn").instantiate()
	app.autostart = false
	add_child(app)
	await get_tree().process_frame
	var entry: Entry = app.get_node(^"Intro/Entry")
	App.rig.head.rotation.x = -0.55   # looking down at the table, as a seated child does
	entry.run()
	await _until(func() -> bool: return entry.find_child("entry_part_touch", true, false) != null)
	entry._on_target(entry.find_child("entry_part_touch", true, false) as Target)
	await get_tree().create_timer(2.5).timeout
	var gear: Node3D = entry.get("_gear")
	var carry: Carry = entry.get("_carry")
	var demo: DemoHand = entry.get("_demo")
	var socket: Vector3 = entry.get("_socket_at")
	var rest: Vector3 = entry.get("_gear_rest")
	gear.visible = true
	gear.scale = Vector3.ONE * Entry.GEAR_PLAY_SCALE
	gear.global_position = rest
	(entry.get("_gear_spin") as GearSpin).running = false
	await get_tree().create_timer(0.5).timeout
	await _save("0_gear_waiting")
	var rim: Vector3 = (entry.get("_box") as Node3D).global_position + Vector3.UP * (entry.get("_rim") as float)
	# The hand frozen at exact moments of each gesture (its loop time), seen from the seat and from the side.
	demo.tap(rim)
	await _phases(demo, "tap", rim, [0.0, 0.9, 1.05, 1.6])
	demo.stop()
	await get_tree().create_timer(1.0).timeout
	demo.pinch_lift(gear)
	await _phases(demo, "pinch_lift", Carry.middle_of(gear), [0.0, 1.1, 1.7, 2.9])
	demo.stop()
	await get_tree().create_timer(1.0).timeout
	demo.lower_release(socket)
	await _phases(demo, "lower_release", socket + Vector3.UP * 0.026, [0.0, 1.3, 2.4])
	demo.stop()
	await get_tree().create_timer(1.0).timeout
	carry.begin(gear, socket)
	var input := App.sim_input
	input.set_hand(&"right", Transform3D(Basis.IDENTITY, Carry.middle_of(gear) + Vector3(0.0, 0.0, 0.05)))
	await get_tree().create_timer(0.2).timeout
	input.press(&"right", &"trigger_click", true)
	await get_tree().create_timer(0.2).timeout
	input.set_hand(&"right", Transform3D(Basis.IDENTITY, socket + Vector3(0.06, 0.09, 0.03) + Vector3(0.0, 0.0, 0.05)))
	await get_tree().create_timer(1.2).timeout
	await _save("6_carrying_with_outline")
	input.press(&"right", &"trigger_click", false)
	await get_tree().create_timer(0.12).timeout
	await _save("7_aligning")
	await get_tree().create_timer(0.8).timeout
	await _save("8_docked")
	get_tree().quit()

## [param times] of the loop of the gesture [param demo] is showing: it is held at each one and photographed
## from the child's seat and from the hand's own side, 30 cm away.
func _phases(demo: DemoHand, name: String, anchor: Vector3, times: Array) -> void:
	demo.set_process(false)
	demo._fade = 1.0
	var side := Camera3D.new()
	add_child(side)
	var seat := App.rig.head
	for time: float in times:
		demo._t = time
		demo._pose(time)
		await get_tree().process_frame
		await _save("hand_%s_%.2f_seated" % [name, time])
		side.global_position = demo.global_position + demo.global_basis.x * 0.30 + Vector3.UP * 0.03   # from the hand's own side
		side.look_at(demo.global_position)
		side.current = true
		await get_tree().process_frame
		await _save("hand_%s_%.2f_side" % [name, time])
		seat.make_current()
	side.queue_free()
	demo.set_process(true)


func _until(c: Callable) -> void:
	var n := 0
	while not c.call() and n < 900:
		await get_tree().process_frame
		n += 1

func _save(shot: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(shot + ".png"))
	print("SHOT ", shot)
