extends RefCounted
## Local, metre-sized source models and their top-view silhouettes share a pivot.

const Props := preload("res://trials/study_props.gd")
const OUTLINES := {
	"mug": preload("res://trials/desk/assets/mug_outline.png"),
	"notebook": preload("res://trials/desk/assets/notebook_outline.png"),
	"pencil": preload("res://trials/desk/assets/pencil_outline.png"),
	"headphones": preload("res://trials/desk/assets/headphones_outline.png"),
	"plant": preload("res://trials/desk/assets/plant_outline.png"),
}


static func build_table(parent: Node3D) -> void:
	var wood := Props.material(Color("#c7a57c"))
	wood.albedo_texture = Props.WOOD
	wood.uv1_triplanar = true
	wood.uv1_scale = Vector3.ONE * 1.5
	Props.box(parent, Vector3(0.82, 0.025, 0.49), Vector3(0, -0.016, -0.245), wood)
	var leg := Props.material(Color("#3e5157"))
	for x in [-0.355, 0.355]:
		for z in [-0.43, -0.07]:
			Props.box(parent, Vector3(0.025, 0.65, 0.025), Vector3(x, -0.35, z), leg)
	# Quiet, contrasting working mat; no labels or per-object colours give away matches.
	Props.box(parent, Vector3(0.365, 0.003, 0.44), Vector3(0.17, 0, -0.245), Props.material(Color("#edf0df")))
	var tray := Props.material(Color("#b1c4bb"))
	Props.box(parent, Vector3(0.34, 0.009, 0.44), Vector3(-0.195, 0, -0.245), tray)
	for x in [-0.365, -0.025]:
		Props.box(parent, Vector3(0.006, 0.012, 0.44), Vector3(x, 0.003, -0.245), tray)
	for z in [-0.465, -0.025]:
		Props.box(parent, Vector3(0.34, 0.012, 0.006), Vector3(-0.195, 0.003, z), tray)


static func outline(key: String) -> MeshInstance3D:
	var decal := MeshInstance3D.new()
	decal.name = "Outline_" + key
	var quad := QuadMesh.new()
	var size := Props.size_of(key)
	quad.size = Vector2(size.x, size.z) + Vector2.ONE * 0.016
	decal.mesh = quad
	decal.rotation.x = -PI / 2.0
	var ink := Props.material(Color.WHITE)
	ink.albedo_texture = OUTLINES[key]
	ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	decal.material_override = ink
	decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return decal
