extends Node
## Save (autoload "Save"): the child's progress in user://profiles/<id>/save.json,
## as in XRVision.
##
## Any node with these two methods is saved, keyed by its `save_key` property
## if it has one, else by its node name:
##     func save_state() -> Dictionary
##     func load_state(data: Dictionary) -> void
##
## [b]Loading always replaces.[/b] A saveable gets [code]load_state()[/code] when
## it becomes ready and after [method reload] (a wiped profile), with {} when the
## file has nothing for it.
##
## [b]Writing needs no asking.[/b] Rounds and reports are written once at the end
## of the frame; [method write] writes now, and so do quitting and pausing. The
## file is replaced through a temporary one, so a failed write keeps the last
## save. A file from another [constant VERSION] is not loaded: that child starts fresh.

const GROUP := &"saveable"
const VERSION := 1
const FILE := "save.json"

var _data: Dictionary = {}
var _queued := false


func _ready() -> void:
	_read()
	get_tree().node_added.connect(_on_node_added)
	for node in get_tree().root.get_children(): # autoloads that loaded before us
		_on_node_added(node)
	Events.trial_ended.connect(func(_skill: StringName, _success: bool, _data_: Dictionary) -> void: request())
	Events.reported.connect(func(_what: StringName, _data_: Dictionary) -> void: request())


func _notification(what: int) -> void:
	if not is_inside_tree():
		return
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			write()


## Writes at the end of this frame, once, however many things asked.
func request() -> void:
	if not _queued:
		_queued = true
		_flush.call_deferred()


func _flush() -> void:
	_queued = false
	write()


func write() -> void:
	for node in get_tree().get_nodes_in_group(GROUP):
		_capture(node)
	var path := _path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		push_error("[Save] Cannot open temporary save: %s" % path)
		return
	file.store_string(JSON.stringify(JSON.from_native({version = VERSION, nodes = _data}), "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(path + ".tmp", path)
	if error != OK:
		push_error("[Save] Could not replace save (%s): %s" % [error_string(error), path])


## Re-reads the file and puts every saveable back to what it says, dropping
## anything not written yet. Profile.wipe does this, so nothing outlives a wipe.
func reload() -> void:
	_queued = false
	_read()
	for node in get_tree().get_nodes_in_group(GROUP):
		_restore(node)


func _path() -> String:
	return Profile.path(FILE)


func _read() -> void:
	_data = {}
	if not FileAccess.file_exists(_path()):
		return
	var encoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path()))
	var parsed: Variant = JSON.to_native(encoded) if encoded is Dictionary and encoded.has("type") else null
	if parsed is Dictionary and parsed.get("version") == VERSION and parsed.get("nodes") is Dictionary:
		_data = parsed.nodes
	else:
		push_warning("[Save] Not a save this version can read, starting fresh: %s" % _path())


func _on_node_added(node: Node) -> void:
	if not (node.has_method(&"save_state") and node.has_method(&"load_state")):
		return
	node.add_to_group(GROUP)
	node.tree_exiting.connect(_capture.bind(node), CONNECT_ONE_SHOT)
	if node.is_node_ready():
		_restore(node)
	else:
		node.ready.connect(_restore.bind(node), CONNECT_ONE_SHOT)


func _key(node: Node) -> String:
	var key := str(node.get(&"save_key")) if &"save_key" in node else ""
	return key if not key.is_empty() else str(node.name)


func _restore(node: Node) -> void:
	node.load_state(_data.get(_key(node), {}))


func _capture(node: Node) -> void:
	_data[_key(node)] = node.save_state()
