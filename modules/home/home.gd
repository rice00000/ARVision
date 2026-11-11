extends Module
## Main menu for games, the room and staff tools.

const GAMES := [&"find_object", &"global_motion"]
## Above the work surface so a ray toward a table object misses the menu.
const ENTRY_OFFSET := Vector3(0.30, 0.09, -0.49)
## Megan, Nov 10: the Menu button stays at the TOP LEFT of the view (head-relative, about 24 deg left and
## 15 deg up, 0.5 m away), following the head gently instead of being left in the room and re-placed.
## It is still well above the work surface, so a ray at a table object misses it.
const ENTRY_VIEW_OFFSET := Vector3(-0.22, 0.13, -0.5)
## How quickly it catches up with the head (1/s); a big jump (a recentre) snaps.
const ENTRY_FOLLOW := 6.0
## How far in front of the eyes the menu panel opens, metres (was 0.48; the panel scales to look the same size).
const MENU_DISTANCE := 0.34
## Each shop page and the page that confirms its purchase.
const CONFIRM := {&"shop": &"confirm_item", &"rooms": &"confirm_room", &"pets": &"confirm_pet"}
## The shop's pages, always on show along its top: page, caption, speech, icon.
const TABS := [
	[&"shop", "Furniture", "Shop for furniture.", "chair"],
	[&"pets", "Pets", "See the pets. A pet brings you magic stones.", "pet"],
	[&"rooms", "Rooms", "See rooms. You can buy a new room or visit one you own.", "door"]]

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
var _wallet := Node3D.new()   # the magic stones the child has, beside the Menu button (Megan, Nov 10)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_entry = HomeUI.button(App.rig, &"menu_open", "Menu", "Point and pinch to open the game menu.", Vector3.ZERO, "≡")
	_entry.show_ray = false
	_entry.collision_layer = Pointer.UI_LAYER
	_entry_face = (_entry.get_node(^"Face") as MeshInstance3D).material_override as StandardMaterial3D
	_wallet.name = "Wallet"
	_wallet.position = Vector3(0.115, 0.0, 0.0)   # just right of the button
	_entry.add_child(_wallet)
	Events.inventory_changed.connect(_update_wallet)
	_update_wallet.call_deferred()
	_entry_face.render_priority = 5
	for text: Label3D in _entry.find_children("*", "Label3D", false, false):
		text.render_priority = 6
		text.outline_render_priority = 5
	_panel.visible = false
	add_child(_panel)
	Events.selected.connect(_select)
	Events.scene_changing.connect(close)
	Events.player_menu_requested.connect(open)
	Events.room_requested.connect(func() -> void:
		open()
		if is_open: _show(&"room"))
	Events.facilitator_toggled.connect(func(open: bool) -> void:
		if open: close()
		_update_entry())
	Events.inventory_changed.connect(func() -> void:
		if _in_room: _build.call_deferred())
	_anchor_entry.call_deferred()


## The stone and the number of magic stones beside the Menu button (nothing if there is no Inventory).
func _update_wallet() -> void:
	for child in _wallet.get_children():
		child.queue_free()
	var inventory := App.module(&"Inventory")
	if inventory == null:
		return
	HomeUI.stones(_wallet, inventory.count(&"magic_stone"), Vector3(0.03, 0.0, 0.0))
	for text: Label3D in _wallet.find_children("*", "Label3D", true, false):
		text.no_depth_test = true   # readable over whatever is behind it
		text.render_priority = 20


func _anchor_entry() -> void:
	var eye := App.head().global_transform
	var forward := Vector3(-eye.basis.z.x, 0, -eye.basis.z.z).normalized()
	_entry_frame = Transform3D(Basis.looking_at(forward), eye.origin)
	_offscreen = -1.0   # the next frame places it at the top left of the view at once


func open() -> void:
	if is_open or App.main.switching: return
	is_open = true
	App.hold_pause(&"player_menu", true)
	_update_entry()
	Events.player_menu_toggled.emit(true)
	var eye := App.head().global_transform
	var forward := Vector3(-eye.basis.z.x, 0, -eye.basis.z.z).normalized()
	var height := clampf(-eye.basis.z.y * 0.48, -0.16, 0.16) - 0.035
	# Megan, Nov 10: at 0.48 m the shelf (and the bench's shapes) stood in front of the panel and cut through
	# its buttons. Nearer, at the same apparent size, it stays in front of what is on the table.
	_panel.global_transform = Transform3D(Basis.looking_at(forward).scaled(Vector3.ONE * 0.8 * MENU_DISTANCE / 0.48),
		eye.origin + forward * MENU_DISTANCE + Vector3.UP * height * MENU_DISTANCE / 0.48)
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
			Events.say("Pinch to move furniture. Let go to place it. Hold it and point at the box with your other hand, then pinch to put it away.")
		&"home_shop": _index = 0; _show(&"shop")
		&"home_tab_shop", &"home_tab_pets", &"home_tab_rooms":
			_index = 0
			_show(StringName(String(id).trim_prefix("home_tab_")))
		&"home_back": _show(&"room")
		&"home_box":
			# A held piece goes into the box; an empty hand opens it.
			var decor := App.module(&"Decor")
			if decor and decor.held:
				Events.furniture_store_requested.emit()
			else:
				_index = 0
				_show(&"bag")
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
			if item.kind == ItemDef.Kind.ROOM:
				_show(CONFIRM.find_key(page))
			else:
				# New furniture and pets go straight into the room.
				_show(&"room")
				if item.kind == ItemDef.Kind.FURNITURE: Events.furniture_requested.emit(item.id)
		&"home_use_room":
			App.module(&"Rooms").choose(_item().id)
			Events.say("Welcome to your room.")
			_build()
		&"home_place":
			var id_to_place := _item().id
			_show(&"room")
			Events.furniture_requested.emit(id_to_place)
		&"menu_game_find_object", &"menu_game_global_motion":
			App.main.change_scene(StringName(String(id).trim_prefix("menu_game_")))


func _show(next: StringName) -> void:
	page = next
	_set_room(page not in [&"menu", &"games"])
	if _in_room: Events.furniture_editing.emit(page == &"room")
	_build()
	if page in [&"shop", &"rooms", &"pets", &"bag"]: _speak_item()


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
		Events.say("Your box is empty.")
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
	if page == &"room":
		# One bar above the view; the room and its furniture stay clear.
		HomeUI.box(_panel, Vector3(0.68, 0.2, 0.025), Vector3(0, 0.185, -0.05), HomeUI.INK)
		HomeUI.button(_panel, &"menu_back", "Menu", "Back to the game menu.", Vector3(-0.24, 0.2, 0), "back")
		HomeUI.button(_panel, &"menu_resume", "Practice", "Return to your game.", Vector3(-0.08, 0.2, 0), "▶")
		HomeUI.button(_panel, &"home_shop", "Shop", "Shop. Spend your magic stones here.", Vector3(0.08, 0.2, 0), "stone")
		HomeUI.button(_panel, &"home_box", "My things", "Your things. Pinch to open the box. Hold furniture and pinch here to put it away.", Vector3(0.24, 0.2, 0), "box")
		return
	# The shop is taller: its pages run along the top.
	var tall := 0.085 if page in CONFIRM else 0.0
	HomeUI.box(_panel, Vector3(0.68, 0.53 + tall, 0.025), Vector3(0, tall * 0.5, -0.05), HomeUI.INK)
	if page == &"menu":
		HomeUI.label(_panel, "MENU", Vector3(0, 0.10, 0), 44)
		var buttons := [
			[&"menu_resume", "Practice", "Return to your game.", "▶"],
			[&"menu_games", "Games", "Choose a game. Finish it to earn magic stones.", "◎"]]
		if App.module(&"Inventory") and App.module(&"Rooms"):
			buttons.append([&"menu_room", "My room", "Visit your room and shop.", "house"])
		for i in buttons.size():
			var entry: Array = buttons[i]
			HomeUI.button(_panel, entry[0], entry[1], entry[2], Vector3((i - (buttons.size() - 1) * 0.5) * 0.22, 0, 0.02), entry[3])
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
	if page in CONFIRM:
		HomeUI.button(_panel, &"home_back", "My room", "Back to your room.", Vector3(-0.265, 0.28, 0), "back")
		HomeUI.stones(_panel, balance, Vector3(-0.25, 0.15, 0))
		var column := 0
		for tab: Array in TABS:
			if tab[0] == &"pets" and App.module(&"Pets") == null: continue
			var button := HomeUI.button(_panel, StringName("home_tab_" + tab[0]), tab[1], tab[2], Vector3(-0.07 + column * 0.16, 0.28, 0.02), tab[3])
			# A gold frame marks the page that is open.
			if tab[0] == page: HomeUI.box(button, Vector3(0.139, 0.129, 0.012), Vector3(0, 0, -0.008), HomeUI.GOLD)
			column += 1
	elif page == &"bag":
		HomeUI.label(_panel, "MY THINGS", Vector3(0, 0.225, 0), 32)
		HomeUI.button(_panel, &"home_back", "My room", "Back to your room.", Vector3(-0.265, 0.21, 0), "back")
		if _catalogue().is_empty(): return
	else:
		HomeUI.label(_panel, "BUY?", Vector3(-0.04, 0.225, 0), 32)
		HomeUI.stones(_panel, balance, Vector3(0.12, 0.225, 0))
		HomeUI.button(_panel, &"home_confirm", "Buy", "Confirm this purchase.", Vector3(0.19, -0.19, 0.03), "check")
		HomeUI.button(_panel, &"home_cancel", "Cancel", "Go back without buying.", Vector3(-0.19, -0.19, 0.03), "cross")
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
		HomeUI.button(_panel, &"home_place", "Place", "Take this furniture out of your box.", Vector3(0, -0.19, 0.04), "↓")
	elif not _for_sale(item):
		if item.kind == ItemDef.Kind.ROOM:
			HomeUI.button(_panel, &"home_use_room", "Visit", "Visit this room.", Vector3(0, -0.19, 0.04), "door")
		else:
			HomeUI.check(_panel, Vector3(0, -0.15, 0.04), 1.2, HomeUI.GOLD)
	elif balance >= item.price:
		HomeUI.button(_panel, &"home_buy", "Buy", "Preview the purchase.", Vector3(0, -0.19, 0.04), "stone")


## Not in the box, and not a room or pet the child already has.
func _for_sale(item: ItemDef) -> bool:
	return page != &"bag" and (item.kind == ItemDef.Kind.FURNITURE or App.module(&"Inventory").count(item.id) == 0)


func _process(delta: float) -> void:
	_cooldown = maxf(0, _cooldown - delta)
	_update_entry()
	if _entry.visible:
		var eye := App.head().global_transform
		var goal := eye * ENTRY_VIEW_OFFSET
		var facing := Basis.looking_at(goal - eye.origin, Vector3.UP)   # its face (+z) toward the eye, kept level
		if _offscreen < 0.0 or _entry_frame.origin.distance_to(goal) > 0.4:
			_entry_frame = Transform3D(facing, goal)   # first frame, or a recentre: straight there
		else:
			var k := 1.0 - exp(-ENTRY_FOLLOW * delta)
			_entry_frame = Transform3D(_entry_frame.basis.orthonormalized().slerp(facing, k), _entry_frame.origin.lerp(goal, k))
		_offscreen = 0.0
		var slot := App.player_menu_slot()
		var in_header := slot != null
		# Draw above the panel backing only while the button is in its header.
		if _entry_face.no_depth_test != in_header:
			_entry_face.no_depth_test = in_header
			for text: Label3D in _entry.find_children("*", "Label3D", false, false):
				text.no_depth_test = in_header
		_entry.global_transform = slot.global_transform if slot else _entry_frame
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
