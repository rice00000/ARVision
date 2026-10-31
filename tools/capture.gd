extends Node
## Renders what the child sees under every view preset, on the simulated room,
## to build/captures/<view>.png, then the tidy-up shelf with each kind of
## sticker (tidy_<kind>.png). For people (and agents) to look at; no headset.
##
##   godot --xr-mode off --path . res://tools/capture.tscn -- --profile=test_capture

const VIEWS := "res://content/views/"
const TIDY := preload("res://trials/tidy/tidy.tres")
## Sticker kinds of the tidy-up shelf: name -> pinned axes.
const STICKERS := {shadow = {}, outline = {&"outline": 1.0}, size = {&"match": 1.0}, colour = {&"match": 2.0}}


func _ready() -> void:
	var out := ProjectSettings.globalize_path("res://build/captures")
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1280, 800)
	Profile.wipe()
	var app: Node3D = load("res://main.tscn").instantiate()
	app.autostart = false
	var plan := TestCase.plan_of(load("res://trials/find/find.tres"), 1, false, 0.6)
	for kind in STICKERS:
		plan.blocks.append(TestCase.plan_of(TIDY, 1, false, 1.0 if kind == "shadow" else 0.67, null, STICKERS[kind]).blocks[0])
	app.plan = plan
	add_child(app)
	await get_tree().process_frame
	App.session.run()
	while App.session.trial == null or not App.session.trial.is_running():
		await get_tree().process_frame
	App.sim_input.look_at(App.reality.work_surface().transform.origin + Vector3(0, 0.0, -0.3))
	for file in DirAccess.get_files_at(VIEWS):
		if file.ends_with(".tres"):
			App.reality.apply_view(load(VIEWS + file))
			await _save(out.path_join(file.get_basename() + ".png"))
	App.reality.apply_view(View.new())
	var magic := App.module(&"Magic")
	magic.sparkle((App.session.trial.get("_target") as Node3D).global_position, magic.GOLD, 24)
	await get_tree().create_timer(0.3).timeout
	await _save(out.path_join("sparkles.png"))
	for kind in STICKERS:
		App.session.skip_block()
		while App.session.trial == null or App.session.trial.def != TIDY or not App.session.trial.is_running():
			await get_tree().process_frame
		await get_tree().create_timer(0.7).timeout # the things have landed
		App.sim_input.look_at(App.session.trial.focus_point() + Vector3(0, -0.04, 0))
		await _save(out.path_join("tidy_%s.png" % kind))
	var trial := App.session.trial
	var thing: Target = trial.get("_things")[0]
	App.sim_input.point(&"right", thing.global_position + Vector3(0.0, 0.03, 0.05).normalized() * 0.05, thing.global_position)
	await get_tree().create_timer(0.2).timeout
	App.sim_input.point(&"right", App.head().global_position + Vector3(0.12, -0.22, -0.2), trial.focus_point())
	await get_tree().create_timer(0.2).timeout
	await _save(out.path_join("tidy_carry.png"))
	App.sim_input.look_at(App.reality.work_surface().transform.origin + Vector3(0, 0.0, -0.3))
	App.sim_input.menu()
	await _save(out.path_join("facilitator.png"))
	App.module(&"Facilitator").call(&"_show", &"Saves")
	App.module(&"Facilitator").call(&"_refresh")
	await _save(out.path_join("facilitator_saves.png"))
	print("CAPTURED ", out)
	get_tree().quit()


func _save(path: String) -> void:
	for i in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
