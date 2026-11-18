@tool
extends "res://content/rooms/room_set.gd"

const PLASTER := Color("eed4ab")
const WALNUT := Color("634031")
const OAK := Color("ac7548")
const BRASS := Color("edbb68")
const OLIVE := Color("6f8260")


func _build() -> void:
	section("Interior")
	_floor()
	# A low window seat and plaster fireplace are built beyond the editable floor.
	box(Vector3(-1.52, 1.52, -3.30), Vector3(3.9, 3.04, 0.16), PLASTER)
	box(Vector3(1.76, 0.30, -3.30), Vector3(2.66, 0.6, 0.16), PLASTER)
	box(Vector3(2.97, 1.82, -3.30), Vector3(0.89, 2.44, 0.16), PLASTER)
	box(Vector3(1.47, 2.82, -3.30), Vector3(2.13, 0.44, 0.16), PLASTER)
	for x: float in [0.44, 1.47, 2.51]:
		box(Vector3(x, 1.61, -3.18), Vector3(0.075, 2.04, 0.15), WALNUT)
	for y: float in [0.59, 1.36, 2.61]:
		box(Vector3(1.47, y, -3.18), Vector3(2.13, 0.068, 0.19), WALNUT)
	box(Vector3(1.48, 0.23, -2.91), Vector3(2.35, 0.46, 0.91), OAK)
	box(Vector3(1.48, 0.49, -2.90), Vector3(2.25, 0.12, 0.78), OLIVE)
	orb(Vector3(0.72, 0.62, -3.01), Vector3(0.25, 0.21, 0.16), Color("be6149"))
	orb(Vector3(2.20, 0.64, -3.01), Vector3(0.22, 0.22, 0.16), Color("efb969"))
	_fireplace()
	for x: float in [-2.85, 2.92]:
		box(Vector3(x, 1.67, -3.11), Vector3(0.08, 0.26, 0.10), WALNUT)
		orb(Vector3(x, 1.77, -2.99), Vector3(0.105, 0.105, 0.105), Color("fff2bb"))
	planter(Vector3(2.91, 0, -2.70), 0.24, 0.38, Color("ac5b45"), OLIVE, 248)
	hanging_globe(Vector3(0, 2.67, -1.72), 3.75, 0.26, WALNUT, Color("ffe8b0"))
	section("Sides")
	for side: float in [-1.0, 1.0]:
		var x := side * 3.42
		box(Vector3(x, 1.52, 0), Vector3(0.14, 3.04, 6.6), PLASTER.darkened(0.07))
		box(Vector3(x - side * 0.08, 0.15, 0), Vector3(0.07, 0.3, 6.6), OAK)
		for z: float in [-2.1, 0.0, 2.1]:
			box(Vector3(x - side * 0.10, 1.50, z), Vector3(0.13, 3.0, 0.10), WALNUT)
		for z: float in [-1.16, 0.95]:
			box(Vector3(x - side * 0.12, 1.83, z), Vector3(0.06, 0.88, 0.66), WALNUT)
			box(Vector3(x - side * 0.16, 1.83, z), Vector3(0.02, 0.72, 0.51), Color("f4deae"))
			box(Vector3(x - side * 0.18, 1.83, z), Vector3(0.02, 0.38, 0.23), OLIVE,
				Basis(Vector3.RIGHT, PI * 0.25))
	section("Front")
	box(Vector3(0, 1.52, 3.30), Vector3(6.84, 3.04, 0.16), PLASTER)
	box(Vector3(0, 1.12, 3.19), Vector3(1.08, 2.24, 0.13), WALNUT)
	box(Vector3(0, 1.12, 3.11), Vector3(0.84, 1.97, 0.07), OAK)
	orb(Vector3(0.33, 1.04, 3.00), Vector3.ONE * 0.048, BRASS)
	section("Roof")
	for side: float in [-1.0, 1.0]:
		var eaves := side * 3.47
		quad(Vector3(0, 4.23, -3.4), Vector3(0, 4.23, 3.4),
			Vector3(eaves, 3.03, 3.4), Vector3(eaves, 3.03, -3.4), OAK)
		for z: float in [-3.38, 3.38]:
			triangle(Vector3(0, 3.03, z), Vector3(0, 4.23, z), Vector3(eaves, 3.03, z), PLASTER)
		for z: float in [-3.23, -1.62, 0.0, 1.62, 3.23]:
			beam(Vector3(0, 4.18, z), Vector3(eaves, 2.98, z), 0.17, WALNUT)
	beam(Vector3(0, 4.15, -3.40), Vector3(0, 4.15, 3.40), 0.23, WALNUT)
	section("Sky")
	gradient(Vector3(-25, -5, -24), Vector3(25, -5, -24),
		Vector3(25, 16, -24), Vector3(-25, 16, -24), Color("ffd6a0"), Color("8dbbc9"))
	orb(Vector3(6.8, 4.0, -22), Vector3.ONE * 1.2, Color("fff3b4"))
	for i in 8:
		var x := -18.0 + i * 5.5
		orb(Vector3(x, -3.7, -18 + i % 3), Vector3(6.8, 4.5 + cos(i * 1.6), 3.0),
			Color("74866d").lightened((i % 3) * 0.09), 7, 16)


func _floor() -> void:
	box(Vector3(0, -0.13, 0), Vector3(6.84, 0.25, 6.6), WALNUT)
	for i in 21:
		var x := (i - 10) * 0.325
		var split := sin(i * 1.83) * 2.0
		for row in [Vector2(-3.29, split), Vector2(split + 0.012, 3.29)]:
			var shade := 0.04 + (i % 5) * 0.028
			box(Vector3(x, -0.015, (row.x + row.y) * 0.5), Vector3(0.316, 0.03, row.y - row.x),
				OAK.darkened(shade) if row.x < -3.0 else OAK.lightened(shade))
	var rug := Vector3(0, 0.009, -0.94)
	box(rug, Vector3(3.26, 0.014, 2.34), Color("eed7b7"))
	box(rug + Vector3.UP * 0.010, Vector3(3.10, 0.007, 2.18), Color("8b4d42"))
	box(rug + Vector3.UP * 0.015, Vector3(2.90, 0.007, 1.98), Color("b96450"))
	for i in range(-1, 2):
		var at := rug + Vector3(i * 0.91, 0.022, 0)
		_diamond(at, 0.44, 0.76, Color("f2d8af"))
		_diamond(at + Vector3.UP * 0.002, 0.31, 0.52, Color("8b4d42"))
		_diamond(at + Vector3.UP * 0.004, 0.16, 0.28, Color("f4b270"))


func _diamond(at: Vector3, x: float, z: float, colour: Color) -> void:
	quad(at + Vector3.LEFT * x, at + Vector3.FORWARD * z, at + Vector3.RIGHT * x,
		at + Vector3.BACK * z, colour)


func _fireplace() -> void:
	var x := -1.24
	box(Vector3(x, 0.09, -2.91), Vector3(2.28, 0.18, 0.81), Color("b68d71"))
	box(Vector3(x, 0.77, -3.14), Vector3(1.99, 1.34, 0.28), Color("dfb99d"))
	box(Vector3(x, 0.40, -2.986), Vector3(1.10, 0.50, 0.04), Color("342520"))
	for i in 24:
		var a := PI * i / 24
		var b := PI * (i + 1) / 24
		var centre := Vector3(x, 0.65, -2.96)
		triangle(centre, centre + Vector3(cos(a) * 0.55, sin(a) * 0.48, 0),
			centre + Vector3(cos(b) * 0.55, sin(b) * 0.48, 0), Color("342520"))
	arch(Vector3(x, 0.65, -2.92), 0.55, 0.48, 0.13, Color("f6d9b9"))
	for side: float in [-1.0, 1.0]:
		box(Vector3(x + side * 0.615, 0.401, -2.965), Vector3(0.13, 0.50, 0.09), Color("f6d9b9"))
	box(Vector3(x, 1.45, -3.05), Vector3(2.23, 0.14, 0.50), WALNUT)
	band(Vector3(x, 2.15, -3.19), 0.35, 0.43, BRASS)
	band(Vector3(x, 2.15, -3.203), 0, 0.35, Color("819c9c"))
	tube(Vector3(x - 0.38, 0.29, -2.83), Vector3(x + 0.34, 0.22, -2.79), 0.072, 0.065, WALNUT, 9)
	tube(Vector3(x - 0.29, 0.22, -2.69), Vector3(x + 0.30, 0.28, -2.74), 0.063, 0.070, OAK, 9)
	for i in 5:
		var base := Vector3(x + (i - 2) * 0.145, 0.27, -2.85 + (i % 2) * 0.07)
		var height := 0.24 + (i % 3) * 0.085
		var flame := Color("f79a41") if i % 2 == 0 else Color("ffce61")
		triangle(base - Vector3.RIGHT * 0.105, base + Vector3.RIGHT * 0.105,
			base + Vector3(0.075, height, -0.025), flame)
		triangle(base - Vector3.FORWARD * 0.075, base + Vector3.FORWARD * 0.075,
			base + Vector3(0.075, height, -0.025), flame.lightened(0.25))
