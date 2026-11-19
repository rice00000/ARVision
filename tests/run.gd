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
	var test_profile := Profile.id
	var args := OS.get_cmdline_user_args()
	if not String(test_profile).begins_with("test") or not args.has("--profile=" + String(test_profile)):
		push_error("Run the tests with -- --profile=test: they wipe the profile they run on.")
		get_tree().quit(2)
		return
	var only := ""
	for arg in args:
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
			_reset_saves(test_profile)
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
	_reset_saves(test_profile)
	DirAccess.remove_absolute(_test_index(test_profile))
	if passed == 0 and failed.is_empty():
		push_error("No tests matched: %s" % only)
		get_tree().quit(2)
		return
	# Megan, Nov 18: every line the game says must be baked. A line said in the tests with no clip fails the run
	# (lines a test makes up itself, written in a test script, don't count).
	var missing := _unbaked_game_lines()
	if not missing.is_empty():
		print("\nUNBAKED SPEECH: %d line(s) the game says have no voice clip. Bake: python3 tools/bake_speech.py" % missing.size())
		for text in missing:
			print("  ", text)
		failed.append("speech: %d unbaked line(s)" % missing.size())
	print("\nTESTS: %d passed, %d failed" % [passed, failed.size()])
	for name in failed:
		print("  FAILED ", name)
	get_tree().quit(failed.size())


func _test_index(profile: StringName) -> String:
	return Profile.ROOT.path_join("%s.cfg" % profile)


## A case may switch saves. The next case starts on the pinned profile, with a fresh save list.
func _reset_saves(profile: StringName) -> void:
	for save in Profile.saves():
		if String(save).begins_with(String(profile) + "_s"):
			Profile.id = save
			Profile.wipe()
	Profile.id = profile
	DirAccess.remove_absolute(_test_index(profile))
	Profile.wipe()


## The lines said with no baked clip, less those a test script wrote itself.
func _unbaked_game_lines() -> PackedStringArray:
	if BakedSpeech.unbaked.is_empty():
		return []
	var tests := ""
	for path in _scripts("res://tests"):
		tests += FileAccess.get_file_as_string(path)
	var missing := PackedStringArray()
	for text in BakedSpeech.unbaked:
		if not tests.contains(text):
			missing.append(text)
	return missing


func _scripts(folder: String) -> Array[String]:
	var found: Array[String] = []
	for sub in DirAccess.get_directories_at(folder):
		found.append_array(_scripts(folder.path_join(sub)))
	for file in DirAccess.get_files_at(folder):
		if file.ends_with("_test.gd"):
			found.append(folder.path_join(file))
	return found
