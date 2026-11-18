extends Module
## Sound effects by name: [code]Events.play(&"place", at)[/code] plays a cue from where it happens,
## and a cue with no place plays flat (menus, scene changes, My room). Cues with several takes
## (name_1.ogg, name_2.ogg...) never repeat the same take twice in a row; handled things also vary
## their pitch a little, so nothing sounds machine-made. Built by tools/sound/design.py from the
## team's library, tonal ones in C major like the piano. Delete the node to unplug it.
##
## Mix: everything here runs on the SFX bus, under the voice and over the music.
## The feedback chimes are Feedback's, the piano is Music's.

const CUES := {
	ui_hover = [preload("cues/ui_hover.ogg")],
	ui_press = [preload("cues/ui_press_1.ogg"), preload("cues/ui_press_2.ogg")],
	menu_open = [preload("cues/menu_open.ogg")],
	menu_close = [preload("cues/menu_close.ogg")],
	transition = [preload("cues/transition.ogg")],
	room_enter = [preload("cues/room_enter.ogg")],
	room_exit = [preload("cues/room_exit.ogg")],
	grab = [preload("cues/grab_1.ogg"), preload("cues/grab_2.ogg"), preload("cues/grab_3.ogg")],
	place = [preload("cues/place_1.ogg"), preload("cues/place_2.ogg"), preload("cues/place_3.ogg"),
		preload("cues/place_4.ogg")],
	slide = [preload("cues/slide_1.ogg"), preload("cues/slide_2.ogg")],
	drop = [preload("cues/drop_1.ogg"), preload("cues/drop_2.ogg"), preload("cues/drop_3.ogg"),
		preload("cues/drop_4.ogg")],
	swish = [preload("cues/swish_1.ogg"), preload("cues/swish_2.ogg"), preload("cues/swish_3.ogg")],
	catch = [preload("cues/catch_1.ogg"), preload("cues/catch_2.ogg")],
	flutter_away = [preload("cues/flutter_away.ogg")],
	sweep = [preload("cues/sweep_1.ogg"), preload("cues/sweep_2.ogg"), preload("cues/sweep_3.ogg")],
	stone = [preload("cues/stone.ogg")],
	purchase = [preload("cues/purchase.ogg")],
	appear = [preload("cues/appear.ogg")],
	stash = [preload("cues/stash.ogg")],
	vanish = [preload("cues/vanish.ogg")],
	hop = [preload("cues/hop.ogg")],
	mark = [preload("cues/mark.ogg")],
}
## Handled things vary in pitch by up to this fraction; tuned cues never do.
const JITTER := {grab = 0.06, place = 0.05, slide = 0.05, drop = 0.08, swish = 0.06, catch = 0.04, sweep = 0.05,
	hop = 0.08}
## The shortest time between two plays of a cue, s: a ray sliding over a row of buttons or a
## swarm flying off stays one gentle sound.
const GAP := {ui_hover = 0.06, swish = 0.22, sweep = 0.3, flutter_away = 0.6, hop = 0.2}

var _last_take: Dictionary[StringName, int] = {}
var _last_time: Dictionary[StringName, float] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.sound.connect(_play)
	Events.player_menu_toggled.connect(func(open: bool) -> void: _play(&"menu_open" if open else &"menu_close"))
	Events.facilitator_toggled.connect(func(open: bool) -> void: _play(&"menu_open" if open else &"menu_close"))
	Events.home_toggled.connect(func(open: bool) -> void: _play(&"room_enter" if open else &"room_exit"))
	Events.scene_changing.connect(func() -> void:
		for player in get_children():
			if player is AudioStreamPlayer3D:   # what was happening in the old scene; a transition plays on
				player.free())


func _play(cue: StringName, at := Vector3.INF) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_time.get(cue, -INF) < GAP.get(cue, 0.0):
		return
	_last_time[cue] = now
	var takes: Array = CUES[cue]
	var take := randi() % takes.size()
	if takes.size() > 1 and take == _last_take.get(cue, -1):
		take = (take + 1) % takes.size()
	_last_take[cue] = take
	if at.is_finite():
		var placed := AudioStreamPlayer3D.new()
		placed.unit_size = 1.0   # full level within a metre, falling off naturally beyond
		placed.max_db = 0.0
		placed.stream = takes[take]
		placed.bus = &"SFX"
		placed.pitch_scale = 1.0 + randf_range(-1.0, 1.0) * JITTER.get(cue, 0.0)
		placed.finished.connect(placed.queue_free)
		add_child(placed)
		placed.global_position = at
		placed.play()
	else:
		var flat := AudioStreamPlayer.new()
		flat.stream = takes[take]
		flat.bus = &"SFX"
		flat.finished.connect(flat.queue_free)
		add_child(flat)
		flat.play()
