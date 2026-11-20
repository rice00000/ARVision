class_name WorkshopController
extends Node
## The workshop after the opening (Scene 7; Megan's visual pass, Nov 18, `claude/VISUAL_PASS_LOG.md`):
## hub → game → hub → … → the gear lifted out → closing.
##
## * **The cauldron is the menu.** While it is closed a still ☰ floats over the brew; the cauldron glows when a
##   hand comes near it or aims at it (the first few times Onion says "Games"); one tap (touch or pinch) on
##   the cauldron or the ☰ opens the bubble menu ([ImpressionRing]): each choice rises in its own bubble. The
##   first time, after the reveal, the menu waits for that tap; after ~5 s with none, the teaching hand shows a
##   tap at the cauldron (no line). Once open it stays open until a choice (it rests after ~20 s with no hand
##   near, and wakes when one comes).
## * **Tasks** on a still arc of bubbles: one press picks any; the chosen bubble pops. A hand coming to a bubble
##   hears its name. The first visit offers the shelf, with the dots beside it in a closed bubble ("Soon")
##   ("Welcome to the workshop."); after ~5 s with the menu open and no choice the teaching hand shows
##   aim-and-pinch. After the first game the dots' bubble opens ("There are more waiting.", once). Turn to fit
##   joins only when it can run.
## * **Places:** below the tasks from after the first game: ? (the controls tour) · eye (the child's look for the
##   real room) · the Virtual Workshop house (with the stones badge) · ✕ (finish, after Onion asks).
## * **Check-in:** when due, its own optional button above the games. It returns directly to this menu.
## * **Stones and levels** (design chat, Nov 18, `claude/DESIGN_STONES_AND_LEVELS.md`): after every game its
##   stones rise from the brew into the house's badge (effort, not accuracy: 3 first time, 2 on a repeat, 1 for
##   leaving early); the first time Onion says what they're for. Pressing a game with a finished level opens its
##   own row (the recommended level big in the middle). What's been played, one-time lines and the look are
##   saved per child (HubMemory).
## * **The gear** turns in its socket. Lifting it out ends the visit: Onion asks "All done for today?"; set back
##   in, nothing happens; let go anywhere else, the closing starts (the gear flies home into the cauldron).
## * **During a game** the bubbles sink into the cauldron, the gear can't be lifted, and the
##   exit-task token stands low in front of the cauldron: a pinch on it ends the game (the round is skipped),
##   "We can come back to these.", back to the hub (the menu rises again by itself).
## * **Pause** (headset menu, Staff tools) pauses the world and the running game.
##   Nothing in the hub times out, and a lost hand never counts as a choice.

signal _picked_signal

const CUE_AFTER := 5.0          # seconds without a tap / choice before the teaching hand shows it (first visit)
const WELCOME := "Welcome to the workshop."
## Story chat, Nov 18 (locked): the stones, the first time they land in the house's badge.
const STONES_YOURS := "Oh, look! Some magic stones!"
const STONES_SPEND := "They're yours to spend in the Virtual Workshop."
## The workshop introduces itself after "Welcome to the workshop." (first visit), then the menu "clicks ready".
const PARTICULAR := "It's a bit particular, this place. Things wake up when they're ready."
const READY := "Well, this one's ready for us!"
## The dots' first unlock (replaces "There are more waiting.").
const DOTS_WOKE := "Oh! Looks like we've woken another one!"
const DOTS_AWAKE := "The Dots are awake. Shall we see what they're up to?"
const BREATH := 0.7             # seconds between Onion's lines (story chat: ~0.6-1 s)
## The other games' first unlocks (story chat revision, Nov 18), once per child.
const BUTTERFLIES_BACK := "The butterflies have returned. I wonder where they've been."
const CUP_DIFFERENT := "This one's a little different. We'll need something from your world."
## Placeholders for the story chat: Real Life and Odd Color's first unlocks.
const REAL_LIFE_AWAKE := "Oh! These look just like things at home."
const ODD_COLOR_AWAKE := "Someone has mixed up the colours. Can you spot the odd one?"
## The first time the child picks the house (not waited for: the child goes in at once).
const COME_ALONG := "Come along. There's something I'd like to show you."
const ROW_WAIT := 8.0           # a game's own row or the looks: this long with no press, they sink
const LEFT_EARLY := "We can come back to these."
const ALL_DONE := "All done for today?"
const GLOW_NEAR_FROM := 0.35            # a hand this close to the cauldron starts its glow...
const GLOW_NEAR_FULL := 0.12            # ...fully at this distance
const GEAR_SEAT := 0.008
## Sound labels (Megan, Nov 18): a bubble says its name ([method Impression.title_for]) when a hand comes to it;
## a closed one says "Soon".
const SOON := "Soon"
const GAMES := "Games"          # the cauldron's label, the first few times a hand comes to it
const GAMES_TIMES := 3
const STOP_GUARD := 0.5         # a ✕ bubble ignores presses for its first half second (no double press)
const STOP_WAIT := 6.0          # with no choice for this long, the ✕ bubble sinks and things carry on
const STOP_SCALE := 0.45
const TOUR_STEP := 5.0          # seconds per tour step (its line and one teaching-hand demo)
const TOUR_DIM := 0.25          # what the tour isn't showing fades a little (story chat: no dramatic dimming)
## The controls tour (design chat, Nov 18; step 2 is a pinch, Megan 9:13): what each step says.
## Story chat revision, Nov 18: an opening line, then one line per control; no closing line (Onion nods).
const TOUR_OPENING := "Need a little reminder? I'll show you."
const TOUR_LINES: Array[String] = ["Tap the cauldron to find your games.", "Pinch a bubble to choose.",
		"This little house leads to your Virtual Workshop.", "When you're ready to finish, lift the gear."]
const LABEL_QUIET := 1.2        # seconds of Onion's quiet before a label may play
const LABEL_SETTLE := 2.0       # no label in the hub's first seconds (a resting hand sits near)
## What opens when: Real Life after the first game (Nov 18: the most fun, so it comes first), then the dots, the
## butterflies, Odd Color, and Turn to fit (the cup, the last game) only once it can run (a saved cup setup and
## the CV server answering). One unlock per return to the hub. Locked games show with a padlock from the first visit.
const UNLOCKS: Array[Array] = [[&"real_life", &""], [&"dots", &"real_life"], [&"butterflies", &"dots"],
		[&"odd_color", &"butterflies"], [&"turn_to_fit", &"odd_color"]]
## Games played on Wei's bench (the socket fades under it; the pause offers the eye).
const BENCH_GAMES: Array[StringName] = [&"shelf", &"real_life", &"odd_color"]
const REAL_LIFE_HALF := 0.42    # half the widest Real Life board (the desk, 0.82 m)
const REAL_LIFE_DEEP := 0.6     # how far out its far edge reaches from the eyes
const CAULDRON_CLEAR := 0.14    # the pot's half width and a gap

var workshop: Workshop
var activities: Array[Summonable] = []
var ring: ImpressionRing
## During a game: the cauldron's pause bubble (one ✕, "Stop"); in the hub: the finish check's ✕. Null otherwise.
var stop_bubble: Impression
var cauldron_menu: WorkshopCauldronMenu
## The child lifts the gear out to finish.
var carry: Carry
var lanterns: Array[Lantern] = []   # the workshop's warm lanterns (decor only, never pressed)
var ambience: HubAmbience           # the quiet fireplace crackle under the hub
var current: Summonable
var state := &"idle"            # &"hub", &"game", &"check_in", &"home", &"closing", &"closed"
var check_in_board: WorkshopCheckIn
var _offered_check_in: Place
var played: Array[StringName] = []
## Saved per child: games played, one-time lines, the look (design chat, Nov 18).
var memory: HubMemory
## The stones badge on the house (from when the places row shows).
var badge: StonesBadge
## A row shown in the menu's place: a game's levels (&"levels") or the looks (&"looks"); null otherwise.
var row: ImpressionRing
var row_kind := &""
## During a game: the pause bubble's eye (shelf and Turn to fit only), beside the ✕.
var eye_bubble: Impression
## The menu has been opened by the child at least once.
var ever_opened := false
var _picked: StringName = &""
var _demo: DemoHand
var _exited := false
var _opening := false
var _poking: Dictionary = {}    # side -> the fingertip is inside the cauldron's reach
var _games_said := 0
var _hub_since := 0.0           # when the hub last began waiting (seconds)
var _quiet_since := 0.0         # when Onion last finished a line (a story line: sound labels don't count)
var _labels: Dictionary = {}    # the sound labels said so far (text → true), so they never hold up the next one
var _label_turn := 0            # bumped by each new label: a cut label doesn't go on to say its count
var _label_now := ""            # the label being said (with its count), "" once it has finished
var _clock := 0.0               # game time, seconds (unpaused)
var _clock_real := 0.0          # time that runs while paused too (the pause bubble's own clock)
var _stop_since := 0.0
var _stop_chosen := false
var _cauldron_tapped := false
var _touring := false
var _tour_id := 0
var _cauldron_hover := false
var _row_pressed: Impression
var _row_since := 0.0
var _pause_lit: Impression          # the pause bubble lit now (✕ or eye), or null
var _pinch_frame := -1              # the frame a lit bubble last took a pinch (the ray's select of it is the same pinch)
var _taken_frame: Dictionary = {}   # hand -> the frame a game last reported a pick-up ("taken")
var _stop_pick := &""            # the pause bubbles' answer: &"stop", &"eye" or &"" (carry on)
var _looking := false            # the looks row is up (from the hub's eye)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # sees the pause come and go


## Runs the workshop until the closing has played. [param first]: a DEV jump's game to start with
## (&"shelf" / &"dots"; &"motion" = &"dots"), or &"". [param welcome]: the opening's own flow (first visit).
## [param closing]: the visit's closing (MotionVisit.closing). [param home]: goes to Wei's room and back.
func run(on: Workshop, list: Array, first := &"", welcome := false, closing := Callable(), home := Callable()) -> void:
	workshop = on
	for a in list:
		activities.append(a as Summonable)
		add_child(a)
	_demo = DemoHand.new()
	add_child(_demo)
	var voice := App.module(&"Voice")
	if voice != null and voice.has_signal(&"line_finished"):
		voice.line_finished.connect(func(text: String, _completed: bool) -> void:
			if not _labels.has(text):
				_quiet_since = _clock)
		Events.said.connect(func(text: String) -> void:
			if not _labels.has(text):
				_quiet_since = INF)   # Onion speaking now: wait for its end
	memory = HubMemory.get_or_make()
	if memory != null:
		played = memory.played   # the same array: what's played is saved as it happens
	_build_ring()
	check_in_board = WorkshopCheckIn.new()
	add_child(check_in_board)
	Events.trial_started.connect(_on_check_in_round)
	cauldron_menu = WorkshopCauldronMenu.new()
	add_child(cauldron_menu)
	cauldron_menu.build(workshop.cauldron() if workshop != null else null, _mouth(), App.head().global_position)
	_build_carry()
	_hang_lanterns()
	ambience = HubAmbience.make(self)
	if first == &"motion":
		first = &"dots"
	var activity := _activity(first)
	# The whole menu, also for a jump (Staff tools → Scenes): Megan, Nov 18, a jump to the dots showed one bubble,
	# no locked games and no places. The jumped-to game is open for this visit even if it would still be locked.
	await _offer(_activity(&"shelf"))
	for unlock: Array in UNLOCKS:   # there's more: each waits in a locked bubble until it opens
		var next := _activity(unlock[0])
		if next != null:
			await _offer(next, false, next != activity and not _unlocked(unlock))
	if not played.is_empty():
		_show_places()   # a later visit: the places row is there from the start
	if activity != null:
		ever_opened = true   # a jump: the child is past the first tap; the game starts at once
		await _run(activity)
	elif welcome:
		_welcome()   # not awaited: talk never blocks play (story chat, Nov 18)
	while true:
		await _visit(home)
		state = &"closing"
		await _closing_starts()
		if closing.is_valid():
			await closing.call()
		await _dim_lanterns()   # the lanterns go out one by one (story chat), after "Well. I'll do my best."
		state = &"closed"
		if not await _restart():   # Megan, Nov 18: a tap on the cauldron starts again (the gear pops out)
			break


## The hub's own loop, until the visit ends (the gear lifted out and let go, or the ✕ confirmed).
func _visit(home: Callable) -> void:
	while true:
		_picked = &""
		var choice := await _hub()
		if choice == &"check_in":
			await _run_check_in(_offered_check_in)
			continue
		if choice not in [&"gear_finish", &"finish", &"gear_home"] and not await _choose_level(_activity(choice)):
			continue
		if choice == &"gear_finish":
			break
		if choice == &"finish":
			if await _ask_finish():
				break
			continue
		if choice == &"gear_home":
			if home.is_valid():
				if memory == null or memory.first_time(&"house_come"):
					Onion.line(COME_ALONG, self)   # not awaited: the child goes in at once (story chat)
				state = &"home"
				carry.stop()
				_show_lanterns(false)
				ambience.fade_out()
				await ring.sink(_mouth(), 0.9)   # the bubbles sink: nothing over the Virtual Workshop
				await home.call()
				_show_lanterns(true)
				await ring.rise(_mouth())
			continue
		await _run(_activity(choice))


# --- Restart after the goodbye (Megan, Nov 18) -------------------------------------------------------

const RESTARTED := &"visit_restarted"
var _restart_tapped := false
var _seat_at := Vector3.INF   # where the gear sits in its socket (kept from the visit, for the restart)


## The lanterns dim one by one, farthest first (the goodbye's end).
func _dim_lanterns() -> void:
	var eye := App.head().global_position
	var order := lanterns.filter(func(l: Lantern) -> bool: return is_instance_valid(l) and l.visible)
	order.sort_custom(func(a: Lantern, b: Lantern) -> bool: return a.global_position.distance_to(eye) > b.global_position.distance_to(eye))
	Lantern.quiet = true
	for lantern: Lantern in order:
		create_tween().tween_property(lantern, ^"lit", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
		await get_tree().create_timer(0.35, false).timeout


## After the goodbye: waits for a tap on the cauldron (no time limit; the grown-up ends the session in Staff
## tools). Then the closing plays backwards: no hello, no lines. Onion pops back up, the socket rises, the gear
## pops out onto the table; the child sets it back in (the teaching hand shows how after a moment), the gears
## turn, the lanterns glow, and the menu opens. Saved progress carries on. False only if the scene is leaving.
func _restart() -> bool:
	_restart_tapped = false
	while not _restart_tapped:
		await get_tree().process_frame
		if not is_inside_tree():
			return false
	state = &"restarting"
	print("HUB restart")
	Events.report(RESTARTED, {})
	App.results_after_closing = false
	var socket := workshop.socket_at() if workshop != null else _mouth()
	var seat := _seat_at if _seat_at != Vector3.INF else socket + Vector3.UP * GEAR_SEAT
	if workshop != null:
		workshop.onion_back(_onion_spot())
		await workshop.socket_back()
		var eye := App.head().global_position
		var toward := Vector3(eye.x - socket.x, 0.0, eye.z - socket.z).normalized()
		await workshop.gear_out(Vector3(socket.x, seat.y - GEAR_SEAT, socket.z) + toward * 0.14)   # clear of the socket, toward the child
	var gear := workshop.gear_node() if workshop != null else null
	if gear != null:
		carry.begin(gear, seat)
		var waited := 0.0
		var shown := false
		while not carry.has_docked():
			await get_tree().process_frame
			if not is_inside_tree():
				return false
			waited += get_process_delta_time()
			if not shown and waited > CUE_AFTER and not carry.held:
				shown = true
				_demo.pinch_lift(gear)   # how to put it back: no words
			if carry.held:
				_demo.stop()
		_demo.stop()
	# Quick wake-up: the gears turn, the lanterns glow again, the fire comes back; then the menu.
	if workshop != null:
		workshop.start_gears()
	Lantern.quiet = false
	for lantern in lanterns:
		lantern.visible = true
		lantern.appear(1.0)
	ambience.hub()
	await get_tree().create_timer(0.8, false).timeout
	state = &"hub"
	_hub_since = _clock
	await ring.rise(_mouth())
	ring.wake()
	return true


# --- The hub ---------------------------------------------------------------------------------------

## The hub: waits for a choice in the menu, or the gear lifted out. Opens the menu on the child's tap.
func _hub() -> StringName:
	state = &"hub"
	_hub_since = _clock
	if memory != null and App.reality != null:
		# The child's look, every time the hub begins (Megan, Nov 18: the room stayed dark after a jump that cut the
		# dots off mid-haze; the dots' 60 % dim lives on the room, which outlasts scenes). Spotlight: Normal here.
		App.reality.apply_view(memory.room_view())
	Lantern.quiet = false   # the lanterns breathe again (and the odd ember rises)
	ambience.hub()
	SceneMarker.show_text("Hub")
	_refresh_check_in_offer()
	if ring.opened:
		ring.wake()
	_begin_carry()
	if workshop != null:
		workshop.float_to(_onion_spot(), 1.0)
	var waited := 0.0
	var cued := &""
	while _picked == &"":
		await get_tree().process_frame
		if get_tree().paused or _opening:
			continue
		waited += get_process_delta_time()
		if not ring.opened:
			if _welcoming:
				waited = 0.0   # the teaching hand waits for Onion's welcome to finish
			if not ever_opened and cued != &"tap" and waited > CUE_AFTER:
				cued = &"tap"
				_demo.tap(_rim())   # shows a tap at the cauldron: no words
			continue
		if cued == &"tap":
			_demo.stop()
			cued = &""
			waited = 0.0
		if played.is_empty() and cued == &"" and waited > CUE_AFTER and ring.leader() != null:
			cued = &"pinch"
			_demo.aim_pinch(ring.leader().target)   # shows aim-and-pinch on the shelf: no words
	_demo.stop()
	print("HUB choice: ", _picked)
	return _picked


## The child tapped the cauldron: the fog rises with the pieces (the menu is open until a choice).
func _open_menu() -> void:
	if state != &"hub" or ring.opened or _opening or get_tree().paused:
		return
	_opening = true
	ever_opened = true
	_demo.stop()
	print("HUB menu opens")
	Events.report(&"hub_menu_opened", {})
	await ring.rise(_mouth())
	_refresh_check_in_offer()
	_opening = false


## A game's impression rises into the menu (and comes to the front); with the menu closed it simply joins.
## [param welcome]: Onion's "Welcome to the workshop." then a look at the cauldron (the first visit).
func _offer(activity: Summonable, welcome := false, locked := false) -> void:
	if activity == null or _impression_of(activity) != null:
		return
	var impression := activity.make_impression() as Impression
	if impression == null:
		return
	var levels := activity.levels()
	if levels.size() == 1:
		impression.level = levels[0]
	await ring.add(impression, _mouth())
	if locked:
		impression.set_sealed(true)   # shown, not open yet: a press says "Soon" (Megan: there's more to explore)
	if impression.kind == &"shelf":
		impression.set_rows(_shelf_rows())   # one row more for each shelf level finished
	if welcome:
		await Onion.line(WELCOME, self)
	if workshop != null:
		# Onion looks at it (attention cue, no words); at the cauldron while the menu is closed.
		workshop.attend(impression.global_position if ring.opened else _rim())


func _run(activity: Summonable) -> void:
	if activity == null:
		return
	state = &"game"
	Lantern.quiet = true    # steady glow, no embers: nothing moves on its own beside a task
	ambience.game()
	current = activity
	_exited = false
	carry.stop()
	_demo.stop()
	await HubGlow.quiet_all(0.3)
	if ring.opened or ring.visible:
		await ring.sink(_mouth(), 0.9)   # Megan, Nov 18: the pieces sink into the cauldron with the fog during a game
	if workshop != null:
		workshop.attend(null)
	print("HUB game: ", activity.id())
	# Wei's bench board can reach the socket at the front right too (Megan's laptop test, Nov 18): it always fades
	# under the board during the shelf, as before (the layout's zones miss the board's real edge on some tables).
	var under_bench := activity.id() in BENCH_GAMES and workshop != null
	if under_bench:
		workshop.hide_socket(true)
	var aside := _cauldron_aside() if activity.id() == &"real_life" and workshop != null else Vector3.ZERO
	if aside != Vector3.ZERO:
		await _slide_cauldron(aside)
	_watch_cauldron()
	activity.summon(_workspace())
	var outcome: StringName = await activity.finished
	if under_bench:
		workshop.hide_socket(false)
	if aside != Vector3.ZERO:
		_slide_cauldron(-aside)
	_drop_stop_bubble()
	print("HUB ", activity.id(), " finished: ", outcome)
	Events.report(&"hub_activity_finished", {activity = activity.id(), outcome = outcome})
	var stones_before := _stones()
	var grew := activity.id() == &"shelf" and activity.played_level != null \
			and not App.main.progress.is_done(activity.task(), activity.played_level)
	var stones := _award(activity, outcome)
	grew = grew and not _exited and stones > 0
	activity.fold()
	current = null
	ever_opened = true
	await ring.rise(_mouth())   # and the menu rises again by itself, back at the hub
	if memory != null:
		memory.mark_played(activity.id())
	elif not played.has(activity.id()):
		played.append(activity.id())
	ring.wake()
	# After the first game: the places row (with the stones badge) appears below, the next game opens.
	if ring.door == null:
		_show_places(stones_before)
	elif badge != null:
		badge.set_count(stones_before)
	var woke := await _unlock_next()
	for a in activities:   # Turn to fit (or anything) that can run now
		if a.is_available() and _impression_of(a) == null and a.id() != &"dots":
			await _offer(a)
	_after_game(woke, stones, grew)   # not awaited: presses on the bubbles work while Onion talks and stones fly


## Offer one due check-in at a time, once the child has played a game at its place.
## A staff request takes precedence. Either way, the player starts it explicitly.
func _refresh_check_in_offer() -> void:
	_offered_check_in = null
	var check_ins := App.module(&"CheckIns") as CheckIns
	if check_ins == null:
		return
	for activity in activities:
		if activity.id() not in played:
			continue
		var place := activity.place()
		if place == null or not check_ins.due(place) or place.check_in.round_count() <= 0:
			continue
		if check_ins.requested_for(place):
			_offered_check_in = place
			return
		if _offered_check_in == null:
			_offered_check_in = place


func _can_pick_check_in() -> bool:
	return state == &"hub" and _picked == &"" and ring.opened and not ring.turning \
			and row == null and not _looking and not _touring and not carry.held and not get_tree().paused


func _run_check_in(place: Place) -> void:
	var check_ins := App.module(&"CheckIns") as CheckIns
	if check_ins == null or place == null or not check_ins.due(place):
		return
	state = &"check_in"
	SceneMarker.show_text("Check-in")
	carry.stop()
	Lantern.quiet = true
	ambience.game()
	await HubGlow.quiet_all(0.15)
	await ring.sink(_mouth(), 0.45)
	var at_bench := workshop != null and CheckIns.key(place) == &"table"
	if workshop != null:
		workshop.attend(null)
	if at_bench:
		workshop.hide_socket(true)
	check_in_board.begin(place)
	var completed := await check_ins.run(place, false)
	if at_bench:
		workshop.hide_socket(false)
	if completed:
		check_in_board.complete()
		Events.say(place.check_in.farewell)
	else:
		check_in_board.returning()
	await ring.rise(_mouth(), 0.8)
	check_in_board.clear_status()


func _on_check_in_round(_trial: StringName, condition: Dictionary) -> void:
	if state != &"check_in" or not condition.probe:
		return
	var session := App.session
	var index: int = condition.round
	for i in session.block_index:
		index += session.plan.blocks[i].rounds
	if index == 0:
		check_in_board.place_status(session.trial.focus_point())
	check_in_board.show_round(index, condition.skill)
	if index == 0 and condition.skill == &"global_motion":
		Events.say("Magic dots! Sweep your hand the way they flow.")


## Opens the next locked game whose time has come (UNLOCKS), once per return: its lock clicks open and drops away,
## Returns the game that opened (its lines come after, in [method _after_game]), or null.
func _unlock_next() -> Summonable:
	for unlock: Array in UNLOCKS:
		var activity := _activity(unlock[0])
		if activity == null or not activity.is_available():
			continue
		var after: StringName = unlock[1]
		if after != &"" and not played.has(after):
			continue
		if after == &"" and played.is_empty():
			continue
		var piece := _impression_of(activity)
		if piece != null and not piece.sealed:
			continue
		if piece != null:
			await piece.unseal()
		else:
			await _offer(activity)
		return activity
	return null


## A game is left early through the cauldron's ✕: its round is dropped (interrupted), "We can come back to these."
func _exit_game() -> void:
	if current == null or _exited:
		return
	_exited = true
	print("HUB exit: ", current.id())
	Events.report(&"task_exited", {activity = current.id()})
	current.leave()


func _closing_starts() -> void:
	var gear := workshop.gear_node() if workshop != null else null
	if gear != null:
		_seat_at = gear.global_position + Vector3.UP * GEAR_SEAT   # for a restart
	carry.stop()
	_demo.stop()
	_drop_stop_bubble()
	ambience.fade_out(3.0)
	if ring.visible:
		await ring.sink(_mouth())   # Scene 10: the bubbles sink quietly into the cauldron first


# --- Building ----------------------------------------------------------------------------------------

func _build_ring() -> void:
	var mouth := _mouth()
	ring = ImpressionRing.make(self, [] as Array[Impression], ImpressionRing.spot(mouth, App.head().global_position), App.head().global_position, mouth)
	ring.visible = false   # closed: the child's tap on the cauldron opens it
	ring.opened = false
	ring.chosen.connect(func(impression: Impression) -> void:
		if impression.kind == &"help":
			impression.reset_bubble()   # the menu stays: the tour plays over it
			_tour()
			return
		if impression.kind == &"eye":
			impression.reset_bubble()
			_looks_from_hub()
			return
		_pick(&"gear_home" if impression == ring.door else impression.kind))
	ring.hovered.connect(func(impression: Impression) -> void:
		# A soft glass tink, a note higher up the scale for each bubble along the arc, then its name.
		var step := ring.impressions.find(impression)
		_play(&"hover_tink", impression.global_position, Sounds.step(step if step >= 0 else -2))
		if impression == ring.door:
			# Its name, then the count (design chat, Nov 18: "Seven stones"). The teaser line is cut.
			_label(impression.label(), false, StonesBadge.spoken(badge.count if badge != null else _stones()))
			return
		_label(SOON if impression.sealed else impression.label()))
	Events.selected.connect(func(_hand: StringName, target: Target, _o: Vector3, _d: Vector3) -> void: _on_press(target, true))
	Events.touched.connect(func(_hand: StringName, target: Target) -> void: _on_press(target, false))
	Events.button.connect(_on_pinch_without_ray)
	Events.reported.connect(func(what: StringName, data: Dictionary) -> void:
		if what == &"taken":
			_taken_frame[StringName(str(data.get("hand", "")))] = Engine.get_process_frames()
		elif what == &"check_in_asked":
			_refresh_check_in_offer()
		elif what == &"player_menu" and data.get("button") == &"menu_cheat":
			_cheat())


## Megan, Nov 18: in the dots the pinch never reached the cauldron, so there was no way out. The dots run with
## the pointing ray off (a sweep is the answer), and with it off a pinch selects nothing. During a game the
## hub's own few targets (the cauldron, the ☰, the ✕ and the eye) still take a pinch aimed at them.
## Nov 19: a pinch that picks a game's thing up (a notebook on Wei's desk, with the cauldron behind it) is the
## game's, never a pause; and a fingertip already inside a bubble still presses it.
func _on_pinch_without_ray(side: StringName, action: StringName, pressed: bool) -> void:
	if not pressed or action != &"trigger_click" or App.rig == null or _pinch_frame == Engine.get_process_frames():
		return
	# Nov 19: a lit bubble (a row's, the pause's, or the menu's in the hub) takes any pinch, ray or not.
	var lit := _lit()
	if lit != null:
		_on_press(lit.target, true)
		_pinch_frame = Engine.get_process_frames()
		return
	if state not in [&"game", &"asking"]:
		return
	var pointer := App.rig.pointer(side)
	if pointer == null or pointer.ray_on() or not pointer.tracked():
		return   # with the ray on, the pointer selects it itself
	var pinched_at := Engine.get_process_frames()
	var query := PhysicsRayQueryParameters3D.create(pointer.global_position,
			pointer.global_position - pointer.global_basis.z * pointer.length, Pointer.TARGET_LAYER)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.hit_from_inside = true
	var hit: Dictionary = pointer.get_world_3d().direct_space_state.intersect_ray(query)
	var target: Target = hit.collider as Target if not hit.is_empty() else null
	var ours: Array[Target] = [cauldron_menu.target, cauldron_menu.sign_target]
	for bubble: Impression in [stop_bubble, eye_bubble]:
		if bubble != null and is_instance_valid(bubble):
			ours.append(bubble.target)
	if target == null or target not in ours:
		return
	await get_tree().process_frame   # the game hears the same pinch: did it pick something up?
	if _taken_frame.get(side, -1) >= pinched_at:
		return
	_on_press(target, true)


func _on_press(target: Target, pinched: bool) -> void:
	if target == null or (pinched and _pinch_frame == Engine.get_process_frames()):
		return   # this pinch already went to the lit bubble
	if check_in_board != null and target == check_in_board.offer.target:
		if pinched and _offered_check_in != null and _can_pick_check_in() and check_in_board.offer.visible:
			_pinch_frame = Engine.get_process_frames()
			check_in_board.show_offer(null)
			_pick(&"check_in")
		return
	if check_in_board != null and target == check_in_board.back.target:
		if pinched and state == &"check_in" and not get_tree().paused \
				and check_in_board.back.is_visible_in_tree() and App.session.running:
			_pinch_frame = Engine.get_process_frames()
			check_in_board.returning()
			var voice := App.module(&"Voice")
			if voice != null:
				voice.skip()
			App.session.stop()
		return
	if stop_bubble != null and is_instance_valid(stop_bubble) and target == stop_bubble.target:
		if pinched and _clock_real - _stop_since >= STOP_GUARD:
			_stop_chosen = true   # pinch only: a sweep through it never counts
		return
	if eye_bubble != null and is_instance_valid(eye_bubble) and target == eye_bubble.target:
		if pinched and _clock_real - _stop_since >= STOP_GUARD:
			_stop_pick = &"eye"
		return
	var on_cauldron := target == cauldron_menu.target or target == cauldron_menu.sign_target
	if row != null:
		# A game's own row or the looks: a tap on the cauldron takes them away; a pinch picks (a look stays up).
		if on_cauldron:
			_cauldron_tapped = true
			return
		var piece := row.impression_for(target)
		if piece == null or not pinched:
			return
		_row_since = _clock_real
		if row_kind == &"looks":
			_press_look(piece)
		elif row.press(piece) == &"chosen":
			pass   # it pops; [signal ImpressionRing.chosen] follows
		return
	if on_cauldron and state == &"closed":
		_restart_tapped = true   # after the goodbye: start again
		return
	if on_cauldron and (state == &"game" or state == &"asking"):
		# A game: pause it (or carry on); the finish check: no, not yet. A pinch only (Megan, Nov 18: a hand
		# passing over the cauldron mid-game paused it): games happen right around the cauldron.
		if pinched:
			_cauldron_tapped = true
		return
	if state != &"hub" or get_tree().paused:
		return
	_stop_tour()   # any real action ends the tour at once (and happens as usual)
	if on_cauldron:
		_open_menu()   # the cauldron takes a tap (Scene 2 taught it) or a pinch
		return
	if not pinched:
		return   # a bubble is chosen by a pinch (a click on the desktop) only: never by a touch or a hand passing by (Megan, Nov 18)
	var impression := ring.impression_for(target)
	if impression != null and ring.press(impression) == &"sealed":
		_play(&"locked_bonk", impression.global_position)
		_label(SOON)


## The bubble a pinch takes now: the pause's lit one, else the open row's, else (in the hub) the menu's.
func _lit() -> Impression:
	if stop_bubble != null:
		return _pause_lit
	if row != null:
		return row.lit
	if state == &"hub" and ring != null and not get_tree().paused:
		return ring.lit
	return null


## The gear in its socket can be lifted out (Carry): out = the visit ends.
func _build_carry() -> void:
	carry = Carry.new()
	carry.name = "HubCarry"
	add_child(carry)
	carry.seat_depth = GEAR_SEAT
	carry.dock_feedback = false
	var gear := workshop.gear_node() if workshop != null else null
	var socket: Node3D = workshop.get("_mechanism") if workshop != null else null
	if gear != null and socket != null and is_instance_valid(socket):
		var pot := workshop.cauldron()
		carry.configure(socket.global_position.y - 0.012, App.head().global_position,
				maxf(App.head().global_position.distance_to(socket.global_position), 0.45) + 0.15,
				socket.rotation.y, pot.global_position if pot != null else Vector3.INF, 0.2)
		carry.follow(pot, socket)
	carry.picked_up.connect(func() -> void:
		if state == &"restarting":
			return   # putting the gear back after the goodbye: not "All done for today?"
		_stop_tour()
		_play(&"gear_lift", _gear_at())
		if workshop != null:
			workshop.slow_gears(2.5)   # the workshop starts slowing (story chat); setting the gear back wakes it
		print("HUB gear lifted")
		Onion.line(ALL_DONE, self))
	carry.docked.connect(func() -> void:
		_play(&"seat", _gear_at())
		_play(&"power_up", _gear_at())
		if workshop != null:
			workshop.start_gears()
		_spin_gear(true))
	carry.released.connect(func(docked: bool) -> void:
		if not docked:
			print("HUB gear out: the visit ends")
			_pick(&"gear_finish"))


func _begin_carry() -> void:
	var gear := workshop.gear_node() if workshop != null else null
	if gear == null or not gear.visible:
		return
	carry.begin(gear, gear.global_position + Vector3.UP * GEAR_SEAT)


func _spin_gear(on: bool) -> void:
	var gear := workshop.gear_node() if workshop != null else null
	if gear == null:
		return
	for spin: GearSpin in gear.find_children("*", "GearSpin", true, false):
		spin.running = on


## One lantern behind and above the cauldron, plus a few on the scanned walls (Megan, Nov 18). They fade in.
func _hang_lanterns() -> void:
	lanterns = Lantern.take_from_reveal(self)   # lit by the reveal already (Megan, Nov 18): they just stay
	if not lanterns.is_empty():
		return
	var middle := workshop.layout.table.origin if workshop != null and workshop.layout != null else _mouth() + Vector3.LEFT * 0.4
	lanterns = Lantern.hang_style(self, _mouth(), App.head().global_position, middle)
	for lantern in lanterns:
		lantern.appear(2.0)


func _show_lanterns(on: bool) -> void:
	for lantern in lanterns:
		lantern.visible = on
	var rafters := get_node_or_null(^"Rafters") as Node3D
	if rafters != null:
		rafters.visible = on


func _pick(id: StringName) -> void:
	_stop_tour()
	if _picked == &"" and state == &"hub":
		_picked = id
		_picked_signal.emit()


# --- Pause ---------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_clock_real += delta
	if not get_tree().paused:
		_clock += delta
	_cauldron_step(delta)
	if check_in_board != null:
		check_in_board.visible = not get_tree().paused
		var offer := _offered_check_in if _can_pick_check_in() else null
		if offer != null:
			check_in_board.place_offer(ring.global_position)
		check_in_board.show_offer(offer)


## The cauldron glows while the menu is closed in the hub and a hand comes near or aims at it; a fingertip
## going into its reach taps it.
func _cauldron_step(delta: float) -> void:
	if cauldron_menu == null:
		return
	var open_to_tap := state == &"hub" and not ring.opened and not _opening and not get_tree().paused
	# During a game (and the finish check) the cauldron takes a tap too: it pauses the game (design chat, Nov 18).
	var tap_in_game := state == &"game" or state == &"asking" or state == &"closed"   # closed: a tap restarts
	cauldron_menu.set_targetable(open_to_tap or tap_in_game)
	var want := 0.0
	if open_to_tap and App.rig:
		for side: StringName in [&"left", &"right"]:
			var pointer := App.rig.pointer(side)
			if pointer == null:
				continue
			if pointer.aimed == cauldron_menu.target:
				want = 1.0
			if pointer.tracked() and open_to_tap:
				var gap := pointer.tip().distance_to(cauldron_menu.target.global_position)
				want = maxf(want, clampf(inverse_lerp(GLOW_NEAR_FROM, GLOW_NEAR_FULL, gap), 0.0, 1.0))
				var inside := gap <= cauldron_menu.radius
				var was: bool = _poking.get(side, false)
				_poking[side] = inside
				if inside and not was and App.xr != null:
					_on_press(cauldron_menu.target, false)   # a headset fingertip into the pot (desktop: the click)
	if open_to_tap and not ever_opened:
		want = maxf(want, 0.4)   # the first time it waits glowing softly ("you can tap me")
	# The sound label: a hand coming to the cauldron, the first few times, "Games".
	if want >= 0.6 and not _cauldron_hover and open_to_tap:
		_cauldron_hover = true
		if _games_said < GAMES_TIMES:
			_games_said += 1
			_label(GAMES)
	elif want < 0.45:
		_cauldron_hover = false
	cauldron_menu.update_glow(want, delta)


## Says a bubble's (or the cauldron's) name, quietly: only when Onion has been quiet for a moment
## ([constant LABEL_QUIET] s) and not in the hub's first [constant LABEL_SETTLE] s, so a label never stacks
## on a line (Megan, Nov 18, issue 5). A newer label cuts an older one at once, and labels never make each other
## wait (Megan, Nov 18 5:14). True if it was said.
func _label(text: String, anywhere := false, then := "") -> bool:
	if text == "" or (state != &"hub" and not anywhere):
		return false
	var now := _clock
	if now - _hub_since < LABEL_SETTLE or now - _quiet_since < LABEL_QUIET:
		return false
	if text == _label_now:
		return false   # the same bubble again: its name is still going (with its count)
	var voice := App.module(&"Voice")
	if voice != null and voice.has_method(&"speaking") and voice.speaking() != "":
		# Megan, Nov 18 5:14: the name must match where the hand is now. A label still playing is cut and the new
		# one plays at once; one of Onion's lines is never talked over.
		if not _labels.has(voice.speaking()) or not voice.has_method(&"skip"):
			return false
		voice.skip()
	print("HUB label: ", text)
	_labels[text] = true
	if then != "":
		_labels[then] = true
	_label_turn += 1
	var turn := _label_turn
	_label_now = text
	(func() -> void:
		await Onion.line(text, self)
		if not is_instance_valid(self):
			return   # the hub went (a scene change) mid-name
		if then != "" and turn == _label_turn:   # not cut by the next bubble's name: then its count
			await get_tree().create_timer(0.3, false).timeout   # a short breath, then the count
			if turn == _label_turn:
				await Onion.line(then, self)
		if is_instance_valid(self) and turn == _label_turn:
			_label_now = "").call()
	return true


# --- Places, stones and levels (design chat, Nov 18, `claude/DESIGN_STONES_AND_LEVELS.md`) -------------------

## Is [param unlock] (a row of UNLOCKS) open for this child? (Saved: what they've played.)
func _unlocked(unlock: Array) -> bool:
	var activity := _activity(unlock[0])
	if activity == null or not activity.is_available():
		return false
	var after: StringName = unlock[1]
	return not played.is_empty() if after == &"" else played.has(after)


## The places row: ? · eye · house · ✕ (design chat, Nov 18), the house with the stones badge showing
## [param stones] (default: the inventory's count).
func _show_places(stones := -1) -> void:
	var house := Impression.make(&"house")
	ring.set_places([Impression.make(&"help"), Impression.make(&"eye"), house, Impression.make(&"finish")] as Array[Impression], house)
	badge = StonesBadge.attach(house, stones if stones >= 0 else _stones())


## The menu's Cheat button (testing; Home adds the 50 stones): every game played and open, every level finished.
func _cheat() -> void:
	for activity in activities:
		if memory != null:
			memory.mark_played(activity.id())
		elif not played.has(activity.id()):
			played.append(activity.id())
		if activity.task() != null:
			App.main.progress.finish_all(activity.task())
		var piece := _impression_of(activity)
		if piece != null:
			piece.unseal()
			if piece.kind == &"shelf":
				piece.set_rows(_shelf_rows(), 0.4)
	_refresh_check_in_offer()
	if badge != null:
		(func() -> void: badge.set_count(_stones())).call_deferred()   # Home adds the stones after its report


## The shelf piece's rows: 1 + shelf levels finished, at most 4.
func _shelf_rows() -> int:
	var shelf := _activity(&"shelf")
	return mini(1 + (shelf.done_levels().size() if shelf != null else 0), 4)


func _stones() -> int:
	var inventory := App.module(&"Inventory")
	return inventory.count(&"magic_stone") if inventory != null else 0


## A game's stones (§3: effort, never accuracy): its level's first / repeat reward (Wei's TaskProgress, which
## also marks it done) when it ran to its end, whatever the score; 1 when the child left it by the ✕ (the level
## isn't marked done). Returns how many.
func _award(activity: Summonable, outcome: StringName) -> int:
	if _exited:
		var inventory := App.module(&"Inventory")
		if inventory == null:
			return 0
		inventory.add(&"magic_stone", 1)
		Events.report(&"stones_for_trying", {activity = activity.id()})
		return 1
	if outcome == &"interrupted" or activity.task() == null or activity.played_level == null:
		return 0
	return App.main.progress.complete(activity.task(), activity.played_level)


## The earning moment (§2, §4): [param stones] rise from the brew into the house's badge, one clink each; a
## first-time shelf level grows the shelf a row; the first time ever, Onion says what they're for.
## The first visit's welcome (story chat, Nov 18): "Welcome to the workshop.", a fond look round, "It's a bit
## particular…", the cauldron clicks ready and the menu opens by itself, "Well, this one's ready for us!". Not awaited:
## a tap on the cauldron works throughout, and the rest stops once the menu is open.
var _welcoming := false
func _welcome() -> void:
	_welcoming = true
	await Onion.line(WELCOME, self)
	if workshop != null and not ring.opened:
		for look: Vector3 in [Vector3(-0.8, 0.5, -1.2), Vector3(0.8, 0.4, -1.2)]:   # affectionately round the room
			workshop.attend(App.head().global_position + App.head().global_basis * look)
			await get_tree().create_timer(1.0, false).timeout   # slow glances: a fond look, not a twitch
		workshop.attend(null)
	if not ring.opened and not _opening:
		await Onion.line(PARTICULAR, self)
	if not ring.opened and not _opening:
		await get_tree().create_timer(BREATH, false).timeout
		_play(&"unlock", _mouth())   # the mechanism clicks ready
		cauldron_menu.glow = 1.0
		# Megan, Nov 18: the menu opens by itself here and Find Objects waits in front, glowing; the child pinches it.
		_open_menu()
		if workshop != null:
			workshop.attend(_mouth() + Vector3.UP * 0.25)
		await Onion.line(READY, self)
		if workshop != null:
			workshop.attend(null)
	_welcoming = false


## After a game, once the menu is back (not awaited): a game that just opened gets its lines (the dots, the first
## time: "Oh! Looks like we've woken another one!" / "The Dots are awake…"; story chat, Nov 18), then the stones.
func _after_game(woke: Summonable, stones: int, grew: bool) -> void:
	var other_line := {&"butterflies": BUTTERFLIES_BACK, &"turn_to_fit": CUP_DIFFERENT, &"real_life": REAL_LIFE_AWAKE,
			&"odd_color": ODD_COLOR_AWAKE}
	if woke != null and woke.id() in other_line and (memory == null or memory.first_time(StringName("%s_awake" % woke.id()))):
		var piece := _impression_of(woke)
		if piece != null:
			piece.touched()   # a gentle flutter of the icon
			if workshop != null:
				workshop.attend(piece.global_position)
		await Onion.line(other_line[woke.id()], self)
		if workshop != null:
			workshop.attend(null)
		if state != &"hub":
			if badge != null:
				badge.land_all()
			return
		await get_tree().create_timer(BREATH, false).timeout
	if woke != null and woke.id() == &"dots" and (memory == null or memory.first_time(&"dots_awake")):
		var piece := _impression_of(woke)
		if workshop != null and piece != null:
			workshop.attend(piece.global_position)   # Onion looks toward it with interest
		await Onion.line(DOTS_WOKE, self)
		if state == &"hub":
			await get_tree().create_timer(BREATH, false).timeout
			await Onion.line(DOTS_AWAKE, self)
		if workshop != null:
			workshop.attend(null)
		if state != &"hub":
			if badge != null:
				badge.land_all()
			return
		await get_tree().create_timer(BREATH, false).timeout
	await _stones_rise(stones, grew)


func _stones_rise(stones: int, grew: bool) -> void:
	if badge == null or stones <= 0:
		return
	var mine := badge
	await mine.fly_in(self, _mouth() + Vector3.UP * 0.03, stones, func(at: Vector3) -> void:
		_play(&"stone_clink", at))
	if not is_instance_valid(mine) or state != &"hub":
		return
	if grew:
		var shelf := _impression_of(_activity(&"shelf"))
		if shelf != null:
			shelf.set_rows(_shelf_rows(), 0.4)
	if memory != null and &"stones" in memory.said:
		return
	var house := ring.door
	if house == null or not ring.opened:
		return
	if memory != null:
		memory.first_time(&"stones")
	if workshop != null:
		workshop.attend(house.global_position)   # Onion turns to the house; it glows while Onion speaks
	house.set_waiting(0.8)
	await Onion.line(STONES_YOURS, self)
	await get_tree().create_timer(BREATH, false).timeout
	await Onion.line(STONES_SPEND, self)
	if is_instance_valid(house):
		house.set_waiting(0.0)


## Pressing a game (§5b): with nothing of it finished (or one level), its recommended level, at once. Else its own
## row: the recommended next level big in the middle, the finished ones around it to play again. True = play
## (the level is set on [param activity]); false = back to the menu (a tap on the cauldron, or ROW_WAIT s).
func _choose_level(activity: Summonable) -> bool:
	if activity == null:
		return false
	if badge != null:
		badge.land_all()
	var levels := activity.levels()
	var done := activity.done_levels()
	if levels.size() <= 1 or done.is_empty():
		activity.level = activity.recommended()
		return true
	var best := activity.recommended()
	var shown: Array[Impression] = []
	var middle := 0
	for level in levels:
		if level != best and level not in done:
			continue
		if level == best:
			middle = shown.size()
		var piece := activity.make_impression() as Impression
		piece.title = level.title
		piece.level = level
		if not LevelPiece.dress(piece, level) and piece.kind == &"shelf":
			piece.set_rows(_shelf_rows())
		shown.append(piece)
	await ring.sink(_mouth(), 0.4)
	await _open_row(&"levels", shown, middle)
	var picked := await _wait_row()
	var level: TaskLevel = picked.level if picked != null else null
	await _close_row()
	if level == null:
		await ring.rise(_mouth(), 0.6)
		return false
	activity.level = level
	print("HUB level: ", level.id)
	return true


# --- Rows in the menu's place: a game's levels, the looks ----------------------------------------------------

func _open_row(kind: StringName, pieces: Array[Impression], middle := -1) -> void:
	row_kind = kind
	_row_pressed = null
	_cauldron_tapped = false
	var eye := App.head().global_position
	row = ImpressionRing.make(self, pieces, ImpressionRing.spot(_mouth(), eye), eye, _mouth())
	row.name = "row_%s" % kind
	row.centre = middle
	row.visible = false
	row.opened = false
	row.hovered.connect(func(piece: Impression) -> void:
		_play(&"hover_tink", piece.global_position, Sounds.step(row.impressions.find(piece)))
		_label(piece.label(), true))
	row.chosen.connect(func(piece: Impression) -> void: _row_pressed = piece)
	await row.rise(_mouth(), 0.4)
	_row_since = _clock_real


## Waits for a press in the row (a level: the bubble that popped) or for it to be left: a tap on the cauldron,
## or ROW_WAIT s with no press (null).
func _wait_row() -> Impression:
	while row != null:
		await get_tree().process_frame
		if _row_pressed != null:
			return _row_pressed
		if _cauldron_tapped:
			return null
		if _clock_real - _row_since >= ROW_WAIT:
			return null
	return null


func _close_row() -> void:
	if row == null:
		return
	var leaving := row
	await leaving.sink(_mouth(), 0.4)
	leaving.queue_free()
	if row == leaving:
		row = null
		row_kind = &""
	_cauldron_tapped = false


## The eye in the hub's places row (§6): the menu sinks, the four looks rise; the menu comes back after.
func _looks_from_hub() -> void:
	if _looking or state != &"hub":
		return
	_looking = true
	_stop_tour()
	await ring.sink(_mouth(), 0.4)
	await _show_looks()
	if state == &"hub":
		await ring.rise(_mouth(), 0.6)
	_looking = false


## The looks row: Normal · High contrast · Edges · Black and white, each a little picture of the same scene in
## that look, the current one ringed. A pinch applies one to the real room at once (it stays up); a tap on the
## cauldron or ROW_WAIT s without a press leaves, keeping the last one chosen.
func _show_looks(in_game := false) -> void:
	var pieces: Array[Impression] = []
	for id in HubMemory.LOOKS:
		if in_game or id not in HubMemory.GAME_ONLY:   # Spotlight only in a game (Megan, Nov 18)
			pieces.append(Impression.make_look(id))
	await _open_row(&"looks", pieces)
	for piece in row.impressions:
		piece.set_picked(memory != null and piece.look == memory.look)
	await _wait_row()
	await _close_row()


func _press_look(piece: Impression) -> void:
	if piece.look == &"" or row == null:
		return
	print("HUB look: ", piece.look)
	if memory != null:
		memory.choose_look(piece.look)
	for other in row.impressions:
		other.set_picked(other == piece)
	piece.touched()
	_play(&"hover_tink", piece.global_position, Sounds.step(1))


# --- The ✕ bubble: pausing a game, the finish check (design chat, Nov 18) -------------------------------

## While a game runs: a tap on the cauldron (or the ☰) pauses it and raises one ✕ bubble ("Stop"). Pinch it:
## the game ends (interrupted). No choice in ~6 s, or a second tap: the bubble sinks and the game goes on.
func _watch_cauldron() -> void:
	_cauldron_tapped = false
	while state == &"game" and current != null:
		await get_tree().process_frame
		if not _cauldron_tapped or stop_bubble != null:
			continue
		_cauldron_tapped = false
		print("HUB cauldron tapped: the game pauses")
		App.hold_pause(&"cauldron", true)
		# The eye beside the ✕ in the shelf and Turn to fit (not the dots: their dim must stay the same every round).
		var with_eye := current != null and (current.id() in BENCH_GAMES or current.id() == &"turn_to_fit")
		var chosen := await _offer_stop(&"stop", with_eye)
		if _stop_pick == &"eye":
			await _show_looks(true)   # still paused; leaving the looks, the game carries on
			_stop_pick = &""
		App.hold_pause(&"cauldron", false)
		if chosen:
			print("HUB stop: the game ends")
			_exit_game()
		else:
			print("HUB carry on")


## The finish check (the places row's ✕): "All done for today?", then one ✕ over the brew. True = finish.
func _ask_finish() -> bool:
	state = &"asking"
	_stop_tour()
	await ring.sink(_mouth(), 0.6)
	await Onion.line(ALL_DONE, self)
	var yes := await _offer_stop(&"finish")
	state = &"hub"
	if not yes:
		print("HUB finish: not yet")
		await ring.rise(_mouth())
	return yes


## Raises one ✕ bubble of [param kind] from the brew (with the eye on its left when [param with_eye]: eye · ✕)
## and waits: true if the ✕ was pinched (it pops), false after STOP_WAIT s, a tap on the cauldron (they sink) or
## a pinch on the eye ([member _stop_pick] = &"eye"). Runs while the world is paused.
## Lights the one pause bubble aimed at or nearest a hand (as the menu's), so the lit one is what a pinch takes.
func _light_pause(bubbles: Array[Impression]) -> void:
	var best := 0.0
	_pause_lit = null
	if _clock_real - _stop_since < STOP_GUARD:
		bubbles = []   # still rising: nothing lit yet, so nothing lit ever ignores a pinch
	for piece in bubbles:
		var near := 0.0
		for hand: StringName in [&"left", &"right"]:
			var pointer := App.rig.pointer(hand)
			if pointer == null or not pointer.tracked():
				continue
			if pointer.aimed == piece.target:
				near = 1.0
			var gap := pointer.global_position.distance_to(piece.target.global_position)
			near = maxf(near, clampf(inverse_lerp(ImpressionRing.NEAR_FROM, ImpressionRing.NEAR_FULL, gap), 0.0, 1.0))
		if near > best:
			best = near
			_pause_lit = piece
	for piece in bubbles:
		piece.set_near(best if piece == _pause_lit else 0.0)


func _offer_stop(kind: StringName, with_eye := false) -> bool:
	_stop_chosen = false
	_stop_pick = &""
	_cauldron_tapped = false
	stop_bubble = Impression.make(kind)
	var bubbles: Array[Impression] = [stop_bubble]
	if with_eye:
		eye_bubble = Impression.make(&"eye")
		bubbles.push_front(eye_bubble)
	for piece in bubbles:
		piece.add_bubble()
		add_child(piece)
	var eye := App.head().global_position
	var top := ImpressionRing.spot(_mouth(), eye) + Vector3.DOWN * 0.06
	var toward := Vector3(eye.x - top.x, 0.0, eye.z - top.z).normalized()
	var right := Vector3.UP.cross(toward).normalized()   # the child's right
	var size := STOP_SCALE
	var spots: Array[Vector3] = []
	for i in bubbles.size():
		spots.append(top + right * (i - (bubbles.size() - 1) * 0.5) * 0.15)
	var rise := create_tween()
	rise.tween_method(func(k: float) -> void:
		for i in bubbles.size():
			var piece := bubbles[i]
			piece.scale = Vector3.ONE * size * lerpf(0.2, 1.0, k)
			piece.global_position = _mouth().lerp(spots[i], k) - Vector3.UP * Impression.MIDDLE.y * size * lerpf(0.2, 1.0, k)
			piece.look_at(piece.global_position + toward, Vector3.UP, true)
			piece.scale = Vector3.ONE * size * lerpf(0.2, 1.0, k), 0.0, 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_play(&"brew_rise", _mouth())
	_stop_since = _clock_real
	var labelled := {}
	while _clock_real - _stop_since < STOP_WAIT:
		await get_tree().process_frame
		if _stop_chosen or _stop_pick != &"" or _cauldron_tapped:
			break
		_light_pause(bubbles)
		for piece in bubbles:
			if not labelled.get(piece, false) and _hand_near(piece.target.global_position, 0.12):
				labelled[piece] = _label(piece.label(), true)
	_pause_lit = null
	var chosen := _stop_chosen
	var popped: Impression = stop_bubble if chosen else (eye_bubble if _stop_pick == &"eye" else null)
	if chosen:
		_stop_pick = &"stop"
	if popped != null:
		popped.touched()
		popped.pop()
	var starts: Array[Vector3] = []
	for piece in bubbles:
		starts.append(piece.global_position)
	_play(&"brew_sink", _mouth())   # 0.4 s: shorter than its BREW_LAND, so it starts at once
	var sink := create_tween()
	sink.tween_method(func(k: float) -> void:
		for i in bubbles.size():
			if bubbles[i] != popped and is_instance_valid(bubbles[i]):
				bubbles[i].global_position = starts[i].lerp(_mouth(), k)
				bubbles[i].scale = Vector3.ONE * size * lerpf(1.0, 0.2, k), 0.0, 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await sink.finished
	_drop_stop_bubble()
	_cauldron_tapped = false
	_stop_chosen = false
	return chosen


func _drop_stop_bubble() -> void:
	for piece in [stop_bubble, eye_bubble]:
		if piece != null and is_instance_valid(piece):
			piece.queue_free()
	stop_bubble = null
	eye_bubble = null


func _hand_near(at: Vector3, within: float) -> bool:
	if App.rig == null:
		return false
	for side: StringName in [&"left", &"right"]:
		var pointer := App.rig.pointer(side)
		if pointer != null and (pointer.global_position.distance_to(at) < within or (stop_bubble != null and pointer.aimed == stop_bubble.target)):
			return true
	return false


# --- The controls tour (the ? bubble; design chat, Nov 18) -------------------------------------------------

## Four steps, one control at a time: the thing shown stays bright while the rest of the menu dims to half, the
## teaching hand shows the action, Onion says the line; ~5 s each, on by itself. Any real action stops it.
func _tour() -> void:
	if _touring or state != &"hub":
		return
	_touring = true
	_tour_id += 1
	var mine := _tour_id
	print("HUB tour starts")
	var gear := workshop.gear_node() if workshop != null else null
	await Onion.line(TOUR_OPENING, self)
	if mine != _tour_id or state != &"hub":
		return
	await get_tree().create_timer(BREATH, false).timeout
	for step in TOUR_LINES.size():
		if mine != _tour_id or state != &"hub":
			break
		var shown: Impression = null
		match step:
			1: shown = ring.leader()
			2: shown = ring.door
			3: shown = ring.place_of(&"finish")
		for piece in ring._all():
			piece.set_dim(0.0 if piece == shown else TOUR_DIM)
		_play(&"hover_tink", _mouth(), Sounds.step(-1))
		match step:
			0: _demo.tap(_rim())
			1, 2:
				if shown != null:
					_demo.aim_pinch(shown.target)
			3:
				if gear != null:
					_demo.pinch_lift(gear)
		var began := _clock
		Onion.line(TOUR_LINES[step], self)
		while _clock - began < TOUR_STEP and mine == _tour_id:
			await get_tree().process_frame
	if mine == _tour_id:
		_end_tour()
		if workshop != null:
			workshop.cheer()   # a reassuring nod; no closing line


func _stop_tour() -> void:
	if _touring:
		_tour_id += 1
		print("HUB tour stopped")
		_end_tour()


func _end_tour() -> void:
	_touring = false
	_demo.stop()
	for piece in ring._all():
		piece.set_dim(0.0)


# --- Helpers -------------------------------------------------------------------------------------------

func _impression_of(activity: Summonable) -> Impression:
	for impression in ring.impressions:
		if is_instance_valid(impression) and impression.kind == activity.id():
			return impression
	return null


func _activity(id: StringName) -> Summonable:
	for a in activities:
		if a.id() == id:
			return a
	return null


## The cauldron's rim at the child's side (where the teaching hand taps).
func _rim() -> Vector3:
	var mouth := _mouth()
	var eye := App.head().global_position
	return mouth + Vector3(eye.x - mouth.x, 0.0, eye.z - mouth.z).normalized() * 0.06 + Vector3.UP * 0.01


func _gear_at() -> Vector3:
	var gear := workshop.gear_node() if workshop != null else null
	return gear.global_position if gear != null else _mouth()


func _play(sound: StringName, at: Vector3, pitch := 1.0) -> void:
	var sounds: Variant = workshop.get("_sounds") if workshop != null else null
	if sounds != null and is_instance_valid(sounds):
		(sounds as Sounds).play(sound, at, pitch)


func _mouth() -> Vector3:
	if workshop != null and is_instance_valid(workshop):
		return workshop.mouth()
	return App.head().global_position + Vector3(0, -0.4, -0.6)


## Where Onion waits in the hub: beside the cauldron, lifted (the layout's reveal spot).
func _onion_spot() -> Vector3:
	if workshop != null and workshop.layout != null:
		return workshop.layout.onion_reveal
	return workshop.onion_position() if workshop != null else Vector3.ZERO


## Wei's bench frame (where the opening planned the shelf), or straight ahead.
## Real Life's boards (Wei's desk, bookshelf, sandwich counter: up to 0.82 m wide) stand straight ahead toward
## the table and would swallow the cauldron: it glides sideways, on its own side, until it is clear of them.
## Zero when it already is.
func _cauldron_aside() -> Vector3:
	var head := App.head().global_position
	var toward := App.reality.work_surface().transform.origin - head
	var ahead := Vector3(toward.x, 0.0, toward.z).normalized()
	var side := ahead.cross(Vector3.UP)   # the child's right
	var pot := workshop.cauldron().global_position
	var across := (pot - head).dot(side)
	var clear := REAL_LIFE_HALF + CAULDRON_CLEAR
	if absf(across) >= clear or (pot - head).dot(ahead) > REAL_LIFE_DEEP + CAULDRON_CLEAR:
		return Vector3.ZERO
	return side * ((signf(across) if across != 0.0 else -1.0) * clear - across)


## Glides the cauldron and its tap targets and glow by [param offset].
func _slide_cauldron(offset: Vector3) -> void:
	cauldron_menu.slide(offset, 0.6)
	_play(&"rattle_soft", workshop.cauldron().global_position)
	await workshop.slide_cauldron(offset, 0.6).finished


func _workspace() -> Transform3D:
	if workshop != null and workshop.layout != null:
		return workshop.layout.bench
	return Transform3D(Basis.IDENTITY, App.head().global_position)


func _exit_tree() -> void:
	Lantern.quiet = false
