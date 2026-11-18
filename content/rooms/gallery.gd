@tool
extends "res://content/rooms/room_set.gd"

const STONE := Color("d4c6af")
const SAND := Color("efdec2")
const INK := Color("28384a")
const BRONZE := Color("ba8763")
const BLUE := Color("395d78")


func _build() -> void:
	section("Interior")
	_terrace()
	# Floor-to-ceiling windows along the ocean-facing wall.
	box(Vector3(0, 0.15, -4.15), Vector3(7.6, 0.30, 0.22), INK)
	box(Vector3(0, 3.32, -4.15), Vector3(7.6, 0.46, 0.23), SAND)
	box(Vector3(0, 0.89, -4.22), Vector3(7.58, 0.038, 0.052), BRONZE)
	for x: float in [-3.76, -2.50, -1.25, 1.25, 2.5, 3.76]:
		box(Vector3(x, 1.78, -4.14), Vector3(0.055, 3.12, 0.10), INK)
		box(Vector3(x + 0.033, 1.78, -4.09), Vector3(0.015, 3.12, 0.015), BRONZE)
	# Upholstered window sofa, low travertine shelves and draped curtains.
	_sofa()
	var left := Vector3(-2.64, 0, -3.87)
	box(left + Vector3.UP * 0.26, Vector3(1.82, 0.45, 0.45), INK)
	box(left + Vector3.UP * 0.51, Vector3(1.94, 0.093, 0.52), SAND)
	tube(left + Vector3(-0.55, 0.555, 0), left + Vector3(-0.55, 0.64, 0), 0.19, 0.17, BRONZE)
	band(left + Vector3(-0.55, 0.93, 0.03), 0.23, 0.31, BRONZE, Basis(Vector3.UP, -0.18))
	orb(left + Vector3(-0.55, 0.93, 0.03), Vector3.ONE * 0.135, Color("f9deb1"))
	planter(left + Vector3(0.57, 0.556, 0.04), 0.18, 0.23, SAND, Color("739875"), 16)
	for side: float in [-1.0, 1.0]:
		for i in 8:
			var x := side * (3.25 + i * 0.068)
			var z := -3.95 + cos(i * 2.1) * 0.047
			gradient(Vector3(x, 0.11, z), Vector3(x + side * 0.085, 0.11, z + 0.045),
				Vector3(x + side * 0.062, 3.20, z + 0.045), Vector3(x, 3.20, z),
				STONE.darkened((i % 3) * 0.08), SAND.lightened(0.14))
	for i in 3:
		hanging_globe(Vector3(-0.54 + i * 0.54, 2.87 - (i % 2) * 0.26, -2.21),
			3.50, 0.14 + (i % 2) * 0.037, BRONZE, Color("ffe6b6"))
	section("Sides")
	for side: float in [-1.0, 1.0]:
		var x := side * 3.79
		box(Vector3(x, 1.78, 0), Vector3(0.14, 3.56, 8.3), SAND)
		box(Vector3(x - side * 0.081, 0.45, 0), Vector3(0.04, 0.90, 8.3), INK)
		box(Vector3(x - side * 0.11, 0.91, 0), Vector3(0.04, 0.028, 8.3), BRONZE)
		for i in 12:
			box(Vector3(x - side * 0.10, 1.77, 1.64 + i * 0.13), Vector3(0.10, 3.54, 0.055), BRONZE.darkened(0.33))
		_seascape_panel(x - side * 0.128, -0.68, side)
	section("Front")
	box(Vector3(0, 1.77, 4.15), Vector3(7.6, 3.54, 0.20), SAND)
	for i in range(-6, 7):
		box(Vector3(i * 0.18, 1.77, 4.02), Vector3(0.075, 3.54, 0.09), INK)
	section("Roof")
	box(Vector3(0, 3.61, 0), Vector3(7.68, 0.17, 8.45), SAND)
	for side: float in [-1.0, 1.0]:
		box(Vector3(side * 3.42, 3.40, 0), Vector3(0.76, 0.18, 8.31), STONE)
		box(Vector3(side * 3.05, 3.51, 0), Vector3(0.042, 0.045, 8.2), Color("ffe2a5"))
		box(Vector3(0, 3.40, side * 3.87), Vector3(6.10, 0.18, 0.57), STONE)
	section("Sky")
	_ocean()


func _terrace() -> void:
	box(Vector3(0, -0.13, 0), Vector3(7.6, 0.25, 8.32), INK)
	for x in 6:
		for z in 7:
			var colour := STONE.lightened(0.04 * ((x * 7 + z * 3) % 6))
			box(Vector3((x - 2.5) * 1.265, -0.015, (z - 3) * 1.186),
				Vector3(1.253, 0.03, 1.174), colour)
	for side: float in [-1.0, 1.0]:
		box(Vector3(side * 3.42, 0.002, 0), Vector3(0.042, 0.005, 7.6), BRONZE)
		box(Vector3(0, 0.002, side * 3.8), Vector3(6.88, 0.005, 0.042), BRONZE)
	var at := Vector3(0, 0.012, -0.84)
	var horizontal := Basis(Vector3.RIGHT, PI * 0.5)
	band(at, 0, 1.43, Color("95adac"), horizontal, 64)
	band(at + Vector3.UP * 0.002, 1.30, 1.38, Color("e4d4ab"), horizontal, 64)
	band(at + Vector3.UP * 0.004, 1.14, 1.17, BLUE, horizontal, 64)


func _sofa() -> void:
	var at := Vector3(2.05, 0, -3.83)
	box(at + Vector3.UP * 0.105, Vector3(2.50, 0.21, 0.71), BRONZE.darkened(0.42))
	box(at + Vector3.UP * 0.265, Vector3(2.60, 0.22, 0.77), BLUE.darkened(0.22))
	box(at + Vector3(0, 0.51, -0.25), Vector3(2.56, 0.48, 0.23), BLUE)
	for i in 5:
		var x := (i - 2) * 0.48
		orb(at + Vector3(x, 0.39, 0.065), Vector3(0.265, 0.11, 0.31), BLUE, 6, 12)
		orb(at + Vector3(x, 0.62, -0.095), Vector3(0.255, 0.215, 0.155), BLUE.lightened(0.10), 6, 12)
	for x: float in [-1.22, 1.22]:
		orb(at + Vector3(x, 0.54, 0.03), Vector3(0.16, 0.17, 0.36), BLUE)
	orb(at + Vector3(-0.84, 0.69, 0.084), Vector3(0.19, 0.19, 0.14), Color("dc9e74"))
	orb(at + Vector3(0.83, 0.69, 0.084), Vector3(0.21, 0.21, 0.14), Color("e4d2b2"))


func _seascape_panel(x: float, z: float, side: float) -> void:
	box(Vector3(x, 1.85, z), Vector3(0.065, 1.06, 1.95), BRONZE)
	x -= side * 0.037
	gradient(Vector3(x, 1.38, z - 0.92), Vector3(x, 1.38, z + 0.92),
		Vector3(x, 2.32, z + 0.92), Vector3(x, 2.32, z - 0.92), BLUE, Color("f0b28d"))


func _ocean() -> void:
	gradient(Vector3(-68, -1.9, -46), Vector3(68, -1.9, -46),
		Vector3(68, 16, -46), Vector3(-68, 16, -46), Color("f9be91"), Color("616f9d"))
	gradient(Vector3(-68, 16, -46), Vector3(68, 16, -46),
		Vector3(68, 52, -46), Vector3(-68, 52, -46), Color("616f9d"), Color("4a5d8b"))
	orb(Vector3(-9.4, 3.45, -43), Vector3(2.08, 2.08, 0.18), Color("ffdaa2"), 12, 32)
	gradient(Vector3(-62, -1.65, -4.2), Vector3(62, -1.65, -4.2),
		Vector3(62, -1.65, -45.8), Vector3(-62, -1.65, -45.8), Color("237b87"), Color("807993"))
	for layer in 3:
		var z := -40.0 + layer * 4.2
		var colours := [Color("858198"), Color("646e8b"), Color("426b80")]
		var edge := -58.0 + layer * 2.8
		while edge < -13.0 + layer * 0.85:
			var span := 2.9 + 1.9 * absf(sin(edge))
			var height := 1.02 + absf(cos(edge * 1.82)) * (2.4 - layer * 0.3)
			triangle(Vector3(edge, -1.62, z), Vector3(edge + span * 1.6, -1.62, z),
				Vector3(edge + span * 0.60, height, z), colours[layer])
			edge += span * 0.65
	var rng := RandomNumberGenerator.new()
	rng.seed = 140
	for i in 88:
		var at := Vector3(rng.randf_range(-35.0, 35.0), -1.64, rng.randf_range(-43.0, -5.2))
		var colour := Color("b2a7bc") if i % 4 == 0 else Color("70a7af")
		var span := rng.randf_range(0.3, 3.7)
		quad(at, at + Vector3(span, 0, 0), at + Vector3(span * 0.84, 0, 0.09), at + Vector3(0.13, 0, 0.092), colour)
