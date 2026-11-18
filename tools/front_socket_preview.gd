extends Node
## MOCK-UP (Hub chat, Nov 17 late): the socket on the table's FRONT FACE, the gear set in from the front,
## the gear's buttons above it. Pictures only; nothing in the game changes. To build/front_socket/.

var _out := ProjectSettings.globalize_path("res://build/front_socket")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1280, 800)
	Profile.wipe()
	var app: Node3D = load("res://main.tscn").instantiate()
	app.autostart = false
	add_child(app)
	await get_tree().process_frame
	var entry: Entry = app.get_node(^"Intro/Entry")
	entry.run()
	var n := 0
	while not entry.zones_available() and n < 900:
		await get_tree().process_frame
		n += 1
	await _pause(0.8)
	entry.jump_to(&"reveal")
	await _pause(14.0)
	var panel: Node3D = entry.get("_panel")
	if panel:
		panel.visible = false
	var eye := App.head().global_position
	var layout: EntryLayout = entry.get("_layout")
	var mech: Node3D = entry.get("_mechanism")
	var gear: Node3D = entry.get("_gear")
	var shelf: Node3D = entry.get("_shelf")
	if shelf:
		shelf.visible = false
	var old_eye_view := [eye, mech.global_position]
	await _save("0_today", eye, mech.global_position + Vector3(0.1, 0, 0), 75.0)
	# The table's front face, a little right of the child's middle.
	var t := layout.table
	var front := t.origin + t.basis.z.normalized() * (layout.table_size.y * 0.5)
	var right := t.basis.x.normalized()
	var face_at := front + right * 0.12 + Vector3.DOWN * 0.045 + t.basis.z.normalized() * 0.004
	if is_instance_valid(gear):
		gear.reparent(mech, true)
	mech.global_transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5).rotated(Vector3.UP, atan2(t.basis.z.x, t.basis.z.z)), face_at)
	var menu := GearMenu.make(self, front + right * 0.12 + Vector3.UP * 0.0, eye, true)
	menu.set_stones(3)
	menu.reveal()
	await _pause(0.6)
	await _save("1_child_view", eye, face_at + Vector3.UP * 0.12, 75.0)
	await _save("2_close", eye, face_at + Vector3.UP * 0.04, 30.0)
	var side := front + right * 0.75 + t.basis.z.normalized() * 0.35 + Vector3.UP * 0.25
	await _save("3_side", side, face_at + Vector3.UP * 0.05, 55.0)
	get_tree().quit()


func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _save(name: String, eye: Vector3, at: Vector3, fov: float) -> void:
	var cam := App.rig.head as Camera3D
	cam.fov = fov
	cam.global_position = eye
	cam.look_at(at)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))
	print("SHOT ", name)
