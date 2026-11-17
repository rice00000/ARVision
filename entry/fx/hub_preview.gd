extends Node
## PREVIEW pictures for Megan (Effects chat, Nov 17), not the hub itself: the opening up to the end of the
## reveal with the cauldron left standing (v0.3: it never sinks) and Wei's shelf hidden, then three
## impressions around the cauldron and the glow options, to build/fx/hub_*.png.
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --xr-mode off --path . \
##       res://entry/fx/hub_preview.tscn -- --profile=test_capture

var _out := ProjectSettings.globalize_path("res://build/fx")
var _entry: Entry
var _impressions: Array[Impression] = []
var _extras: Array[Node3D] = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1280, 800)
	Profile.wipe()
	RevealFx.room_strength = 0.0
	var app: Node3D = load("res://main.tscn").instantiate()
	app.autostart = false
	add_child(app)
	await get_tree().process_frame
	(App.rig.head as Camera3D).fov = 80.0
	_entry = app.get_node(^"Intro/Entry")
	_entry.run()
	await _until(func() -> bool: return _entry.zones_available())
	await _pause(0.8)
	App.rig.head.rotation = Vector3(-0.62, 0.0, 0.0)
	_entry.set("_cauldron_gone", true)   # v0.3: the cauldron stays (the Hub chat removes the sink)
	_entry.jump_to(&"reveal")
	await _pause(13.0)
	for detail: Node3D in _entry.get("_details"):   # v0.3: the reveal no longer shows Wei's shelf
		detail.visible = false
	var panel: Node3D = _entry.get("_panel")
	if panel:
		panel.visible = false
	for pointer: Node in get_tree().root.find_children("*", "Pointer", true, false):
		if pointer is Node3D:
			(pointer as Node3D).visible = false
	var box: Node3D = _entry.get("_box")
	box.visible = true
	box.scale = Vector3.ONE
	await _save("hub_0_table_only")
	# 1. Glow A: the gear's afterglow, as the reveal's light ends.
	var after := HubGlow.afterglow(self, _entry.get("_socket_at"), 30.0)
	await _pause(2.0)
	await _save("story_1_afterglow")
	after.queue_free()
	# 2. The first hub: the shelf open and waiting on its pool (glow C), the dots sealed; no cup yet
	#    (Turn to fit is only offered when it can run).
	_place_impressions(box.global_position)
	_impressions[2].visible = false
	_impressions[1].set_sealed(true)
	var offer := HubGlow.offer(self, _impressions, 0.3)
	await _pause(0.6)
	await _save("story_2_first_hub")
	# 3. A hand comes near the shelf: its pool brightens.
	offer.near(_impressions[0], 1.0)
	await _save("story_3_hand_near")
	# 4. Touched: its sound and pulse, the glow goes quiet, and the shelf grows out of it.
	_impressions[0].touched()
	await _pause(0.15)
	await _save("story_4_touched")
	await HubGlow.quiet_all(0.8)
	var shelf: Node3D = (_entry.get("_shelf").shelf() as Node3D).get_parent()   # the pivot under the bench
	var workspace := shelf.global_transform
	shelf.scale = shelf.get_meta(&"size", Vector3.ONE)
	shelf.visible = false
	SummonFx.grow(_impressions[0], shelf, workspace, 1.6)
	for i in 4:
		await _pause(0.4)
		await _save("story_5_summon_%d" % i)
	await _pause(1.2)
	await _save("story_6_shelf_out")
	# 5. "Found its place": the signal where a shape settles (on the bench, front middle).
	PlaceSignal.play(self, workspace.origin + workspace.basis.z * 0.06 + Vector3.UP * 0.002, Vector3.UP, 0.08)
	await _pause(0.35)
	await _save("story_7_found_its_place")
	await _pause(1.5)
	# 6. Fold back; the dots unseal (a visual change and a sound, no line).
	SummonFx.fold(shelf, _impressions[0], 1.2)
	await _pause(0.35)
	await _save("story_8_fold")
	await _pause(1.4)
	_impressions[1].unseal(0.8)
	await _pause(0.3)
	await _save("story_9_dots_unseal")
	await _pause(1.0)
	_impressions[2].visible = true   # the cup set up and seen: Turn to fit is offered too
	HubGlow.offer(self, _impressions, 0.3)
	await _pause(0.6)
	await _save("story_10_later_hub")
	# 7. The dots' entrance: a stand-in cloud rises straight up from behind the table's far edge.
	await HubGlow.quiet_all(0.6)
	for impression in _impressions:
		impression.visible = false
	var cloud := _stand_in_cloud()
	var eye := App.head().global_position
	var ahead := -App.head().global_transform.basis.z
	ahead = Vector3(ahead.x, 0.0, ahead.z).normalized()
	var to := Transform3D(Basis.looking_at(ahead), eye + ahead * 1.05 + Vector3.DOWN * 0.2)
	App.rig.head.rotation = Vector3(-0.3, 0.0, 0.0)
	DotsEntrance.rise(cloud, DotsEntrance.start_of(to), to, 1.4)
	for i in 4:
		await _save("story_11_dots_%d" % i)
		await _pause(0.45)
	App.rig.head.rotation = Vector3(-0.62, 0.0, 0.0)
	cloud.queue_free()
	for impression in _impressions:
		impression.visible = true
		impression.set_sealed(false)
	# Glow options as first shown (A, B, C), kept for reference.
	_impressions[2].visible = true
	var ring := _socket_ring(_entry.get("_socket_at"))
	await _save("hub_glow_A_socket")
	ring.queue_free()
	await _save("hub_1_impressions")
	var motes := _motes(_entry.get("_mouth"))
	await _save("hub_glow_B_motes")
	motes.queue_free()
	for impression in _impressions:
		impression.set_waiting(1.0)
	await _save("hub_glow_C_waiting")
	# Close-up of the three looks, straight on.
	for impression in _impressions:
		impression.set_waiting(0.0)
	var cam := App.rig.head as Camera3D
	var mid := Vector3.ZERO
	for impression in _impressions:
		mid += impression.global_position
	mid /= _impressions.size()
	cam.global_position = mid + Vector3(0, 0.22, 0.5)
	cam.look_at(mid + Vector3.UP * 0.07)
	cam.fov = 50.0
	await _save("hub_2_impressions_close")
	get_tree().quit()


## A stand-in for the dots (the real cloud is Wei's MotionCloud, started by the Hub): 300 cream dots in
## a 50 x 30 x 20 cm box.
func _stand_in_cloud() -> MultiMeshInstance3D:
	var cloud := MultiMeshInstance3D.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	var dot := SphereMesh.new()
	dot.radius = 0.006
	dot.height = 0.012
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.97, 0.95, 0.88)
	dot.material = material
	multi.mesh = dot
	multi.instance_count = 300
	var random := RandomNumberGenerator.new()
	random.seed = 7
	for i in 300:
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(random.randf_range(-0.25, 0.25), random.randf_range(-0.15, 0.15), random.randf_range(-0.1, 0.1))))
	cloud.multimesh = multi
	add_child(cloud)
	return cloud


## Three impressions in reach, near the cauldron but clear of it, the socket and each other: the
## nearest free spots on an arc 45 cm from the eyes. (A preview: the Hub chat owns the real spots.)
func _place_impressions(cauldron: Vector3) -> void:
	var eye := App.head().global_position
	var socket: Vector3 = _entry.get("_socket_at")
	var ahead := -App.head().global_transform.basis.z
	ahead = Vector3(ahead.x, 0.0, ahead.z).normalized()
	var spots: Array[Vector3] = []
	for degrees: float in [8.0, -20.0, -48.0]:   # left of the view to right; the cauldron sits further left
		var at := eye + ahead.rotated(Vector3.UP, deg_to_rad(degrees)) * 0.46
		spots.append(Vector3(at.x, cauldron.y, at.z))
	var kinds: Array[StringName] = [&"shelf", &"dots", &"turn_to_fit"]
	for i in spots.size():
		var impression := Impression.make(kinds[i])
		add_child(impression)
		impression.global_position = spots[i]
		impression.look_at(Vector3(eye.x, spots[i].y, eye.z), Vector3.UP, true)
		_impressions.append(impression)
		print("PREVIEW ", kinds[i], " ", snappedf(spots[i].distance_to(cauldron), 0.01), " m from the cauldron")


func _socket_ring(at: Vector3) -> Node3D:
	var glow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.36
	quad.orientation = PlaneMesh.FACE_Y
	var light := StandardMaterial3D.new()
	light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	light.albedo_texture = Onion.soft_dot()
	light.albedo_color = Color(1.0, 0.86, 0.55, 0.7)
	quad.material = light
	glow.mesh = quad
	add_child(glow)
	glow.global_position = at + Vector3.UP * 0.004
	return glow


func _motes(mouth: Vector3) -> Node3D:
	var group := Node3D.new()
	add_child(group)
	var heights := [0.03, 0.07, 0.11, 0.15, 0.2, 0.25, 0.31]
	for i in heights.size():
		var mote := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * 0.045
		var light := StandardMaterial3D.new()
		light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		light.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		light.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		light.albedo_texture = Onion.soft_dot()
		light.albedo_color = Color(1.0, 0.86, 0.55, 0.85 * (1.0 - heights[i] / 0.36))
		quad.material = light
		mote.mesh = quad
		group.add_child(mote)
		mote.global_position = mouth + Vector3(sin(i * 2.1) * 0.04, heights[i], cos(i * 1.7) * 0.04)
	return group


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
	get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))
	print("SHOT ", name)
