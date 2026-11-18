@tool
extends Node3D
## Static scenery is batched by the parts the shop can remove for its cutaway.

static var _cache: Dictionary = {}
static var _material: StandardMaterial3D
var _parts: Dictionary
var _part: String
var _surface: SurfaceTool


func _ready() -> void:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
	var key: String = get_script().resource_path
	if not _cache.has(key):
		_parts = {}
		_build()
		_finish_part()
		_cache[key] = _parts
	for part: String in _cache[key]:
		var piece := MeshInstance3D.new()
		piece.name = part
		piece.mesh = _cache[key][part]
		piece.material_override = _material
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(piece)


func _build() -> void:
	pass


func section(part: String) -> void:
	_finish_part()
	_part = part
	_surface = SurfaceTool.new()
	_surface.begin(Mesh.PRIMITIVE_TRIANGLES)


func _finish_part() -> void:
	if _surface == null:
		return
	_surface.index()
	_parts[_part] = _surface.commit()
	_surface = null


func _vertex(at: Vector3, colour: Color) -> void:
	_surface.set_color(colour)
	_surface.add_vertex(at)


func triangle(a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	_vertex(a, colour)
	_vertex(b, colour)
	_vertex(c, colour)


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, colour: Color) -> void:
	triangle(a, b, c, colour)
	triangle(a, c, d, colour)


func gradient(a: Vector3, b: Vector3, c: Vector3, d: Vector3, low: Color, high: Color) -> void:
	_vertex(a, low)
	_vertex(b, low)
	_vertex(c, high)
	_vertex(a, low)
	_vertex(c, high)
	_vertex(d, high)


func box(at: Vector3, size: Vector3, colour: Color, basis := Basis.IDENTITY) -> void:
	var x := basis.x * size.x * 0.5
	var y := basis.y * size.y * 0.5
	var z := basis.z * size.z * 0.5
	quad(at - x + y - z, at + x + y - z, at + x + y + z, at - x + y + z, colour.lightened(0.10))
	quad(at - x - y + z, at + x - y + z, at + x - y - z, at - x - y - z, colour.darkened(0.30))
	quad(at - x - y + z, at + x - y + z, at + x + y + z, at - x + y + z, colour)
	quad(at + x - y - z, at - x - y - z, at - x + y - z, at + x + y - z, colour.darkened(0.10))
	quad(at - x - y - z, at - x - y + z, at - x + y + z, at - x + y - z, colour.darkened(0.16))
	quad(at + x - y + z, at + x - y - z, at + x + y - z, at + x + y + z, colour.darkened(0.23))


func beam(a: Vector3, b: Vector3, width: float, colour: Color, depth := 0.0) -> void:
	var along := (b - a).normalized()
	var up := Vector3.UP if absf(along.y) < 0.99 else Vector3.FORWARD
	box((a + b) * 0.5, Vector3(width, depth if depth > 0.0 else width, a.distance_to(b)),
		colour, Basis.looking_at(along, up))


func tube(a: Vector3, b: Vector3, r0: float, r1: float, colour: Color, sides := 16) -> void:
	var along := (b - a).normalized()
	var basis := Basis.looking_at(along, Vector3.UP if absf(along.y) < 0.99 else Vector3.FORWARD)
	for i in sides:
		var first := _circle(basis, i * TAU / sides)
		var next := _circle(basis, (i + 1) * TAU / sides)
		var side := _lit(colour, (first + next).normalized())
		quad(a + first * r0, a + next * r0, b + next * r1, b + first * r1, side)
		triangle(a, a + first * r0, a + next * r0, _lit(colour, -along))
		triangle(b, b + next * r1, b + first * r1, _lit(colour, along))


func orb(at: Vector3, radii: Vector3, colour: Color, rings := 8, sides := 14) -> void:
	for j in rings:
		for i in sides:
			var a := _sphere(i, j, sides, rings)
			var b := _sphere(i + 1, j, sides, rings)
			var c := _sphere(i + 1, j + 1, sides, rings)
			var d := _sphere(i, j + 1, sides, rings)
			_vertex(at + a * radii, _lit(colour, a))
			_vertex(at + b * radii, _lit(colour, b))
			_vertex(at + c * radii, _lit(colour, c))
			_vertex(at + a * radii, _lit(colour, a))
			_vertex(at + c * radii, _lit(colour, c))
			_vertex(at + d * radii, _lit(colour, d))


func _sphere(i: int, j: int, sides: int, rings: int) -> Vector3:
	var latitude := PI * (float(j) / rings - 0.5)
	var longitude := TAU * i / sides
	return Vector3(cos(longitude) * cos(latitude), sin(latitude), sin(longitude) * cos(latitude))


func _lit(colour: Color, normal: Vector3) -> Color:
	var shade := normal.dot(Vector3(-0.42, 0.8, 0.39))
	return colour.lightened(shade * 0.19) if shade > 0.0 else colour.darkened(-shade * 0.32)


func _circle(basis: Basis, angle: float) -> Vector3:
	return basis.x * cos(angle) + basis.y * sin(angle)


func band(at: Vector3, inner: float, outer: float, colour: Color, basis := Basis.IDENTITY, sides := 48) -> void:
	for i in sides:
		var a := _circle(basis, i * TAU / sides)
		var b := _circle(basis, (i + 1) * TAU / sides)
		quad(at + a * inner, at + a * outer, at + b * outer, at + b * inner, colour)


func arch(at: Vector3, radius: float, rise: float, frame: float, colour: Color, depth := 0.09) -> void:
	# A semicircular frame in XY with real depth along Z.
	for i in 24:
		var a := PI * i / 24
		var b := PI * (i + 1) / 24
		var i0 := at + Vector3(cos(a) * radius, sin(a) * rise, 0)
		var i1 := at + Vector3(cos(b) * radius, sin(b) * rise, 0)
		var o0 := at + Vector3(cos(a) * (radius + frame), sin(a) * (rise + frame), 0)
		var o1 := at + Vector3(cos(b) * (radius + frame), sin(b) * (rise + frame), 0)
		var back := Vector3(0, 0, -depth)
		quad(i0, i1, o1, o0, colour)
		quad(i0, i1, i1 + back, i0 + back, colour.darkened(0.25))
		quad(o0, o1, o1 + back, o0 + back, colour.lightened(0.13))


func hanging_globe(at: Vector3, ceiling: float, radius: float, metal: Color, glass: Color) -> void:
	tube(at + Vector3.UP * radius, Vector3(at.x, ceiling, at.z), radius * 0.08, radius * 0.08, metal, 8)
	orb(at, Vector3.ONE * radius, glass)
	tube(at + Vector3.UP * (radius * 0.77), at + Vector3.UP * (radius * 1.05), radius * 0.54, radius * 0.38, metal, 12)


func leaf(at: Vector3, tip: Vector3, width: float, colour: Color) -> void:
	var stem := tip - at
	var side := stem.cross(Vector3.UP).normalized() * width
	var ridge := at + stem * 0.47 + Vector3.UP * width * 0.42
	var left := at + stem * 0.5 + side
	var right := at + stem * 0.5 - side
	quad(at, left, tip, ridge, colour)
	quad(at, ridge, tip, right, colour.darkened(0.22))


func planter(at: Vector3, radius: float, height: float, pot: Color, foliage: Color, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var dirt := at + Vector3.UP * height
	tube(at, dirt, radius * 0.74, radius, pot)
	tube(dirt - Vector3.UP * 0.07, dirt + Vector3.UP * 0.012, radius * 1.06, radius * 1.06, pot.lightened(0.15))
	tube(dirt, dirt + Vector3.UP * 0.014, radius * 0.89, radius * 0.89, Color("46362b"))
	for i in 12:
		var angle := i * 2.39996
		var out := Vector3(cos(angle), 0, sin(angle))
		var length := rng.randf_range(0.74, 1.72) * radius * 2.6
		var stem_end := dirt + (out * 0.20 + Vector3.UP * 0.67) * length
		var tip := dirt + (out * 0.85 + Vector3.UP * rng.randf_range(0.38, 0.82)) * length
		tube(dirt, stem_end, 0.012, 0.008, foliage.darkened(0.20), 6)
		leaf(stem_end, tip, radius * rng.randf_range(0.46, 0.82), foliage.lerp(Color("c2d47b"), rng.randf_range(0.0, 0.40)))
