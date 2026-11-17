extends Node
## PREVIEW pictures of the hub's ring of choices (Build B, Nov 17), to build/fx/ring_*.png: the opening up to
## the end of the reveal (cauldron left standing, no shelf), then the ring above the cauldron.
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --xr-mode off --path . \
##       res://entry/fx/ring_preview.tscn -- --profile=test_capture

var _out := ProjectSettings.globalize_path("res://build/fx")
var _view := []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1280, 800)
	Profile.wipe()
	RevealFx.shows_workshop = false
	var app: Node3D = load("res://main.tscn").instantiate()
	app.autostart = false
	add_child(app)
	await get_tree().process_frame
	var cam := App.rig.head as Camera3D
	cam.fov = 80.0
	var entry: Entry = app.get_node(^"Intro/Entry")
	entry.run()
	var n := 0
	while not entry.zones_available() and n < 900:
		await get_tree().process_frame
		n += 1
	await _pause(0.8)
	entry.set("_cauldron_gone", true)
	entry.jump_to(&"reveal")
	await _pause(13.0)
	var panel: Node3D = entry.get("_panel")
	if panel:
		panel.visible = false
	var box: Node3D = entry.get("_box")
	box.visible = true
	box.scale = Vector3.ONE
	var mouth: Vector3 = entry.get("_mouth")
	# Seen from where v0.3 puts the child: the cauldron ~70 cm away at the side spot (this sim layout has it
	# nearer; the Hub's layout will move it), eyes ~45 cm above the table.
	var real_eye := App.head().global_position
	var toward := Vector3(real_eye.x - mouth.x, 0.0, real_eye.z - mouth.z).normalized()
	var eye := mouth + toward * 0.7 + Vector3.UP * 0.4
	_view = [eye, mouth + Vector3.UP * (ImpressionRing.ABOVE_RIM + 0.05)]
	var made: Array[Impression] = []
	for kind: StringName in [&"shelf", &"dots", &"turn_to_fit"]:
		made.append(Impression.make(kind))
	var ring := ImpressionRing.make(self, made, Vector3(mouth.x, mouth.y + ImpressionRing.ABOVE_RIM, mouth.z), eye)
	await _pause(0.3)
	await _save("ring_1_waiting")
	var cup := made[2]
	var at := cup.target.global_position
	App.sim_input.point(&"right", eye + (at - eye).normalized() * 0.25 + Vector3.DOWN * 0.05, at)
	await _pause(0.2)
	await _save("ring_2_aim_at_cup")
	ring.press(cup)
	await _pause(ImpressionRing.TURN_SECONDS * 0.5)
	await _save("ring_3_turning")
	await _pause(ImpressionRing.TURN_SECONDS * 0.5 + 0.3)
	var away := eye + Vector3(0.5, -0.4, -0.3)
	App.sim_input.point(&"right", eye + (away - eye).normalized() * 0.25 + Vector3.DOWN * 0.05, away)
	await _pause(0.2)
	await _save("ring_4_cup_in_front")
	# First visit: only the shelf open, the dots sealed (no cup: Turn to fit not set up).
	ring.queue_free()
	var first: Array[Impression] = [Impression.make(&"shelf"), Impression.make(&"dots")]
	ImpressionRing.make(self, first, Vector3(mouth.x, mouth.y + ImpressionRing.ABOVE_RIM, mouth.z), eye)
	first[1].set_sealed(true)
	await _pause(0.3)
	await _save("ring_0_first_visit")
	get_tree().quit()


func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _save(name: String) -> void:
	var cam := App.rig.head as Camera3D
	cam.global_position = _view[0]
	cam.look_at(_view[1])
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))
	print("SHOT ", name)
