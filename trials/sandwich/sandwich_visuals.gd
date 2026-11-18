extends RefCounted

const MODELS := {
	"bread": preload("res://trials/sandwich/assets/bread.glb"),
	"lettuce": preload("res://trials/sandwich/assets/lettuce.glb"),
	"tomato": preload("res://trials/sandwich/assets/tomato.glb"),
	"cheese": preload("res://trials/sandwich/assets/cheese.glb"),
}
const SIZES := {
	"bread": Vector3(0.117, 0.026, 0.136),
	"lettuce": Vector3(0.140, 0.019, 0.139),
	"tomato": Vector3(0.108, 0.019, 0.108),
	"cheese": Vector3(0.121, 0.013, 0.121),
}
const PLATE := preload("res://trials/sandwich/assets/plate.glb")
const DEEP := Color("#193c3e")
const TEAL := Color("#32635e")
const GOLD := Color("#ffc879")
const CREAM := Color("#fff4d7")


static func model(key: String) -> Node3D:
	return MODELS[key].instantiate()


static func material(colour: Color, unlit := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.78
	if unlit:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


static func display(parent: Node3D, mesh: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = mat
	parent.add_child(part)
	part.position = at
	return part


static func box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return display(parent, mesh, at, mat)


static func slab(parent: Node3D, size: Vector3, radius: float, at: Vector3, mat: Material) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge: Array[Vector3] = []
	var half := size * 0.5
	for corner in 4:
		var diagonal := (corner + 0.5) * PI * 0.5
		var centre := Vector3(signf(cos(diagonal)) * (half.x - radius), half.y,
			signf(sin(diagonal)) * (half.z - radius))
		for step in 7:
			var angle := (corner + step / 6.0) * PI * 0.5
			edge.append(centre + Vector3(cos(angle), 0, sin(angle)) * radius)
	for index in edge.size():
		var start := edge[index]
		var end := edge[(index + 1) % edge.size()]
		var down := Vector3.DOWN * size.y
		surface.set_normal(Vector3.UP)
		for point in [Vector3.UP * half.y, start, end]:
			surface.add_vertex(point)
		surface.set_normal((end - start).cross(Vector3.DOWN).normalized())
		for point in [end, start, start + down, end, start + down, end + down]:
			surface.add_vertex(point)
	return display(parent, surface.commit(), at, mat)


static func disc(parent: Node3D, radius: float, height: float, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 40
	mesh.rings = 0
	return display(parent, mesh, at, mat)


static func label(parent: Node3D, text: String, at: Vector3, pixels: float) -> Label3D:
	var lettering := Label3D.new()
	lettering.text = text
	lettering.font_size = 42
	lettering.pixel_size = pixels
	lettering.modulate = CREAM
	lettering.outline_size = 0
	parent.add_child(lettering)
	lettering.position = at
	return lettering


static func counter(parent: Node3D, wells: Array[Vector3], plate: Vector3) -> void:
	var dark := material(DEEP)
	slab(parent, Vector3(0.669, 0.039, 0.459), 0.022, Vector3(0, -0.0275, -0.233), dark)
	slab(parent, Vector3(0.676, 0.008, 0.463), 0.022, Vector3(0, -0.012, -0.233), material(Color("#c6a36f")))
	slab(parent, Vector3(0.676, 0.008, 0.463), 0.022, Vector3(0, -0.004, -0.233), material(TEAL))
	for across: float in [-0.28, 0.28]:
		for depth: float in [-0.08, -0.40]:
			box(parent, Vector3(0.04, 0.57, 0.045), Vector3(across, -0.32, depth), dark)
	slab(parent, Vector3(0.326, 0.003, 0.327), 0.014, Vector3(-0.169, 0.0013, -0.199), dark)
	var rim := material(Color("#54827a"))
	var well := material(Color("#244c4a"))
	for at in wells:
		disc(parent, 0.075, 0.002, at - Vector3.UP * 0.002, rim)
		disc(parent, 0.071, 0.002, at - Vector3.UP * 0.001, well)
	var dish: Node3D = PLATE.instantiate()
	parent.add_child(dish)
	dish.position = plate
	label(parent, "PREP", Vector3(-0.166, 0.002, -0.023), 0.00029).rotation.x = -PI * 0.5
	label(parent, "BUILD", Vector3(0.165, 0.002, -0.023), 0.00029).rotation.x = -PI * 0.5


static func sample(parent: Node3D, recipe: Array[String]) -> void:
	var body := Node3D.new()
	parent.add_child(body)
	body.rotation.x = -0.69
	body.position = Vector3(0, 0.036, 0.048)
	var dark := material(DEEP)
	var bronze := material(Color("#c6a36f"))
	slab(parent, Vector3(0.212, 0.014, 0.133), 0.014, Vector3(0, 0.007, -0.021), dark)
	slab(body, Vector3(0.207, 0.012, 0.315), 0.013, Vector3(0, 0.149, -0.034), dark).rotation.x = PI * 0.5
	box(body, Vector3(0.181, 0.003, 0.012), Vector3(0, 0.297, -0.035), bronze)
	box(parent, Vector3(0.196, 0.028, 0.008), Vector3(0, 0.025, 0.047), dark).rotation.x = -0.30
	label(parent, "SAMPLE", Vector3(0, 0.025, 0.053), 0.00044).rotation.x = -0.30
	var bottom := 0.033
	var layers: Array[String] = ["bread"]
	layers.append_array(recipe)
	for key in layers:
		var layer := model(key)
		body.add_child(layer)
		layer.position = Vector3(0, bottom, 0.029)
		layer.rotation = Vector3(0.46, -0.12, 0.0)
		layer.scale = Vector3.ONE * 0.87
		bottom += SIZES[key].y * 0.87 + 0.036


static func spark(parent: Node3D, colour: Color) -> MeshInstance3D:
	var mat := material(colour, true)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = []
	for index in 8:
		var angle := index * TAU / 8.0
		var radius := 0.009 if index % 2 == 0 else 0.0025
		points.append(Vector3(cos(angle) * 0.75, sin(angle), 0) * radius)
	for index in points.size():
		for point in [Vector3.ZERO, points[index], points[(index + 1) % points.size()]]:
			surface.add_vertex(point)
	var star := display(parent, surface.commit(), Vector3.ZERO, mat)
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return star
