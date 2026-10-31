class_name SceneMarker
## DEV: a small head-locked label at the top left of the view naming the running state
## ("Opening", "Shelf", "Tutorial", "Motion"), so a tester always knows where they are.
## It hangs on the head, which stays across scene switches. Off: SHOW := false.

const SHOW := true
const NAME := &"DevSceneMarker"


static func show_text(text: String) -> void:
	if not SHOW or App.head() == null:
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
