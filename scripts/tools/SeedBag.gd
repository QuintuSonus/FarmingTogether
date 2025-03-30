# scripts/tools/SeedBag.gd
class_name SeedBag
extends Tool

@export var seed_type: String = "carrot"
@export_file("*.tscn") var plant_scene_path: String = "res://scenes/plants/CarrotPlant.tscn"
var plant_scene: PackedScene
var has_been_used: bool = false

## Reference to mesh for changing appearance
#@onready var mesh_instance = $MeshInstance3D

# Reference to different seed bag meshes
@export var carrot_seed_mesh: PackedScene
@export var tomato_seed_mesh: PackedScene

# Instances
var current_mesh_instance = null

func _ready():
	super._ready()  # Call parent's _ready function
	
	# Load the plant scene
	plant_scene = load(plant_scene_path)
	if not plant_scene:
		push_error("SeedBag: Failed to load plant scene from path: " + plant_scene_path)
	
	# Update visual appearance based on seed type
	update_appearance()
	
	

# Update the visual appearance based on seed type
func update_appearance():
	# Make sure we have a mesh to work with
	#if not mesh_instance:
		#print("SeedBag: No mesh instance found!")
		#return
	
	# Create a new material
	var material = StandardMaterial3D.new()
	
	# Set color based on seed type
	match seed_type.to_lower():
		"carrot":
			current_mesh_instance = carrot_seed_mesh.instantiate()
		"tomato":
			current_mesh_instance = tomato_seed_mesh.instantiate()
	
	# Add the mesh to the scene
	if current_mesh_instance != null:
		add_child(current_mesh_instance)
		# Ensure it's positioned correctly
		current_mesh_instance.position = Vector3.ZERO
	
	# Add/update text label if it exists
	var label = get_node_or_null("SeedTypeLabel")
	if label:
		label.text = seed_type.capitalize() + " Seeds"

# Set seed type and update appearance
func set_seed_type(new_type: String):
	seed_type = new_type
	
	# Update plant scene path based on seed type
	match seed_type.to_lower():
		"carrot":
			plant_scene_path = "res://scenes/plants/CarrotPlant.tscn"
		"tomato":
			plant_scene_path = "res://scenes/plants/TomatoPlant.tscn"
	
	# Reload plant scene
	plant_scene = load(plant_scene_path)
	
	# Update appearance
	update_appearance()

# Override to specify this tool's capabilities
func get_capabilities() -> int:
	return ToolCapabilities.Capability.PLANT_SEEDS

# For tool usage - progress-based
func get_usage_interaction_type() -> int:
	return Interactable.InteractionType.PROGRESS_BASED
	
func get_usage_duration() -> float:
	var parameter_manager = get_parameter_manager()
	var duration = 2.0  # Default
	
	if parameter_manager:
		# Get the base duration
		duration = parameter_manager.get_value("tool.seeding.usage_time", 2.0)
		
		# Apply global tool speed multiplier from Energy Drink upgrade
		duration *= get_global_tool_speed_multiplier()
	
	return duration

# Check if can use at position
func use(target_position: Vector3i) -> bool:

	
	# Don't allow using if already used
	if has_been_used:
		print("SeedBag: Already used - cannot plant again")
		return false
	
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
			
		
		return true
	
	
	return false

# Complete the planting action
func complete_use(target_position: Vector3i) -> bool:
	
	
	# Don't allow completing if already used
	if has_been_used:
		print("SeedBag: Already used - cannot complete planting")
		return false
	
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
			
		# Don't create a new plant, but still mark as used and remove the bag
		has_been_used = true
		call_deferred("remove_seed_bag")
		return true
	
	# DIRECT CALCULATION with CENTERING
	# Add 0.5 to X and Z to center the plant on the tile
	var world_pos = Vector3(
		float(target_position.x) + 0.5, # Add 0.5 to center on X axis
		0.75, # Fixed height above soil 
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
	
	# Mark as used and remove - use call_deferred to avoid immediate deletion
	has_been_used = true
	call_deferred("remove_seed_bag")
	
	return true

# Method to remove the seed bag after use
func remove_seed_bag():
	print("SeedBag: Single-use complete - removing bag")
	
	# Find all players that might be holding this tool
	var players = get_tree().get_nodes_in_group("players")
	if players.size() == 0:
		# Fallback to direct path if players group not used
		var player = get_node_or_null("/root/Main/Player")
		if player:
			players = [player]
			
		# Try PlayerManager path - all players from PlayerManager
		var player_manager = get_node_or_null("/root/Main/PlayerManager")
		if player_manager and player_manager.has_method("get_players"):
			players = player_manager.get_players()
		elif player_manager and player_manager.has("players"):
			players = player_manager.players
	
	# Check each player for holding this tool
	for player in players:
		if player and player.has_method("get_current_tool") and player.get_current_tool() == self:
			print("SeedBag: Clearing reference from player " + str(player.name))
			
			# Safer way to clear the reference - use a method instead of direct property access
			if player.has_method("clear_tool_reference"):
				player.clear_tool_reference(self)
			else:
				# Fallback to direct assignment if method doesn't exist
				player.tool_handler.current_tool = null
				
	# Delete after two frames to ensure all references are cleared
	await get_tree().process_frame
	await get_tree().process_frame
	queue_free()
	
func get_parameter_manager():
	var service_locator = get_node_or_null("/root/ServiceLocator")
	if service_locator and service_locator.has_method("get_service"):
		return service_locator.get_service("parameter_manager")
		print("parameters found")
	return null
