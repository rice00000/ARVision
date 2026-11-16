extends SceneTree
## Which cameras can Godot see on this computer? (Turn to fit lab, Nov 15)
## Run:  Godot --xr-mode off --path . --script res://tools/cv_lab/camera_check.gd
## Prints each step, then quits after 4 seconds.

var _time := 0.0


func _initialize() -> void:
	print("CAMERA CHECK 1: platform ", OS.get_name())
	print("CAMERA CHECK 2: permission asked → ", OS.request_permission("CAMERA"))
	CameraServer.camera_feeds_updated.connect(func() -> void:
		print("CAMERA CHECK 4: the camera list changed, now ", CameraServer.get_feed_count()))
	CameraServer.monitoring_feeds = true
	print("CAMERA CHECK 3: looking for cameras (monitoring = ", CameraServer.monitoring_feeds, ")")


func _process(delta: float) -> bool:
	_time += delta
	if _time < 4.0:
		return false
	print("CAMERA CHECK 5: cameras found: ", CameraServer.get_feed_count())
	for feed in CameraServer.feeds():
		print("   • \"%s\"  colour type %d, %d formats" % [feed.get_name(), feed.get_datatype(), feed.get_formats().size()])
	return true # quit
