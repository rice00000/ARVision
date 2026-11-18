@tool
extends "res://content/rooms/room_set.gd"

const IRON := Color("315a50")
const GOLD := Color("c49b5b")
const LIMESTONE := Color("ccc5a6")
const LEAVES := Color("4c8053")
const PINK := Color("d98683")


func _build() -> void:
	section("Interior")
	_tiles()
	for x: float in [-2.8, 0.0, 2.8]:
		_window(Vector3(x, 0, -4.15))
	_fountain(Vector3(0, 0, -3.52))
	planter(Vector3(-2.56, 0, -3.63), 0.46, 0.49, Color("c17d67"), LEAVES, 845)
	planter(Vector3(2.66, 0, -3.57), 0.50, 0.58, LIMESTONE, Color("3b6e52"), 841)
	_flowers(Vector3(-1.45, 0, -3.67), PINK)
	_flowers(Vector3(1.48, 0, -3.57), Color("ebba6a"))
	for i in 3:
		var x := (i - 1) * 1.53
		hanging_globe(Vector3(x, 2.96 + (i % 2) * 0.23, -2.16), 3.94, 0.17, GOLD, Color("fff1bc"))
		band(Vector3(x, 2.96 + (i % 2) * 0.23, -2.16), 0.18, 0.212, GOLD)
	section("Sides")
	for side: float in [-1.0, 1.0]:
		var x := side * 4.20
		box(Vector3(x, 0.435, 0), Vector3(0.16, 0.87, 8.3), IRON)
		box(Vector3(x, 2.56, 0), Vector3(0.13, 0.17, 8.3), IRON)
		box(Vector3(x - side * 0.086, 0.865, 0), Vector3(0.038, 0.041, 8.28), GOLD)
		for z: float in [-4.15, -2.1, 0.0, 2.1, 4.15]:
			box(Vector3(x, 1.70, z), Vector3(0.12, 1.80, 0.12), IRON)
		for z: float in [-1.58, 1.68]:
			planter(Vector3(x - side * 0.48, 0, z), 0.38, 0.44, Color("7d9583"), LEAVES, int((4 + side) * 296 + z * 35))
	section("Front")
	box(Vector3(0, 0.40, 4.15), Vector3(8.4, 0.80, 0.16), IRON)
	for x: float in [-4.17, -2.7, -1.4, 0.0, 1.4, 2.7, 4.17]:
		box(Vector3(x, 1.70, 4.15), Vector3(0.09, 1.8, 0.12), IRON)
	box(Vector3(0, 2.54, 4.15), Vector3(8.4, 0.13, 0.13), IRON)
	section("Roof")
	for z: float in [-4.15, -2.1, 0.0, 2.1, 4.15]:
		arch(Vector3(0, 2.57, z), 4.17, 1.78, 0.065, IRON, 0.1)
		box(Vector3(0, 2.56, z), Vector3(8.4, 0.095, 0.10), IRON)
	for i in range(1, 8):
		var angle := i * PI / 8
		box(Vector3(cos(angle) * 4.20, 2.60 + sin(angle) * 1.79, 0), Vector3(0.085, 0.085, 8.4), IRON)
	section("Sky")
	_garden_outside()


func _tiles() -> void:
	box(Vector3(0, -0.13, 0), Vector3(8.48, 0.25, 8.38), IRON)
	for x in 12:
		for z in 12:
			var stone := LIMESTONE if (x + z) % 2 == 0 else Color("778f78")
			var at := Vector3((x - 5.5) * 0.7, -0.015, (z - 5.5) * 0.692)
			box(at, Vector3(0.689, 0.03, 0.68), stone.lightened(((x + 3 * z) % 4) * 0.027))
			var centre := at + Vector3.UP * 0.017
			var inset := IRON if (x + z) % 2 == 0 else Color("c9bc90")
			if x in [0, 11] or z in [0, 11]:
				quad(centre + Vector3.LEFT * 0.11, centre + Vector3.FORWARD * 0.11, centre + Vector3.RIGHT * 0.11,
					centre + Vector3.BACK * 0.11, inset)


func _window(at: Vector3) -> void:
	box(at + Vector3(0, 0.44, 0), Vector3(2.8, 0.88, 0.18), IRON)
	box(at + Vector3(0, 0.88, 0.092), Vector3(2.8, 0.042, 0.045), GOLD)
	for x: float in [-1.30, -0.035, 1.30]:
		box(at + Vector3(x, 1.73, 0.024), Vector3(0.064, 1.72, 0.11), IRON)
	arch(at + Vector3(0, 2.53, 0.072), 1.24, 0.79, 0.08, IRON)
	arch(at + Vector3(0, 2.53, 0.082), 1.23, 0.77, 0.026, GOLD)
	box(at + Vector3(0, 2.53, 0.05), Vector3(2.75, 0.09, 0.12), IRON)
	band(at + Vector3(0, 2.78, 0.082), 0.19, 0.235, GOLD, Basis.IDENTITY, 32)
	for x: float in [-0.61, 0.61]:
		box(at + Vector3(x, 1.045, 0.107), Vector3(1.04, 0.18, 0.07), IRON.lightened(0.16))


func _flowers(at: Vector3, petals: Color) -> void:
	planter(at, 0.25, 0.33, Color("a47e5e"), LEAVES, 271)
	for i in 7:
		var angle := i * TAU / 7
		var blossom := at + Vector3(cos(angle) * 0.26, 0.94 + cos(i * 2.4) * 0.13, sin(angle) * 0.21)
		tube(at + Vector3.UP * 0.30, blossom, 0.014, 0.008, LEAVES, 6)
		orb(blossom, Vector3.ONE * 0.094, petals.lightened(0.04 * (i % 3)), 5, 10)
		orb(blossom + Vector3(0, 0.06, 0.05), Vector3.ONE * 0.04, Color("f6cd74"), 5, 9)


func _fountain(at: Vector3) -> void:
	tube(at, at + Vector3.UP * 0.18, 0.79, 0.85, IRON, 24)
	tube(at + Vector3.UP * 0.18, at + Vector3.UP * 0.49, 0.83, 0.92, LIMESTONE, 32)
	tube(at + Vector3.UP * 0.49, at + Vector3.UP * 0.512, 0.83, 0.83, Color("6caf9f"), 32)
	tube(at + Vector3.UP * 0.53, at + Vector3.UP * 1.10, 0.33, 0.15, LIMESTONE, 16)
	tube(at + Vector3.UP * 1.04, at + Vector3.UP * 1.16, 0.19, 0.37, LIMESTONE, 20)
	tube(at + Vector3.UP * 1.16, at + Vector3.UP * 1.18, 0.30, 0.30, Color("73b7a8"), 24)
	orb(at + Vector3.UP * 1.29, Vector3(0.064, 0.16, 0.064), Color("bfe3cb"), 6, 12)
	var horizontal := Basis(Vector3.RIGHT, PI * 0.5)
	for i in 3:
		band(at + Vector3.UP * 0.518, 0.46 + i * 0.12, 0.474 + i * 0.12, Color("a4d1b9"), horizontal, 40)
	for i in 5:
		var direction := Vector3(cos(i * TAU / 5), 0, sin(i * TAU / 5))
		beam(at + Vector3.UP * 1.15 + direction * 0.36, at + Vector3.UP * 0.53 + direction * 0.52,
			0.013, Color("bde2cc"))


func _garden_outside() -> void:
	for i in 4:
		var turn := Basis(Vector3.UP, i * PI * 0.5)
		gradient(turn * Vector3(-32, -2, -28), turn * Vector3(32, -2, -28),
			turn * Vector3(32, 24, -28), turn * Vector3(-32, 24, -28), Color("e2edb5"), Color("84bdc7"))
	box(Vector3(0, 24.2, 0), Vector3(56.01, 0.42, 56.01), Color("84bdc7"))
	box(Vector3(0, -0.72, 0), Vector3(58, 0.62, 58), Color("729575"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1844
	for i in 46:
		var angle := TAU * i / 46.0
		var direction := Vector3(cos(angle), 0, sin(angle))
		var distance := rng.randf_range(7.4, 19.0)
		var at := direction * distance
		var height := rng.randf_range(1.6, 4.8)
		tube(at, at + Vector3.UP * height * 0.75, 0.14, 0.072, Color("746456"), 7)
		for leaf_index in 3:
			var offset := Vector3(cos(leaf_index * 2.4), 0.15 * leaf_index, sin(leaf_index * 2.4))
			orb(at + Vector3.UP * height * 0.72 + offset, Vector3(1.18, height * 0.40, 1.21),
				LEAVES.lerp(Color("b3bc76"), rng.randf_range(0.12, 0.70)), 5, 10)
