# scripts/editor/TileUpgradeTool.gd
class_name TileUpgradeTool
extends Node

# References
var level_editor = null
var upgrade_system = null
var tile_highlighter = null
var highlight_material = null

# State
var active = false
var current_upgrade_id = ""
var current_upgrade_data = null

# Visual feedback
var highlight_color_can_apply = Color(0.3, 0.8, 0.3, 0.5)  # Green
var highlight_color_cannot_apply = Color(0.8, 0.3, 0.3, 0.5)  # Red

func _init(editor, upgrade_id, upgrade_data):
	level_editor = editor
	current_upgrade_id = upgrade_id
	current_upgrade_data = upgrade_data
	
	# Get upgrade system
	var service_locator = ServiceLocator.get_instance()
	if service_locator:
		upgrade_system = service_locator.get_service("upgrade_system")
	
	# Set up highlighter
	setup_highlighter()
	
	# Start in active state
	active = true
	
	print("TileUpgradeTool: Initialized for upgrade: " + upgrade_id)

func setup_highlighter():
	# Create or get reference to a tile highlighter
	tile_highlighter = level_editor.get_node_or_null("TileHighlighter")
	
	# Create a new one if it doesn't exist
	if not tile_highlighter:
		tile_highlighter = Node3D.new()
		tile_highlighter.name = "TileHighlighter"
		level_editor.add_child(tile_highlighter)
		
		# Create a plane mesh for highlighting
		var plane = PlaneMesh.new()
		plane.size = Vector2(0.95, 0.95)  # Slightly smaller than tile
		
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "HighlightMesh"
		mesh_instance.mesh = plane
		tile_highlighter.add_child(mesh_instance)
		
		# Create material
		highlight_material = StandardMaterial3D.new()
		highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		highlight_material.albedo_color = highlight_color_can_apply
		
		mesh_instance.material_override = highlight_material
	else:
		# Get existing material
		var mesh_instance = tile_highlighter.get_node_or_null("HighlightMesh")
		if mesh_instance:
			highlight_material = mesh_instance.material_override

# Process input for applying upgrades to tiles
func process_input(event):
	if not active:
		return false
	
	# Get level manager for tile operations
	var level_manager = level_editor.level_manager
	if not level_manager:
		return false
	
	# Handle mouse input for tile selection
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = level_editor.get_viewport().get_mouse_position()
		var from = level_editor.editor_camera.project_ray_origin(mouse_pos)
		var to = from + level_editor.editor_camera.project_ray_normal(mouse_pos) * 100
		
		# Raycast to find intersected tile
		var space_state = level_editor.get_viewport().get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		var result = space_state.intersect_ray(query)
		
		if result and result.has("position"):
			var pos = result.position
			var grid_pos = level_manager.world_to_grid(pos)
			
			# Check if the tile is suitable for this upgrade
			if can_apply_upgrade_to_tile(grid_pos):
				# Apply the upgrade
				apply_upgrade_to_tile(grid_pos)
				return true
	
	# Update highlights on mouse movement
	if event is InputEventMouseMotion:
		update_highlight()
		return true
	
	return false

# Update the tile highlight based on mouse position
func update_highlight():
	if not active or not level_editor or not level_editor.level_manager:
		return
	
	var level_manager = level_editor.level_manager
	var mouse_pos = level_editor.get_viewport().get_mouse_position()
	var from = level_editor.editor_camera.project_ray_origin(mouse_pos)
	var to = from + level_editor.editor_camera.project_ray_normal(mouse_pos) * 100
	
	# Raycast to find intersected tile
	var space_state = level_editor.get_viewport().get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var result = space_state.intersect_ray(query)
	
	if result and result.has("position"):
		var pos = result.position
		var grid_pos = level_manager.world_to_grid(pos)
		
		# Show highlighter
		tile_highlighter.visible = true
		
		# Position highlighter
		var world_pos = level_manager.grid_to_world(grid_pos)
		world_pos.y = 0.3  # Slightly above the ground
		tile_highlighter.global_position = world_pos
		
		# Update color based on whether we can apply the upgrade
		if highlight_material:
			if can_apply_upgrade_to_tile(grid_pos):
				highlight_material.albedo_color = highlight_color_can_apply
			else:
				highlight_material.albedo_color = highlight_color_cannot_apply
	else:
		# Hide highlighter if no tile found
		tile_highlighter.visible = false

# Check if the upgrade can be applied to a specific tile
func can_apply_upgrade_to_tile(grid_pos) -> bool:
	if not upgrade_system or not level_editor.level_manager:
		return false
	
	# Get level manager for tile operations
	var level_manager = level_editor.level_manager
	
	# Check based on upgrade type
	match current_upgrade_id:
		"fertile_soil", "preservation_mulch", "crop_rotation_plot", "greenhouse_tile":
			# These can only be applied to soil tiles
			return level_manager.is_tile_type(grid_pos, level_manager.TileType.SOIL)
			
		"sprinkler_system":
			# Sprinklers can be placed on regular ground
			return level_manager.is_tile_type(grid_pos, level_manager.TileType.REGULAR_GROUND)
			
		"express_delivery_zone", "quality_control_station":
			# These can only be applied to delivery tiles
			return level_manager.is_tile_type(grid_pos, level_manager.TileType.DELIVERY)
			
		_:
			return false

# Apply the upgrade to a specific tile
func apply_upgrade_to_tile(grid_pos):
	if not upgrade_system:
		return
	
	print("TileUpgradeTool: Applying " + current_upgrade_id + " to tile at " + str(grid_pos))
	
	# Apply the upgrade to the tile
	var success = upgrade_system.apply_upgrade_to_tile(grid_pos, current_upgrade_id)
	
	if success:
		# Play a success sound
		# ... sound code ...
		
		# Visual feedback
		create_apply_effect(grid_pos)
		
		# Notify the editor UI to update
		if level_editor.editor_ui and level_editor.editor_ui.has_method("update_currency_display"):
			level_editor.editor_ui.update_currency_display()

# Create a visual effect when applying an upgrade
func create_apply_effect(grid_pos):
	# Get level manager for tile operations
	var level_manager = level_editor.level_manager
	if not level_manager:
		return
	
	# Get world position of the tile
	var world_pos = level_manager.grid_to_world(grid_pos)
	
	# Create particles effect
	var particles = CPUParticles3D.new()
	level_editor.add_child(particles)
	particles.global_position = world_pos + Vector3(0, 0.5, 0)
	
	# Configure particles
	particles.amount = 20
	particles.lifetime = 1.0
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.randomness = 0.5
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 30.0
	particles.gravity = Vector3(0, -9.8, 0)
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 4.0
	
	# Set color based on upgrade type
	match current_upgrade_id:
		"fertile_soil":
			particles.color = Color(0.4, 0.8, 0.2)  # Green
		"preservation_mulch":
			particles.color = Color(0.8, 0.4, 0.1)  # Orange
		"sprinkler_system":
			particles.color = Color(0.2, 0.4, 1.0)  # Blue
		"express_delivery_zone", "quality_control_station":
			particles.color = Color(1.0, 0.8, 0.2)  # Gold
		"greenhouse_tile":
			particles.color = Color(0.2, 0.8, 0.8)  # Cyan
		_:
			particles.color = Color(0.8, 0.8, 0.2)  # Yellow default
	
	# Start particles
	particles.emitting = true
	
	# Remove after they finish
	await level_editor.get_tree().create_timer(particles.lifetime + 0.1).timeout
	particles.queue_free()

# Activate or deactivate the tool
func set_active(value: bool):
	active = value
	
	# Show/hide highlighter
	if tile_highlighter:
		tile_highlighter.visible = active
	
	# Update UI to show active state
	if level_editor and level_editor.editor_ui:
		# You might want to add a method to show which upgrade is being applied
		pass

# Clean up when done
func cleanup():
	# Hide highlighter
	if tile_highlighter:
		tile_highlighter.visible = false
	
	active = false
