extends Node
## Reproducible rendered review: godot --xr-mode off --path . res://tools/home_capture.tscn -- --profile=test_home_capture

var out := "res://build/home_review/"


func _ready() -> void:
	if not String(Profile.id).begins_with("test"):
		get_tree().quit(2)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1280, 800)
	Profile.wipe()
	var main: Main = load("res://main.tscn").instantiate()
	main.autostart = false
	main.initial_scene = "find_object"
	add_child(main)
	await _frames(5)
	App.module(&"Inventory").add(&"magic_stone", 8)
	var home := App.module(&"Home")
	await shot("menu_entry", "menu_open")
	home.open()
	await shot("menu", "menu_staff_tools", false)
	home._show(&"games")
	await shot("games", "menu_game_global_motion", false)
	home._show(&"room")
	await shot("home", "home_shop")
	home._show(&"shop")
	await shot("shop", "home_next")
	home._show(&"rooms")
	home._index = 1
	home._build()
	await shot("rooms", "home_next")
	home._show(&"confirm_room")
	await shot("confirm", "home_confirm")
	App.module(&"Inventory").buy(&"chair")
	home._show(&"decorate")
	Events.furniture_requested.emit(&"chair")
	App.sim_input.look_at(App.reality.room_frame * Vector3(0, 0.55, -1.0))
	await shot("decorate")
	home.close()
	App.sim_input.menu()
	await shot("facilitator", "fac_saves")
	App.sim_input.menu()
	App.sim_input.look_at(App.head().global_position + Vector3.FORWARD)
	await _frames(3)
	await RenderingServer.frame_post_draw
	for style in [WallBreak.Style.CRACK, WallBreak.Style.SPACE]:
		WallBreak.burst(App.head().global_position, Vector3.FORWARD, Vector3.RIGHT, style)
		for phase in [0.12, 0.45, 0.40]:
			await get_tree().create_timer(phase).timeout
			await shot("wall_%d_%s" % [style, str(phase)])
		for effect in App.stage.get_children():
			if effect is WallBreak: effect.queue_free()
	# Actual Onion model, with the same touch component used by the opening.
	var holder := Node3D.new()
	main.add_child(holder)
	holder.position = App.head().global_position + Vector3(0, -0.06, -0.45)
	var onion: Node3D = load("res://entry/assets/onion_the_wisp.glb").instantiate()
	holder.add_child(onion)
	var bounds := HomeUI.bounds_of(onion)
	onion.scale *= 0.18 / bounds.size.y
	bounds = HomeUI.bounds_of(onion)
	onion.global_position -= (onion.global_transform * bounds).get_center() - holder.global_position
	var touch := OnionTouch.new()
	touch.setup(onion)
	holder.add_child(touch)
	await shot("onion_rest")
	Events.touched.emit(&"right", touch)
	await get_tree().create_timer(0.08).timeout
	await shot("onion_touch")
	await App.main.change_scene(&"intro")
	var entry: Entry = App.main.get_node(^"Intro/Entry")
	entry.skip_setup = false
	entry.run()
	await _frames(10)
	await shot("intro_setup", "entry_step_next")
	await press_button("menu_open")
	await get_tree().create_timer(0.35).timeout
	await press_button("menu_staff_tools")
	await shot("intro_tools", "fac_jump_reveal", false)
	await press_button("fac_restart")
	await shot("confirm_restart", "fac_cancel_tool", false)
	Profile.wipe()
	get_tree().quit()


func _frames(count: int) -> void:
	for i in count: await get_tree().process_frame


func press_button(id: String) -> void:
	var target := App.main.find_child(id, true, false) as UITarget
	App.sim_input.point(&"right", App.head().global_position + Vector3(0.12, -0.18, -0.15), target.global_position)
	await _frames(3)
	App.sim_input.click(&"right", &"trigger_click")
	await _frames(3)


func shot(name: String, aimed_id := "", look_at_button := true) -> void:
	if not aimed_id.is_empty():
		var target := App.main.find_child(aimed_id, true, false) as UITarget
		if look_at_button: App.sim_input.look_at(target.global_position)
		App.sim_input.point(&"right", App.head().global_position + Vector3(0.12, -0.18, -0.15), target.global_position)
	await get_tree().physics_frame
	await _frames(3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + name + ".png")
