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


static func find(item_id: StringName) -> ItemDef:
	var path := DIR + String(item_id) + ".tres"
	return load(path) as ItemDef if ResourceLoader.exists(path) else null


static func all(kind_filter: Kind) -> Array[ItemDef]:
	var items: Array[ItemDef] = []
	for file in ResourceLoader.list_directory(DIR):
		if file.ends_with(".tres"):
			var item := load(DIR + file) as ItemDef
			if item.kind == kind_filter:
				items.append(item)
	items.sort_custom(func(a: ItemDef, b: ItemDef) -> bool:
		if a.price != b.price: return a.price < b.price
		return String(a.id).naturalnocasecmp_to(String(b.id)) < 0)
	return items
