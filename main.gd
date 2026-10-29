class_name Main
extends Node3D
## Boots the app. Picks the Reality: the Quest's passthrough, or the simulated
## room when the headset has no passthrough, there is no headset, or
## `-- --sim` is given. Without XR it creates the synthetic hands (SimInput)
## and lets the mouse drive them (DesktopDriver).
##
## The game in play is the Session, the World and what they put on the stage;
## [method restart] builds it again (another save was opened). The room, the
## rig and the modules stay.

@export var sim_room: PackedScene

## Session and World as they were set up, before they ran: what a fresh game is made from.
var _fresh: Array[PackedScene] = []


func _enter_tree() -> void:
	App.main = self
	for node: Node in [$Session, $World]:
		var scene := PackedScene.new()
		scene.pack(node)
		_fresh.append(scene)


func _ready() -> void:
	App.stage = $Stage
	var reality: Reality
	if App.has_passthrough() and not "--sim" in OS.get_cmdline_user_args():
		reality = PassthroughReality.new()
	else:
		reality = SimReality.new()
		reality.room = sim_room
	reality.name = "Reality"
	App.reality = reality
	add_child(reality)
	if App.xr == null:
		App.sim_input = SimInput.new(App.rig)
		add_child(DesktopDriver.new())


## Ends the game in play, runs [param between] (the files are swapped) and
## starts a fresh one.
func restart(between: Callable) -> void:
	for node in [$Session, $World] + App.stage.get_children():
		node.free()
	between.call()
	for scene in _fresh:
		add_child(scene.instantiate())


func _exit_tree() -> void:
	if App.sim_input:
		App.sim_input.release()
		App.sim_input = null
