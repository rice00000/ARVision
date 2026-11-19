class_name Shapes
extends RefCounted
## The meshes of the toys: ball, block, cone, drum, ring, egg and gem; and for
## check-ins only, never trained on: pyramid, prism, capsule, disc and bar.
## [param size] is the height, metres.


static func mesh(shape: StringName, size: float) -> Mesh:
	match shape:
		&"ball", &"egg":
			var sphere := SphereMesh.new()
			sphere.radius = size * (0.5 if shape == &"ball" else 0.38)
			sphere.height = size
			return sphere
		&"gem":
			var gem := SphereMesh.new() # four sides and one ring: a cut stone
			gem.radius = size * 0.4
			gem.height = size
			gem.radial_segments = 4
			gem.rings = 1
			return gem
		&"block":
			var box := BoxMesh.new()
			box.size = Vector3.ONE * size
			return box
		&"ring":
			var ring := TorusMesh.new()
			ring.inner_radius = size * 0.28
			ring.outer_radius = size * 0.5
			return ring
		&"pyramid", &"prism":
			var pointed := CylinderMesh.new() # four sides to a point; three sides upright
			pointed.radial_segments = 4 if shape == &"pyramid" else 3
			pointed.rings = 1
			pointed.top_radius = 0.0 if shape == &"pyramid" else size * 0.5
			pointed.bottom_radius = size * 0.6 if shape == &"pyramid" else size * 0.5
			pointed.height = size
			return pointed
		&"capsule":
			var capsule := CapsuleMesh.new()
			capsule.radius = size * 0.25
			capsule.height = size
			return capsule
		&"disc":
			var disc := CylinderMesh.new()
			disc.top_radius = size * 0.5
			disc.bottom_radius = size * 0.5
			disc.height = size * 0.3
			return disc
		&"bar":
			var bar := BoxMesh.new()
			bar.size = Vector3(size * 1.2, size * 0.35, size * 0.35)
			return bar
	var cylinder := CylinderMesh.new() # cone, drum
	cylinder.top_radius = 0.0 if shape == &"cone" else size * 0.45
	cylinder.bottom_radius = size * 0.5 if shape == &"cone" else size * 0.45
	cylinder.height = size if shape == &"cone" else size * 0.8
	return cylinder
