class_name TurnToFitActivity
extends Summonable
## Turn to fit in the workshop hub (Megan, Nov 18; `claude/SCENE_REVIEW_DECISIONS.md` → "Turn to fit"):
## the cup's bubble in the cauldron's menu. Replaces the hub's stand-in `TurnToFitSlot` (never available).
##
## * Offered (is_available) once this player has a saved cup setup (Staff tools → Scenes → "Turn to fit (real cup)", the setup page) AND the
##   CV server answers. Not tied to "cup seen" (it flickers whenever the cup leaves the camera's view): if the
##   cup isn't in view when the game starts, the game asks for it.
## * summon(): one go (TurnToFitGame) at the child's table spot (62 cm ahead; the hub's workspace, Wei's bench,
##   isn't used). finished: &"done", or &"left" after [method leave] (the exit token).
## * pause()/resume(): the game node pauses with the world by itself (it's PAUSABLE under the always-running
##   controller); nothing else to do.

## How often the CV server is asked "are you there?" (GET /health), and how long an answer may take.
const PROBE_EVERY := 3.0
const PROBE_TIMEOUT := 1.5

## The server answered the last probe.
var server_ok := false
## Tests: skip the HTTP probe and use this instead (true / false); null = probe for real.
var server_override: Variant = null
## Tests: a camera for the game (see TurnToFitGame.frame_source).
var frame_source := Callable()
## Tests: no HTTP for the game's tracker either.
var use_server := true
## Tests: track on the main thread, so rounds play out the same way every run.
var threaded := true
var current: TurnToFitGame

var _probe := HTTPRequest.new()
var _since_probe := PROBE_EVERY
var _probing := false


func _init() -> void:
	name = "TurnToFitActivity"


func _ready() -> void:
	_probe.timeout = PROBE_TIMEOUT
	add_child(_probe)
	_probe.request_completed.connect(_on_probe)


func id() -> StringName:
	return &"turn_to_fit"


func is_available() -> bool:
	return TurnToFitGame.has_setup() and (server_override if server_override != null else server_ok)


func summon(_workspace: Transform3D) -> void:
	current = TurnToFitGame.new()
	current.frame_source = frame_source
	current.tracker.use_server = use_server
	current.tracker.threaded = threaded
	current.tracker.server = server()
	var parent := get_parent()
	current.workshop = parent.get("workshop") if parent != null and &"workshop" in parent else null
	add_child(current)
	var outcome: StringName = await current.play()
	finished.emit(outcome)


func leave() -> void:
	if current != null and is_instance_valid(current):
		current.leave()


func fold() -> void:
	if current != null and is_instance_valid(current):
		current.queue_free()
	current = null


## The CV server's address: the one saved in Staff tools, a launch flag, or the laptop default.
static func server() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cv-server="):
			return arg.trim_prefix("--cv-server=")
	var saved := FitTracker.saved_server()
	return saved if saved != "" else FitTracker.DEFAULT_SERVER


func _process(delta: float) -> void:
	if server_override != null or _probing or current != null:
		return
	_since_probe += delta
	if _since_probe >= PROBE_EVERY:
		_since_probe = 0.0
		_probing = _probe.request(server() + "/health") == OK


func _on_probe(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_probing = false
	server_ok = result == HTTPRequest.RESULT_SUCCESS and code == 200
