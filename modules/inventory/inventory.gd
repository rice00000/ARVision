extends Module
## Port of XRVision inventory. Every mutation reports and saves atomically.

const STONE := &"magic_stone"
var _items: Dictionary[StringName, int] = {}


func _ready() -> void:
	Events.level_won.connect(_reward)


func count(id: StringName) -> int:
	return _items.get(id, 0)


func all() -> Dictionary[StringName, int]:
	return _items.duplicate()


func add(id: StringName, amount := 1) -> void:
	_set_count(id, count(id) + amount)
	_changed(&"inventory_added", {item = id, amount = amount})


func take(id: StringName) -> bool:
	if count(id) == 0:
		return false
	_set_count(id, count(id) - 1)
	_changed(&"inventory_taken", {item = id})
	return true


func buy(id: StringName) -> bool:
	var item := ItemDef.find(id)
	if item == null or (item.kind != ItemDef.Kind.FURNITURE and count(id) > 0):
		return false
	if count(STONE) < item.price:
		Events.report(&"purchase_declined", {item = id, balance = count(STONE), price = item.price})
		return false
	_set_count(STONE, count(STONE) - item.price)
	_set_count(id, count(id) + 1)
	_changed(&"purchased", {item = id, price = item.price, balance = count(STONE)})
	return true


func _reward(task: StringName, level: int, stones: int) -> void:
	if stones == 0: return
	_set_count(STONE, count(STONE) + stones)
	_changed(&"reward_granted", {task = task, level = level, stones = stones, balance = count(STONE)})


func _set_count(id: StringName, value: int) -> void:
	if value == 0:
		_items.erase(id)
	else:
		_items[id] = value


func _changed(what: StringName, data: Dictionary) -> void:
	Events.inventory_changed.emit()
	Events.report(what, data)


func save_state() -> Dictionary:
	return {items = _items.duplicate()}


func load_state(data: Dictionary) -> void:
	_items.assign(data.get("items", {&"room_sun": 1}))
	Events.inventory_changed.emit()
