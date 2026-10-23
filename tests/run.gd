extends Node
## Test runner: every test_* method of every tests/**/*_test.gd.
##
##   godot --headless --xr-mode off --fixed-fps 60 --path . res://tests/run.tscn -- --profile=test [--only=find]
##
## --fixed-fps 60 runs game time as fast as the machine allows. Without --headless
## it runs only tests/rendered/ (they need rendered frames); headless skips them.
## Uses (and wipes) a "test..." profile. Exit code = number of failed tests.
## A script error fails the test it happens in: it stops the test silently, so
## the expects after it would never run.


## Counts script errors from any thread.
class ScriptErrors:
	extends Logger
	var count := 0
	var _lock := Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String,
			_editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_SCRIPT:
			_lock.lock()
			count += 1
			_lock.unlock()


func _ready() -> void:
	if not String(Profile.id).begins_with("test"):
		push_error("Run the tests with -- --profile=test: they wipe the profile they run on.")
		get_tree().quit(2)
		return
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	var passed := 0
	var failed: Array[String] = []
	var rendered := DisplayServer.get_name() != "headless"
	var errors := ScriptErrors.new()
	OS.add_logger(errors)
	for path in _scripts("res://tests"):
		if path.begins_with("res://tests/rendered/") != rendered or (not only.is_empty() and not path.contains(only)):
			continue
		var script: Script = load(path)
		for method in script.get_script_method_list():
			if not method.name.begins_with("test_"):
				continue
			Profile.wipe()
			var case: TestCase = script.new()
			add_child(case)
			print("%s :: %s" % [path.get_file(), method.name])
			var before := errors.count
			await case.call(method.name)
			await case.shutdown()
			if errors.count > before:
				case.failures.append("%d script error(s)" % (errors.count - before))
			if case.failures.is_empty():
				passed += 1
			else:
				failed.append("%s :: %s" % [path.get_file(), method.name])
			case.queue_free()
	Profile.wipe()
	print("\nTESTS: %d passed, %d failed" % [passed, failed.size()])
	for name in failed:
		print("  FAILED ", name)
	get_tree().quit(failed.size())


func _scripts(folder: String) -> Array[String]:
	var found: Array[String] = []
	for sub in DirAccess.get_directories_at(folder):
		found.append_array(_scripts(folder.path_join(sub)))
	for file in DirAccess.get_files_at(folder):
		if file.ends_with("_test.gd"):
			found.append(folder.path_join(file))
	return found
