extends Node
## App lifecycle (autoload "App"): XR start, the pieces of main.tscn, module
## lookup and pause.
##
## Without an OpenXR runtime the app still runs: main.tscn then simulates the
## room and the desktop driver moves the hands (see SimReality, DesktopDriver).

## The OpenXR interface, or null when there is no runtime.
var xr: OpenXRInterface
## Set by main.tscn's pieces as they become ready.
var main: Main
var rig: Rig
var reality: Reality
var stage: Node3D
var session: Session
var world: World
## Synthetic hands when there is no headset (desktop and tests). Null in XR.
var sim_input: SimInput

## Who holds the world paused (&"facilitator", &"headset"). Paused while anyone does.
var _pause_holds: Dictionary[StringName, bool] = {}


func _ready() -> void:
	var openxr := XRServer.find_interface("OpenXR") as OpenXRInterface
	if openxr == null or not openxr.is_initialized():
		return
	xr = openxr
	get_viewport().use_xr = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED) # the headset paces frames
	xr.session_begun.connect(func() -> void:
		Engine.physics_ticks_per_second = roundi(xr.display_refresh_rate))
	xr.session_visible.connect(hold_pause.bind(&"headset", true)) # system menu on top
	xr.session_focussed.connect(hold_pause.bind(&"headset", false))
	# Never center_on_hmd: the Stage space stays on the room, and recentring the
	# world (Quest asks on every headset off and on) left the menus behind while
	# the table moved.


## True when the headset can show the real world behind the app.
func has_passthrough() -> bool:
	return xr != null and xr.get_supported_environment_blend_modes().has(XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND)


## The plugged-in module named [param module_name] (its node name under
## Main/Modules), or null when it was unplugged.
func module(module_name: StringName) -> Node:
	for node in get_tree().get_nodes_in_group(Module.GROUP):
		if node.name == module_name:
			return node
	return null


func head() -> XRCamera3D:
	return rig.head


## Pauses the world for [param who] ([param on]) or lets go of that pause.
func hold_pause(who: StringName, on: bool) -> void:
	if on:
		_pause_holds[who] = true
	else:
		_pause_holds.erase(who)
	get_tree().paused = not _pause_holds.is_empty()
