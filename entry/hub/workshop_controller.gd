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
##   joins only when it can run. Buds under the shelf and the dots show their next level as a silhouette.
## * **Places:** Wei's room's door sits below the tasks from after the first game, its line "The room has a few
##   surprises left in it." after the next game (≤ 2 lines between the child's actions).
## * **The gear** turns in its socket. Lifting it out ends the visit: Onion asks "All done for today?"; set back
##   in, nothing happens; let go anywhere else, the closing starts (the gear flies home into the cauldron).
## * **During a game** the bubbles sink into the cauldron, the gear can't be lifted, and the
##   exit-task token stands low in front of the cauldron: a pinch on it ends the game (the round is skipped),
##   "We can come back to these.", back to the hub (the menu rises again by itself).
## * **Pause** (headset menu, Staff tools) pauses the world; the running game is told (Summonable.pause/resume).
##   Nothing in the hub times out, and a lost hand never counts as a choice.

signal _picked_signal

const CUE_AFTER := 5.0          # seconds without a tap / choice before the teaching hand shows it (first visit)
const WELCOME := "Welcome to the workshop."
const MORE := "There are more waiting."
const SURPRISES := "The room has a few surprises left in it."
const LEFT_EARLY := "We can come back to these."
const ALL_DONE := "All done for today?"
const ORDER: Array[StringName] = [&"shelf", &"dots", &"turn_to_fit"]
const GLOW := Color(1.0, 0.86, 0.55)    # HubGlow's warm tint
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
const TOUR_DIM := 0.5           # everything the tour isn't showing fades to half
## The controls tour (design chat, Nov 18; step 2 is a pinch, Megan 9:13): what each step says.
const TOUR_LINES: Array[String] = ["Tap the cauldron for games.", "Pinch a bubble to choose.",
		"This goes to the Virtual Workshop.", "Lift the gear to finish."]
const LABEL_QUIET := 1.2        # seconds of Onion's quiet before a label may play
const LABEL_SETTLE := 2.0       # no label in the hub's first seconds (a resting hand sits near)
## Games whose bubble shows a bud (their next level, as a silhouette).
const BUDS: Array[StringName] = [&"shelf", &"dots", &"butterflies"]
## What opens when (Megan, Nov 18): the dots after the first game, the butterflies after the dots, Turn to fit
## (the cup, the last game) after the butterflies and only once it can run (a saved cup setup and the CV server
## answering). One unlock per return to the hub. Locked games show with a padlock from the first visit.
const UNLOCKS: Array[Array] = [[&"dots", &""], [&"butterflies", &"dots"], [&"turn_to_fit", &"butterflies"]]                # Entry.SOCKET_SINK: the seated gear sits this far down in its socket

var workshop: Workshop
var activities: Array[Summonable] = []
var ring: ImpressionRing
## During a game: the cauldron's pause bubble (one ✕, "Stop"); in the hub: the finish check's ✕. Null otherwise.
var stop_bubble: Impression
## The cauldron's tap target (opens the menu) and its glow.
var cauldron_target: Target
var glow := 0.0
## The child lifts the gear out to finish.
var carry: Carry
var lanterns: Array[Lantern] = []   # the workshop's warm lanterns (decor only, never pressed)
var ambience: HubAmbience           # the quiet fireplace crackle under the hub
var current: Summonable
var state := &"idle"            # &"hub", &"game", &"home", &"closing", &"closed"
var played: Array[StringName] = []
var said_more := false
var said_surprises := false
## The menu has been opened by the child at least once.
var ever_opened := false
var _picked: StringName = &""
var _demo: DemoHand
var _was_paused := false
var _exited := false
var _opening := false
var _glow_light: StandardMaterial3D
var _glow_quad: MeshInstance3D
var _poking: Dictionary = {}    # side -> the fingertip is inside the cauldron's reach
## The ☰ over the brew while the menu is closed (Megan, Nov 18: like a phone's menu sign), and its target.
var menu_sign: Node3D
var sign_target: Target
var _games_said := 0
var _hub_since := 0.0           # when the hub last began waiting (seconds)
var _quiet_since := 0.0         # when Onion last finished a line
var _clock := 0.0               # game time, seconds (unpaused)
var _clock_real := 0.0          # time that runs while paused too (the pause bubble's own clock)
var _stop_since := 0.0
var _stop_chosen := false
var _cauldron_tapped := false
var _touring := false
var _tour_id := 0
var _cauldron_hover := false


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
		voice.line_finished.connect(func(_text: String, _completed: bool) -> void:
			_quiet_since = _clock)
		Events.said.connect(func(_text: String) -> void: _quiet_since = INF)   # speaking now: wait for its end
	_build_ring()
	_build_cauldron()
	_build_carry()
	_hang_lanterns()
	ambience = HubAmbience.make(self)
	if first == &"motion":
		first = &"dots"
	var activity := _activity(first)
	if activity != null:
		await _offer(activity, false)
		ever_opened = true   # a DEV jump: the child is past the first tap
		await _run(activity)
	else:
		await _offer(_activity(&"shelf"))
		for unlock: Array in UNLOCKS:   # there's more: each waits in a locked bubble until it opens
			var locked := _activity(unlock[0])
			if locked != null:
				await _offer(locked, false, true)
		if welcome:
			await Onion.line(WELCOME, self)
	while true:
		_picked = &""
		var choice := await _hub()
		if choice == &"gear_finish":
			break
		if choice == &"finish":
			if await _ask_finish():
				break
			continue
		if choice == &"gear_home":
			if home.is_valid():
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
	state = &"closing"
	await _closing_starts()
	if closing.is_valid():
		await closing.call()
	state = &"closed"


# --- The hub ---------------------------------------------------------------------------------------

## The hub: waits for a choice in the menu, or the gear lifted out. Opens the menu on the child's tap.
func _hub() -> StringName:
	state = &"hub"
	_hub_since = _clock
	Lantern.quiet = false   # the lanterns breathe again (and the odd ember rises)
	ambience.hub()
	SceneMarker.show_text("Hub")
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
	_play(&"menu_open", _mouth())
	await ring.rise(_mouth())
	_opening = false


## A game's impression rises into the menu (and comes to the front); with the menu closed it simply joins.
## [param welcome]: Onion's "Welcome to the workshop." then a look at the cauldron (the first visit).
func _offer(activity: Summonable, welcome := false, locked := false) -> void:
	if activity == null or _impression_of(activity) != null:
		return
	var impression := activity.make_impression() as Impression
	if impression == null:
		return
	await ring.add(impression, _mouth())
	if locked:
		impression.set_sealed(true)   # shown, not open yet: a press says "Soon" (Megan: there's more to explore)
	impression.set_bud(impression.kind in BUDS)
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
	ring.quiet(0.3)
	await HubGlow.quiet_all(0.3)
	if ring.opened or ring.visible:
		_play(&"menu_close", _mouth())
		await ring.sink(_mouth(), 0.9)   # Megan, Nov 18: the pieces sink into the cauldron with the fog during a game
	if workshop != null:
		workshop.attend(null)
	print("HUB game: ", activity.id())
	# Wei's bench board can reach the socket at the front right too (Megan's laptop test, Nov 18): it always fades
	# under the board during the shelf, as before (the layout's zones miss the board's real edge on some tables).
	var under_bench := activity.id() == &"shelf" and workshop != null
	if under_bench:
		workshop.hide_socket(true)
	activity.summon(_workspace())
	_watch_cauldron()
	var outcome: StringName = await activity.finished
	if under_bench:
		workshop.hide_socket(false)
	_drop_stop_bubble()
	print("HUB ", activity.id(), " finished: ", outcome)
	Events.report(&"hub_activity_finished", {activity = activity.id(), outcome = outcome})
	activity.fold()
	current = null
	ever_opened = true
	_play(&"menu_open", _mouth())
	await ring.rise(_mouth())   # and the menu rises again by itself, back at the hub
	if not played.has(activity.id()):
		played.append(activity.id())
	ring.wake()
	# After the first game: the dots rise in, the door to Wei's room appears below. One line each, at most 2
	# lines before the child's next action (the game's own ending line was the first).
	await _unlock_next()
	if ring.door == null:
		# The places row, from after the first game (design chat, Nov 18): ? · house · ✕. The house says its own
		# teaser the first time a hand comes to it; ? plays the controls tour; ✕ finishes the visit after Onion asks.
		var house := Impression.make(&"house")
		ring.set_places([Impression.make(&"help"), house, Impression.make(&"finish")] as Array[Impression], house)
	for a in activities:   # Turn to fit (or anything) that can run now
		if a.is_available() and _impression_of(a) == null and a.id() != &"dots":
			await _offer(a)


## Opens the next locked game whose time has come (UNLOCKS), once per return: its lock clicks open and drops away,
## then "There are more waiting.".
func _unlock_next() -> void:
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
		await Onion.line(MORE, self)
		return


## A game is left early through the cauldron's ✕: its round is dropped (interrupted), "We can come back to these."
func _exit_game() -> void:
	if current == null or _exited:
		return
	_exited = true
	print("HUB exit: ", current.id())
	Events.report(&"task_exited", {activity = current.id()})
	current.leave()


func _closing_starts() -> void:
	carry.stop()
	_demo.stop()
	_drop_stop_bubble()
	ambience.fade_out(3.0)
	if ring.visible:
		_play(&"menu_close", _mouth())
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
		_pick(&"gear_home" if impression == ring.door else impression.kind))
	ring.hovered.connect(func(impression: Impression) -> void:
		# A soft glass tink, a little higher for each bubble along the arc, then its name.
		var step := ring.impressions.find(impression)
		_play(&"hover_tink", impression.global_position, 1.0 + 0.08 * (step if step >= 0 else -2))
		if impression == ring.door and not said_surprises:
			# The house introduces itself (Megan, Nov 18, option D): its teaser the first time a hand comes to it.
			if _label(SURPRISES):
				said_surprises = true
			return
		_label(SOON if impression.sealed else Impression.title_for(impression.kind)))
	Events.selected.connect(func(_hand: StringName, target: Target, _o: Vector3, _d: Vector3) -> void: _on_press(target, true))
	Events.touched.connect(func(_hand: StringName, target: Target) -> void: _on_press(target, false))


func _on_press(target: Target, pinched: bool) -> void:
	if target == null:
		return
	if stop_bubble != null and is_instance_valid(stop_bubble) and target == stop_bubble.target:
		if pinched and _clock_real - _stop_since >= STOP_GUARD:
			_stop_chosen = true   # pinch only: a sweep through it never counts
		return
	var on_cauldron := target == cauldron_target or target == sign_target
	if on_cauldron and (state == &"game" or state == &"asking"):
		_cauldron_tapped = true   # a game: pause it (or carry on); the finish check: no, not yet
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


## The cauldron's tap target (the whole pot and a margin, like the opening's) and its warm glow on the brew.
func _build_cauldron() -> void:
	var pot := workshop.cauldron() if workshop != null else null
	var mouth := _mouth()
	var width := 0.3
	if pot != null:
		width = maxf(0.2, (mouth.y - pot.global_position.y) * 2.0 + 0.1)
	cauldron_target = Target.sphere(&"hub_cauldron", width * 0.5)
	add_child(cauldron_target)
	cauldron_target.global_position = (pot.global_position + mouth) * 0.5 if pot != null else mouth
	_glow_light = StandardMaterial3D.new()
	_glow_light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_light.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_light.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow_light.albedo_texture = Onion.soft_dot()
	_glow_light.albedo_color = Color(GLOW, 0.0)
	_glow_light.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.24
	quad.material = _glow_light
	_glow_quad = MeshInstance3D.new()
	_glow_quad.name = "cauldron_glow"
	_glow_quad.mesh = quad
	_glow_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow_quad)
	_glow_quad.global_position = mouth + Vector3.UP * 0.01
	_glow_quad.rotation = Vector3(-PI * 0.5, 0.0, 0.0)   # lies on the brew
	_build_sign(mouth)


## The ☰: three short rounded frosted bars with dark outlines, still, just over the brew, facing the child.
## A hint, not a separate button: tapping it or the cauldron opens the menu.
func _build_sign(mouth: Vector3) -> void:
	menu_sign = Node3D.new()
	menu_sign.name = "menu_sign"
	add_child(menu_sign)
	var eye := App.head().global_position
	menu_sign.global_position = mouth + Vector3.UP * 0.1
	menu_sign.look_at(menu_sign.global_position + Vector3(eye.x - mouth.x, 0.0, eye.z - mouth.z), Vector3.UP, true)
	var frost := Impression._lit(Color(0.97, 0.97, 0.96), true)
	for row in 3:
		var bar := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.008
		capsule.height = 0.07
		bar.mesh = capsule
		bar.material_override = frost
		bar.rotation.z = PI * 0.5   # lying across
		bar.position = Vector3(0.0, (1 - row) * 0.022, 0.0)
		menu_sign.add_child(bar)
	sign_target = Target.sphere(&"hub_menu_sign", 0.06)
	menu_sign.add_child(sign_target)
	menu_sign.visible = false


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
		_stop_tour()
		_play(&"gear_lift", _gear_at())
		print("HUB gear lifted")
		Onion.line(ALL_DONE, self))
	carry.docked.connect(func() -> void:
		_play(&"seat", _gear_at())
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
	var paused := get_tree().paused
	if paused == _was_paused:
		return
	_was_paused = paused
	print("HUB ", "paused" if paused else "resumed", " (", state, ")")
	if current != null:
		if paused:
			current.pause()
		else:
			current.resume()


## The cauldron glows while the menu is closed in the hub and a hand comes near or aims at it; a fingertip
## going into its reach taps it.
func _cauldron_step(delta: float) -> void:
	if cauldron_target == null:
		return
	var open_to_tap := state == &"hub" and not ring.opened and not _opening and not get_tree().paused
	# During a game (and the finish check) the cauldron takes a tap too: it pauses the game (design chat, Nov 18).
	var tap_in_game := state == &"game" or state == &"asking"
	cauldron_target.collision_layer = Pointer.TARGET_LAYER if open_to_tap or tap_in_game else 0   # nothing to aim at over the open menu
	var want := 0.0
	if open_to_tap and App.rig:
		for side: StringName in [&"left", &"right"]:
			var pointer := App.rig.pointer(side)
			if pointer == null:
				continue
			if pointer.aimed == cauldron_target:
				want = 1.0
			if tap_in_game and pointer.tracked() and App.xr != null:
				var poke := pointer.tip().distance_to(cauldron_target.global_position) <= _cauldron_radius()
				var poked: bool = _poking.get(side, false)
				_poking[side] = poke
				if poke and not poked:
					_cauldron_tapped = true
			if pointer.tracked() and open_to_tap:
				var gap := pointer.tip().distance_to(cauldron_target.global_position)
				want = maxf(want, clampf(inverse_lerp(GLOW_NEAR_FROM, GLOW_NEAR_FULL, gap), 0.0, 1.0))
				var inside := gap <= _cauldron_radius()
				var was: bool = _poking.get(side, false)
				_poking[side] = inside
				if inside and not was and App.xr != null:
					_open_menu()   # a headset fingertip into the pot (desktop: the click)
	if open_to_tap and not ever_opened:
		want = maxf(want, 0.4)   # the first time it waits glowing softly ("you can tap me")
	menu_sign.visible = open_to_tap or state == &"game"   # the still ☰ stays over the brew during a game
	sign_target.collision_layer = Pointer.TARGET_LAYER if open_to_tap or tap_in_game else 0
	# The sound label: a hand coming to the cauldron, the first few times, "Games".
	if want >= 0.6 and not _cauldron_hover and open_to_tap:
		_cauldron_hover = true
		if _games_said < GAMES_TIMES:
			_games_said += 1
			_label(GAMES)
	elif want < 0.45:
		_cauldron_hover = false
	glow = move_toward(glow, want, delta * (3.0 if want > glow else 1.5))
	_glow_light.albedo_color.a = glow * 0.35
	_glow_quad.visible = glow > 0.003


## Says a bubble's (or the cauldron's) name, quietly: only when Onion has been quiet for a moment
## ([constant LABEL_QUIET] s) and not in the hub's first [constant LABEL_SETTLE] s, so a label never stacks
## on a line (Megan, Nov 18, issue 5). True if it was said.
func _label(text: String, anywhere := false) -> bool:
	if text == "" or (state != &"hub" and not anywhere):
		return false
	var now := _clock
	if now - _hub_since < LABEL_SETTLE or now - _quiet_since < LABEL_QUIET:
		return false
	var voice := App.module(&"Voice")
	if voice != null and voice.has_method(&"speaking") and voice.speaking() != "":
		return false
	print("HUB label: ", text)
	Onion.line(text, self)
	return true


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
		if current != null:
			current.pause()
		var chosen := await _offer_stop(&"stop")
		App.hold_pause(&"cauldron", false)
		if current != null:
			current.resume()
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


## Raises one ✕ bubble of [param kind] from the brew and waits: true if it was pinched (it pops), false after
## STOP_WAIT s or a tap on the cauldron (it sinks). Runs while the world is paused.
func _offer_stop(kind: StringName) -> bool:
	_stop_chosen = false
	_cauldron_tapped = false
	stop_bubble = Impression.make(kind)
	stop_bubble.add_bubble()
	add_child(stop_bubble)
	var eye := App.head().global_position
	var top := ImpressionRing.spot(_mouth(), eye) + Vector3.DOWN * 0.06
	var size := STOP_SCALE
	var rise := create_tween()
	rise.tween_method(func(k: float) -> void:
		stop_bubble.scale = Vector3.ONE * size * lerpf(0.2, 1.0, k)
		stop_bubble.global_position = _mouth().lerp(top, k) - Vector3.UP * Impression.MIDDLE.y * size * lerpf(0.2, 1.0, k)
		stop_bubble.look_at(stop_bubble.global_position + Vector3(eye.x - top.x, 0.0, eye.z - top.z), Vector3.UP, true)
		stop_bubble.scale = Vector3.ONE * size * lerpf(0.2, 1.0, k), 0.0, 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_play(&"menu_open", _mouth())
	_stop_since = _clock_real
	var labelled := false
	while _clock_real - _stop_since < STOP_WAIT:
		await get_tree().process_frame
		if _stop_chosen:
			break
		if _cauldron_tapped:
			break
		if not labelled and _hand_near(stop_bubble.target.global_position, 0.12):
			labelled = _label(Impression.title_for(kind), true)
	var chosen := _stop_chosen
	if chosen:
		stop_bubble.touched()
		stop_bubble.pop()
		await get_tree().create_timer(0.35, true).timeout
	else:
		var at := stop_bubble.global_position
		var sink := create_tween()
		sink.tween_method(func(k: float) -> void:
			stop_bubble.global_position = at.lerp(_mouth(), k)
			stop_bubble.scale = Vector3.ONE * size * lerpf(1.0, 0.2, k), 0.0, 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await sink.finished
	_drop_stop_bubble()
	_cauldron_tapped = false
	_stop_chosen = false
	return chosen


func _drop_stop_bubble() -> void:
	if stop_bubble != null and is_instance_valid(stop_bubble):
		stop_bubble.queue_free()
	stop_bubble = null


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
		_play(&"hover_tink", _mouth(), 0.9)
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


## True while the cauldron's glow is lit.
func cauldron_lit() -> bool:
	return glow > 0.003


func _cauldron_radius() -> float:
	return ((cauldron_target.get_child(0) as CollisionShape3D).shape as SphereShape3D).radius


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
func _workspace() -> Transform3D:
	if workshop != null and workshop.layout != null:
		return workshop.layout.bench
	return Transform3D(Basis.IDENTITY, App.head().global_position)


func _exit_tree() -> void:
	Lantern.quiet = false
