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
## Progress
##   this child's levels and check-ins (CheckIns) per skill: first and latest
##   check-in score, so staff see change at a glance; "Check-in next time" asks
##   for one before the next menu. The full report: python3 tools/progress.py.
## Vision (this child's profile, saved with them; see Vision)
##   left: the filter, from a preset then contrast, brightness, colour, dim,
##   spotlight, black and white, edges. Right: start from a profile preset,
##   object size, how soon help comes, time limits, difficulty for the skill
##   in play (a menu level's offset, or the staircase level), adaptive, reset.
##   Changes show at once and are logged; a block's own view still wins.
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
## Starting points for a child's profile, on the Vision page.
@export var vision_presets: Array[VisionPreset] = []

## Vision page filter rows: View field -> [step, lowest, highest].
const FILTER_STEPS := {
	&"contrast": [0.2, 0.4, 3.0],
	&"brightness": [10.0, -50.0, 50.0],
	&"saturation": [0.25, 0.0, 2.0],
	&"dim": [0.1, 0.0, 0.9],
	&"focus_radius": [0.05, 0.0, 0.6],
}
const EDGE_COLOUR := Color(1, 0.9, 0.2, 1)
## What a button says when aimed at, where its caption is a sign or a number
## (else it says its caption). Vision rows: "<field>_down" / "<field>_up".
const SPOKEN := {
	fac_prev = "Previous page", fac_next = "Next page", fac_new_save = "New save",
	fac_add_stones = "Add ten magic stones", fac_space = "Space",
	fac_v_filter_down = "Previous filter", fac_v_filter_up = "Next filter",
	fac_v_contrast_down = "Less contrast", fac_v_contrast_up = "More contrast",
	fac_v_brightness_down = "Darker", fac_v_brightness_up = "Brighter",
	fac_v_saturation_down = "Less colour", fac_v_saturation_up = "More colour",
	fac_v_dim_down = "Less dim", fac_v_dim_up = "More dim",
	fac_v_focus_radius_down = "Smaller spotlight", fac_v_focus_radius_up = "Bigger spotlight",
	fac_v_bw = "Black and white", fac_v_edges = "Edges",
	fac_v_preset_down = "Previous preset", fac_v_preset_up = "Next preset",
	fac_v_size_down = "Smaller things", fac_v_size_up = "Bigger things",
	fac_v_help_down = "Help sooner", fac_v_help_up = "Help later",
	fac_v_time_down = "Less time", fac_v_time_up = "More time",
	fac_v_level_down = "Easier", fac_v_level_up = "Harder",
	fac_v_adaptive = "Adaptive", fac_v_reset = "Reset to normal",
	fac_check_in = "Check-in next time",
}

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
var _progress := Label3D.new()
var _vision_status := Label3D.new()
var _vision_rows := Node3D.new()
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
	(_panel.get_node(^"fac_close") as UITarget).speech = "Menu" if from_menu else "Close"
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
		_close()
		Entry.go_to(StringName(String(target.id).trim_prefix("fac_scene_")))   # Megan, Nov 18: always through the workshop
		return
	if String(target.id).begins_with("fac_res_"):
		_results.press(target.id)
		_refresh_results()
		return
	if String(target.id).begins_with("fac_v_"):
		_adjust_vision(String(target.id).trim_prefix("fac_v_"))
		_refresh()
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
		&"fac_vision":
			_show(&"Vision")
		&"fac_progress":
			_show(&"Progress")
		&"fac_check_in":
			var check_ins := App.module(&"CheckIns") as CheckIns
			if check_ins:
				check_ins.ask()
		&"fac_saves", &"fac_cancel":
			_show(&"Saves")
		&"fac_prev", &"fac_next":
			_saves_page += -1 if target.id == &"fac_prev" else 1
		&"fac_new_save":
			_typed = ""
			_show(&"Naming")
		&"fac_fresh_start":
			Events.report(&"fresh_start", {from = String(Profile.id)})
			App.main.current_scene = &"intro"   # the save switch reloads this scene: the opening, from the hello
			_open_save(Profile.new_save())
			return
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
				if App.main.current_scene == &"first_visit":   # the hub: a fresh hub, its room rebuilt (Megan, Nov 18)
					_close()
					Entry.go_to(&"hub")
				else:
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
	_refresh_training()
	_refresh_vision()
	_refresh_progress()
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


func _refresh_vision() -> void:
	for child in _vision_rows.get_children():
		if child is Target:
			_disabled.erase(child)
		child.free()
	var view := Vision.view
	var session := App.session
	var block_view := session.block != null and not Vision.is_childs(App.reality.view)
	_vision_status.text = "%s · from %s · change %d%s" % [Profile.label(), Vision.preset if not Vision.preset.is_empty()
		else "nothing", Vision.revision, "\nThis block shows its own view: %s" % App.reality.view.title if block_view else ""]
	_vision_row("filter", "Filter: %s" % view.title, 0, 0, "<", ">")
	_vision_row("contrast", "Contrast %.1f" % view.contrast, 0, 1)
	_vision_row("brightness", "Brightness %+d" % roundi(view.brightness), 0, 2)
	_vision_row("saturation", "Colour %.2f" % view.saturation, 0, 3)
	_vision_row("dim", "Dim %.1f" % view.dim, 0, 4)
	_vision_row("focus_radius", "Spotlight %s" % ("off" if view.focus_radius <= 0.0 else "%d cm" % roundi(view.focus_radius * 100.0)), 0, 5)
	_vision_toggle("bw", "B&W " + ("on" if view.black_and_white else "off"), -0.165, 6)
	_vision_toggle("edges", "Edges " + ("on" if view.edges.a > 0.0 else "off"), -0.055, 6)

	_vision_row("preset", "Start: %s" % (Vision.preset if not Vision.preset.is_empty() else "-"), 1, 0, "<", ">")
	_vision_row("size", "Size x%.2f" % Vision.size_scale, 1, 1)
	_vision_row("help", "Help wait x%.2f" % Vision.help_scale, 1, 2)
	_vision_row("time", "Time x%.1f" % Vision.time_scale, 1, 3)
	if session.block == null:
		_vision_row("level", "Difficulty: no game", 1, 4, "-", "+", false)
	elif not session.on_staircase():
		_vision_row("level", "Offset %+.1f%s" % [Vision.offset(session.staircase()), _pinned_note()], 1, 4)
	else:
		_vision_row("level", "Level %.2f%s" % [Profile.level(session.staircase(), session.start_level()), _pinned_note()], 1, 4)
	_vision_toggle("adaptive", "Adaptive " + ("on" if Vision.adaptive else "off"), 0.11, 5, 0.2)
	_vision_toggle("reset", "Reset to normal", 0.11, 6, 0.2)


func _refresh_progress() -> void:
	var page := _pages[&"Progress"]
	_clear_buttons(page)
	var check_ins := App.module(&"CheckIns") as CheckIns
	var lines := ["%s   ·   levels finished: %d" % [Profile.label(), _levels_done()]]
	if check_ins == null:
		lines.append("Check-ins are switched off (no CheckIns module).")
	else:
		var latest: Dictionary = check_ins.history.back() if not check_ins.history.is_empty() else {}
		lines.append("Last check-in: %s" % ("none yet" if latest.is_empty() else "%s, %s%s" % [_when(int(latest.time)),
			latest.title, "" if latest.done else " (not finished)"]))
		if check_ins.asked():
			lines.append("A check-in comes before the next menu.")
		_enable(_button("fac_check_in", "Check-in next time", Vector2(0.22, 0.045), Vector2(0.0, -0.17), page), not check_ins.asked())
	lines.append("")
	var skills: Array[StringName] = Profile.skills()
	if check_ins:
		for skill in check_ins.skills():
			if not skill in skills:
				skills.append(skill)
	if skills.is_empty():
		lines.append("Nothing measured yet.")
	for skill in skills:
		var level := "level %.2f" % Profile.level(skill) if skill in Profile.skills() else "level -"
		var scores: Array[Dictionary] = []
		if check_ins:
			scores = check_ins.results(skill)
		var change := ""
		if scores.size() == 1:
			change = "check-in %d/%d" % [scores[0].right, scores[0].rounds]
		elif scores.size() > 1:
			change = "check-in %d/%d -> %d/%d" % [scores[0].right, scores[0].rounds, scores.back().right, scores.back().rounds]
		lines.append("%s:  %s   %s" % [CheckIns.skill_name(skill), level, change])
	_progress.text = "\n".join(lines)


func _levels_done() -> int:
	var count := 0
	for ids: Array in App.main.progress.done.values():
		count += ids.size()
	return count


func _pinned_note() -> String:
	return " (pinned)" if not is_nan(App.session.pinned) else ""


## A row of the Vision page: [param text] between a lower and a higher button.
func _vision_row(field: String, text: String, column: int, row: int, lower := "-", higher := "+", enabled := true) -> void:
	var x := -0.11 + 0.22 * column
	var y := 0.075 - 0.044 * row
	var label := Label3D.new()
	_text(label, Vector2(x, y), _vision_rows)
	label.font_size = 28
	label.text = text
	for side: Array in [["down", lower, -0.087], ["up", higher, 0.087]]:
		_enable(_button("fac_v_%s_%s" % [field, side[0]], side[1], Vector2(0.036, 0.038), Vector2(x + side[2], y), _vision_rows), enabled)


func _vision_toggle(action: String, text: String, x: float, row: int, width := 0.099) -> void:
	_button("fac_v_" + action, text, Vector2(width, 0.034), Vector2(x, 0.075 - 0.044 * row), _vision_rows)


## One press on the Vision page: "contrast_up", "bw", "reset"...
func _adjust_vision(action: String) -> void:
	var field := action.trim_suffix("_up").trim_suffix("_down")
	var direction := 1.0 if action.ends_with("_up") else -1.0
	var view: View = Vision.view.duplicate()
	match field:
		"filter":
			var titles := views.map(func(preset: View) -> String: return preset.title)
			Vision.set_view(views[posmod(titles.find(view.title) + int(direction), views.size())])
		"preset":
			var titles := vision_presets.map(func(preset: VisionPreset) -> String: return preset.label)
			Vision.use_preset(vision_presets[posmod(titles.find(Vision.preset) + int(direction), vision_presets.size())])
		"bw":
			view.black_and_white = not view.black_and_white
			_custom(view)
		"edges":
			view.edges = Color(0, 0, 0, 0) if view.edges.a > 0.0 else EDGE_COLOUR
			_custom(view)
		"size":
			Vision.set_size_scale(Vision.size_scale + 0.25 * direction)
		"help":
			Vision.set_help_scale(Vision.help_scale + 0.25 * direction)
		"time":
			Vision.set_time_scale(Vision.time_scale + 0.5 * direction)
		"level":
			var session := App.session
			if session.block == null:
				return
			var skill := session.staircase()
			if not session.on_staircase():
				Vision.set_offset(skill, Vision.offset(skill) + 0.1 * direction)
			else:
				Profile.set_level(skill, Profile.level(skill, session.start_level()) + 0.1 * direction, session.start_level())
		"adaptive":
			Vision.set_adaptive(not Vision.adaptive)
		"reset":
			Vision.reset()
		_:
			var limits: Array = FILTER_STEPS[StringName(field)]
			view.set(field, clampf(snappedf(view.get(field) + limits[0] * direction, 0.01), limits[1], limits[2]))
			_custom(view)


## The child's filter, edited by hand.
func _custom(view: View) -> void:
	view.title = "Custom"
	Vision.set_view(view)


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
	# Merge Nov 18: Megan's Scenes and Results tabs (Graphs chat), Wanchun's Vision and Progress; Wei's Model credits
	# sit on the Tools page. Eight tabs in one row across the panel.
	var tabs := [["fac_scenes", "Scenes"], ["fac_training", "Training"], ["fac_vision", "Vision"],
		["fac_progress", "Progress"], ["fac_saves", "Saves"], ["fac_results", "Results"], ["fac_tools", "Tools"],
		["fac_close", "Close"]]
	for i in tabs.size():
		var tab := _button(tabs[i][0], tabs[i][1], Vector2(0.05, 0.045),
			Vector2((i - (tabs.size() - 1) * 0.5) * 0.0525, 0.17), _panel)
		(tab.get_node(^"Caption") as Label3D).font_size = 24

	var scenes := _page(&"Scenes")
	_text(_scene_label, Vector2(0.0, 0.1), scenes)
	# Megan, Nov 18: the places in the workshop (Entry.PLACES), two columns; each goes through the opening's room, so
	# the cauldron, Onion and the gear are always there. Wei's own scenes are reached from his room.
	var places: Array = Entry.PLACES.keys()
	for i in places.size():
		_button("fac_scene_" + String(places[i]), Entry.PLACES[places[i]], Vector2(0.18, 0.055),
			Vector2(-0.095 + 0.19 * (i % 2), 0.032 - floori(i / 2.0) * 0.063), scenes)
	var row := ceili(places.size() / 2.0)
	# Megan, Nov 18: start over as a brand-new child, from the hello. A new save, so the current child's progress is
	# kept (it is still under Saves); never a wipe.
	_button("fac_fresh_start", "Restart: new player save", Vector2(0.38, 0.055), Vector2(0.0, 0.032 - row * 0.063 - 0.012), scenes)

	var training := _page(&"Training")
	_text(_status, Vector2(0.0, 0.1), training)

	var vision := _page(&"Vision")
	_text(_vision_status, Vector2(0.0, 0.122), vision)
	_vision_status.font_size = 26
	_vision_rows.name = "Rows"
	vision.add_child(_vision_rows)

	var progress := _page(&"Progress")
	_text(_progress, Vector2(0.0, 0.0), progress)
	_progress.font_size = 34
	_progress.line_spacing = 6.0
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_progress.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_progress.position = Vector3(-WIDTH * 0.5 + 0.02, 0.135, 0.0)

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
	# Save names are typed, so cannot be baked; the staff keyboard stays quiet too.
	var silent := id.begins_with("fac_slot_") or id.begins_with("fac_key_")
	button.speech = "" if silent else SPOKEN.get(StringName(id), text)
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
