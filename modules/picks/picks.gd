extends Module
## One CSV row per pick, for the team to open in a spreadsheet:
## user://profiles/<save>/picks.csv. tools/picks.py gathers every save's into one file.
##
##   time      local date and time of the pick
##   save      the save's name (the child)
##   game      the plan played: "Find the toys, level 3"
##   round     1 = the first round of that game
##   target    what the guide asked for; picked: what the child chose
##   correct   1 or 0
##   seconds   since the round began, paused time not counted
##   accuracy  right picks so far in this game, % of all its picks
##
## Delete the node to unplug it.

const FILE := "picks.csv"
const COLUMNS := ["time", "save", "game", "round", "target", "picked", "correct", "seconds", "accuracy"]

var _picks := 0
var _right := 0


func _ready() -> void:
	Events.block_started.connect(func(_index: int, _info: Dictionary) -> void:
		_picks = 0
		_right = 0)
	Events.picked.connect(_on_picked)


func _on_picked(data: Dictionary) -> void:
	_picks += 1
	_right += int(data.correct)
	var path := Profile.path(FILE)
	var fresh := not FileAccess.file_exists(path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE if fresh else FileAccess.READ_WRITE)
	file.seek_end()
	if fresh:
		file.store_csv_line(PackedStringArray(COLUMNS))
	file.store_csv_line(PackedStringArray([Time.get_datetime_string_from_system(false, true), Profile.label(),
		App.session.plan.title, data.round + 1, data.target, data.picked, int(data.correct), data.seconds,
		roundi(100.0 * _right / _picks)]))
