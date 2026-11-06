extends Module
## Owns room selection. Only Reality creates the environment; no XR code here.

var selected := &"room_sun"
var is_open := false


func _ready() -> void:
	Events.home_toggled.connect(_toggle)


func choose(id: StringName) -> bool:
	var inventory := App.module(&"Inventory")
	var item := ItemDef.find(id)
	if inventory == null or item == null or item.kind != ItemDef.Kind.ROOM or inventory.count(id) == 0:
		return false
	selected = id
	if is_open:
		_show()
	Events.room_changed.emit(id)
	Events.report(&"room_selected", {room = id})
	return true


func _toggle(open: bool) -> void:
	is_open = open
	if open:
		var eye := App.head().global_transform
		var forward := Vector3(-eye.basis.z.x, 0, -eye.basis.z.z).normalized()
		App.reality.room_frame = Transform3D(Basis.looking_at(forward), Vector3(eye.origin.x, 0, eye.origin.z))
		_show()
	else:
		App.reality.show_home_room(null)


func _show() -> void:
	App.reality.show_home_room(ItemDef.find(selected).scene)


func save_state() -> Dictionary:
	return {selected = selected}


func load_state(data: Dictionary) -> void:
	selected = StringName(data.get("selected", &"room_sun"))
	if is_open: _show()
	Events.room_changed.emit(selected)
