# scripts/tools/Hoe.gd
class_name Hoe
extends Tool

func _ready():
	super._ready()
	print("Hoe initialized")

# This should only apply to the use of the tool, not pickup
# We need to distinguish between pickup and use actions
func use(target_position):
	# Get the level manager
	var level_manager = get_node("/root/Main/LevelManager")
	
	print("Hoe.use() called for position: ", target_position)
	
	# Check if the target position is a dirt tile
	if level_manager:
		var is_dirt = level_manager.is_tile_type(target_position, level_manager.TileType.DIRT_GROUND)
		print("Is dirt tile? ", is_dirt)
		print("Tile type: ", level_manager.get_tile_type(target_position))
		return is_dirt
	else:
		print("ERROR: Level manager not found!")
		return false

# IMPORTANT: We're overriding this for using the hoe, not for pickup
# Make sure Tool.gd has this returning INSTANTANEOUS for pickup
func get_interaction_type():
	# We need to distinguish between pickup and "use" action
	# The parent class (Tool) already returns INSTANTANEOUS for pickup
	# This function is called for the "use_tool" action, not pickup
	return Interactable.InteractionType.PROGRESS_BASED
	
func get_interaction_duration():
	return 3.0  # 3 seconds to till soil

func complete_use(target_position):
	print("Hoe.complete_use() called for position: ", target_position)
	var level_manager = get_node("/root/Main/LevelManager")
	if level_manager:
		var result = level_manager.convert_to_soil(target_position)
		print("Convert to soil result: ", result)
		return result
	else:
		print("ERROR: Level manager not found!")
		return false
