class_name DevSkip
extends CanvasLayer
## DESKTOP ONLY (Megan, Nov 18): a "Skip ▸" button at the top of the window (and the N key) to move through the
## scenes fast while testing. Never on a headset, never in the tests or the picture tools. One press does the
## next useful thing:
##   * setup panel: Skip setup, then Start
##   * the opening (Scenes 1-6): the next part, played fast; after the reveal, into the hub (with its welcome)
##   * a game: every remaining round won (the shelf, the dots, the butterflies); Turn to fit: the go ends as a
##     full go (Megan, Nov 18 6:05: skip works in every game, for prototype testing). Either way the hub gives the
##     game's stones and opens the next game, as after a real one.
##   * Wei's room: back to the workshop
##   * the hub, menu closed: open it; menu open: the leading game (and in its own row, the recommended level)
##   * otherwise, Onion talking: cut the line

const NEXT_PART := {"1": &"touch", "2": &"emerge", "3": &"pickup", "4": &"place", "5": &"reveal"}

var _button: Button
var _finishing := false


## Adds the skip button once, on the desktop only.
static func ensure() -> void:
	if App.xr != null or App.main == null or App.main.get_node_or_null(^"DevSkip") != null:
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile=test"):
			return   # tests and picture tools: the window stays clean
	var skip := DevSkip.new()
	skip.name = "DevSkip"
	App.main.add_child(skip)


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_button = Button.new()
	_button.text = "Skip ▸   (N)"
	_button.focus_mode = Control.FOCUS_NONE   # a click never steals the keyboard
	_button.add_theme_font_size_override(&"font_size", 18)
	_button.anchor_left = 0.5
	_button.anchor_right = 0.5
	_button.offset_left = -70
	_button.offset_right = 70
	_button.offset_top = 8
	_button.offset_bottom = 44
	_button.pressed.connect(skip)
	add_child(_button)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_N:
		skip()
		get_viewport().set_input_as_handled()


## Does the next useful thing (see the top of this file).
func skip() -> void:
	if get_tree().paused:
		return
	var entry := App.main.find_child("Entry", true, false) as Entry
	var hub := App.main.find_child("WorkshopController", true, false) as WorkshopController
	var home := App.module(&"Home")
	if home != null and home.get(&"is_open"):
		home.close()
		_say("back to the workshop")
		return
	if hub != null:
		if hub.state == &"game" and App.session.running:
			_finish_rounds()
			return
		if hub.state == &"game" and finish_go(hub.current as TurnToFitActivity):
			_say("Turn to fit: the go finished")
			return
		if hub.state == &"hub" and not hub.ring.opened:
			Events.selected.emit(&"right", hub.cauldron_target, Vector3.ZERO, Vector3.FORWARD)
			_say("menu opened")
			return
		if hub.state == &"hub" and not hub.ring.turning:   # Megan, Nov 18: the next game (its recommended level)
			var piece: Impression = hub.row.leader() if hub.row != null and hub.row.opened else hub.ring.leader()
			if piece != null and not piece.sealed:
				Events.selected.emit(&"right", piece.target, Vector3.ZERO, Vector3.FORWARD)
				_say("chose " + String(piece.kind))
				return
	elif entry != null and is_instance_valid(entry):
		for id: StringName in [&"entry_skip_setup", &"entry_part_all"]:
			var target := entry.find_child(String(id), true, false) as Target
			if target != null and target.is_visible_in_tree():
				Events.selected.emit(&"right", target, target.global_position, Vector3.FORWARD)
				_say("setup skipped" if id == &"entry_skip_setup" else "start")
				return
		var beat := String(entry.beat)
		var number := beat.get_slice(":", 0)
		if number == "6":
			entry.call(&"_to_shelf", false)
			_say("into the hub")
			return
		if NEXT_PART.has(number):
			entry.jump_to(NEXT_PART[number])
			_say("next: " + String(NEXT_PART[number]))
			return
	var line_skip := App.main.get_node_or_null(^"LineSkip") as LineSkip
	if line_skip != null and line_skip.skip():
		_say("line cut")
		return
	_say("nothing to skip here")


## Ends Turn to fit's go now, as a full go ("done": the hub gives its stones). False if no go is running.
static func finish_go(activity: TurnToFitActivity) -> bool:
	if activity == null or activity.current == null or not is_instance_valid(activity.current):
		return false
	var game := activity.current
	if game.get(&"_ending") or game.go == null:
		return false
	game.call(&"_end")
	return true


func _finish_rounds() -> void:
	if _finishing:
		return
	_finishing = true
	_say("winning the rounds")
	Engine.time_scale = 3.0
	while App.session.running:
		if App.session.trial != null and App.session.trial.is_running():
			App.session.trial.finish(true)
		await get_tree().process_frame
	Engine.time_scale = 1.0
	_finishing = false


func _say(what: String) -> void:
	print("DEV SKIP: ", what)
	_button.tooltip_text = what
