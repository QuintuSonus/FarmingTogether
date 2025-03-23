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
	
func get_usage_duration() -> float:
	print("Hoe.get_usage_duration called, returning 3.0")
	return 3.0

# Implement use logic
func use(target_position: Vector3i) -> bool:
	print("Hoe.use called for position:", target_position)
	
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
				print("Hoe can be used on spoiled plant")
				return true
	
	# If no spoiled plant, check if it's dirt ground as before
	var result = level_manager.is_tile_type(target_position, level_manager.TileType.DIRT_GROUND)
	print("Hoe can be used (is dirt):", result)
	return result

# Implement completion logic
func complete_use(target_position: Vector3i) -> bool:
	print("Hoe.complete_use called for position:", target_position)
	
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
