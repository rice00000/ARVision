extends Node
## Simulation server: boots the real main.tscn on the simulated room and lets a
## local client (tools/sim/client.py) play it, one JSON object per line over
## TCP on 127.0.0.1.
##
##   godot --headless --xr-mode off --fixed-fps 60 --path . res://tools/sim/server.tscn
##       -- --profile=test_x --port=N --out=<dir> [--plan=res://... | --plan-spec=<json file>]
##       [--unplug=Detector,Voice] [--seat=x,z,yaw] [--eye=1.15] [--keep-profile] [--cv-server=<url>]
##
## Lockstep: the world only moves while a command runs. Between commands the
## engine waits for the next line, so game time never depends on how fast the
## client thinks. With --fixed-fps every frame is 1/60 s of game time.
##
## It acts only through the child's real input path: SimInput head and hand
## poses (moved over time), hand inputs and tracking. It never emits
## events, never calls trial or session methods and runs no client code; it
## only reads engine facts (see observe.gd).

const Observe := preload("res://tools/sim/observe.gd")
## Seconds without a command (real time) before the server gives up and quits.
const IDLE_LIMIT := 300.0
const ACTIONS: Array[StringName] = [&"trigger_click", &"grip_click", &"menu_pressed"]

var _server := TCPServer.new()
var _peer: StreamPeerTCP
var _buffer := PackedByteArray()
var _busy := false
var _out := ""
var _trace: FileAccess
## Every event since boot: {seq, t, event, ...}.
var _events: Array[Dictionary] = []
## Events already sent to the client.
var _sent := 0
## Game seconds since boot.
var _clock := 0.0
var _lost: Dictionary[StringName, bool] = {}
var _main: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100 # read commands before anything else moves this frame
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=", true, 1)
		args[pair[0]] = pair[1] if pair.size() > 1 else ""
	if not String(Profile.id).begins_with("test"):
		push_error("The sim server needs a test profile (--profile=test_...): it wipes it.")
		get_tree().quit(2)
		return
	if not args.has("keep-profile"):
		Profile.wipe()
	_out = args.out
	DirAccess.make_dir_recursive_absolute(_out)
	_trace = FileAccess.open(_out.path_join("trace.jsonl"), FileAccess.WRITE)
	_listen_to_events()
	_main = load("res://main.tscn").instantiate()
	_main.initial_scene = "intro" if args.has("entry") else "find_object"
	if args.has("plan-spec"):
		_main.plan = _plan(JSON.parse_string(FileAccess.get_file_as_string(args["plan-spec"])))
	for module_name in String(args.get("unplug", "")).split(",", false):
		_main.get_node("Modules/" + module_name).free() # what deleting the node from main.tscn does
	if args.has("seat"):
		var seat := String(args.seat).split_floats(",")
		_main.get_node(^"Rig").transform = Transform3D(Basis(Vector3.UP, deg_to_rad(seat[2])), Vector3(seat[0], 0.0, seat[1]))
	if args.has("cv-server"):
		var detector := _main.get_node(^"Modules/Detector")
		detector.backend = 2 # Backend.REMOTE
		detector.server = args["cv-server"]
	get_tree().root.add_child.call_deferred(_main)
	if args.has("eye"):
		_main.ready.connect(func() -> void:
			App.sim_input.set_head(App.rig.global_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, float(args.eye), 0.0))))
	var error := _server.listen(int(args.port), "127.0.0.1")
	if error != OK:
		push_error("Sim server port: %s" % error_string(error))
		get_tree().quit(2)
		return
	print("SIM READY port=%s out=%s" % [args.port, _out])


func _process(delta: float) -> void:
	_clock += delta
	if _busy or _main == null or not _main.is_node_ready():
		return
	while not _busy:
		var request := _next_request()
		if request.is_empty():
			get_tree().quit()
			return
		_trace_line({kind = "command", command = request})
		_busy = true
		_run(request)
		if request.get("op") == "quit":
			return


## Blocks the whole engine until a full line arrives. Empty on disconnect or idle timeout.
func _next_request() -> Dictionary:
	var since := Time.get_ticks_msec()
	while true:
		var newline := _buffer.find(10)
		if newline >= 0:
			var line := _buffer.slice(0, newline).get_string_from_utf8()
			_buffer = _buffer.slice(newline + 1)
			var parsed: Variant = JSON.parse_string(line)
			return parsed if parsed is Dictionary else {op = "invalid", line = line}
		if _peer == null:
			if _server.is_connection_available():
				_peer = _server.take_connection()
				_peer.set_no_delay(true)
		else:
			_peer.poll()
			if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
				return {}
			var available := _peer.get_available_bytes()
			if available > 0:
				_buffer.append_array(_peer.get_data(available)[1])
				continue
		if Time.get_ticks_msec() - since > IDLE_LIMIT * 1000.0:
			return {}
		OS.delay_usec(100)
	return {}


func _run(request: Dictionary) -> void:
	var reply: Dictionary = await _execute(request)
	if not reply.has("ok"):
		reply.ok = true
	reply.events = _events.slice(_sent)
	_sent = _events.size()
	reply.t = _clock
	_trace_line({kind = "reply", op = request.get("op"), ok = reply.ok, error = reply.get("error", "")})
	_peer.put_data((JSON.stringify(Log.plain(reply)) + "\n").to_utf8_buffer())
	_busy = false
	if request.get("op") == "quit":
		get_tree().quit()


func _execute(cmd: Dictionary) -> Dictionary:
	match cmd.get("op", ""):
		"observe":
			return {observation = Observe.everything(_clock, _events.size())}
		"wait":
			await _advance(float(cmd.seconds))
			return {}
		"run":
			return {matched = await _run_until(cmd.until, float(cmd.timeout))}
		"head":
			var head := App.rig.head.global_transform
			var eye := _vector(cmd.position) if cmd.has("position") else head.origin
			var basis := _aim(_vector(cmd.at) - eye) if cmd.has("at") else head.basis
			await _glide(func(pose: Transform3D) -> void: App.sim_input.set_head(pose),
				head, Transform3D(basis, eye), float(cmd.get("seconds", 0.0)))
			return {}
		"hand":
			var side := StringName(cmd.side)
			if _lost.has(side):
				return {ok = false, error = "%s hand is not tracked" % side}
			var hand := App.rig.hand(side).global_transform
			var at := _vector(cmd.position)
			var basis := _aim(_vector(cmd.at) - at) if cmd.has("at") else hand.basis
			await _glide(func(pose: Transform3D) -> void: App.sim_input.set_hand(side, pose),
				hand, Transform3D(basis, at), float(cmd.get("seconds", 0.0)))
			return {}
		"button":
			var action := StringName(cmd.action)
			if action not in ACTIONS:
				return {ok = false, error = "unknown button %s" % action}
			App.sim_input.press(StringName(cmd.side), action, bool(cmd.pressed))
			return {}
		"track":
			var side := StringName(cmd.side)
			if cmd.on:
				_lost.erase(side)
			else:
				_lost[side] = true
			App.sim_input.track(side, bool(cmd.on))
			return {}
		"probe":
			return {probe = Observe.sweep(cmd.points, float(cmd.radius))}
		"capture":
			if DisplayServer.get_name() == "headless":
				return {ok = false, error = "capture needs a rendered run (--rendered)"}
			for i in 3:
				await RenderingServer.frame_post_draw
			var path := _out.path_join(String(cmd.name).get_file() + ".png")
			return {ok = get_viewport().get_texture().get_image().save_png(path) == OK, path = path}
		"quit":
			return {}
	return {ok = false, error = "unknown op %s" % cmd.get("op", "")}


## Moves something from [param from] to [param to] over [param seconds] of game time, one frame at a
## time, then lets one frame pass at the end so everything reacting to poses (rays, overlaps) has seen it.
func _glide(apply: Callable, from: Transform3D, to: Transform3D, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		apply.call(from.interpolate_with(to, elapsed / seconds))
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	apply.call(to)
	await get_tree().process_frame


func _advance(seconds: float) -> void:
	var end := _clock + seconds
	while _clock < end - 0.0001:
		await get_tree().process_frame


## Runs until a new event matches one of [param specs] ({event, what?}), at most [param timeout] seconds.
func _run_until(specs: Array, timeout: float) -> Variant:
	var from := _events.size()
	var end := _clock + timeout
	while true:
		for i in range(from, _events.size()):
			for spec: Dictionary in specs:
				if _events[i].event == spec.event and (not spec.has("what") or _events[i].get("what") == spec.what):
					return _events[i]
		from = _events.size()
		if _clock >= end:
			return null
		await get_tree().process_frame
	return null


## A basis looking along [param direction]; straight up or down keeps the head's forward as up.
func _aim(direction: Vector3) -> Basis:
	var up := Vector3.UP if absf(direction.normalized().y) < 0.99 else -App.rig.head.global_basis.z
	return Basis.looking_at(direction, up)


func _listen_to_events() -> void:
	Events.said.connect(func(text: String) -> void: _record("said", {text = text}))
	Events.feedback.connect(func(kind: StringName, at: Vector3) -> void: _record("feedback", {kind = kind, at = at}))
	Events.view_changed.connect(func(view: Dictionary) -> void: _record("view_changed", {view = view}))
	Events.trial_started.connect(func(trial: StringName, condition: Dictionary) -> void:
		_record("trial_started", {trial = trial, condition = condition}))
	Events.trial_ended.connect(func(skill: StringName, success: bool, data: Dictionary) -> void:
		_record("trial_ended", {skill = skill, success = success, data = data}))
	Events.block_started.connect(func(index: int, info: Dictionary) -> void:
		_record("block_started", {index = index, info = info}))
	Events.session_finished.connect(func() -> void: _record("session_finished", {}))
	Events.reported.connect(func(what: StringName, data: Dictionary) -> void: _record("reported", {what = what, data = data}))
	Events.facilitator_toggled.connect(func(open: bool) -> void: _record("facilitator_toggled", {open = open}))
	Events.selected.connect(func(hand: StringName, target: Target, _origin: Vector3, _direction: Vector3) -> void:
		_record("selected", {hand = hand, target = target.id if target else ""}))
	Events.touched.connect(func(hand: StringName, target: Target) -> void: _record("touched", {hand = hand, target = target.id}))
	Events.help_requested.connect(func() -> void: _record("help_requested", {}))
	Events.hand_tracking.connect(func(hand: StringName, tracked: bool) -> void:
		_record("hand_tracking", {hand = hand, tracked = tracked}))


func _record(event: String, data: Dictionary) -> void:
	data.merge({seq = _events.size() + 1, t = _clock, event = event})
	_events.append(Log.plain(data))
	_trace_line({kind = "event", data = _events.back()})


func _trace_line(entry: Dictionary) -> void:
	_trace.store_line(JSON.stringify(Log.plain(entry)))


## A SessionPlan from a JSON spec: {greeting, farewell, blocks: [{trial, rounds, probe,
## difficulty, pins, view, intro, pause_between}]}, resources as res:// paths.
func _plan(spec: Dictionary) -> SessionPlan:
	var plan := SessionPlan.new()
	plan.title = spec.get("title", "Simulation")
	plan.greeting = spec.get("greeting", "")
	plan.farewell = spec.get("farewell", "")
	for entry: Dictionary in spec.blocks:
		var block := Block.new()
		block.trial = load(entry.trial)
		block.rounds = int(entry.get("rounds", 1))
		block.probe = entry.get("probe", false)
		block.difficulty = entry.get("difficulty", -1.0)
		for axis: String in entry.get("pins", {}):
			block.pins[StringName(axis)] = float(entry.pins[axis])
		if entry.has("view"):
			block.view = load(entry.view)
		block.intro = entry.get("intro", "")
		block.ray = entry.get("ray", true)
		block.pause_between = entry.get("pause_between", 1.5)
		plan.blocks.append(block)
	return plan


func _vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])
