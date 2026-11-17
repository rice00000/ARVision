extends RefCounted
## Local, metre-sized source models and their top-view silhouettes share a pivot.

const KEYS: Array[String] = ["mug", "notebook", "pencil", "headphones", "plant"]
const MODELS := {
	"mug": preload("res://trials/desk/assets/mug.glb"),
	"notebook": preload("res://trials/desk/assets/notebook.glb"),
	"pencil": preload("res://trials/desk/assets/pencil.glb"),
	"headphones": preload("res://trials/desk/assets/headphones.glb"),
	"plant": preload("res://trials/desk/assets/plant.glb"),
}
const OUTLINES := {
	"mug": preload("res://trials/desk/assets/mug_outline.png"),
	"notebook": preload("res://trials/desk/assets/notebook_outline.png"),
	"pencil": preload("res://trials/desk/assets/pencil_outline.png"),
	"headphones": preload("res://trials/desk/assets/headphones_outline.png"),
	"plant": preload("res://trials/desk/assets/plant_outline.png"),
}
const WOOD := preload("res://trials/tidy/assets/plywood_diff_1k.jpg")
const SIZES := {
	"mug": Vector3(0.105, 0.083519, 0.087112),
	"notebook": Vector3(0.105305, 0.012506, 0.17),
	"pencil": Vector3(0.008176, 0.009374, 0.145),
	"headphones": Vector3(0.135, 0.047157, 0.12314),
	"plant": Vector3(0.135608, 0.112251, 0.14),
}


static func size_of(key: String) -> Vector3:
	return SIZES[key]


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


static func build_table(parent: Node3D) -> void:
	var wood := material(Color("#c7a57c"))
	wood.albedo_texture = WOOD
	wood.uv1_triplanar = true
	wood.uv1_scale = Vector3.ONE * 1.5
	box(parent, Vector3(0.82, 0.025, 0.49), Vector3(0, -0.016, -0.245), wood)
	var leg := material(Color("#3e5157"))
	for x in [-0.355, 0.355]:
		for z in [-0.43, -0.07]:
			box(parent, Vector3(0.025, 0.65, 0.025), Vector3(x, -0.35, z), leg)
	# Quiet, contrasting working mat; no labels or per-object colours give away matches.
	box(parent, Vector3(0.365, 0.003, 0.44), Vector3(0.17, 0, -0.245), material(Color("#edf0df")))
	var tray := material(Color("#b1c4bb"))
	box(parent, Vector3(0.34, 0.009, 0.44), Vector3(-0.195, 0, -0.245), tray)
	for x in [-0.365, -0.025]:
		box(parent, Vector3(0.006, 0.012, 0.44), Vector3(x, 0.003, -0.245), tray)
	for z in [-0.465, -0.025]:
		box(parent, Vector3(0.34, 0.012, 0.006), Vector3(-0.195, 0.003, z), tray)


static func outline(key: String) -> MeshInstance3D:
	var decal := MeshInstance3D.new()
	decal.name = "Outline_" + key
	var quad := QuadMesh.new()
	var size := size_of(key)
	quad.size = Vector2(size.x, size.z) + Vector2.ONE * 0.016
	decal.mesh = quad
	decal.rotation.x = -PI / 2.0
	var ink := material(Color.WHITE)
	ink.albedo_texture = OUTLINES[key]
	ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	decal.material_override = ink
	decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return decal
