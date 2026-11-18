extends Module
## The facilitator's panel opens from Menu → Staff tools or the left-hand
## menu pinch (desktop: M). Play pauses while it is open.
## Saves manages profiles. Tools holds developer actions.
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
## Results (Graphs chat, Nov 17)
##   the dots game's rounds as three graphs, one at a time (modules/results/results_view.gd):
##   Rounds / Time / Coherence; This visit or All visits; Showing: Play, Pinned level, Dev or
##   Older logs, never pooled. For the adult only: describes, never diagnoses.

const PAGE_SIZE := 4
const KEYS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
const KEY_COLUMNS := 9
const NAME_LENGTH := 20
const WIDTH := 0.44
const HEIGHT := 0.42
## Polish V6: the whole staff panel 20 % bigger (its text was ~1.1 deg tall at 0.55 m; now ~1.4 deg).
const PANEL_SCALE := 1.2

## Presets "Next view" cycles through.
@export var views: Array[View] = []

var _scene_label := Label3D.new()
var is_open := false

var _panel := Node3D.new()
## Page name -> its node; only the page shown is in the tree, so the others cannot be pressed.
var _pages: Dictionary[StringName, Node3D] = {}
var _page_shown: StringName = &"Training"
var _from_menu := false
var _status := Label3D.new()
var _intro_status := Label3D.new()
var _confirm_label := Label3D.new()
var _confirmed_action: StringName
var _pending: Target
var _playing := Label3D.new()
var _page_label := Label3D.new()
var _name := Label3D.new()
var _slots := Node3D.new()
var _disabled: Dictionary[Target, bool] = {}
var _view_index := 0
var _saves_page := 0
var _typed := ""
var _face := _material(UIStyle.STAFF_BUTTON)   # polish V5: the grown-up look (core/ui_style.gd)
var _greyed := _material(UIStyle.STAFF_DISABLED)
## Results tab: the graph shown and its "you are here" button colour.
var _results := ResultsView.new()
var _chosen := _material(UIStyle.STAFF_PRIMARY)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Events.button.connect(func(hand: StringName, action: StringName, pressed: bool) -> void:
		if hand == &"left" and action == &"menu_pressed" and pressed:
			toggle())
	Events.selected.connect(_on_selected)
	Events.staff_tools_requested.connect(_open.bind(true))
	Events.scene_changing.connect(_close)


func _exit_tree() -> void:
	for page: Node3D in _pages.values():
		if page.get_parent() == null:
			page.free()
	if is_open:
		App.hold_pause(&"facilitator", false) # the panel goes with this node
	else:
		_panel.free()


func toggle() -> void:
	if App.main.switching:
		return
	if is_open:
		_close()
		return
	_open(false)


func _open(from_menu: bool) -> void:
	if is_open or App.main.switching: return
	is_open = true
	_from_menu = from_menu
	App.hold_pause(&"facilitator", true)
	Events.facilitator_toggled.emit(true)
	if App.results_after_closing:   # Scene 10: after a closing, Results first (End session is there)
		App.results_after_closing = false
		_show(&"Results")
		_results.reload()
	elif from_menu and _page_shown != &"Tools": _show(&"Tools")
	(_panel.get_node(^"fac_close/Caption") as Label3D).text = "Menu" if from_menu else "Close"
	var eye := App.head().global_transform
	var forward := Vector3(-eye.basis.z.x, 0.0, -eye.basis.z.z).normalized()
	add_child(_panel)
	_panel.global_transform = Transform3D(Basis.looking_at(forward).scaled(Vector3.ONE * PANEL_SCALE),
		eye.origin + forward * 0.55 + Vector3.DOWN * 0.08)   # polish V6: a little higher, so the bigger panel fits the view
	_refresh()


func _close(return_to_menu := false) -> void:
	if not is_open: return
	is_open = false
	_pending = null
	if _page_shown == &"Confirm": _show(&"Tools")
	remove_child(_panel)
	if return_to_menu: Events.player_menu_requested.emit()
	App.hold_pause(&"facilitator", false)
	Events.facilitator_toggled.emit(false)


func _on_selected(_hand: StringName, target: Target, _origin: Vector3, _direction: Vector3) -> void:
	if not is_open or App.main.switching or _pending or target == null or not _panel.is_ancestor_of(target) or _disabled.get(target, false):
		return
	_pending = target
	_activate.call_deferred()


func _activate() -> void:
	var target := _pending
	_pending = null
	if not is_instance_valid(target): return
	Events.report(&"facilitator", {button = target.id})
	if String(target.id).begins_with("fac_key_"):
		_type(String(target.id).right(1))
		return
	if String(target.id).begins_with("fac_slot_"):
		_open_save(StringName(String(target.id).trim_prefix("fac_slot_")))
		return
	if String(target.id).begins_with("fac_scene_"):
		_view_index = 0
		App.main.change_scene(StringName(String(target.id).trim_prefix("fac_scene_")))
		return
	if String(target.id).begins_with("fac_res_"):
		_results.press(target.id)
		_refresh_results()
		return
	if String(target.id).begins_with("fac_jump_"):
		_close()
		Events.intro_jump_requested.emit(StringName(String(target.id).trim_prefix("fac_jump_")))
		return
	match target.id:
		&"fac_mode":
			PlayMode.toggle("staff tools")
			_refresh_tools()
			print("ENTRY mode: ", PlayMode.name(), " (staff tools)")
		&"fac_scenes":
			_show(&"Scenes")
		&"fac_credits":
			_show(&"Credits")
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
		&"fac_results":
			_show(&"Results")
			_results.reload()   # the logs as they are now
			_refresh_results()
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
			_close(_from_menu)
			return
		&"fac_tools":
			_show(&"Tools")
		&"fac_cancel_tool":
			_show(&"Results" if _confirmed_action == &"fac_end_session" else &"Tools")
		&"fac_add_stones":
			App.module(&"Inventory").add(&"magic_stone", 10)
		&"fac_zones":
			_close()
			Events.intro_zones_requested.emit()
			return
		&"fac_room_intro":
			_close()
			Events.room_intro_requested.emit()
			return
		&"fac_restart", &"fac_exit", &"fac_redo_setup", &"fac_end_session":
			_confirmed_action = target.id
			_confirm_label.text = {fac_restart = "Restart this scene?", fac_exit = "Exit ARVision?",
					fac_redo_setup = "Redo setup?\nThe opening starts again.",
					fac_end_session = "End this session?\nARVision closes."}[String(target.id)]
			_show(&"Confirm")
		&"fac_confirm_tool":
			Save.write()
			if _confirmed_action == &"fac_restart":
				_view_index = 0
				App.main.restart()
			elif _confirmed_action == &"fac_redo_setup":   # Megan, Nov 17: the layout turned out bad mid-session
				_view_index = 0
				_close()
				Entry.redo_next = true
				if App.main.current_scene == &"intro":
					App.main.restart()
				else:
					App.main.change_scene(&"intro")
			else:
				if _confirmed_action == &"fac_end_session":   # Scene 10: the grown-up ends it here
					Events.report(&"session_ended", {by = "staff_results"})
				get_tree().quit()
			return
	_refresh()


## Closes the panel and plays [param save]: the game starts again from it.
func _open_save(save: StringName) -> void:
	_close()
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
	_scene_label.text = "Current: %s" % Main.SCENES[App.main.current_scene].title
	for id: StringName in Main.SCENES:
		if Main.SCENES[id].get("listed", true):
			_enable(_pages[&"Scenes"].get_node("fac_scene_" + String(id)), id != App.main.current_scene)
	_refresh_training()
	_refresh_saves()
	_refresh_results()
	_name.text = "Name: %s_" % _typed
	_refresh_tools()


func _refresh_tools() -> void:
	var intro := App.main.intro()
	var tools := _pages[&"Tools"]
	_clear_buttons(tools)
	var can_jump := intro != null and intro.tools_ready
	_intro_status.text = "Intro: " + intro.beat if can_jump else "Tools"
	var actions := []
	if can_jump:
		for part: String in Entry.PARTS:
			actions.append(["fac_jump_" + part, Entry.PARTS[part]])
	actions.append(["fac_room_intro", "Room intro"])
	actions.append(["fac_mode", "Mode: " + PlayMode.name()])   # Megan, Nov 10
	if can_jump:
		actions.append(["fac_redo_setup", "Redo setup"])   # scene review, Nov 17
	if App.module(&"Inventory"):
		actions.append(["fac_add_stones", "+10 Magic Stones"])
	for i in actions.size():
		var column := -0.095 + 0.19 * (i % 2) if can_jump else 0.0
		var row := floori(i / 2.0) if can_jump else i
		_button(actions[i][0], actions[i][1], Vector2(0.18, 0.032),
			Vector2(column, 0.065 - 0.038 * row), tools)
	var zones := can_jump and intro.zones_available()
	if zones:
		_button("fac_zones", "Zones", Vector2(0.095, 0.045), Vector2(-0.153, -0.16), tools)
	_button("fac_restart", "Restart scene", Vector2(0.154, 0.045), Vector2(-0.022 if zones else -0.095, -0.16), tools)
	_button("fac_exit", "Exit app", Vector2(0.12, 0.045), Vector2(0.127 if zones else 0.095, -0.16), tools)
	if not can_jump:
		_button("fac_credits", "Model credits", Vector2(0.18, 0.038), Vector2(0, -0.015), tools)


func _refresh_training() -> void:
	var session := App.session
	var training := _pages[&"Training"]
	_clear_buttons(training)
	var actions := [["fac_view", "Next view"]]
	if session.block != null:
		actions = [["fac_easier", "Easier"], ["fac_harder", "Harder"], ["fac_auto", "Auto level"],
			["fac_view", "Next view"], ["fac_skip", "Skip block"]]
	for i in actions.size():
		_button(actions[i][0], actions[i][1], Vector2(0.18, 0.06),
			Vector2(-0.095 + 0.19 * (i % 2) if actions.size() > 1 else 0.0, 0.02 - 0.075 * floori(i / 2.0)), training)
	if session.block == null:
		_status.text = "No block running"
		return
	_status.text = "Block %d / %d: %s\nLevel %.2f %s\nView: %s" % [session.block_index + 1,
		session.plan.blocks.size(), session.block.trial.title, session.level(),
		"(pinned)" if not is_nan(session.pinned) else "(auto)", App.reality.view.title]


func _clear_buttons(page: Node3D) -> void:
	for child in page.get_children():
		if child is Target:
			_disabled.erase(child)
			child.free()


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


## Results tab: captions and which graph button is lit.
func _refresh_results() -> void:
	var page := _pages[&"Results"]
	for id: StringName in ResultsView.GRAPHS:
		var button: Target = page.get_node(String(id))
		if ResultsView.GRAPHS[id] == &"coherence":
			button.visible = _results.has_coherence()   # hub review: hidden until 2+ levels
			button.collision_layer = Pointer.MENU_LAYER if button.visible else 0
		(button.get_node(^"Face") as MeshInstance3D).material_override = \
			_chosen if ResultsView.GRAPHS[id] == _results.graph_kind else _face
	(page.get_node(^"fac_res_scope/Caption") as Label3D).text = _results.scope_caption()
	(page.get_node(^"fac_res_group/Caption") as Label3D).text = _results.group_caption()
	_enable(page.get_node(^"fac_res_task"), _results.has_more_tasks())


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
	quad.material = _material(UIStyle.STAFF_PANEL, 20)
	back.mesh = quad
	back.position = Vector3(0.0, 0.0, -0.012)
	_panel.add_child(back)
	# Merge Nov 18: Megan's Scenes and Results tabs (Graphs chat); Wei's Model credits sit on the Tools page.
	var tabs := [["fac_scenes", "Scenes"], ["fac_training", "Training"], ["fac_saves", "Saves"],
		["fac_results", "Results"], ["fac_tools", "Tools"], ["fac_close", "Close"]]
	for i in tabs.size():
		_button(tabs[i][0], tabs[i][1], Vector2(0.068, 0.045), Vector2(-0.18 + i * 0.072, 0.17), _panel)

	var scenes := _page(&"Scenes")
	_text(_scene_label, Vector2(0.0, 0.1), scenes)
	var row := 0
	for id: StringName in Main.SCENES:
		if not Main.SCENES[id].get("listed", true):
			continue   # reached only through another scene (the first visit, through the Intro)
		_button("fac_scene_" + String(id), Main.SCENES[id].title, Vector2(0.38, 0.055),
			Vector2(0.0, 0.032 - row * 0.063), scenes)
		row += 1

	var training := _page(&"Training")
	_text(_status, Vector2(0.0, 0.1), training)

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

	var tools := _page(&"Tools")
	_text(_intro_status, Vector2(0, 0.11), tools)

	var results := _page(&"Results")
	var graphs := [["fac_res_rounds", "Rounds"], ["fac_res_time", "Time"], ["fac_res_coherence", "Coherence"]]
	for i in graphs.size():   # hub review: a little narrower, so End session fits on the row
		_button(graphs[i][0], graphs[i][1], Vector2(0.1, 0.042), Vector2(-0.165 + 0.105 * i, 0.118), results)
	_button("fac_end_session", "End session", Vector2(0.11, 0.042), Vector2(0.16, 0.118), results)
	_results.position = Vector3(0.0, -0.02, 0.0)
	results.add_child(_results)
	_button("fac_res_scope", "This visit", Vector2(0.15, 0.042), Vector2(-0.135, -0.168), results)
	_button("fac_res_group", "Showing: Play", Vector2(0.17, 0.042), Vector2(0.035, -0.168), results)
	_button("fac_res_task", "Next task", Vector2(0.09, 0.042), Vector2(0.165, -0.168), results)
	var credits := _page(&"Credits")
	var attribution := Label3D.new()
	_text(attribution, Vector2(0, -0.01), credits)
	attribution.font_size = 22
	attribution.text = "STUDY DESK MODELS\n\nNotebook + Pencil by Poly by Google\nCC BY 3.0, via Poly Pizza\npoly.pizza/m/aXVPyk0zekf\npoly.pizza/m/3Sd2klX0_s4\ncreativecommons.org/licenses/by/3.0/\nRescaled, rotated, grouped; outlines derived.\n\nMug: Kenney / Headphones: CreativeTrio (CC0)\nStudent, chair, plant: Quaternius (CC0)\nWood: Rob Tuytel, Poly Haven (CC0)"

	var confirm := _page(&"Confirm")
	_text(_confirm_label, Vector2(0, 0.06), confirm)
	_button("fac_cancel_tool", "Cancel", Vector2(0.16, 0.05), Vector2(-0.09, -0.045), confirm)
	_button("fac_confirm_tool", "Confirm", Vector2(0.16, 0.05), Vector2(0.09, -0.045), confirm)
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
	label.no_depth_test = true
	label.render_priority = 23
	label.outline_render_priority = 22
	parent.add_child(label)


func _button(id: String, text: String, size: Vector2, at: Vector2, parent: Node3D) -> Target:
	var button := UITarget.new()
	button.id = StringName(id)
	button.name = id
	button.collision_layer = Pointer.MENU_LAYER
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
	label.name = "Caption"
	label.text = text
	label.pixel_size = 0.0004
	label.font_size = 34 if size.x < 0.1 else (40 if size.y < 0.05 else 48)
	label.position.z = 0.006
	label.no_depth_test = true
	label.render_priority = 23
	label.outline_render_priority = 22
	button.add_child(label)
	parent.add_child(button)
	return button


## A button that cannot be pressed looks sunk and grey.
func _enable(button: Target, on: bool) -> void:
	_disabled[button] = not on
	button.collision_layer = Pointer.MENU_LAYER if on else 0
	(button.get_node(^"Face") as MeshInstance3D).material_override = _face if on else _greyed


static func _material(colour: Color, priority := 21) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.render_priority = priority
	material.albedo_color = colour
	return material
