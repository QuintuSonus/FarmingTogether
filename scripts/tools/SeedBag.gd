# scripts/tools/SeedBag.gd
class_name SeedBag
extends Tool

@export var seed_type: String = "carrot"
@export_file("*.tscn") var plant_scene_path: String = "res://scenes/plants/CarrotPlant.tscn"
var plant_scene: PackedScene

func _ready():
	super._ready()
	# Load the plant scene
	plant_scene = load(plant_scene_path)
	if not plant_scene:
		push_error("SeedBag: Failed to load plant scene from path: " + plant_scene_path)

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
	
	print("SeedBag: Trying to plant at grid position: ", target_position)
	
	# Check if this is a valid soil tile
	if not level_manager.is_tile_type(target_position, level_manager.TileType.SOIL):
		print("SeedBag: Cannot plant - not a soil tile")
		return false
	
	if not plant_scene:
		print("SeedBag: Cannot plant - plant scene not loaded")
		return false
	
	# DIRECT CALCULATION with CENTERING
	# Add 0.5 to X and Z to center the plant on the tile
	var world_pos = Vector3(
		float(target_position.x) + 0.5, # Add 0.5 to center on X axis
		0.26, # Fixed height above soil 
		float(target_position.z) + 0.5  # Add 0.5 to center on Z axis
	)
	
	print("SeedBag: Using centered world position: ", world_pos)
	
	# Instantiate the plant
	var plant = plant_scene.instantiate()
	plant.crop_type = seed_type
	plant.global_position = world_pos
	
	print("SeedBag: Plant spawned at: ", plant.global_position)
	
	get_node("/root/Main").add_child(plant)
	return true
