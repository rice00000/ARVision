extends Node
## Pictures of the hub's stones, levels and the eye (design chat, Nov 18, DESIGN_STONES_AND_LEVELS), to
## build/hub_stones/:
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --xr-mode off --path . \
##       res://tools/stones_shots.tscn -- --profile=test_capture --mode=play

var _out := ProjectSettings.globalize_path("res://build/hub_stones")
var _n := 0
var _line := ""
var _hub: WorkshopController


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1280, 800)
	Profile.wipe()
	var app: Node3D = load("res://main.tscn").instantiate()
	app.autostart = false
	add_child(app)
	await get_tree().process_frame
	(App.rig.head as Camera3D).fov = 80.0
	Events.said.connect(func(text: String) -> void: _line = text)
	app.autostart = true
	var entry: Entry = app.get_node(^"Intro/Entry")
	entry.plan_at_start = false
	App.main.progress.done[&"tidy_shelf"] = [&"size"]   # a child who has finished Size Match before
	entry.run()
	await _until(func() -> bool: return entry.tools_ready and entry.zones_available() and entry.get("_layout") != null, 2400)
	await _pause(1.0)
	_look(-0.6)
	entry.call(&"_to_shelf", false)
	await _until(func() -> bool: return App.main.current_scene == &"first_visit" and not App.main.switching)
	await _until(func() -> bool:
		_hub = app.find_child("WorkshopController", true, false) as WorkshopController
		return _hub != null and _hub.state == &"hub" and not _hub.ring.turning, 1800)
	var hub := _hub
	_open(hub)
	await _until(func() -> bool: return hub.ring.opened and not hub.ring.turning)
	await _pause(0.8)
	_press(hub, &"shelf")
	await _until(func() -> bool: return hub.state == &"game" and App.session.running and App.session.trial != null)
	await _pause(2.0)
	Events.selected.emit(&"right", hub.cauldron_target, Vector3.ZERO, Vector3.FORWARD)
	await _until(func() -> bool: return hub.eye_bubble != null)
	await _pause(0.6)
	await _shot("pause_eye_x", "Shelf paused: eye · ✕ over the brew")
	await _pause(6.5)
	await _finish_rounds()
	await _until(func() -> bool: return hub.state == &"hub" and hub.badge != null and hub.badge.flying(), 1800)
	_look(-0.7)
	await _pause(0.5)
	await _shot("stones_flying", "Back at the hub: the stones arc from the brew into the house's badge")
	await _until(func() -> bool: return not hub.badge.flying(), 600)
	await _pause(0.3)
	await _shot("stones_landed", "The badge shows the count; the shelf grew a row")
	await _until(func() -> bool: return _line == WorkshopController.STONES_SPEND, 900)
	await _pause(2.5)
	_press(hub, &"shelf")
	await _until(func() -> bool: return hub.row != null and hub.row.opened, 900)
	_look(-0.6)
	await _pause(0.5)
	await _shot("level_row", "The shelf's own row: the next level (Clutter Search) big in the middle, finished ones around")
	Events.selected.emit(&"right", hub.cauldron_target, Vector3.ZERO, Vector3.FORWARD)
	await _until(func() -> bool: return hub.row == null and hub.ring.opened, 900)
	await _pause(0.5)
	Events.selected.emit(&"right", hub.ring.place_of(&"eye").target, Vector3.ZERO, Vector3.FORWARD)
	await _until(func() -> bool: return hub.row != null and hub.row.opened, 900)
	await _pause(0.5)
	await _shot("looks_row", "The eye: four looks, the current one ringed")
	Events.selected.emit(&"right", hub.row.impressions[2].target, Vector3.ZERO, Vector3.FORWARD)
	await _pause(0.6)
	await _shot("looks_edges", "Edges picked: the real room changes (sim), the ring moves")
	get_tree().quit()


func _open(hub: WorkshopController) -> void:
	Events.selected.emit(&"right", hub.cauldron_target, Vector3.ZERO, Vector3.FORWARD)


func _press(hub: WorkshopController, kind: StringName) -> void:
	for impression in hub.ring.impressions:
		if is_instance_valid(impression) and impression.kind == kind:
			Events.selected.emit(&"right", impression.target, Vector3.ZERO, Vector3.FORWARD)


func _finish_rounds() -> void:
	Engine.time_scale = 3.0
	while App.session.running:
		if App.session.trial != null and App.session.trial.is_running():
			App.session.trial.finish(true)
		await get_tree().process_frame
	Engine.time_scale = 1.0


func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _until(cond: Callable, frames := 900) -> void:
	var n := 0
	while not cond.call() and n < frames:
		await get_tree().process_frame
		n += 1


func _look(pitch: float) -> void:
	App.rig.head.rotation = Vector3(pitch, 0.0, 0.0)


func _shot(file: String, what: String) -> void:
	await RenderingServer.frame_post_draw
	_n += 1
	var name := "%02d_%s.png" % [_n, file]
	get_viewport().get_texture().get_image().save_png(_out.path_join(name))
	print("SHOT ", name, " | ", what, " | line: ", _line)
