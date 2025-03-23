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
	if level_manager:
		var result = level_manager.is_tile_type(target_position, level_manager.TileType.DIRT_GROUND)
		print("Hoe can be used (is dirt):", result)
		return result
	return false

# Implement completion logic
func complete_use(target_position: Vector3i) -> bool:
	print("Hoe.complete_use called for position:", target_position)
	
	var level_manager = get_node("/root/Main/LevelManager")
	if level_manager:
		var result = level_manager.convert_to_soil(target_position)
		print("Hoe completed use, result:", result)
		return result
	return false
