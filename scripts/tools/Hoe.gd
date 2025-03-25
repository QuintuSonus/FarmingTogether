# scripts/tools/Hoe.gd
class_name Hoe
extends Tool

func _ready():
	super._ready()
	print("Hoe initialized with capabilities:", get_capabilities())

# Override to specify this tool's capabilities
func get_capabilities() -> int:
	return ToolCapabilities.Capability.TILL_SOIL

# For tool usage
func get_usage_interaction_type() -> int:
	print("Hoe.get_usage_interaction_type called, returning PROGRESS_BASED")
	return Interactable.InteractionType.PROGRESS_BASED
	
# In your Hoe.gd - add this to get_usage_duration():
func get_usage_duration() -> float:
	var parameter_manager = get_parameter_manager()
	var duration = 3.0  # Default
	
	if parameter_manager:
		# Get the base duration
		duration = parameter_manager.get_value("tool.hoe.usage_time", 3.0)
		
		# Apply global tool speed multiplier from Energy Drink upgrade
		duration *= get_global_tool_speed_multiplier()
		
		print("Hoe: Retrieved usage time: " + str(duration) + "s (with global multiplier)")
	else:
		print("Hoe: Parameter manager not found!")
		
	return duration

# Implement use logic
func use(target_position: Vector3i) -> bool:
	
	
	var level_manager = get_node("/root/Main/LevelManager")
	if not level_manager:
		return false
		
	# First, check if there's a spoiled plant at this position
	for obj in get_tree().get_nodes_in_group("plants"):
		if obj is Plant and obj.current_stage == Plant.GrowthStage.SPOILED:
			var plant_grid_pos = level_manager.world_to_grid(obj.global_position)
			
			# Also check using direct grid calculation (to be thorough)
			var obj_direct_grid = Vector3i(
				int(floor(obj.global_position.x)),
				0,
				int(floor(obj.global_position.z))
			)
			
			if plant_grid_pos == target_position or obj_direct_grid == target_position:
				return true
	
	# If no spoiled plant, check if it's dirt ground as before
	var result = level_manager.is_tile_type(target_position, level_manager.TileType.DIRT_GROUND)
	return result

# Implement completion logic
func complete_use(target_position: Vector3i) -> bool:
	
	
	var level_manager = get_node("/root/Main/LevelManager")
	if not level_manager:
		return false
		
	# First, check if there's a spoiled plant at this position
	for obj in get_tree().get_nodes_in_group("plants"):
		if obj is Plant and obj.current_stage == Plant.GrowthStage.SPOILED:
			var plant_grid_pos = level_manager.world_to_grid(obj.global_position)
			
			# Also check using direct grid calculation (to be thorough)
			var obj_direct_grid = Vector3i(
				int(floor(obj.global_position.x)),
				0,
				int(floor(obj.global_position.z))
			)
			
			if plant_grid_pos == target_position or obj_direct_grid == target_position:
				print("Hoe removing spoiled plant")
				
				# Remove the spoiled plant
				obj.queue_free()
				
				# Make sure the tile is soil
				if level_manager.is_tile_type(target_position, level_manager.TileType.SOIL) or level_manager.set_tile_type(target_position, level_manager.TileType.SOIL):
					print("Tile successfully set to soil after removing spoiled plant")
					return true
				else:
					print("Failed to set tile to soil after removing plant")
					return false
	
	# If no spoiled plant, try to convert dirt to soil as before
	var result = level_manager.convert_to_soil(target_position)
	print("Hoe completed use (convert dirt to soil), result:", result)
	return result

func get_parameter_manager():
	var service_locator = get_node_or_null("/root/ServiceLocator")
	if service_locator and service_locator.has_method("get_service"):
		return service_locator.get_service("parameter_manager")
		print("parameters found")
	return null
