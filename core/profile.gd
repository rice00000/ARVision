extends Node
## Profile (autoload "Profile"): who is playing, as in XRVision. Several
## children share one headset, so each has a save of their own:
## [codeblock]
## user://profiles/<id>/save.json   progress and training levels (Save)
## user://profiles/<id>/logs/       the research log (Log)
## [/codeblock]
## The team names saves and picks them on the facilitator panel; a child never
## sees this. user://profiles.cfg lists them and remembers the one in use.
##
## [b]Opening a save is the one way state is replaced[/b]: switching and Start
## fresh go through it. Everything is written, the game in play goes (Main.restart),
## the files are swapped, everything loads from them and a fresh game starts.
## Nothing is patched in place, so nothing from the last child is left behind.
##
## [code]-- --profile=<id>[/code] picks one for this run only (tests, tools): it
## never changes the headset's list. Saves made in such a run are listed in
## profiles/<id>.cfg and named <id>_s2, <id>_s3..., so they go with that profile.

const ROOT := "user://profiles/"
const INDEX := "user://profiles.cfg"
const SAVE_FILE := "save.json"
## Level a skill starts at, 0 = easiest, 1 = hardest.
const START_LEVEL := 0.3

## The save in use.
var id: StringName = &""
var save_key := "levels"

## Chosen on the command line.
var _pin: StringName = &""
var _levels: Dictionary[StringName, float] = {}
var _streaks: Dictionary[StringName, int] = {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):
			_pin = StringName(arg.trim_prefix("--profile="))
	if not _pin.is_empty():
		id = _pin
		if saves().is_empty():
			_list([_pin])
		return
	id = StringName(_index().get_value("profiles", "current", ""))
	if not saves().has(id):
		id = saves()[0] if not saves().is_empty() else new_save()
		_remember()


func save_state() -> Dictionary:
	return {levels = _levels, streaks = _streaks}


func load_state(data: Dictionary) -> void:
	_levels.assign(data.get("levels", {}))
	_streaks.assign(data.get("streaks", {}))


## Absolute path of [param file] inside this save's folder.
func path(file := "") -> String:
	return "%s%s/%s" % [ROOT, id, file]


## The saves on this headset, oldest first.
func saves() -> Array[StringName]:
	var found: Array[StringName] = []
	for save: String in _index().get_value("profiles", "saves", []):
		found.append(StringName(save))
	return found


## What the panel calls [param save]: its name, else "Save 2".
func label(save: StringName = id) -> String:
	var title: String = _index().get_value("names", String(save), "")
	if not title.is_empty():
		return title
	var number := String(save).trim_prefix(_prefix()).trim_prefix("s")
	return "Save %s" % number if number.is_valid_int() else String(save)


## When [param save] was last written (unix time), or 0 if it never was.
func played(save: StringName) -> int:
	var file := "%s%s/%s" % [ROOT, save, SAVE_FILE]
	return FileAccess.get_modified_time(file) if FileAccess.file_exists(file) else 0


## Adds an empty save called [param title] and returns its id. Does not switch to it.
func new_save(title := "") -> StringName:
	var known := saves()
	var number := 1
	while known.has(StringName("%ss%d" % [_prefix(), number])):
		number += 1
	var save := StringName("%ss%d" % [_prefix(), number])
	_remove(ProjectSettings.globalize_path(ROOT + String(save))) # left by a wiped test profile
	known.append(save)
	_list(known)
	if not title.is_empty():
		var index := _index()
		index.set_value("names", String(save), title)
		index.save(_index_path())
	return save


## Adds a save called [param title] holding this save's progress as it is on
## disk, and returns its id. Not the research log: that records what this child
## did, once. Does not switch to it.
func copy(title := "") -> StringName:
	var save := new_save(title)
	DirAccess.make_dir_recursive_absolute(ROOT + String(save))
	if FileAccess.file_exists(path(SAVE_FILE)):
		DirAccess.copy_absolute(path(SAVE_FILE), "%s%s/%s" % [ROOT, save, SAVE_FILE])
	return save


## Plays [param save] from where it left off: the game in play ends and starts again.
func switch(save: StringName) -> void:
	Events.report(&"save_switched", {from = String(id), to = String(save)})
	Save.write()
	App.main.restart.call_deferred(func() -> void:
		id = save
		_remember()
		Log.close()
		Save.reload())


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
	Save.request()
	return _levels[skill]


## Deletes this save's files; everything saved starts fresh. Tests start from here.
func wipe() -> void:
	Log.close()
	_remove(ProjectSettings.globalize_path(path()))
	if not _pin.is_empty() and id == _pin:
		_list([_pin])
	Save.reload()


func _remember() -> void:
	var index := _index()
	index.set_value("profiles", "current", String(id))
	index.save(_index_path())


func _list(known: Array[StringName]) -> void:
	var index := _index()
	index.set_value("profiles", "saves", known.map(func(save: StringName) -> String: return String(save)))
	DirAccess.make_dir_recursive_absolute(_index_path().get_base_dir())
	index.save(_index_path())


func _index_path() -> String:
	return INDEX if _pin.is_empty() else "%s%s.cfg" % [ROOT, _pin]


func _prefix() -> String:
	return "" if _pin.is_empty() else String(_pin) + "_"


func _index() -> ConfigFile:
	var index := ConfigFile.new()
	index.load(_index_path())
	return index


func _remove(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for sub in DirAccess.get_directories_at(folder):
		_remove(folder.path_join(sub))
	for file in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
