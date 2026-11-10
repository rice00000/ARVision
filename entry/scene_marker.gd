class_name SceneMarker
## DEV: a small head-locked label at the top left of the view naming the running state
## ("Opening", "Shelf", "Tutorial", "Motion"), so a tester always knows where they are.
## It hangs on the head, which stays across scene switches. Dev mode only ([PlayMode]).

const NAME := &"DevSceneMarker"
const DETAIL := &"DevSceneDetail"
## Seconds a detail line (e.g. the placement) stays under the marker.
const DETAIL_SECONDS := 20.0

static var _last := ""


static func show_text(text: String) -> void:
	_last = text
	if not PlayMode.is_dev() or App.head() == null:
		return
	var label := App.head().get_node_or_null(NodePath(NAME)) as Label3D
	if label == null:
		label = Label3D.new()
		label.name = NAME
		label.font_size = 22
		label.pixel_size = 0.0005
		label.outline_size = 8
		label.no_depth_test = true
		label.render_priority = 30
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.modulate = Color(1.0, 0.95, 0.6)
		label.position = Vector3(-0.47, 0.28, -0.4)   # the top-left corner of the view
		App.head().add_child(label)
	label.text = "DEV · " + text


## A longer second line under the marker for a while (dev only): what setup found, e.g. the
## `ENTRY PLACEMENT:` line, so a tester sees it in the headset.
static func show_detail(text: String, seconds := DETAIL_SECONDS) -> void:
	if not PlayMode.is_dev() or App.head() == null:
		return
	var label := App.head().get_node_or_null(NodePath(DETAIL)) as Label3D
	if label == null:
		label = Label3D.new()
		label.name = DETAIL
		label.font_size = 18
		label.pixel_size = 0.0005
		label.outline_size = 6
		label.no_depth_test = true
		label.render_priority = 30
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.width = 900.0
		label.modulate = Color(0.85, 0.95, 1.0)
		label.position = Vector3(-0.47, 0.26, -0.4)   # just under the marker
		App.head().add_child(label)
	label.text = text
	label.visible = true
	label.set_meta(&"until", Time.get_ticks_msec() + int(seconds * 1000.0))
	var tree := App.head().get_tree()
	await tree.create_timer(seconds, true, false, true).timeout
	if is_instance_valid(label) and Time.get_ticks_msec() >= int(label.get_meta(&"until", 0)):
		label.visible = false


## After a mode change: the marker (and detail) show in dev with the last text, hide in play.
static func refresh() -> void:
	if App.head() == null:
		return
	var dev := PlayMode.is_dev()
	var detail := App.head().get_node_or_null(NodePath(DETAIL)) as Label3D
	if detail != null and not dev:
		detail.visible = false
	var label := App.head().get_node_or_null(NodePath(NAME)) as Label3D
	if label != null:
		label.visible = dev
	elif dev and _last != "":
		show_text(_last)
