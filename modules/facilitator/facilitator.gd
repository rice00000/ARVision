extends Module
## The facilitator's panel, hidden from the child: the left-hand menu pinch
## (palm facing you, pinch) opens and closes it (desktop: M), and play pauses
## while it is open. Point and pinch to press a button. Two tabs, as in XRVision:
##
## Training
##   Easier / Harder   pin the level 0.1 lower / higher for the rest of the session
##   Auto level        back to the child's staircase
##   Next view         the next view preset, until the next block starts
##   Skip block        drop the running round unscored and move on
## Saves
##   every save, the one playing then the newest played first, a page at a
##   time: press one to play it.
##   + New save names one with an on-panel keyboard: Start fresh plays a new
##   game, Copy this save keeps a checkpoint of this one. See Profile.

const PAGE_SIZE := 4
const KEYS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
const KEY_COLUMNS := 9
const NAME_LENGTH := 20
const WIDTH := 0.44
const HEIGHT := 0.42

## Presets "Next view" cycles through.
@export var views: Array[View] = []

var is_open := false

var _panel := Node3D.new()
## Page name -> its node; only the page shown is in the tree, so the others cannot be pressed.
var _pages: Dictionary[StringName, Node3D] = {}
var _page_shown: StringName = &"Training"
var _status := Label3D.new()
var _playing := Label3D.new()
var _page_label := Label3D.new()
var _name := Label3D.new()
var _slots := Node3D.new()
var _disabled: Dictionary[Target, bool] = {}
var _view_index := 0
var _saves_page := 0
var _typed := ""
var _face := _material(Color(0.25, 0.3, 0.42))
var _greyed := _material(Color(0.16, 0.17, 0.2))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Events.button.connect(func(hand: StringName, action: StringName, pressed: bool) -> void:
		if hand == &"left" and action == &"menu_pressed" and pressed:
			toggle())
	Events.selected.connect(_on_selected)


func _exit_tree() -> void:
	for page: Node3D in _pages.values():
		if page.get_parent() == null:
			page.free()
	if is_open:
		App.hold_pause(&"facilitator", false) # the panel goes with this node
	else:
		_panel.free()


func toggle() -> void:
	is_open = not is_open
	if is_open:
		var eye := App.head().global_transform
		var forward := Vector3(-eye.basis.z.x, 0.0, -eye.basis.z.z).normalized()
		add_child(_panel)
		_panel.global_transform = Transform3D(Basis.looking_at(forward), eye.origin + forward * 0.55 + Vector3.DOWN * 0.12)
		_refresh()
	else:
		remove_child(_panel)
	App.hold_pause(&"facilitator", is_open)
	Events.facilitator_toggled.emit(is_open)


func _on_selected(_hand: StringName, target: Target, _origin: Vector3, _direction: Vector3) -> void:
	if not is_open or target == null or not _panel.is_ancestor_of(target) or _disabled.get(target, false):
		return
	if App.session.block == null and target.id in [&"fac_easier", &"fac_harder", &"fac_skip"]:
		return # nothing running to steer
	Events.report(&"facilitator", {button = target.id})
	if String(target.id).begins_with("fac_key_"):
		_type(String(target.id).right(1))
		return
	if String(target.id).begins_with("fac_slot_"):
		_open_save(StringName(String(target.id).trim_prefix("fac_slot_")))
		return
	match target.id:
		&"fac_easier":
			App.session.nudge(-0.1)
		&"fac_harder":
			App.session.nudge(0.1)
		&"fac_auto":
			App.session.unpin()
		&"fac_view":
			_view_index = (_view_index + 1) % views.size()
			App.reality.apply_view(views[_view_index])
		&"fac_skip":
			App.session.skip_block()
		&"fac_training":
			_show(&"Training")
		&"fac_saves", &"fac_cancel":
			_show(&"Saves")
		&"fac_prev", &"fac_next":
			_saves_page += -1 if target.id == &"fac_prev" else 1
		&"fac_new_save":
			_typed = ""
			_show(&"Naming")
		&"fac_space":
			_type(" ")
		&"fac_erase":
			_typed = _typed.left(-1)
		&"fac_create":
			_open_save(Profile.new_save(_typed.strip_edges()))
			return
		&"fac_copy":
			Save.write()
			Profile.copy(_typed.strip_edges())
			_show(&"Saves")
		&"fac_close":
			toggle.call_deferred() # after this press has reached every listener: a trial must not take it as an answer
			return
	_refresh()


## Closes the panel and plays [param save]: the game starts again from it.
func _open_save(save: StringName) -> void:
	toggle.call_deferred()
	Profile.switch(save)


func _type(text: String) -> void:
	if _typed.length() < NAME_LENGTH:
		_typed += text
	_refresh()


func _show(page: StringName) -> void:
	_panel.remove_child(_pages[_page_shown])
	_page_shown = page
	_panel.add_child(_pages[page])


func _refresh() -> void:
	_refresh_training()
	_refresh_saves()
	_name.text = "Name: %s_" % _typed


func _refresh_training() -> void:
	var session := App.session
	if session.block == null:
		_status.text = "No block running"
		return
	_status.text = "Block %d / %d: %s\nLevel %.2f %s\nView: %s" % [session.block_index + 1,
		session.plan.blocks.size(), session.block.trial.title, session.level(),
		"(pinned)" if not is_nan(session.pinned) else "(auto)", App.reality.view.title]


func _refresh_saves() -> void:
	_playing.text = "Playing: %s" % Profile.label()
	var played := {}
	for save in Profile.saves():
		played[save] = Profile.played(save)
	var saves: Array = played.keys()
	saves.sort_custom(func(a: StringName, b: StringName) -> bool:
		return a == Profile.id or (b != Profile.id and played[a] > played[b]))
	var pages := maxi(1, ceili(saves.size() / float(PAGE_SIZE)))
	_saves_page = clampi(_saves_page, 0, pages - 1)
	for row in _slots.get_children():
		_disabled.erase(row)
		row.free()
	var shown := saves.slice(_saves_page * PAGE_SIZE, (_saves_page + 1) * PAGE_SIZE)
	for i in shown.size():
		var save: StringName = shown[i]
		var playing := save == Profile.id
		var row := _button("fac_slot_%s" % save, "%s   ·   %s" % [Profile.label(save),
			"Playing now" if playing else _when(played[save])], Vector2(WIDTH - 0.04, 0.045), Vector2(0.0, 0.07 - 0.055 * i), _slots)
		_enable(row, not playing)
	_page_label.text = "Page %d / %d" % [_saves_page + 1, pages]
	_enable(_pages[&"Saves"].get_node(^"fac_prev"), _saves_page > 0)
	_enable(_pages[&"Saves"].get_node(^"fac_next"), _saves_page < pages - 1)


## Local date and time of a save's last write: "2026-10-15 14:32".
func _when(time: int) -> String:
	if time == 0:
		return "Not played yet"
	var bias: int = Time.get_time_zone_from_system().bias
	return Time.get_datetime_string_from_unix_time(time + bias * 60, true).left(16)


func _build() -> void:
	_panel.name = "FacilitatorPanel"
	var back := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(WIDTH, HEIGHT)
	quad.material = _material(Color(0.08, 0.09, 0.12))
	back.mesh = quad
	back.position = Vector3(0.0, 0.0, -0.012)
	_panel.add_child(back)
	var tab_x := [-0.145, 0.0, 0.145]
	for i in 3:
		_button(["fac_training", "fac_saves", "fac_close"][i], ["Training", "Saves", "Close"][i],
			Vector2(0.13, 0.05), Vector2(tab_x[i], 0.17), _panel)

	var training := _page(&"Training")
	_text(_status, Vector2(0.0, 0.1), training)
	var actions := [["fac_easier", "Easier"], ["fac_harder", "Harder"], ["fac_auto", "Auto level"],
		["fac_view", "Next view"], ["fac_skip", "Skip block"]]
	for i in actions.size():
		_button(actions[i][0], actions[i][1], Vector2(0.18, 0.06), Vector2(-0.095 + 0.19 * (i % 2), 0.02 - 0.075 * floori(i / 2.0)), training)

	var saves := _page(&"Saves")
	_text(_playing, Vector2(0.0, 0.115), saves)
	_slots.name = "Slots"
	saves.add_child(_slots)
	_button("fac_prev", "<", Vector2(0.05, 0.05), Vector2(-0.185, -0.17), saves)
	_text(_page_label, Vector2(-0.1, -0.17), saves)
	_button("fac_next", ">", Vector2(0.05, 0.05), Vector2(-0.015, -0.17), saves)
	_button("fac_new_save", "+ New save", Vector2(0.17, 0.05), Vector2(0.125, -0.17), saves)

	var naming := _page(&"Naming")
	_text(_name, Vector2(0.0, 0.115), naming)
	var pitch := (WIDTH - 0.03) / KEY_COLUMNS
	for i in KEYS.length():
		_button("fac_key_" + KEYS[i], KEYS[i], Vector2(pitch - 0.006, 0.04),
			Vector2(pitch * (i % KEY_COLUMNS - (KEY_COLUMNS - 1) * 0.5), 0.065 - 0.046 * floori(i / float(KEY_COLUMNS))), naming)
	var edits := [["fac_space", "Space"], ["fac_erase", "Delete"], ["fac_cancel", "Cancel"]]
	for i in edits.size():
		_button(edits[i][0], edits[i][1], Vector2(0.13, 0.045), Vector2(-0.145 + 0.145 * i, -0.13), naming)
	_button("fac_create", "Start fresh", Vector2(0.2, 0.045), Vector2(-0.105, -0.183), naming)
	_button("fac_copy", "Copy this save", Vector2(0.2, 0.045), Vector2(0.105, -0.183), naming)
	_panel.add_child(_pages[_page_shown])


func _page(page: StringName) -> Node3D:
	var node := Node3D.new()
	node.name = String(page)
	_pages[page] = node
	return node


func _text(label: Label3D, at: Vector2, parent: Node3D) -> void:
	label.position = Vector3(at.x, at.y, 0.0)
	label.pixel_size = 0.0004
	label.font_size = 40
	parent.add_child(label)


func _button(id: String, text: String, size: Vector2, at: Vector2, parent: Node3D) -> Target:
	var button := Target.new()
	button.id = StringName(id)
	button.name = id
	button.position = Vector3(at.x, at.y, 0.0)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(size.x, size.y, 0.02)
	button.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.name = "Face"
	mesh.mesh = BoxMesh.new()
	(mesh.mesh as BoxMesh).size = Vector3(size.x, size.y, 0.01)
	mesh.material_override = _face
	button.add_child(mesh)
	var label := Label3D.new()
	label.text = text
	label.pixel_size = 0.0004
	label.font_size = 40 if size.y < 0.05 else 48
	label.position.z = 0.006
	button.add_child(label)
	parent.add_child(button)
	return button


## A button that cannot be pressed looks sunk and grey.
func _enable(button: Target, on: bool) -> void:
	_disabled[button] = not on
	(button.get_node(^"Face") as MeshInstance3D).material_override = _face if on else _greyed


static func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	return material
