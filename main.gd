extends Node3D
## Boots the app. Picks the Reality: the Quest's passthrough, or the simulated
## room when the headset has no passthrough, there is no headset, or
## `-- --sim` is given. Without XR it creates the synthetic hands (SimInput)
## and lets the mouse drive them (DesktopDriver).

@export var sim_room: PackedScene


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


func _exit_tree() -> void:
	if App.sim_input:
		App.sim_input.release()
		App.sim_input = null
