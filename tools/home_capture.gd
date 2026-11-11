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
	home._show(&"shop")
	await shot("shop", "home_next")
	home._show(&"rooms")
	home._index = 1
	home._build()
	await shot("rooms", "home_next")
	home._show(&"confirm_room")
	await shot("confirm", "home_confirm")
	App.module(&"Inventory").buy(&"chair")
	home._show(&"room")
	Events.furniture_requested.emit(&"chair")
	await shot("room", "home_box", false)
	App.sim_input.look_at(App.reality.room_frame * Vector3(0, 0.55, -1.0))
	await shot("room_furniture")
	var inventory := App.module(&"Inventory")
	inventory.add(&"pet_cat")
	inventory.add(&"pet_dog")
	inventory.add(&"cushion")
	home._show(&"pets")
	home._index = 2
	home._build()
	await shot("pet_shop", "home_next")
	home._show(&"room")
	Events.furniture_requested.emit(&"cushion")
	var cat: Pet = App.module(&"Pets").pets()[0]
	var dog: Pet = App.module(&"Pets").pets()[1]
	cat.has_stone = true
	dog._mood = Pet.Act.REST
	dog._spot = App.module(&"Pets").cushions()[0]
	dog._mood_for = 600.0
	for pet: Pet in [cat, dog]: pet.position = Vector3(1.2, 0, -1.6)
	App.sim_input.look_at(App.reality.room_frame * Vector3(0.6, 0.5, -1.2))
	await get_tree().create_timer(1.0).timeout
	await shot("pets_walking")
	await get_tree().create_timer(12.0).timeout
	App.sim_input.look_at(App.reality.room_frame * Vector3(0.25, 0.7, -0.32))
	await shot("pet_brings_stone")
	App.sim_input.look_at(App.reality.room_frame * (dog.position + Vector3.UP * 0.1))
	await shot("pet_resting")
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
