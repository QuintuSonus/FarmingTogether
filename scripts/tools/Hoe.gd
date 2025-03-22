# scripts/tools/Hoe.gd
class_name Hoe
extends Tool

func use(target_position):
	# Get the level manager
	var level_manager = get_node("/root/Main/LevelManager")
	
	# Check if the target position is a dirt tile
	if level_manager.is_tile_type(target_position, level_manager.TileType.DIRT_GROUND):
		return true
	return false
	
func get_interaction_duration():
	return 3.0  # 3 seconds to till soil

func complete_use(target_position):
	var level_manager = get_node("/root/Main/LevelManager")
	return level_manager.convert_to_soil(target_position)
