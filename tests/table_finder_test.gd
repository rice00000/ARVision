extends TestCase
## TableFinder replayed on a real Quest 3 session (tests/data/headset_off_on.depth.gz):
## 100 depth looks, 0.5 s apart, at a desk whose top is at 0.64 m. Looks 4-18 were
## taken with the headset off for a moment (put on, taken off, put on again): the
## Quest then still reports the head as tracked, from a placeholder pose, and the
## depth shows a "table" at 0.86 m. From look 19 it is worn again; the child plays
## (reaching for toys, arms on the desk) until the end. Points are in the room's
## (Stage) frame, millimetres.

const DATA := "res://tests/data/headset_off_on.depth.gz"
const DESK := 0.64
const BACK_ON := 19

var _bytes := PackedByteArray()
var _count := 0
var _size := 0


func _look(index: int) -> Array:
	if _bytes.is_empty():
		_bytes = FileAccess.get_file_as_bytes(DATA).decompress_dynamic(8_000_000, FileAccess.COMPRESSION_GZIP)
		_count = _bytes.decode_s32(0)
		_size = _bytes.decode_s32(4)
	var at := 8 + index * (48 + _size * _size * 6)
	var f := _bytes.slice(at, at + 48).to_float32_array()
	var eye := Transform3D(Basis(Vector3(f[3], f[4], f[5]), Vector3(f[6], f[7], f[8]), Vector3(f[9], f[10], f[11])),
		Vector3(f[0], f[1], f[2]))
	var points := PackedVector3Array()
	var valid := PackedByteArray()
	points.resize(_size * _size)
	valid.resize(_size * _size)
	at += 48
	for i in _size * _size:
		var x := _bytes.decode_s16(at + i * 6)
		valid[i] = 0 if x == -32768 else 1
		points[i] = Vector3(x, _bytes.decode_s16(at + i * 6 + 2), _bytes.decode_s16(at + i * 6 + 4)) * 0.001
	return [DepthGrid.new(_size, points, valid), eye]


## Plays looks [param from]..end through a new finder: [[look, event, table height]].
func _replay(from: int) -> Array:
	var finder := TableFinder.new()
	var events := []
	_look(0)
	for index in range(from, _count):
		var look := _look(index)
		var event := finder.look(look[0], look[1])
		if event == &"found":
			events.append([index, event, finder.table.centre.y])
		elif event == &"lost":
			events.append([index, event, 0.0])
	return events


func _ends_on_the_desk(events: Array, why: String) -> void:
	var last: Array = events[-1]
	expect(last[1] == &"found" and absf(last[2] - DESK) < 0.03, "%s: ends on the desk: %s" % [why, events])
	expect(last[0] <= BACK_ON + 10, "%s: within 5 s of the headset going back on: %s" % [why, events])


func test_a_table_found_with_the_headset_off_is_dropped_and_the_desk_found() -> void:
	var events := _replay(4)
	expect(absf(events[0][2] - 0.86) < 0.03, "the placeholder pose shows a table in the air first: %s" % [events])
	expect(events[1][1] == &"lost" and events[1][0] >= BACK_ON, "dropped once worn again: %s" % [events])
	_ends_on_the_desk(events, "found while off")


func test_the_session_as_played_ends_on_the_desk_and_holds_through_play() -> void:
	var events := _replay(0)
	expect(events[0][1] == &"found" and absf(events[0][2] - DESK) < 0.03, "the desk first: %s" % [events])
	_ends_on_the_desk(events, "as played")


func test_a_table_out_of_view_is_kept() -> void:
	var finder := TableFinder.new()
	finder.hold(Vector3(5.0, 0.7, 5.0), Vector2(1.0, 0.6), Vector3.FORWARD)
	var look := _look(40)
	for i in TableFinder.DOUBTS * 3:
		expect_eq(finder.look(look[0], look[1]), &"", "nothing seen there, nothing to doubt")
	expect(not finder.table.is_empty(), "still believed")


func test_a_hand_table_above_the_desk_is_dropped_after_the_doubts() -> void:
	var finder := TableFinder.new()
	var look := _look(40)
	finder.hold(Vector3(0.1, DESK + 0.2, -0.05), Vector2(1.0, 0.6), Vector3.FORWARD)
	for i in TableFinder.DOUBTS - 1:
		expect_eq(finder.look(look[0], look[1]), &"", "doubt %d" % (i + 1))
	expect_eq(finder.look(look[0], look[1]), &"lost", "dropped")
	finder.hold(Vector3(0.1, DESK, -0.05), Vector2(1.0, 0.6), Vector3.FORWARD)
	for i in TableFinder.DOUBTS * 2:
		expect_eq(finder.look(look[0], look[1]), &"", "the desk itself holds")
