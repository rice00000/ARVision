class_name HubMemory
extends Node
## What the workshop hub remembers per child (saved with their progress, key "hub"; design chat, Nov 18,
## `claude/DESIGN_STONES_AND_LEVELS.md`): which games they have played (so the next game opens one at a time,
## across visits), which one-time lines Onion has said, and the visual look they picked through the eye.
##
## The look is the child's own filter ([code]Vision.view[/code], the one staff edit on the Vision page): picking
## one sets it, so it is the base view from then on. [member look] only says which picture wears the ring.

## Megan, Nov 18: Wei's other filters are looks the child can turn on too (Greyscale, Dim room, Spotlight).
## Spotlight lights only round a game's focus, so it's offered in a game's pause bubble only (GAME_ONLY); in the
## hub the room shows Normal while it's the chosen look ([method room_view]).
const LOOKS: Array[StringName] = [&"normal", &"high_contrast", &"edges", &"black_white", &"greyscale", &"dim", &"spotlight"]
const GAME_ONLY: Array[StringName] = [&"spotlight"]

var save_key := "hub"
## Game ids played at least once (finished or left).
var played: Array[StringName] = []
## One-time lines already said (&"stones", &"more").
var said: Array[StringName] = []
## The child's look (one of LOOKS).
var look := &"normal"


## The one memory, under the app's main node (made on first use).
static func get_or_make() -> HubMemory:
	if App.main == null:
		return null
	var memory := App.main.get_node_or_null(^"HubMemory") as HubMemory
	if memory == null:
		memory = HubMemory.new()
		memory.name = "HubMemory"
		App.main.add_child(memory)
	return memory


func save_state() -> Dictionary:
	return {played = played.map(func(id: StringName) -> String: return String(id)),
			said = said.map(func(id: StringName) -> String: return String(id)), look = String(look)}


func load_state(data: Dictionary) -> void:
	played.clear()
	for id: Variant in data.get("played", []):
		played.append(StringName(str(id)))
	said.clear()
	for id: Variant in data.get("said", []):
		said.append(StringName(str(id)))
	look = StringName(str(data.get("look", "normal")))
	if look not in LOOKS:
		look = &"normal"


func mark_played(id: StringName) -> void:
	if id not in played:
		played.append(id)
		Save.request()


## True the first time (and remembers it).
func first_time(line: StringName) -> bool:
	if line in said:
		return false
	said.append(line)
	Save.request()
	return true


## The child picked [param id]: it shows in the real room now and from the start of every later visit.
func choose_look(id: StringName) -> void:
	if id not in LOOKS:
		return
	look = id
	Vision.set_view(view_of(id))
	if App.reality != null:
		App.reality.apply_view(Vision.view)
	Events.report(&"view_chosen", {look = String(id), title = view_of(id).title})
	Save.request()


## What the room shows in the hub (no game): the child's look, but Normal for a game-only look.
func room_view() -> View:
	return view_of(&"normal") if look in GAME_ONLY else Vision.view


static func view_of(id: StringName) -> View:
	return load("res://content/views/%s.tres" % id) as View
