# scripts/tools/SeedBag.gd
class_name SeedBag
extends Tool

# Tool configuration
@export var seed_type: String = "carrot"
@export var usage_time: float = 1.0

# Custom mesh resources
@export var carrot_seed_mesh: PackedScene = null
@export var tomato_seed_mesh: PackedScene = null

@onready var seed_type_label = $SeedTypeLabel

func _ready():
	# Call the parent _ready function to set up tool basics
	super._ready()
	
	# Apply the correct mesh based on seed type
	apply_seed_mesh()
	
	# Set the label text
	if has_node("SeedTypeLabel"):
		$SeedTypeLabel.text = seed_type.capitalize() + " Seeds"
	
	print("SeedBag initialized for type: " + seed_type)

# Function to apply the correct mesh
func apply_seed_mesh():
	# Find any existing custom mesh and remove it
	var existing_custom = find_child("custom_mesh", false)
	if existing_custom:
		existing_custom.queue_free()
	
	# Choose the right mesh based on seed type
	var mesh_to_use = null
	if seed_type == "carrot" and carrot_seed_mesh != null:
		mesh_to_use = carrot_seed_mesh
	elif seed_type == "tomato" and tomato_seed_mesh != null:
		mesh_to_use = tomato_seed_mesh
	
	# If we have a mesh to use, add it and hide the default
	if mesh_to_use != null:
		var mesh_instance = mesh_to_use.instantiate()
		mesh_instance.name = "custom_mesh"
		add_child(mesh_instance)
		
		# Hide the default mesh
		if has_node("MeshInstance3D"):
			$MeshInstance3D.visible = false
	else:
		# No custom mesh available, make sure default is visible
		if has_node("MeshInstance3D"):
			$MeshInstance3D.visible = true
			
			# Set color based on seed type
			var material = StandardMaterial3D.new()
			if seed_type == "carrot":
				material.albedo_color = Color(1.0, 0.5, 0.0)  # Orange
			elif seed_type == "tomato":
				material.albedo_color = Color(0.9, 0.1, 0.1)  # Red
			else:
				material.albedo_color = Color(1.0, 0.8, 0.0)  # Yellow default
			
			$MeshInstance3D.material_override = material

# Set the seed type
func set_seed_type(type: String):
	seed_type = type
	
	# Update the label
	if has_node("SeedTypeLabel"):
		$SeedTypeLabel.text = seed_type.capitalize() + " Seeds"
	
	# Apply the correct mesh
	apply_seed_mesh()

# Override the get_tool_type method from the Tool class
func get_tool_type() -> String:
	return "seed_bag"

# Check if tool can be used on this tile
func use(grid_pos) -> bool:
	print("SeedBag.use called at position: " + str(grid_pos))
	
	# Find level manager
	var level_manager = find_level_manager()
	if level_manager:
		# Check if the tile is soil
		if level_manager.is_tile_type(grid_pos, level_manager.TileType.SOIL):
			print("SeedBag can be used - soil tile found")
			return true
		else:
			print("SeedBag cannot be used - not a soil tile")
	else:
		print("SeedBag cannot be used - no level manager found")
	
	return false

# Called when tool use is completed
func complete_use(grid_pos) -> bool:
	print("SeedBag.complete_use called at position: " + str(grid_pos))
	
	# Find level manager
	var level_manager = find_level_manager()
	if not level_manager:
		print("ERROR: SeedBag.complete_use - Level manager not found")
		return false
		
	# Check if the tile is soil
	if not level_manager.is_tile_type(grid_pos, level_manager.TileType.SOIL):
		print("ERROR: SeedBag.complete_use - Not a soil tile")
		return false
	
	# Instead of creating a plant directly, we'll just log that planting was successful
	# In a real implementation, you would create a crop or plant based on your game's systems
	print("SeedBag: Successfully planted " + seed_type + " at position " + str(grid_pos))
	
	# You'd typically want to convert the soil tile to some kind of planted state
	# This depends on your game's mechanics
	
	# For now, just update statistics if your game has that
	var main = get_node("/root/Main")
	if main:
		var game_data_manager = main.get_node_or_null("GameDataManager")
		if game_data_manager and game_data_manager.has_method("add_stat"):
			game_data_manager.add_stat("seeds_planted")
	
	print("SeedBag.complete_use - Successfully completed")
	return true

# Tool usage interaction type
func get_usage_interaction_type() -> int:
	return 1  # PROGRESS_BASED

# Tool usage duration
func get_usage_duration() -> float:
	# Get parameter manager for possible modifications
	var parameter_manager = get_parameter_manager()
	if parameter_manager:
		return parameter_manager.get_value("tool.seeding.usage_time", usage_time)
	return usage_time

# Interaction prompt
func get_interaction_prompt() -> String:
	return "Take " + seed_type.capitalize() + " Seeds"

# Helper function to reliably find the level manager
func find_level_manager():
	# Try first through service locator
	var service_locator = get_node_or_null("/root/ServiceLocator")
	if service_locator and service_locator.has_method("get_service"):
		var lm = service_locator.get_service("level_manager")
		if lm:
			return lm
	
	# Try through player's grid tracker
	var player = find_parent("Player")
	if player and player.has_node("PlayerGridTracker"):
		var grid_tracker = player.get_node("PlayerGridTracker")
		if grid_tracker and grid_tracker.level_manager:
			return grid_tracker.level_manager
	
	# Try getting from Main scene
	var main = get_node("/root/Main")
	if main and main.has_node("LevelManager"):
		return main.get_node("LevelManager")
	
	return null

# Helper function to get parameter manager
func get_parameter_manager():
	var service_locator = get_node_or_null("/root/ServiceLocator")
	if service_locator and service_locator.has_method("get_service"):
		return service_locator.get_service("parameter_manager")
	return null
