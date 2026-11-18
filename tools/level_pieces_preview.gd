extends Node3D
## A still picture of every level picture (entry/fx/level_piece.gd) in its bubble, in a row, to
## build/level_pieces/level_pieces.png, plus a coarse blurred copy (roughly how a low-vision child might see it):
##   xvfb-run -a -s "-screen 0 1600x700x24" godot --rendering-driver opengl3 --xr-mode off --path . \
##       res://tools/level_pieces_preview.tscn

const IDS: Array[StringName] = [&"shadow", &"size", &"clutter", &"color", &"similar_shadows", &"one_way", &"both_ways"]
const SHELF := preload("res://content/tasks/tidy_shelf.tres")
const BUTTERFLIES := preload("res://content/tasks/catch_butterflies.tres")


func _ready() -> void:
	get_window().size = Vector2i(1600, 560)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.91, 0.89, 0.84)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.6
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-35), deg_to_rad(20), 0)
	add_child(sun)
	for i in IDS.size():
		var level: TaskLevel = SHELF.level_by_id(IDS[i]) if SHELF.level_by_id(IDS[i]) != null else BUTTERFLIES.level_by_id(IDS[i])
		var piece := Impression.make(&"butterflies" if level.project == &"butterflies" else &"shelf")
		add_child(piece)
		LevelPiece.dress(piece, level)
		piece.add_bubble()
		piece.position = Vector3((i - (IDS.size() - 1) * 0.5) * 0.3, -0.075, 0)
	var eye := Camera3D.new()
	eye.position = Vector3(0, 0, 1.25)
	eye.fov = 34.0
	add_child(eye)
	eye.make_current()
	for f in 8:
		await get_tree().process_frame
	var out := ProjectSettings.globalize_path("res://build/level_pieces")
	DirAccess.make_dir_recursive_absolute(out)
	var image := get_viewport().get_texture().get_image()
	image.save_png(out + "/level_pieces.png")
	var small := image.duplicate() as Image
	small.resize(image.get_width() / 8, image.get_height() / 8, Image.INTERPOLATE_BILINEAR)
	small.resize(image.get_width(), image.get_height(), Image.INTERPOLATE_BILINEAR)
	small.save_png(out + "/level_pieces_blurred.png")
	print("LEVEL PIECES: ", out)
	get_tree().quit()
