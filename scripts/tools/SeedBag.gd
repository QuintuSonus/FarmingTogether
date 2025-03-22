# scripts/tools/SeedBag.gd
class_name SeedBag
extends Tool

@export var seed_type: String = "carrot"
@export var plant_scene: PackedScene

func use(target_position):
	# Get the level manager
	var level_manager = get_node("/root/Main/LevelManager")
	
	# Check if the target position is soil
	if level_manager.is_tile_type(target_position, level_manager.TileType.SOIL):
		return true
	return false
	
func get_interaction_type():
	return Interactable.InteractionType.PROGRESS_BASED

func get_interaction_duration():
	return 2.0  # 2 seconds to plant seeds

func complete_use(target_position):
	var level_manager = get_node("/root/Main/LevelManager")
	
	# Instantiate plant at the target position
	if plant_scene and level_manager.is_tile_type(target_position, level_manager.TileType.SOIL):
		var plant = plant_scene.instantiate()
		plant.crop_type = seed_type
		plant.global_position = level_manager.grid_to_world(target_position)
		# Adjust Y position to sit on top of soil
		plant.global_position.y = 0.26  # Adjusted for soil height
		get_node("/root/Main").add_child(plant)
		return true
	return false
