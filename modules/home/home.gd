extends Module
## Persistent right-side home. Single-item browsing, explicit purchase confirmation.
## Training pauses, keeps its objects and resumes in the original real room.

var is_open := false
var page := &"home"
var _index := 0
var _entry: Target
var _panel := Node3D.new()
var _preview: Node3D
var _view: View
var _pending := false
var _cooldown := 0.0
var _hover: Target
var _hover_seconds := 0.0
var _anchor := Vector3.ZERO
var _offscreen := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_entry = HomeUI.button(App.rig, &"home_open", "Home", "Point at the little house and pinch to visit your room and shop.", Vector3.ZERO, "house")
	_panel.visible = false
	add_child(_panel)
	Events.selected.connect(_select)
	Events.scene_changing.connect(close)
	Events.facilitator_toggled.connect(func(open: bool) -> void:
		_entry.visible = not open
		_entry.collision_layer = 0 if open else Pointer.MENU_LAYER
		if open: close())
	Events.inventory_changed.connect(func() -> void:
		if is_open: _build.call_deferred())
	_anchor_entry.call_deferred()


func _anchor_entry() -> void:
	var eye := App.head().global_transform
	var forward := Vector3(-eye.basis.z.x, 0, -eye.basis.z.z).normalized()
	var frame := Basis.looking_at(forward)
	_entry.global_transform = Transform3D(frame, eye.origin + frame * Vector3(0.45, -0.12, -0.35))
	_anchor = eye.origin


func open() -> void:
	if is_open or App.main.switching: return
	if App.module(&"Inventory") == null or App.module(&"Rooms") == null:
		App.hold_pause(&"home", false)
		Events.say("The home is switched off.")
		return
	is_open = true
	App.hold_pause(&"home", true)
	App.main.show_activity(false)
	_view = App.reality.view
	App.reality.apply_view(View.new())
	Events.home_toggled.emit(true)
	var eye := App.head().global_transform
	var forward := Vector3(-eye.basis.z.x, 0, -eye.basis.z.z).normalized()
	_panel.global_transform = Transform3D(Basis.looking_at(forward).scaled(Vector3.ONE * 0.8), eye.origin + forward * 0.44 + Vector3.DOWN * 0.08)
	_panel.visible = true
	_show(&"home")
	Events.say("Your home. Point and pinch to choose furniture, rooms, or decorating.")


func close() -> void:
	if not is_open: return
	is_open = false
	Events.furniture_editing.emit(false)
	Events.home_toggled.emit(false)
	App.main.show_activity(true)
	App.reality.apply_view(_view)
	_panel.visible = false
	_clear_panel()
	App.hold_pause(&"home", false)
	_anchor_entry()
	Events.report(&"home_closed")


func _select(_hand: StringName, target: Target, _origin: Vector3, _direction: Vector3) -> void:
	if target == null or _pending or _cooldown > 0: return
	if target != _entry and not _panel.is_ancestor_of(target): return
	if App.main.switching: return
	# Pause synchronously so this same press cannot answer a trial.
	if target == _entry and not is_open: App.hold_pause(&"home", true)
	_pending = true
	_activate.call_deferred(target.id)


func _activate(id: StringName) -> void:
	_pending = false
	_cooldown = 0.3
	Events.report(&"home_action", {button = id, page = page})
	match id:
		&"home_open":
			if is_open: close()
			else: open()
		&"home_close": close()
		&"home_back": _show(&"home")
		&"home_shop": _index = 0; _show(&"shop")
		&"home_rooms": _index = 0; _show(&"rooms")
		&"home_bag": _index = 0; _show(&"bag")
		&"home_games": _show(&"games")
		&"home_prev", &"home_next":
			_index = posmod(_index + (-1 if id == &"home_prev" else 1), _catalogue().size())
			_build(); _speak_item()
		&"home_buy":
			_show(&"confirm_room" if page == &"rooms" else &"confirm_item")
			Events.say("Point at the check mark and pinch to buy. Choose the arrow to go back.")
		&"home_cancel": _show(&"rooms" if page == &"confirm_room" else &"shop")
		&"home_confirm":
			var item := _item()
			if App.module(&"Inventory").buy(item.id):
				Events.say("It is yours!")
				Events.feedback.emit(&"good", _panel.global_position)
			else:
				Events.say("Earn more magic stones by finishing a game.")
			_show(&"rooms" if page == &"confirm_room" else &"shop")
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
		_:
			if String(id).begins_with("home_scene_"):
				var scene := StringName(String(id).trim_prefix("home_scene_"))
				close()
				App.main.change_scene(scene)


func _show(next: StringName) -> void:
	page = next
	Events.furniture_editing.emit(page == &"decorate")
	_build()
	if page in [&"shop", &"rooms", &"bag"]: _speak_item()
	if page == &"decorate": Events.say("Pinch to move furniture. Let go to place it. Hold it and point at the box with your other hand, then pinch to put it away.")


func _catalogue() -> Array[ItemDef]:
	var items := ItemDef.all(ItemDef.Kind.ROOM if page in [&"rooms", &"confirm_room"] else ItemDef.Kind.FURNITURE)
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
	Events.say("%s. %d magic stones." % [item.title, item.price])


func _clear_panel() -> void:
	_hover = null
	_preview = null
	for child in _panel.get_children(): child.free()


func _build() -> void:
	if not is_open: return
	_clear_panel()
	var inventory := App.module(&"Inventory")
	if page == &"decorate":
		# Move the controls to the side; the centre stays clear for furniture.
		HomeUI.button(_panel, &"home_back", "Back", "Back to the home menu.", Vector3(-0.27, 0.16, 0), "←")
		HomeUI.button(_panel, &"home_store", "Put away", "Hold the furniture, aim at this box with your other hand, and pinch.", Vector3(0.27, 0.12, 0), "bag")
		HomeUI.button(_panel, &"home_turn", "Turn", "Turn the furniture.", Vector3(0.27, -0.07, 0), "↻")
		HomeUI.button(_panel, &"home_bag", "My things", "Choose furniture from your bag.", Vector3(-0.27, -0.05, 0), "chair")
		return
	HomeUI.box(_panel, Vector3(0.68, 0.53, 0.025), Vector3(0, 0, -0.05), HomeUI.INK)
	HomeUI.label(_panel, "HOME     ◆ %d" % inventory.count(&"magic_stone"), Vector3(0, 0.225, 0), 32)
	HomeUI.button(_panel, &"home_close", "Return", "Return to your game.", Vector3(0.265, 0.21, 0), "×")
	if page != &"home": HomeUI.button(_panel, &"home_back", "Home", "Back to the home menu.", Vector3(-0.265, 0.21, 0), "←")
	if page == &"home":
		HomeUI.button(_panel, &"home_shop", "Furniture", "Shop for furniture.", Vector3(-0.15, 0.08, 0.02), "chair")
		HomeUI.button(_panel, &"home_rooms", "Rooms", "See rooms. You can buy a new room or visit one you own.", Vector3(0.15, 0.08, 0.02), "house")
		HomeUI.button(_panel, &"home_bag", "My things", "Put your furniture in your room.", Vector3(-0.15, -0.12, 0.02), "bag")
		HomeUI.button(_panel, &"home_games", "Games", "Choose a game. Finish it to earn magic stones.", Vector3(0.15, -0.12, 0.02), "▶")
	elif page == &"games":
		var i := 0
		for scene: StringName in Main.SCENES:
			HomeUI.button(_panel, StringName("home_scene_" + String(scene)), Main.SCENES[scene].title, Main.SCENES[scene].title,
				Vector3(-0.16 + (i % 2) * 0.32, 0.07 - (i / 2) * 0.20, 0.02), ["◎", "chair", "◎", "→"][i])
			i += 1
	else:
		if _catalogue().is_empty():
			HomeUI.button(_panel, &"home_shop", "Furniture", "Shop for furniture.", Vector3(-0.15, 0, 0.02), "chair")
			HomeUI.button(_panel, &"home_decorate", "My room", "Move the furniture in your room.", Vector3(0.15, 0, 0.02), "house")
			return
		_index = mini(_index, _catalogue().size() - 1)
		var item := _item()
		_preview = HomeUI.preview(_panel, item, Vector3(0, 0.04, 0.06), 0.20)
		HomeUI.label(_panel, item.title, Vector3(0, -0.08, 0.04), 32)
		HomeUI.stones(_panel, item.price, Vector3(0, -0.125, 0.04), inventory.count(&"magic_stone"))
		if page in [&"confirm_room", &"confirm_item"]:
			HomeUI.button(_panel, &"home_confirm", "Buy", "Confirm this purchase.", Vector3(0.19, -0.17, 0.03), "✓")
			HomeUI.button(_panel, &"home_cancel", "Cancel", "Go back without buying.", Vector3(-0.19, -0.17, 0.03), "←")
		else:
			HomeUI.button(_panel, &"home_prev", "Previous", "See the previous one.", Vector3(-0.25, 0.02, 0.04), "←")
			HomeUI.button(_panel, &"home_next", "Next", "See the next one.", Vector3(0.25, 0.02, 0.04), "→")
			if item.kind == ItemDef.Kind.ROOM and inventory.count(item.id) > 0:
				HomeUI.button(_panel, &"home_use_room", "Visit", "Visit this room.", Vector3(0, -0.19, 0.04), "house")
			elif page == &"bag":
				HomeUI.button(_panel, &"home_place", "Place", "Take this furniture out of your bag.", Vector3(0, -0.19, 0.04), "↓")
				HomeUI.button(_panel, &"home_decorate", "My room", "Move the furniture in your room.", Vector3(0.22, -0.17, 0.04), "house")
			else:
				HomeUI.button(_panel, &"home_buy", "Buy", "Preview the purchase.", Vector3(0, -0.19, 0.04), "bag")


func _process(delta: float) -> void:
	_cooldown = maxf(0, _cooldown - delta)
	if not is_instance_valid(_entry) or App.reality == null: return
	if not is_open and App.head().global_position.distance_to(_anchor) > 0.35: _anchor_entry()
	var toward := (_entry.global_position - App.head().global_position).normalized()
	_offscreen = _offscreen + delta if toward.dot(-App.head().global_basis.z) < 0.17 else 0.0
	if not is_open and _offscreen > 0.8:
		_anchor_entry()
		_offscreen = 0.0
	if _preview: _preview.rotation.y += delta * 0.18
	var near: Target
	for side in [&"left", &"right"]:
		var pointer := App.rig.pointer(side)
		if not pointer.tracked(): continue
		var target := pointer.aimed
		if target and (target == _entry or _panel.is_ancestor_of(target)):
			near = target
	if near != _hover:
		_hover = near
		_hover_seconds = 0
	elif near:
		var before := _hover_seconds
		_hover_seconds += delta
		if before < 0.6 and _hover_seconds >= 0.6: Events.say(near.get_meta(&"speech"))


func _exit_tree() -> void:
	App.hold_pause(&"home", false)
	if is_instance_valid(_entry): _entry.queue_free()
