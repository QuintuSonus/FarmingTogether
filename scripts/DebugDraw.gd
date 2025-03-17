# DebugDraw.gd - Put this in a singleton (autoload)
extends Node

# Draw a line in 3D space
func draw_line_3d(pos1: Vector3, pos2: Vector3, color: Color = Color.WHITE):
	var im = ImmediateMesh.new()
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(pos1)
	im.surface_add_vertex(pos2)
	im.surface_end()
	
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = im
	mesh_instance.material_override = material
	get_tree().current_scene.add_child(mesh_instance)
	
	# Auto remove after 1 frame
	await get_tree().process_frame
	mesh_instance.queue_free()

# Draw a sphere in 3D space with x-ray effect
func draw_sphere_xray(pos: Vector3, radius: float = 0.1, color: Color = Color.WHITE):
	var im = ImmediateMesh.new()
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	
	# Create a sphere wireframe
	var segments = 16
	var rings = 8
	
	for i in range(rings + 1):
		var r = sin(PI * i / rings)
		var y = cos(PI * i / rings)
		
		for j in range(segments):
			var x = r * cos(TAU * j / segments)
			var z = r * sin(TAU * j / segments)
			im.surface_add_vertex(pos + Vector3(x, y, z) * radius)
			
			var next_j = (j + 1) % segments
			var x2 = r * cos(TAU * next_j / segments)
			var z2 = r * sin(TAU * next_j / segments)
			im.surface_add_vertex(pos + Vector3(x2, y, z2) * radius)
	
	im.surface_end()
	
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true  # X-ray effect
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = im
	mesh_instance.material_override = material
	get_tree().current_scene.add_child(mesh_instance)
	
	# Auto remove after 1 frame
	await get_tree().process_frame
	mesh_instance.queue_free()
