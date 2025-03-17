# Hoe.gd - Implementation of the Hoe tool
extends Tool

class_name HoeTool

# Hoe-specific properties
@export var till_effect_scene: PackedScene  # Optional visual effect for tilling

# Override _ready to set up Hoe-specific properties
func _ready():
	super._ready()  # Call the parent _ready function
	
	# Set Hoe-specific properties
	tool_name = "Hoe"
	tool_description = "Used to till dirt into soil for planting"
	interaction_time = 3.0  # 3 seconds as specified in the GDD
	
	# Set up hoe-specific visual appearance
	if mesh_instance:
		# Adjust the mesh as needed
		pass

# Override perform_action to implement Hoe-specific behavior
func perform_action(player, target_position):
	# Get the level manager
	var level_manager = player.level_manager
	if not level_manager:
		print("Error: Level manager not found")
		return false
	
	# Convert world position to grid position if needed
	var grid_position = target_position
	if not (target_position is Vector3i):
		grid_position = level_manager.world_to_grid(target_position)
	
	# Check if the target position is a dirt tile
	if level_manager.is_tile_type(grid_position, level_manager.TileType.DIRT_GROUND):
		# Convert dirt to soil
		var success = level_manager.convert_to_soil(grid_position)
		
		if success:
			# Play tilling effect
			spawn_till_effect(level_manager.grid_to_world(grid_position))
			
			# Play sound effect
			# TODO: Add sound effect
			
			print("Tilled dirt to soil at: ", grid_position)
			return true
	
	# If we reach here, the action wasn't successful
	print("Cannot till at position: ", grid_position)
	return false

# Spawn a visual effect for tilling
func spawn_till_effect(world_position):
	if till_effect_scene:
		var effect = till_effect_scene.instantiate()
		get_tree().current_scene.add_child(effect)
		effect.global_position = world_position
		effect.global_position.y = 0.05  # Slightly above ground
		
		# Auto-destroy effect after animation finishes
		if effect.has_method("set_one_shot"):
			effect.set_one_shot(true)

# Override update_interaction_visual for Hoe-specific progress visualization
func update_interaction_visual():
	# If we're currently using the hoe (tilling in progress)
	if is_in_use and using_player:
		# Update progress indication (this could be implemented in various ways)
		# For example, showing a progress bar above the player
		var progress_bar = using_player.get_node_or_null("ProgressBar")
		if progress_bar:
			progress_bar.visible = true
			progress_bar.value = interaction_progress * 100
	else:
		# Hide progress indication
		if using_player:
			var progress_bar = using_player.get_node_or_null("ProgressBar")
			if progress_bar:
				progress_bar.visible = false
