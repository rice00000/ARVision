@tool
extends EditorPlugin
## One background Python worker owns the guide speech: watching, debouncing and generation.

const BAKER := "res://tools/bake_speech.py"
const STATUS := "res://.godot/speech-bake-status.json"
var _pid := -1
var _poll := 0.0
var _last_report := ""
var _status: Label


## The Python that bakes. Kokoro (content/voice/speech.tts) needs a Python with it
## installed; the first that exists wins: $ARVISION_PYTHON, a tts-env next to the
## project (python3 -m venv ../tts-env), a .venv inside it, else the system Python.
func _python() -> String:
	var project := ProjectSettings.globalize_path("res://")
	var bin := "Scripts/python.exe" if OS.has_feature("windows") else "bin/python"
	for candidate in [OS.get_environment("ARVISION_PYTHON"), project.path_join("../tts-env/" + bin).simplify_path(),
			project.path_join(".venv/" + bin)]:
		if not candidate.is_empty() and FileAccess.file_exists(candidate):
			return candidate
	return "python3" if OS.has_feature("macos") else "python"


func _enter_tree() -> void:
	_status = Label.new()
	_status.text = "Speech: checking"
	add_control_to_container(CONTAINER_TOOLBAR, _status)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STATUS))
	_pid = OS.create_process(_python(), PackedStringArray([
		ProjectSettings.globalize_path(BAKER), "--watch", "--status", ProjectSettings.globalize_path(STATUS),
	]), false)
	if _pid < 0:
		_status.text = "Speech: Python unavailable"


func _exit_tree() -> void:
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	remove_control_from_container(CONTAINER_TOOLBAR, _status)
	_status.queue_free()


func _process(delta: float) -> void:
	_poll += delta
	if _poll < 0.25:
		return
	_poll = 0.0
	if _pid > 0 and not OS.is_process_running(_pid):
		_pid = -1
		_status.text = "Speech: error"
		push_error("Speech worker stopped. Run %s tools/bake_speech.py to see the error." % _python())
	if not FileAccess.file_exists(STATUS):
		return
	var source := FileAccess.get_file_as_string(STATUS)
	if source == _last_report:
		return
	_last_report = source
	var report: Dictionary = JSON.parse_string(source)
	_status.text = "Speech: " + report.state
	if report.state == "generating":
		_status.text += " %d / %d" % [report.done, report.total]
	elif report.state == "ready" and report.generated > 0:
		EditorInterface.get_resource_filesystem().scan()
	elif report.state == "error":
		push_error("[Speech] " + report.message)


func _build() -> bool:
	if _status.text != "Speech: ready":
		push_warning("Wait for Speech: ready before running.")
		return false
	var output := []
	var result := OS.execute(_python(), PackedStringArray([ProjectSettings.globalize_path(BAKER), "--check"]), output, true)
	if result != 0:
		push_warning("Speech is updating or failed. Check the toolbar, then run again.\n" + "".join(output))
	return result == 0
