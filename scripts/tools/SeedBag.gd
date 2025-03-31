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


# Complete the planting action
func _effect_plant_seed(target_position: Vector3i) -> bool:#
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
