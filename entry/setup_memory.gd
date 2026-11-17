class_name SetupMemory
## The last setup on this device: the confirmed table and the reach (Megan's scene review, Nov 17,
## Scene 0: "reuse the last table and reach, one press for the grown-up, used only if the room scan
## still finds that table").
##
## Kept per device, not per save: the table is a fact about the room, not about the child.
## Only a table the room scan found is kept (a pointed one has nothing to match next time).
## "Still finds that table" = a scanned table of about the same place, height and size. If the
## headset's tracking origin moved between launches, nothing matches and setup runs as usual.

## Where it is kept. Empty = off (the default under tests, so one test's setup never leaks into the next).
static var path := "" if PlayMode.testing_now() else "user://last_setup.cfg"

## How close a scanned table must be to the kept one to count as the same table.
const SAME_PLACE := 0.15    # metres, centre to centre, seen from above
const SAME_HEIGHT := 0.04   # metres
const SAME_SIZE := 0.20     # metres, each side (either way round)


## Keeps [param table] (its centre and size) and [param reach] (metres; 0 = "Use usual spot").
static func remember(table: Surface, reach: float) -> void:
	if path == "":
		return
	var file := ConfigFile.new()
	file.set_value("table", "centre", table.transform.origin)
	file.set_value("table", "size", table.size)
	file.set_value("reach", "metres", reach)
	file.set_value("saved", "unix", Time.get_unix_time_from_system())
	file.save(path)


## What was kept: {centre, size, reach}, or {} when nothing is.
static func last() -> Dictionary:
	if path == "":
		return {}
	var file := ConfigFile.new()
	if file.load(path) != OK or not file.has_section_key("table", "centre"):
		return {}
	return {centre = file.get_value("table", "centre"), size = file.get_value("table", "size"),
			reach = float(file.get_value("reach", "metres", 0.0))}


## Of [param tables] (the room scan's), the one that is the kept table, or null.
static func match_in(tables: Array[Surface]) -> Surface:
	var kept := last()
	if kept.is_empty():
		return null
	for table in tables:
		if same_table(table, kept.centre, kept.size):
			return table
	return null


static func same_table(table: Surface, centre: Vector3, size: Vector2) -> bool:
	var at := table.transform.origin
	if Vector2(at.x - centre.x, at.z - centre.z).length() > SAME_PLACE:
		return false
	if absf(at.y - centre.y) > SAME_HEIGHT:
		return false
	var straight := absf(table.size.x - size.x) <= SAME_SIZE and absf(table.size.y - size.y) <= SAME_SIZE
	var turned := absf(table.size.x - size.y) <= SAME_SIZE and absf(table.size.y - size.x) <= SAME_SIZE
	return straight or turned


## Forgets it (tests).
static func forget() -> void:
	if path != "" and FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
