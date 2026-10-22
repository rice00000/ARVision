extends Node
## Research log (autoload "Log"): one JSON object per line, one file per run,
## in <profile>/logs/<start time>.jsonl.
##
## Every line has "type" and "time". Round lines carry the full condition,
## including the view, so any result traces back to exactly what the child saw.

## The file being written; empty until the first line.
var file_path := ""

var _file: FileAccess


func _ready() -> void:
	Events.block_started.connect(func(index: int, info: Dictionary) -> void:
		write({type = "block", index = index, info = info}))
	Events.trial_started.connect(func(trial: StringName, condition: Dictionary) -> void:
		write({type = "trial_start", trial = trial, condition = condition}))
	Events.trial_ended.connect(func(skill: StringName, success: bool, data: Dictionary) -> void:
		write({type = "trial_end", skill = skill, success = success, data = data}))
	Events.view_changed.connect(func(view: Dictionary) -> void:
		write({type = "view", view = view}))
	Events.reported.connect(func(what: StringName, data: Dictionary) -> void:
		write({type = "event", what = what, data = data}))
	Events.session_finished.connect(func() -> void: write({type = "session_end"}))


func write(entry: Dictionary) -> void:
	if _file == null:
		_open()
	entry.time = Time.get_unix_time_from_system()
	_file.store_line(JSON.stringify(plain(entry)))
	_file.flush()


## Ends this file; the next line starts a new one (a profile was wiped).
func close() -> void:
	_file = null
	file_path = ""


## [param value] with vectors as arrays, so it reads back from JSON.
static func plain(value: Variant) -> Variant:
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Vector2:
		return [value.x, value.y]
	if value is Color:
		return [value.r, value.g, value.b, value.a]
	if value is Dictionary:
		var result := {}
		for key: Variant in value:
			result[str(key)] = plain(value[key])
		return result
	if value is Array:
		return value.map(plain)
	if value is StringName:
		return String(value)
	return value


func _open() -> void:
	var folder := Profile.path("logs/")
	DirAccess.make_dir_recursive_absolute(folder)
	file_path = "%s%s.jsonl" % [folder, Time.get_datetime_string_from_system().replace(":", "-")]
	_file = FileAccess.open(file_path, FileAccess.READ_WRITE if FileAccess.file_exists(file_path) else FileAccess.WRITE)
	_file.seek_end()
	_file.store_line(JSON.stringify({type = "session", profile = String(Profile.id),
		reality = App.reality.kind() if App.reality else "", time = Time.get_unix_time_from_system()}))
