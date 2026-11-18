extends RefCounted

const MODELS := {
	"mug": preload("res://trials/desk/assets/mug.glb"),
	"notebook": preload("res://trials/desk/assets/notebook.glb"),
	"pencil": preload("res://trials/desk/assets/pencil.glb"),
	"headphones": preload("res://trials/desk/assets/headphones.glb"),
	"plant": preload("res://trials/desk/assets/plant.glb"),
}
const SIZES := {
	"mug": Vector3(0.105, 0.083519, 0.087112),
	"notebook": Vector3(0.105305, 0.012506, 0.17),
	"pencil": Vector3(0.008176, 0.009374, 0.145),
	"headphones": Vector3(0.135, 0.047157, 0.12314),
	"plant": Vector3(0.135608, 0.112251, 0.14),
}
const WOOD := preload("res://trials/tidy/assets/plywood_diff_1k.jpg")


static func size_of(key: String) -> Vector3:
	return SIZES[key]


## The meshes rest on Y = 0. Move the pivot to the centre for carrying and placing them.
static func centred_model(key: String, factor: float) -> Node3D:
	var model: Node3D = MODELS[key].instantiate()
	model.name = "Model"
	model.scale = Vector3.ONE * factor
	model.position.y = -size_of(key).y * factor * 0.5
	return model


static func material(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.9
	return mat


static func box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.material_override = mat
	parent.add_child(part)
	part.position = at
	return part
