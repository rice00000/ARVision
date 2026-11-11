class_name ItemDef
extends Resource
## XRVision's item catalogue, with rooms and pets as unique purchases. Scene is visual only.

enum Kind {FURNITURE, ROOM, PET}
const DIR := "res://content/items/"
@export var title := ""
@export var kind := Kind.FURNITURE
@export var scene: PackedScene
@export_range(1, 20) var price := 1
@export var snap_to_floor := true

var id: StringName:
	get: return StringName(resource_path.get_file().get_basename())

## Keeps the item scenes loaded across menu rebuilds.
static var _catalogue: Dictionary[StringName, ItemDef] = {}


static func warm_up() -> void:
	if not _catalogue.is_empty():
		return
	var items: Array[ItemDef] = []
	for file in ResourceLoader.list_directory(DIR):
		if file.ends_with(".tres"):
			items.append(load(DIR + file) as ItemDef)
	items.sort_custom(func(a: ItemDef, b: ItemDef) -> bool:
		if a.price != b.price: return a.price < b.price
		return String(a.id).naturalnocasecmp_to(String(b.id)) < 0)
	for item in items:
		_catalogue[item.id] = item


static func find(item_id: StringName) -> ItemDef:
	warm_up()
	return _catalogue.get(item_id)


static func all(kind_filter: Kind) -> Array[ItemDef]:
	warm_up()
	var items: Array[ItemDef] = []
	for item: ItemDef in _catalogue.values():
		if item.kind == kind_filter:
			items.append(item)
	return items
