extends Node
## Pictures of the workshop hub (Scenes 7–11, Hub chat Nov 17) for the full-pass review, to build/hub_flow/:
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --xr-mode off --path . \
##       res://tools/hub_shots.tscn -- --profile=test_capture --mode=play
## It runs the real flow from the shelf jump and presses for the child where a press is needed.

var _out := ProjectSettings.globalize_path("res://build/hub_flow")
var _n := 0
var _line := ""
var _hub: WorkshopController
var _visit: MotionVisit


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
	entry.plan_at_start = false   # plan the room now (as the tests do), then hand over to the first visit
	entry.run()
	await _until(func() -> bool: return entry.tools_ready and entry.zones_available() and entry.get("_layout") != null, 2400)
	await _pause(1.0)
	_look(-0.6)
	entry.call(&"_to_shelf", false)   # the opening's own hand-over: the first visit with its welcome
	await _until(func() -> bool: return App.main.current_scene == &"first_visit" and not App.main.switching)
	await _until(func() -> bool:
		_hub = app.find_child("WorkshopController", true, false) as WorkshopController
		return _hub != null and _hub.state == &"hub" and not _hub.ring.turning, 1800)
	var hub := _hub
	await _pause(0.6)
	await _shot("s7_hub_closed", "Scene 7: the first visit: the menu closed: the ☰ over the brew, the cauldron glowing softly")
	await _pause(5.5)
	await _shot("s7_tap_cue", "Scene 7: after ~5 s, the teaching hand taps the cauldron")
	_open(hub)
	await _pause(0.6)
	await _shot("s7_bubbles_rising", "Scene 7: one tap: the bubbles rise")
	await _until(func() -> bool: return hub.ring.opened and not hub.ring.turning)
	await _pause(1.5)
	await _shot("s7_bubbles_first", "Scene 7: the bubble menu: the shelf, the dots closed beside it, buds")
	_press(hub, &"shelf")
	await _pause(0.12)
	await _shot("s7_chosen_pop", "Scene 7: the shelf chosen: its bubble bursts into droplets (pop)")
	await _pause(0.35)
	await _shot("s7_chosen_title", "Scene 7: its name over it in retro letters (chime)")
	await _until(func() -> bool: return hub.state == &"game" and App.session.running and App.session.trial != null)
	await _pause(4.0)
	await _shot("s8_shelf_game", "Scene 8: the shelf plays; the bubbles sank in; the exit token by the cauldron")
	await _finish_rounds()
	await _until(func() -> bool: return hub.state == &"hub" and not hub.ring.turning and hub.ring.door != null, 1800)
	await _pause(1.5)
	await _shot("s8_back_dots_and_door", "Scene 8→7: back at the hub: the dots opened, the Virtual Workshop house below")
	_look(-0.75)
	await _pause(0.3)
	await _shot("s7_bubbles_lower", "Scene 7: looking a little lower: the arc and the door")
	_look(-0.6)
	hub.ring.set_process(false)   # the desktop hand stays near the menu: show the rest as it looks after ~20 s
	hub.ring.call(&"_rest_to", 1.0, ImpressionRing.REST_SECONDS)
	await _pause(ImpressionRing.REST_SECONDS + 0.3)
	await _shot("s7_bubbles_resting", "Scene 7: ~20 s with no hand near: the bubbles rest (70 %, in place)")
	hub.ring.call(&"_rest_to", 0.0, ImpressionRing.WAKE_SECONDS)
	await _pause(ImpressionRing.WAKE_SECONDS + 0.2)
	hub.ring.set_process(true)
	_press(hub, &"dots")
	await _until(func() -> bool:
		_visit = App.main.get_node_or_null(^"FirstVisit/Visit/Motion") as MotionVisit
		return _visit != null and _visit.in_motion() and App.session.trial != null, 2400)
	_look(-0.25)
	await _pause(3.0)
	await _shot("s9_dots_dimmed", "Scene 9: the dots, the room dimmed, subtitles under the cloud")
	await _finish_rounds()
	await _until(func() -> bool: return hub.state == &"hub" and not hub.ring.turning, 2400)
	_look(-0.6)
	await _pause(1.0)
	await _shot("s9_back_to_hub", "Scene 9→7: dim cleared, back at the hub, the menu up again")
	# Scene 11: the door and back.
	Events.selected.emit(&"right", hub.ring.door.target, Vector3.ZERO, Vector3.FORWARD)
	var home := App.module(&"Home")
	await _pause(0.9)
	await _shot("s11_door_chosen", "Scene 11: the door chosen: its bubble pops, the rest sink in")
	await _until(func() -> bool: return home.is_open)
	await _pause(1.5)
	await _shot("s11_weis_room", "Scene 11: Virtual Workshop")
	home.close()
	await _until(func() -> bool: return hub.state == &"hub" and not hub.ring.turning, 1800)
	await _pause(0.8)
	await _shot("s11_back", "Scene 11: back at the hub, the menu up again")
	# Scene 10: the gear lifted out.
	hub.carry.picked_up.emit()
	await _pause(1.5)
	await _shot("s10_all_done", "Scene 10: the gear lifted: \"All done for today?\"")
	hub.carry.released.emit(false)
	await _pause(0.6)
	await _shot("s10_menu_sinks", "Scene 10: let go away from the socket: the bubbles sink into the cauldron")
	await _until(func() -> bool: return hub.state == &"closed", 3600)
	await _pause(1.0)
	await _shot("s10_closed", "Scene 10: after the goodbye; the socket faded")
	App.module(&"Facilitator").call(&"_open", false)
	await _pause(0.5)
	_look(-0.1)
	await _shot("s10_staff_results", "Scene 10: Staff tools opens on Results, End session there")
	get_tree().quit()


func _open(hub: WorkshopController) -> void:
	Events.selected.emit(&"right", hub.cauldron_menu.target, Vector3.ZERO, Vector3.FORWARD)


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
