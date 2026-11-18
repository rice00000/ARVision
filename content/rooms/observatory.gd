@tool
extends "res://content/rooms/room_set.gd"

const NAVY := Color("243654")
const DEEP := Color("161d38")
const GOLD := Color("c9a36b")
const PALE := Color("e8cf9a")
const HORIZONTAL := Basis(Vector3.RIGHT, PI * 0.5)
const RADIUS := 4.25


func _build() -> void:
	section("Interior")
	_floor()
	for i in range(3, 9):
		_balustrade(i)
	_telescope(Vector3(-1.65, 0, -3.30))
	_orrery(Vector3(2.30, 0, -3.44))
	section("Sides")
	for i in [2, 9]:
		_balustrade(i)
	section("Front")
	for i in [0, 1, 10, 11]:
		_balustrade(i)
	section("Roof")
	for i in 12:
		var start := _rim(i, 2.38)
		for j in 8:
			var a := j * PI / 16
			var b := (j + 1) * PI / 16
			var from := Vector3(start.x * cos(a), 2.38 + sin(a) * 2.39, start.z * cos(a))
			var to := Vector3(start.x * cos(b), 2.38 + sin(b) * 2.39, start.z * cos(b))
			# Leave a wide slit over the telescope.
			if i not in [5, 6, 7] or j > 4:
				beam(from, to, 0.108, GOLD.darkened(0.22))
	band(Vector3(0, 4.75, 0), 0.30, 0.52, GOLD, HORIZONTAL, 32)
	section("Sky")
	_night()


func _rim(index: int, height: float) -> Vector3:
	var angle := (index + 0.5) * TAU / 12
	return Vector3(sin(angle) * RADIUS, height, cos(angle) * RADIUS)


func _balustrade(index: int) -> void:
	var a := _rim(index, 0.0)
	var b := _rim(index + 1, 0.0)
	var face := (a + b) * 0.5
	var turn := Basis.looking_at(b - a, Vector3.UP)
	var length := a.distance_to(b)
	box(face + Vector3.UP * 0.41, Vector3(0.21, 0.82, length), NAVY, turn)
	box(face + Vector3.UP * 0.85, Vector3(0.30, 0.076, length), GOLD, turn)
	box(face + Vector3.UP * 0.14, Vector3(0.25, 0.028, length), GOLD.darkened(0.20), turn)
	box(a + Vector3.UP * 1.19, Vector3(0.17, 2.38, 0.17), NAVY, turn)
	box(a + Vector3.UP * 2.14, Vector3(0.23, 0.11, 0.23), GOLD, turn)
	beam(a + Vector3.UP * 2.38, b + Vector3.UP * 2.38, 0.086, GOLD)
	var inset := face - face.normalized() * 0.12 + Vector3.UP * 0.50
	var ornament := Basis.looking_at(face.normalized())
	band(inset, 0.172, 0.192, GOLD.darkened(0.18), ornament, 28)
	_star(inset, 0.11, 0.065, ornament, PALE)
	orb(a - a.normalized() * 0.13 + Vector3.UP * 1.11, Vector3.ONE * 0.078, PALE, 6, 12)


func _floor() -> void:
	tube(Vector3(0, -0.24, 0), Vector3(0, 0, 0), RADIUS, RADIUS, DEEP, 48)
	for i in 12:
		var angle := i * TAU / 12
		var ray := Vector3(cos(angle), 0, sin(angle))
		var next := Vector3(cos(angle + TAU / 12), 0, sin(angle + TAU / 12))
		quad(ray * 1.52 + Vector3.UP * 0.003, ray * 4.0 + Vector3.UP * 0.003,
			next * 4.0 + Vector3.UP * 0.003, next * 1.52 + Vector3.UP * 0.003,
			NAVY.lightened(0.055 if i % 2 == 0 else 0.0))
	band(Vector3(0, 0.006, 0), 3.77, 3.80, GOLD.darkened(0.25), HORIZONTAL)
	band(Vector3(0, 0.008, 0), 0.0, 1.58, NAVY, HORIZONTAL, 64)
	band(Vector3(0, 0.010, 0), 1.53, 1.58, GOLD, HORIZONTAL, 64)
	band(Vector3(0, 0.010, 0), 1.39, 1.413, PALE, HORIZONTAL, 64)
	_star(Vector3(0, 0.014, 0), 0.93, 1.29, HORIZONTAL, GOLD)
	_star(Vector3(0, 0.016, 0), 0.44, 0.45, HORIZONTAL.rotated(Vector3.UP, PI / 4), PALE)
	for i in 12:
		var angle := i * TAU / 12
		_star(Vector3(cos(angle) * 1.11, 0.016, sin(angle) * 1.11), 0.06, 0.09, HORIZONTAL, PALE)


func _star(at: Vector3, width: float, height: float, basis: Basis, colour: Color) -> void:
	var right := basis.x * width
	var up := basis.y * height
	for quadrant in 4:
		var a := right.rotated(basis.z, quadrant * PI * 0.5)
		var b := up.rotated(basis.z, quadrant * PI * 0.5)
		quad(at, at + a, at + (a + b) * 0.22, at + b, colour)


func _telescope(at: Vector3) -> void:
	tube(at, at + Vector3.UP * 0.12, 0.69, 0.76, DEEP, 12)
	tube(at + Vector3.UP * 0.12, at + Vector3.UP * 0.19, 0.75, 0.71, GOLD, 12)
	var mount := at + Vector3.UP * 1.29
	for i in 3:
		var angle := i * TAU / 3 + 0.14
		var leg := at + Vector3(cos(angle) * 0.59, 0.20, sin(angle) * 0.59)
		tube(leg, mount - Vector3.UP * 0.10, 0.065, 0.042, GOLD, 10)
	orb(mount - Vector3.UP * 0.08, Vector3.ONE * 0.21, GOLD)
	var axis := Vector3(0.55, 0.52, -0.66).normalized()
	var tail := mount - axis * 0.80
	var lens := mount + axis * 1.04
	tube(tail, lens, 0.114, 0.215, Color("b69468"), 20)
	tube(tail, tail - axis * 0.19, 0.088, 0.068, DEEP, 16)
	for distance: float in [-0.68, 0.14, 0.91, 1.04]:
		var radius := lerpf(0.13, 0.23, (distance + 0.80) / 1.84)
		tube(mount + axis * distance, mount + axis * (distance + 0.039), radius, radius, PALE, 20)
	tube(lens + axis * 0.041, lens + axis * 0.047, 0.179, 0.179, Color("6289a9"), 20)
	tube(tail + Vector3.UP * 0.23, mount + Vector3.UP * 0.23, 0.049, 0.068, DEEP, 12)


func _orrery(at: Vector3) -> void:
	tube(at, at + Vector3.UP * 0.91, 0.39, 0.29, NAVY, 12)
	tube(at + Vector3.UP * 0.87, at + Vector3.UP * 0.94, 0.36, 0.40, GOLD, 16)
	var centre := at + Vector3.UP * 1.34
	tube(at + Vector3.UP * 0.93, centre, 0.032, 0.027, GOLD, 10)
	orb(centre, Vector3.ONE * 0.22, Color("6d91b8"))
	for i in 3:
		var turn := Basis(Vector3.RIGHT, 0.48 + i * 0.7) * Basis(Vector3.UP, i * 0.52)
		var radius := 0.41 + i * 0.095
		band(centre, radius, radius + 0.03, GOLD, turn, 56)
		orb(centre + turn.x * radius, Vector3.ONE * (0.056 + i * 0.013), PALE, 6, 10)


func _night() -> void:
	for i in 4:
		var turn := Basis(Vector3.UP, i * PI * 0.5)
		gradient(turn * Vector3(-50, -8, -49), turn * Vector3(50, -8, -49),
			turn * Vector3(50, 29, -49), turn * Vector3(-50, 29, -49), Color("404e77"), Color("121930"))
	box(Vector3(0, 30, 0), Vector3(100, 1, 100), Color("121930"))
	box(Vector3(0, -8, 0), Vector3(100, 1, 100), Color("404e77"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1782
	for i in 410:
		var angle := rng.randf_range(0, TAU)
		var radius := rng.randf_range(30.0, 43.0)
		var at := Vector3(cos(angle) * radius, rng.randf_range(-1.5, 27.0), sin(angle) * radius)
		var turn := Basis.looking_at(Vector3(at.x, 0, at.z).normalized())
		var size := rng.randf_range(0.033, 0.105) if i % 13 else 0.22
		_star(at, size, size * 1.25, turn, PALE.lerp(Color("92b9e1"), rng.randf()))
	var planet := Vector3(2.9, 5.45, -27.0)
	orb(planet, Vector3(2.28, 2.21, 2.28), Color("d8a287"), 24, 36)
	var orbit := Basis(Vector3.BACK, -0.28) * Basis(Vector3.RIGHT, -1.04)
	band(planet, 2.77, 3.48, Color("e2c3a5"), orbit, 88)
	band(planet, 3.55, 3.89, Color("aa91a0"), orbit, 88)
	orb(Vector3(-11.1, 4.45, -32.0), Vector3.ONE * 0.68, Color("9daec4"), 12, 20)
