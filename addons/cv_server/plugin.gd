@tool
extends EditorPlugin
## Turn to fit's camera server (tools/cv_server.py) runs while the project is open in the editor (Megan, Nov 18
## 6:24): no Terminal tab to remember, for laptop play and for the Quest over USB (adb reverse tcp:8765 tcp:8765).
## * If a server already answers on 127.0.0.1:8765 (one started by hand), it is left alone.
## * Otherwise it tries each Python in turn until one keeps the server up: $ARVISION_CV_PYTHON, $ARVISION_PYTHON,
##   ../cv-env, ../tts-env, .venv, then python3. A Python without `ultralytics` exits at once and the next is tried.
## * The server's output goes to build/cv_server.log. It stops when the editor closes (or crashes).
## * Never in headless runs (the tests' class import), so tests never start it.
## The toolbar shows "CV server: …".

const SERVER := "res://tools/cv_server.py"
const LOG := "res://build/cv_server.log"
const HEALTH := "http://127.0.0.1:8765/health"
const CHECK_EVERY := 2.0
const START_PATIENCE := 40.0   # seconds a starting server may take to answer (loading the model)

var _status: Label
var _probe: HTTPRequest
var _pid := -1
var _candidates: PackedStringArray = []
var _tried := 0
var _since_start := 0.0
var _since_check := CHECK_EVERY
var _checking := false
var _ours := false


func _enter_tree() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_status = Label.new()
	_status.text = "CV server: checking"
	add_control_to_container(CONTAINER_TOOLBAR, _status)
	_probe = HTTPRequest.new()
	_probe.timeout = 1.5
	add_child(_probe)
	_probe.request_completed.connect(_on_probe)
	_candidates = _pythons()
	_check()


func _exit_tree() -> void:
	if _status == null:
		return
	_stop()
	remove_control_from_container(CONTAINER_TOOLBAR, _status)
	_status.queue_free()
	_probe.queue_free()


func _process(delta: float) -> void:
	if _status == null:
		return
	if _pid > 0:
		_since_start += delta
		if not OS.is_process_running(_pid):   # this Python couldn't run it (no ultralytics?): the next one
			_pid = -1
			_ours = false
			_start_next()
			return
	_since_check += delta
	if _since_check >= CHECK_EVERY and not _checking:
		_check()


func _check() -> void:
	_since_check = 0.0
	_checking = true
	if _probe.request(HEALTH) != OK:
		_checking = false


func _on_probe(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_checking = false
	var answered := result == HTTPRequest.RESULT_SUCCESS and code == 200
	if answered:
		_status.text = "CV server: on" if _ours else "CV server: on (yours)"
		return
	if _pid > 0:
		if _since_start > START_PATIENCE:   # running but never answering: give up on this one
			_stop()
			_start_next()
		else:
			_status.text = "CV server: starting"
		return
	if _tried == 0:
		_start_next()
	elif _tried >= _candidates.size():
		_status.text = "CV server: off (see build/cv_server.log)"


func _start_next() -> void:
	while _tried < _candidates.size():
		var python := _candidates[_tried]
		_tried += 1
		var project := ProjectSettings.globalize_path("res://")
		var log_path := ProjectSettings.globalize_path(LOG)
		DirAccess.make_dir_recursive_absolute(log_path.get_base_dir())
		# The server runs under a small watcher: it stops when the editor goes, even after a crash or a force quit.
		var command := ("cd %s && %s %s >> %s 2>&1 & c=$!; trap 'kill $c 2>/dev/null' EXIT INT TERM; "
				+ "while kill -0 %d 2>/dev/null && kill -0 $c 2>/dev/null; do sleep 2; done") % [_q(project), _q(python),
				_q(ProjectSettings.globalize_path(SERVER)), _q(log_path), OS.get_process_id()]
		_pid = OS.create_process("/bin/sh", PackedStringArray(["-c", command]), false)
		if _pid > 0:
			_ours = true
			_since_start = 0.0
			_status.text = "CV server: starting"
			return
	_pid = -1
	_status.text = "CV server: off (see build/cv_server.log)"


func _stop() -> void:
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = -1
	_ours = false


## [param text] quoted for /bin/sh.
static func _q(text: String) -> String:
	return "'" + text.replace("'", "'\\''") + "'"


## The Pythons to try, first wins (only ones that exist, then python3 from the PATH).
func _pythons() -> PackedStringArray:
	var project := ProjectSettings.globalize_path("res://")
	var bin := "bin/python"
	var list := PackedStringArray()
	for candidate in [OS.get_environment("ARVISION_CV_PYTHON"), OS.get_environment("ARVISION_PYTHON"),
			project.path_join("../cv-env/" + bin).simplify_path(), project.path_join("../tts-env/" + bin).simplify_path(),
			project.path_join(".venv/" + bin)]:
		if not candidate.is_empty() and FileAccess.file_exists(candidate) and not list.has(candidate):
			list.append(candidate)
	for fallback in ["/opt/homebrew/bin/python3", "/usr/local/bin/python3", "python3"]:
		if (fallback == "python3" or FileAccess.file_exists(fallback)) and not list.has(fallback):
			list.append(fallback)
	return list
