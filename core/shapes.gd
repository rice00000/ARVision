class_name Shapes
extends RefCounted
## The meshes of the toys: ball, block, cone, drum, ring, egg and gem.
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
	var cylinder := CylinderMesh.new() # cone, drum
	cylinder.top_radius = 0.0 if shape == &"cone" else size * 0.45
	cylinder.bottom_radius = size * 0.5 if shape == &"cone" else size * 0.45
	cylinder.height = size if shape == &"cone" else size * 0.8
	return cylinder
