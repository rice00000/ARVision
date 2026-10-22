extends Node
## The child playing (autoload "Profile"): their files and training levels.
##
##   godot --path . -- --profile=asha
##
## Everything lives in user://profiles/<id>/: progress.json (one difficulty
## level per skill) and logs/ (see Log). Tests use ids starting with "test".

const DEFAULT_ID := &"dev"
## Level a skill starts at, 0 = easiest, 1 = hardest.
const START_LEVEL := 0.3

var id: StringName = DEFAULT_ID

var _levels: Dictionary[StringName, float] = {}
var _streaks: Dictionary[StringName, int] = {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):
			id = StringName(arg.trim_prefix("--profile="))
	var file := FileAccess.open(path("progress.json"), FileAccess.READ)
	if file:
		var data: Dictionary = JSON.parse_string(file.get_as_text())
		_levels.assign(data.levels)
		_streaks.assign(data.streaks)


## Absolute path of [param file] inside this profile's folder.
func path(file := "") -> String:
	return "user://profiles/%s/%s" % [id, file]


func level(skill: StringName) -> float:
	return _levels.get(skill, START_LEVEL)


## Moves [param skill] after a scored round: [param up_after] successes in a row
## make it harder by [param step], one failure makes it easier. 2-up / 1-down
## settles near 71% correct. Returns the new level.
func adapt(skill: StringName, success: bool, up_after: int, step: float) -> float:
	var next := level(skill)
	if success:
		_streaks[skill] = _streaks.get(skill, 0) + 1
		if _streaks[skill] >= up_after:
			next += step
			_streaks[skill] = 0
	else:
		next -= step
		_streaks[skill] = 0
	_levels[skill] = clampf(next, 0.0, 1.0)
	_save()
	return _levels[skill]


## Deletes this profile's files and levels. Tests start from here.
func wipe() -> void:
	_levels.clear()
	_streaks.clear()
	Log.close()
	if DirAccess.dir_exists_absolute(path()):
		_remove(ProjectSettings.globalize_path(path()))


func _save() -> void:
	DirAccess.make_dir_recursive_absolute(path())
	var file := FileAccess.open(path("progress.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({levels = _levels, streaks = _streaks}, "\t"))


func _remove(folder: String) -> void:
	for sub in DirAccess.get_directories_at(folder):
		_remove(folder.path_join(sub))
	for file in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
