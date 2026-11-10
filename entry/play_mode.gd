class_name PlayMode
## Dev or play: ONE switch for the opening and the visits (Megan, Nov 8), instead of separate
## constants. Read it with [method is_dev].
##
## * **Both modes** run setup (hands, table, reach, sound and room): that is how the table and
##   surface detection get checked. Wei's facilitator panel (the adult's menu) stays in both.
## * **Dev** adds what a tester needs: what setup found (the chosen table's outline plus the other
##   tables, and the `ENTRY PLACEMENT:` line on screen), a "Skip setup" button on the setup panel,
##   the top-left scene marker, hand outlines, the DEV coherence panel and the try-carry key.
## * **Play** shows none of those.
##
## Which one: a launch flag `-- --mode=play` / `-- --mode=dev` wins; tests (`--profile=test`) are
## always dev; otherwise the last choice made with the "Mode" button on the setup panel (saved on
## the device); otherwise dev on a desktop or in the editor, play in an exported headset build.
## Every session logs `session_mode` with the mode, so dev runs (jumps, pinned coherence) never
## mix silently with real data.

enum { DEV, PLAY }

const SAVE_PATH := "user://play_mode.cfg"

static var _mode := -1
static var _source := ""
## Under tests: setup is skipped unless a test turns it on (Entry.skip_setup). A test hook, not a mode.
static var testing := false


## Works the mode out once (flag > tests > saved choice > build default).
static func resolve() -> void:
	if _mode != -1:
		return
	var args := OS.get_cmdline_user_args()
	testing = false
	for arg: String in args:
		if arg.begins_with("--profile=test"):
			testing = true
	for arg: String in args:
		if arg == "--mode=play" or arg == "--mode=dev":
			_mode = PLAY if arg == "--mode=play" else DEV
			_source = "launch flag"
			return
	if testing:
		_mode = DEV
		_source = "tests"
		return
	var saved := ConfigFile.new()
	if saved.load(SAVE_PATH) == OK and saved.has_section_key("mode", "mode"):
		_mode = PLAY if str(saved.get_value("mode", "mode")) == "play" else DEV
		_source = "saved choice"
		return
	_mode = PLAY if OS.has_feature("template") and OS.has_feature("android") else DEV
	_source = "headset build default" if _mode == PLAY else "desktop default"


## True under the test runner (`--profile=test`).
static func testing_now() -> bool:
	resolve()
	return testing


static func is_dev() -> bool:
	resolve()
	return _mode == DEV


## "dev" or "play", for logs and the button.
static func name() -> String:
	return "dev" if is_dev() else "play"


## Where the mode came from: "launch flag", "tests", "saved choice", "desktop default"...
static func source() -> String:
	resolve()
	return _source


## Sets the mode now (and keeps the choice on this device, except under tests). Logged.
static func set_dev(dev: bool, by := "toggle") -> void:
	resolve()
	var mode := DEV if dev else PLAY
	if mode == _mode:
		return
	_mode = mode
	_source = by
	if not testing:
		var saved := ConfigFile.new()
		saved.set_value("mode", "mode", name())
		saved.save(SAVE_PATH)
	Events.report(&"session_mode", {mode = name(), by = by})
	SceneMarker.refresh()


static func toggle(by := "toggle") -> void:
	set_dev(not is_dev(), by)


## Logs the mode at the start of a session.
static func log_start() -> void:
	Events.report(&"session_mode", {mode = name(), by = source()})
	print("ENTRY mode: ", name(), " (", source(), ")")


## Tests only: back to "work it out again".
static func reset_for_tests() -> void:
	_mode = -1
	_source = ""
