class_name EntryZoneOverlay
extends Node3D
## DEV: the zone map (EntryLayout) drawn on the table as 3D wireframes (each zone a real volume: boxes,
## cylinders, Onion's capsule, the gear's flight as a swept ball, the hand's sweep) over a faint flat
## footprint, each with its name, so the layout can be seen in the headset or a picture. Red: overlapping another
## zone that is there at the same time. Toggled by the "Zones" dev button.
##
## Colours: Onion's spots cyan; the teaching hand's sweep orange; things the child uses sage-blue; things moved aside for the revealed room violet; the
## hands' room a faint yellow; panels for the grown-up (setup, dev) grey; an overlap red.

const THING := Color(0.35, 0.7, 0.95, 0.4)
const MOVED := Color(0.65, 0.45, 0.95, 0.4)
const HANDS := Color(1.0, 0.9, 0.35, 0.14)
const PANEL := Color(0.75, 0.75, 0.78, 0.35)
const OVERLAP := Color(1.0, 0.2, 0.2, 0.6)
const TEACH := Color(1.0, 0.65, 0.3, 0.3)   # the teaching hand's sweep
const ONION := Color(0.3, 0.9, 0.95, 0.3)   # where Onion stands


## Draws the zones of [param layout] that are there in any of [param phases] (EntryLayout.SETUP...).
func draw(layout: EntryLayout, phases: int) -> void:
	for child in get_children():
		child.queue_free()
	var clashing: Array[StringName] = []
	for o in layout.overlaps():
		clashing.append_array([o.a, o.b])
	var lift := 0.003
	for z in layout.zones:
		if z.phases & phases == 0:
			continue
		var colour := HANDS if z.kind == EntryLayout.Kind.AREA else PANEL if z.kind == EntryLayout.Kind.PANEL \
				else TEACH if z.kind == EntryLayout.Kind.HAND \
				else ONION if String(z.name).begins_with("onion") \
				else MOVED if String(z.name).ends_with("_after") else THING
		if z.name in clashing:
			colour = OVERLAP
		lift += 0.0008   # each a hair above the last: no flicker where they overlap
		if z.kind != EntryLayout.Kind.PANEL and z.shape != &"path" and z.shape != &"capsule":
			add_child(_footprint(z.outline(), layout.table_y() + lift, Color(colour.r, colour.g, colour.b, colour.a * 0.5), 5 if z.name in clashing else 2))
		add_child(_wireframe(z, Color(colour.r, colour.g, colour.b, 0.95), 7 if z.name in clashing else 6))
		var words := Label3D.new()
		words.text = String(z.name).replace("_", " ")
		words.font_size = 28
		words.pixel_size = 0.0005
		words.outline_size = 8
		words.modulate = Color(1, 1, 1, 0.9)
		words.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		words.no_depth_test = true
		words.render_priority = 8
		var middle := Vector2.ZERO
		for p in z.outline():
			middle += p
		middle /= maxf(z.outline().size(), 1)
		if z.shape == &"ring":   # the hands' room: its name at the middle of its far edge
			middle = Vector2(z.centre.x, z.centre.z) + Vector2(-sin(z.yaw), -cos(z.yaw)) * z.radius * 0.92
		add_child(words)
		words.global_position = Vector3(middle.x, (z.top() + 0.03) if z.shape != &"path" else (z.path[z.path.size() / 2].y + 0.07), middle.y)


## The zone as a 3D wireframe: a prism's bottom and top outlines with its edges; a capsule's rings and
## sides; a swept path as a ring of its radius at every step, joined.
func _wireframe(z: EntryLayout.Zone, colour: Color, priority: int) -> MeshInstance3D:
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = colour
	material.no_depth_test = true
	material.render_priority = priority
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	match z.shape:
		&"capsule":
			var low := z.centre.y + z.radius
			var high := z.centre.y + z.height - z.radius
			for y: float in [z.centre.y, low, high, z.top()]:
				var r := z.radius * (1.0 if y == low or y == high else 0.55)
				_ring(mesh, Vector3(z.centre.x, y, z.centre.z), r)
			for i in 4:
				var a := i * TAU / 4.0
				var off := Vector3(cos(a), 0.0, sin(a)) * z.radius
				mesh.surface_add_vertex(Vector3(z.centre.x, low, z.centre.z) + off)
				mesh.surface_add_vertex(Vector3(z.centre.x, high, z.centre.z) + off)
		&"path":
			for i in z.path.size():
				_ring(mesh, z.path[i], z.radius)
				if i > 0:
					mesh.surface_add_vertex(z.path[i - 1])
					mesh.surface_add_vertex(z.path[i])
		_:
			var outline := z.outline()
			var n := outline.size()
			var step := 1 if z.shape != &"circle" else 4   # a circle: fewer sides, fewer lines
			for i in range(0, n, step):
				var a := outline[i]
				var b := outline[(i + step) % n]
				for y: float in [z.centre.y, z.top()]:
					mesh.surface_add_vertex(Vector3(a.x, y, a.y))
					mesh.surface_add_vertex(Vector3(b.x, y, b.y))
				mesh.surface_add_vertex(Vector3(a.x, z.centre.y, a.y))
				mesh.surface_add_vertex(Vector3(a.x, z.top(), a.y))
	mesh.surface_end()
	var shape := MeshInstance3D.new()
	shape.mesh = mesh
	shape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return shape


func _ring(mesh: ImmediateMesh, at: Vector3, radius: float) -> void:
	for i in 16:
		var a := i * TAU / 16.0
		var b := (i + 1) * TAU / 16.0
		mesh.surface_add_vertex(at + Vector3(cos(a), 0.0, sin(a)) * radius)
		mesh.surface_add_vertex(at + Vector3(cos(b), 0.0, sin(b)) * radius)


func _footprint(outline: PackedVector2Array, y: float, colour: Color, priority: int) -> MeshInstance3D:
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = colour
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.render_priority = priority
	var corners := Geometry2D.triangulate_polygon(outline)
	if not corners.is_empty():
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
		for i in corners:
			mesh.surface_add_vertex(Vector3(outline[i].x, y, outline[i].y))
		mesh.surface_end()
	var edge := material.duplicate() as StandardMaterial3D
	edge.albedo_color = Color(colour.r, colour.g, colour.b, minf(1.0, colour.a + 0.45))
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, edge)
	for i in outline.size() + 1:
		var p := outline[i % outline.size()]
		mesh.surface_add_vertex(Vector3(p.x, y + 0.0005, p.y))
	mesh.surface_end()
	var shape := MeshInstance3D.new()
	shape.mesh = mesh
	shape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return shape
