# scripts/tools/SeedBag.gd
class_name SeedBag
extends Tool

@export var seed_type: String = "carrot"
@export_file("*.tscn") var plant_scene_path: String = "res://scenes/plants/CarrotPlant.tscn"
var plant_scene: PackedScene

func _ready():
	super._ready()  # Call parent's _ready function
	
	# Load the plant scene
	plant_scene = load(plant_scene_path)
	if not plant_scene:
		push_error("SeedBag: Failed to load plant scene from path: " + plant_scene_path)
	
	print("SeedBag initialized for crop type: " + seed_type)

# Override to specify this tool's capabilities
func get_capabilities() -> int:
	return ToolCapabilities.Capability.PLANT_SEEDS

# For tool pickup - keep instantaneous (inherited from Tool base class)
# The base Tool class already returns INSTANTANEOUS, so no need to override

# For tool usage - progress-based
func get_usage_interaction_type() -> int:
	return Interactable.InteractionType.PROGRESS_BASED
	
func get_usage_duration() -> float:
	return 2.0  # 2 seconds to plant seeds

# Check if can use at position
func use(target_position: Vector3i) -> bool:
	print("SeedBag.use() called for position: ", target_position)
	
	# Get the level manager
	var level_manager = get_node("/root/Main/LevelManager")
	
	# Check if the target position is soil
	if level_manager.is_tile_type(target_position, level_manager.TileType.SOIL):
		# Check for existing plants at this position
		var existing_plants = 0
		for obj in get_tree().get_nodes_in_group("plants"):
			if obj is Plant:
				var obj_grid_pos = level_manager.world_to_grid(obj.global_position)
				if obj_grid_pos == target_position:
					existing_plants += 1
		
		if existing_plants > 0:
			print("SeedBag: Cannot plant - already " + str(existing_plants) + " plants at this position!")
			return false
			
		print("SeedBag: Can plant at this position")
		return true
	
	print("SeedBag: Cannot plant - not soil at position ", target_position)
	return false

# Complete the planting action
func complete_use(target_position: Vector3i) -> bool:
	print("SeedBag.complete_use() called for position: ", target_position)
	
	var level_manager = get_node("/root/Main/LevelManager")
	
	# Check if this is a valid soil tile
	if not level_manager.is_tile_type(target_position, level_manager.TileType.SOIL):
		print("SeedBag: Cannot plant - not a soil tile")
		return false
	
	if not plant_scene:
		print("SeedBag: Cannot plant - plant scene not loaded")
		return false
	
	# Check for existing plants at this position again (safety check)
	var existing_plants = []
	for obj in get_tree().get_nodes_in_group("plants"):
		if obj is Plant:
			var obj_grid_pos = level_manager.world_to_grid(obj.global_position)
			if obj_grid_pos == target_position:
				existing_plants.append(obj)
	
	if existing_plants.size() > 0:
		print("SeedBag: ERROR - Already " + str(existing_plants.size()) + " plants at this position!")
		print("SeedBag: Removing duplicate plants before creating a new one")
		
		# Remove all existing plants at this position except the first one
		for i in range(1, existing_plants.size()):
			print("Removing duplicate plant: " + str(i))
			existing_plants[i].queue_free()
			
		# Don't create a new plant, just return success
		return true
	
	# DIRECT CALCULATION with CENTERING
	# Add 0.5 to X and Z to center the plant on the tile
	var world_pos = Vector3(
		float(target_position.x) + 0.5, # Add 0.5 to center on X axis
		0.55, # Fixed height above soil 
		float(target_position.z) + 0.5  # Add 0.5 to center on Z axis
	)
	
	print("SeedBag: Using centered world position: ", world_pos)
	
	# Instantiate the plant
	var plant = plant_scene.instantiate()
	plant.crop_type = seed_type
	plant.global_position = world_pos
	
	# EXPLICIT INITIALIZATION - Ensure proper initial state
	plant.current_stage = Plant.GrowthStage.SEED
	plant.is_watered = false
	plant.growth_progress = 0.0
	plant.spoil_progress = 0.0
	
	print("SeedBag: Plant spawned at: ", plant.global_position)
	
	get_node("/root/Main").add_child(plant)
	
	# Force update appearance after adding to scene
	plant.call_deferred("update_appearance")
	
	return true
