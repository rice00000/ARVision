extends Module
## Main menu for games, the room and staff tools.

const GAMES := [&"find_object", &"global_motion"]
## Above the work surface so a ray toward a table object misses the menu.
const ENTRY_OFFSET := Vector3(0.30, 0.09, -0.49)
## Each browsing page and the page that confirms its purchase.
const TITLES := {&"room": "MY ROOM", &"shop": "FURNITURE", &"rooms": "ROOMS", &"pets": "PETS", &"bag": "MY THINGS",
	&"confirm_item": "BUY?", &"confirm_room": "BUY?", &"confirm_pet": "BUY?"}
const CONFIRM := {&"shop": &"confirm_item", &"rooms": &"confirm_room", &"pets": &"confirm_pet"}

var is_open := false
var page := &"menu"
var _in_room := false
var _index := 0
var _entry: Target
var _entry_face: StandardMaterial3D
var _panel := Node3D.new()
var _preview: Node3D
var _view: View
var _pending: StringName
var _cooldown := 0.0
var _hover: Target
var _hover_seconds := 0.0
var _entry_frame := Transform3D.IDENTITY
var _offscreen := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_entry = HomeUI.button(App.rig, &"menu_open", "Menu", "Point and pinch to open the game menu.", Vector3.ZERO, "≡")
	_entry.show_ray = false
	_entry.collision_layer = Pointer.UI_LAYER
	_entry_face = (_entry.get_node(^"Face") as MeshInstance3D).material_override as StandardMaterial3D
	_entry_face.render_priority = 5
	for text: Label3D in _entry.find_children("*", "Label3D", false, false):
		text.render_priority = 6
		text.outline_render_priority = 5
	_panel.visible = false
	add_child(_panel)
	Events.selected.connect(_select)
	Events.scene_changing.connect(close)
	Events.player_menu_requested.connect(open)
	Events.facilitator_toggled.connect(func(open: bool) -> void:
		if open: close()
		_update_entry())
	Events.inventory_changed.connect(func() -> void:
		if _in_room: _build.call_deferred())
	_anchor_entry.call_deferred()


func _anchor_entry() -> void:
	var eye := App.head().global_transform
	var forward := Vector3(-eye.basis.z.x, 0, -eye.basis.z.z).normalized()
	_entry_frame = Transform3D(Basis.looking_at(forward), eye.origin)
	_offscreen = 0.0


func open() -> void:
	if is_open or App.main.switching: return
	is_open = true
	App.hold_pause(&"player_menu", true)
	_update_entry()
	Events.player_menu_toggled.emit(true)
	var eye := App.head().global_transform
	var forward := Vector3(-eye.basis.z.x, 0, -eye.basis.z.z).normalized()
	var height := clampf(-eye.basis.z.y * 0.48, -0.16, 0.16) - 0.035
	_panel.global_transform = Transform3D(Basis.looking_at(forward).scaled(Vector3.ONE * 0.8),
		eye.origin + forward * 0.48 + Vector3.UP * height)
	_panel.visible = true
	_show(&"menu")
	Events.say("Point and pinch to keep playing, choose a game, or visit your room.")


func close() -> void:
	_pending = &""
	if is_open:
		is_open = false
		_set_room(false)
		Events.player_menu_toggled.emit(false)
		_panel.visible = false
		_clear_panel()
		_anchor_entry()
	App.hold_pause(&"player_menu", false)
	_update_entry()


func _select(_hand: StringName, target: Target, _origin: Vector3, _direction: Vector3) -> void:
	if target == null or _pending != &"" or _cooldown > 0 or App.main.switching: return
	if target == _entry:
		if App.menu_active(): return
		# Keep the opening pinch out of the active trial.
		App.hold_pause(&"player_menu", true)
	elif not is_open or not _panel.is_ancestor_of(target): return
	_pending = target.id
	_activate.call_deferred()


func _activate() -> void:
	var id := _pending
	_pending = &""
	if id == &"": return
	_cooldown = 0.3
	Events.report(&"player_menu", {button = id, page = page})
	match id:
		&"menu_open": open()
		&"menu_resume": close()
		&"menu_back": _show(&"menu")
		&"menu_staff_tools": Events.staff_tools_requested.emit()
		&"menu_games":
			_show(&"games")
			Events.say("Choose a game. Finish it to earn magic stones.")
		&"menu_room":
			_show(&"room")
			Events.say("Your home. Point and pinch to choose furniture, rooms, or decorating.")
		&"home_back": _show(&"room")
		&"home_shop": _index = 0; _show(&"shop")
		&"home_rooms": _index = 0; _show(&"rooms")
		&"home_pets": _index = 0; _show(&"pets")
		&"home_bag": _index = 0; _show(&"bag")
		&"home_prev", &"home_next":
			_index = posmod(_index + (-1 if id == &"home_prev" else 1), _catalogue().size())
			_build(); _speak_item()
		&"home_buy":
			_show(CONFIRM[page])
			Events.say("Point at the check mark and pinch to buy. Choose the cross to go back.")
		&"home_cancel": _show(CONFIRM.find_key(page))
		&"home_confirm":
			var item := _item()
			App.module(&"Inventory").buy(item.id)
			Events.say("It is yours!")
			Events.feedback.emit(&"good", _panel.global_position)
			_show(CONFIRM.find_key(page))
		&"home_use_room":
			App.module(&"Rooms").choose(_item().id)
			Events.say("Welcome to your room.")
			_build()
		&"home_place":
			var id_to_place := _item().id
			_show(&"decorate")
			Events.furniture_requested.emit(id_to_place)
		&"home_decorate": _show(&"decorate")
		&"home_store": Events.furniture_store_requested.emit()
		&"home_turn": Events.furniture_turn_requested.emit()
		&"menu_game_find_object", &"menu_game_global_motion":
			App.main.change_scene(StringName(String(id).trim_prefix("menu_game_")))


func _show(next: StringName) -> void:
	page = next
	_set_room(page not in [&"menu", &"games"])
	if _in_room: Events.furniture_editing.emit(page == &"decorate")
	_build()
	if page in [&"shop", &"rooms", &"pets", &"bag"]: _speak_item()
	if page == &"decorate": Events.say("Pinch to move furniture. Let go to place it. Hold it and point at the box with your other hand, then pinch to put it away.")


func _set_room(on: bool) -> void:
	if _in_room == on: return
	_in_room = on
	if on:
		_view = App.reality.view
		App.main.show_activity(false)
		App.reality.apply_view(View.new())
		Events.home_toggled.emit(true)
	else:
		Events.home_toggled.emit(false)
		App.main.show_activity(true)
		App.reality.apply_view(_view)
		_view = null


func _catalogue() -> Array[ItemDef]:
	var kind := ItemDef.Kind.FURNITURE
	if page in [&"rooms", &"confirm_room"]: kind = ItemDef.Kind.ROOM
	elif page in [&"pets", &"confirm_pet"]: kind = ItemDef.Kind.PET
	var items := ItemDef.all(kind)
	if page == &"bag":
		items = items.filter(func(item: ItemDef) -> bool: return App.module(&"Inventory").count(item.id) > 0)
	return items


func _item() -> ItemDef:
	return _catalogue()[_index]


func _speak_item() -> void:
	if _catalogue().is_empty():
		Events.say("Your bag is empty. Point at the chair and pinch to visit the shop.")
		return
	var item := _item()
	var missing: int = item.price - App.module(&"Inventory").count(&"magic_stone")
	if page == &"bag":
		Events.say(item.title)
	elif not _for_sale(item):
		Events.say("%s. It is yours!" % item.title)
	elif missing > 0:
		Events.say("%s. %d magic stones. You need %d more." % [item.title, item.price, missing])
	else:
		Events.say("%s. %d magic stones. You can buy it." % [item.title, item.price])


func _clear_panel() -> void:
	_hover = null
	_preview = null
	for child in _panel.get_children(): child.free()


func _build() -> void:
	if not is_open: return
	_clear_panel()
	if page == &"decorate":
		# Move the controls to the side; the centre stays clear for furniture.
		HomeUI.button(_panel, &"home_back", "My room", "Back to the home menu.", Vector3(-0.27, 0.16, 0), "house")
		HomeUI.button(_panel, &"home_store", "Put away", "Hold the furniture, aim at this box with your other hand, and pinch.", Vector3(0.27, 0.12, 0), "bag")
		HomeUI.button(_panel, &"home_turn", "Turn", "Turn the furniture.", Vector3(0.27, -0.07, 0), "↻")
		HomeUI.button(_panel, &"home_bag", "My things", "Choose furniture from your bag.", Vector3(-0.27, -0.05, 0), "chair")
		return
	HomeUI.box(_panel, Vector3(0.68, 0.53, 0.025), Vector3(0, 0, -0.05), HomeUI.INK)
	if page == &"menu":
		HomeUI.label(_panel, "MENU", Vector3(0, 0.10, 0), 44)
		HomeUI.button(_panel, &"menu_resume", "Keep playing", "Return to your game.", Vector3(-0.22, 0, 0.02), "▶")
		HomeUI.button(_panel, &"menu_games", "Games", "Choose a game. Finish it to earn magic stones.", Vector3(0, 0, 0.02), "◎")
		if App.module(&"Inventory") and App.module(&"Rooms"):
			HomeUI.button(_panel, &"menu_room", "My room", "Visit your room and shop.", Vector3(0.22, 0, 0.02), "house")
		if App.module(&"Facilitator"):
			HomeUI.button(_panel, &"menu_staff_tools", "Staff tools", "Open the staff tools.", Vector3(0, -0.17, 0.02))
		return
	if page == &"games":
		HomeUI.label(_panel, "GAMES", Vector3(0, 0.10, 0), 44)
		HomeUI.button(_panel, &"menu_back", "Menu", "Back to the game menu.", Vector3(-0.265, 0.17, 0), "back")
		for i in GAMES.size():
			var scene: StringName = GAMES[i]
			var title: String = Main.SCENES[scene].title
			var at := Vector3(-0.17 + i * 0.34, -0.02, 0.02)
			if scene == App.main.current_scene:
				HomeUI.label(_panel, title + "\nPlaying now", at, 29)
			else:
				HomeUI.button(_panel, StringName("menu_game_" + scene), title, title, at, "chair" if i == 0 else "◎")
		return
	var inventory := App.module(&"Inventory")
	var balance: int = inventory.count(&"magic_stone")
	HomeUI.label(_panel, TITLES[page], Vector3(-0.04, 0.225, 0), 32)
	HomeUI.stones(_panel, balance, Vector3(0.12, 0.225, 0))
	if page == &"room":
		HomeUI.button(_panel, &"menu_back", "Menu", "Back to the game menu.", Vector3(-0.265, 0.21, 0), "back")
		HomeUI.button(_panel, &"menu_resume", "Resume", "Return to your game.", Vector3(0.265, 0.21, 0), "▶")
		var pets := App.module(&"Pets") != null
		HomeUI.button(_panel, &"home_shop", "Furniture", "Shop for furniture.", Vector3(-0.21 if pets else -0.15, 0.08, 0.02), "chair")
		if pets:
			HomeUI.button(_panel, &"home_pets", "Pets", "See the pets. A pet brings you magic stones.", Vector3(0, 0.08, 0.02), "pet")
		HomeUI.button(_panel, &"home_rooms", "Rooms", "See rooms. You can buy a new room or visit one you own.", Vector3(0.21 if pets else 0.15, 0.08, 0.02), "house")
		HomeUI.button(_panel, &"home_bag", "My things", "Put your furniture in your room.", Vector3(-0.15, -0.12, 0.02), "bag")
		HomeUI.button(_panel, &"home_decorate", "Decorate", "Move the furniture in your room.", Vector3(0.15, -0.12, 0.02), "↔")
		return
	if page in CONFIRM.values():
		HomeUI.button(_panel, &"home_confirm", "Buy", "Confirm this purchase.", Vector3(0.19, -0.19, 0.03), "check")
		HomeUI.button(_panel, &"home_cancel", "Cancel", "Go back without buying.", Vector3(-0.19, -0.19, 0.03), "cross")
	else:
		HomeUI.button(_panel, &"home_back", "My room", "Back to the home menu.", Vector3(-0.265, 0.21, 0), "house")
	if _catalogue().is_empty():
		HomeUI.button(_panel, &"home_shop", "Furniture", "Shop for furniture.", Vector3(0, 0, 0.02), "chair")
		return
	_index = mini(_index, _catalogue().size() - 1)
	var item := _item()
	_preview = HomeUI.preview(_panel, item, Vector3(0, 0.065, 0.06), 0.19)
	HomeUI.label(_panel, item.title, Vector3(0, -0.05, 0.04), 32)
	if _for_sale(item):
		HomeUI.price(_panel, item.price, balance, Vector3(0, -0.095, 0.04))
	if page in CONFIRM.values(): return
	HomeUI.button(_panel, &"home_prev", "Previous", "See the previous one.", Vector3(-0.25, 0.02, 0.04), "left")
	HomeUI.button(_panel, &"home_next", "Next", "See the next one.", Vector3(0.25, 0.02, 0.04), "right")
	if page == &"bag":
		HomeUI.button(_panel, &"home_place", "Place", "Take this furniture out of your bag.", Vector3(0, -0.19, 0.04), "↓")
	elif not _for_sale(item):
		if item.kind == ItemDef.Kind.ROOM:
			HomeUI.button(_panel, &"home_use_room", "Visit", "Visit this room.", Vector3(0, -0.19, 0.04), "house")
		else:
			HomeUI.check(_panel, Vector3(0, -0.15, 0.04), 1.2, HomeUI.GOLD)
	elif balance >= item.price:
		HomeUI.button(_panel, &"home_buy", "Buy", "Preview the purchase.", Vector3(0, -0.19, 0.04), "bag")


## Not in the bag, and not a room or pet the child already has.
func _for_sale(item: ItemDef) -> bool:
	return page != &"bag" and (item.kind == ItemDef.Kind.FURNITURE or App.module(&"Inventory").count(item.id) == 0)


func _process(delta: float) -> void:
	_cooldown = maxf(0, _cooldown - delta)
	_update_entry()
	if _entry.visible:
		var eye := App.head().global_transform
		var toward := (_entry_frame * ENTRY_OFFSET - eye.origin).normalized()
		_offscreen = _offscreen + delta if toward.dot(-eye.basis.z) < 0.17 else 0.0
		if _offscreen > 0.8 or eye.origin.distance_to(_entry_frame.origin) > 0.35:
			_anchor_entry()
		var slot := App.player_menu_slot()
		var in_header := slot != null
		# Draw above the panel backing only while the button is in its header.
		if _entry_face.no_depth_test != in_header:
			_entry_face.no_depth_test = in_header
			for text: Label3D in _entry.find_children("*", "Label3D", false, false):
				text.no_depth_test = in_header
		_entry.global_transform = slot.global_transform if slot else _entry_frame.translated_local(ENTRY_OFFSET)
	if _preview: _preview.rotation.y += delta * 0.18
	var near: Target
	for side in [&"left", &"right"]:
		var pointer := App.rig.pointer(side)
		if not pointer.tracked(): continue
		var target := pointer.aimed
		if target and ((_entry.visible and target == _entry) or (is_open and _panel.is_ancestor_of(target))):
			near = target
	if near != _hover:
		_hover = near
		_hover_seconds = 0
	elif near:
		var before := _hover_seconds
		_hover_seconds += delta
		if before < 0.6 and _hover_seconds >= 0.6: Events.say(near.get_meta(&"speech"))


func _update_entry() -> void:
	var available := not App.menu_active() and not App.main.switching
	if _entry.visible == available: return
	_entry.visible = available
	_entry.collision_layer = Pointer.UI_LAYER if available else 0


func _exit_tree() -> void:
	App.hold_pause(&"player_menu", false)
	if is_instance_valid(_entry): _entry.queue_free()
