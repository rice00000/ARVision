extends Node
## Turn to fit in the hub, beat by beat (TurnToFitActivity, with Megan's mug photos as the camera and a stand-in
## mug where the real cup would be). Reaches the hub like tools/hub_shots. → build/ttf_hub/
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --xr-mode off --path . \
##       res://tools/ttf_hub_shots.tscn -- --profile=test_capture --mode=play

const DATA := "res://tests/data/turn_to_fit/"
var _out := ProjectSettings.globalize_path("res://build/ttf_hub")
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
	app.autostart = true
	var entry: Entry = app.get_node(^"Intro/Entry")
	entry.plan_at_start = false
	entry.run()
	await _until(func() -> bool: return entry.tools_ready and entry.zones_available() and entry.get("_layout") != null, 2400)
	await _pause(1.0)
	entry.call(&"_to_shelf", false)
	await _until(func() -> bool: return App.main.current_scene == &"first_visit" and not App.main.switching)
	await _until(func() -> bool:
		_hub = app.find_child("WorkshopController", true, false) as WorkshopController
		return _hub != null and _hub.state == &"hub" and not _hub.ring.turning, 1800)
	await _pause(1.0)
	_hub.ring.visible = false   # a game runs: the menu has sunk into the cauldron
	_hub.exit_token.visible = true
	_save_setup()
	var activity := TurnToFitActivity.new()
	activity.server_override = true
	activity.use_server = false
	activity.frame_source = func() -> Image: return Image.load_from_file(DATA + "santa_%s.jpg" % _view)
	_hub.add_child(activity)
	_cup_stand_in()
	App.rig.head.rotation = Vector3(-0.45, 0.0, 0.0)
	activity.summon(Transform3D.IDENTITY)
	var g := activity.current
	_set_view(g, "left")
	await _pause(0.2)
	await _shot("1a_appearing", "Beat 1: the window grows in place")
	await _until(func() -> bool: return g.free_look, 300)
	await _pause(1.2)
	await _shot("1b_free_look", "Beat 1, first go: the free look (live shadow only, no card, no green)")
	_set_view(g, "right")
	await _until(func() -> bool: return g.phase == &"turn" and g.game.playing, 1200)
	_set_view(g, _other(g))
	await _pause(1.2)
	await _shot("2a_mirror", "Beat 2, Mirror: the gold card and the live shadow (smooth edge)")
	_set_view(g, _card(g))
	await _until(func() -> bool: return g.phase == &"reveal", 600)
	await _pause(0.15)
	await _shot("2b_fit", "Beat 2: a fit: green, the hop, the found-its-place ring")
	await _fit(g)
	await _until(func() -> bool: return g.phase == &"turn" and g.game.playing and g.game.help == FitGame.Help.GLIMMER, 1200)
	_set_view(g, _other(g))
	await _pause(1.2)
	await _shot("3a_glimmer_wrong", "Beat 3, Glimmer: a wrong view: no shadow")
	_set_view(g, _card(g))
	await _pause(0.45)
	await _shot("3b_glimmer_near", "Beat 3, Glimmer: nearest this card: the shadow shows")
	await _until(func() -> bool: return g.phase == &"reveal", 600)
	await _fit(g)
	await _until(func() -> bool: return g.phase == &"turn" and g.game.playing and g.game.help == FitGame.Help.BLIND, 1200)
	_set_view(g, _card(g))
	await _pause(1.0)
	await _shot("4a_blind", "Beat 4, Blind: the card only, the round ✓ button by the cup")
	App.rig.head.rotation = Vector3(-0.8, 0.0, 0.0)
	await _pause(0.3)
	await _shot("4b_blind_button", "Beat 4: looking down at the cup and the ✓ button")
	App.rig.head.rotation = Vector3(-0.45, 0.0, 0.0)
	g.fits.press()
	await _until(func() -> bool: return g.phase == &"reveal", 300)
	await _pause(0.2)
	await _shot("4c_blind_answer", "Beat 4: after the press: the answer for 2.5 s")
	await _until(func() -> bool: return g.phase == &"pick" and g.game.playing, 1200)
	_set_view(g, "right")
	await _pause(1.0)
	await _shot("5a_check_in", "Beat 5: the check-in: big, well-spaced cards, no numbers")
	var slot := g.game.cards.find(g.matcher.names.find("right"))
	Events.touched.emit(&"right", g.find_child("ttf_card_%d" % slot, true, false) as Target)
	await _until(func() -> bool: return g.phase == &"reveal", 300)
	await _pause(0.2)
	await _shot("5b_check_in_answer", "Beat 5: the answer")
	await _until(func() -> bool: return g.phase == &"end", 900)
	await _pause(0.3)
	await _shot("6a_end", "Beat 6: the ending line, then the window goes in place")
	get_tree().quit()


var _view := "left"


func _set_view(g: TurnToFitGame, view: String) -> void:
	_view = view
	var b: Array = JSON.parse_string(FileAccess.get_file_as_string(DATA + "santa.json")).boxes[view]
	g.tracker.set_box(Rect2i(int(b[0]), int(b[1]), int(b[2] - b[0]), int(b[3] - b[1])))


func _card(g: TurnToFitGame) -> String:
	return g.matcher.names[g.game.card]


func _other(g: TurnToFitGame) -> String:
	return g.matcher.names[(g.game.card + 1) % g.matcher.names.size()]


## Plays rounds to fits until the help has moved on (2 fits).
func _fit(g: TurnToFitGame) -> void:
	await _until(func() -> bool: return g.phase == &"turn" and g.game.playing, 1200)
	_set_view(g, _card(g))
	await _until(func() -> bool: return g.phase == &"reveal", 600)


func _save_setup() -> void:
	var shapes := {}
	for view: String in ["left", "right", "toward"]:
		var b: Array = JSON.parse_string(FileAccess.get_file_as_string(DATA + "santa.json")).boxes[view]
		var box := Rect2i(int(b[0]), int(b[1]), int(b[2] - b[0]), int(b[3] - b[1]))
		shapes[view] = ShapeCV.target_from_mask(Image.load_from_file(DATA + "santa_%s_sam.png" % view), box).shape
	var bl: Array = JSON.parse_string(FileAccess.get_file_as_string(DATA + "santa.json")).boxes["left"]
	var lbox := Rect2i(int(bl[0]), int(bl[1]), int(bl[2] - bl[0]), int(bl[3] - bl[1]))
	var model := ShapeCV.learn_colours(Image.load_from_file(DATA + "santa_left.jpg"), Image.load_from_file(DATA + "santa_left_sam.png"), lbox)
	DirAccess.make_dir_recursive_absolute(Profile.path())
	var file := FileAccess.open(Profile.path(TurnToFit.SAVE_FILE), FileAccess.WRITE)
	file.store_var({version = TurnToFit.SAVE_VERSION, shapes = shapes, model = model, saved = "shots"})
	file.close()


## A white mug where the child's real cup would stand (passthrough on the headset).
func _cup_stand_in() -> void:
	var eye := App.head().global_transform
	var forward := Vector3(-eye.basis.z.x, 0.0, -eye.basis.z.z).normalized()
	var right := forward.cross(Vector3.UP)
	var table_y := App.reality.work_surface().transform.origin.y
	var floor_eye := Vector3(eye.origin.x, table_y, eye.origin.z)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.95, 0.95, 0.95)
	var cup := MeshInstance3D.new()
	var body := CylinderMesh.new()
	body.top_radius = 0.042
	body.bottom_radius = 0.04
	body.height = 0.1
	body.material = white
	cup.mesh = body
	add_child(cup)
	cup.global_position = floor_eye + forward * 0.45 + Vector3.UP * 0.05
	var handle := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.018
	torus.outer_radius = 0.03
	torus.material = white
	handle.mesh = torus
	cup.add_child(handle)
	handle.position = -right * 0.05
	handle.rotation = Vector3(PI / 2.0, 0.0, 0.0)


func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _until(cond: Callable, frames := 900) -> void:
	var n := 0
	while not cond.call() and n < frames:
		await get_tree().process_frame
		n += 1


func _shot(file: String, what: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(file + ".png"))
	print("SHOT ", file, " | ", what)
