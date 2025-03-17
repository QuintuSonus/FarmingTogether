# SeedBag.gd - Implementation of the Seed Bag tool
extends Tool

class_name SeedBagTool

# Constants for seed types
enum SeedType {
	CARROT,
	TOMATO
}

# Seed-specific properties
@export var seed_type: SeedType = SeedType.CARROT
@export var planting_effect_scene: PackedScene  # Optional visual effect for planting
@export var seed_mesh_carrots: Mesh
@export var seed_mesh_tomatoes: Mesh
@export var material_carrots: Material
@export var material_tomatoes: Material

# Override _ready to set up Seed Bag-specific properties
func _ready():
	super._ready()  # Call the parent _ready function
	
	# Set seed bag-specific interaction time
	interaction_time = 2.0  # 2 seconds as specified in the GDD
	
	# Configure based on seed type
	configure_for_seed_type()

# Configure the seed bag based on the type of seed
func configure_for_seed_type():
	match seed_type:
		SeedType.CARROT:
			tool_name = "Carrot Seeds"
			tool_description = "Used to plant carrots in tilled soil"
			if mesh_instance and seed_mesh_carrots:
				mesh_instance.mesh = seed_mesh_carrots
			if mesh_instance and material_carrots:
				mesh_instance.material_override = material_carrots
		
		SeedType.TOMATO:
			tool_name = "Tomato Seeds"
			tool_description = "Used to plant tomatoes in tilled soil"
			if mesh_instance and seed_mesh_tomatoes:
				mesh_instance.mesh = seed_mesh_tomatoes
			if mesh_instance and material_tomatoes:
				mesh_instance.material_override = material_tomatoes

# Override perform_action to implement Seed Bag-specific behavior
func perform_action(player, target_position):
	# Get the level manager
	var level_manager = player.level_manager
	if not level_manager:
		print("Error: Level manager not found")
		return false
	
	# Convert world position to grid position if needed
	var grid_position = target_position
	if not (target_position is Vector3i):
		grid_position = level_manager.world_to_grid(target_position)
	
	# Check if the target position is a soil tile
	if level_manager.is_tile_type(grid_position, level_manager.TileType.SOIL):
		# Plant the seed
		var success = level_manager.plant_seed(grid_position, seed_type)
		
		if success:
			# Play planting effect
			spawn_planting_effect(level_manager.grid_to_world(grid_position))
			
			# Play sound effect
			# TODO: Add sound effect
			
			print("Planted " + tool_name + " at: ", grid_position)
			return true
	
	# If we reach here, the action wasn't successful
	print("Cannot plant at position: ", grid_position)
	return false

# Spawn a visual effect for planting
func spawn_planting_effect(world_position):
	if planting_effect_scene:
		var effect = planting_effect_scene.instantiate()
		get_tree().current_scene.add_child(effect)
		effect.global_position = world_position
		effect.global_position.y = 0.05  # Slightly above ground
		
		# Auto-destroy effect after animation finishes
		if effect.has_method("set_one_shot"):
			effect.set_one_shot(true)

# Override update_interaction_visual for Seed Bag-specific progress visualization
func update_interaction_visual():
	# If we're currently using the seed bag (planting in progress)
	if is_in_use and using_player:
		# Update progress indication (this could be implemented in various ways)
		# For example, showing a progress bar above the player
		var progress_bar = using_player.get_node_or_null("ProgressBar")
		if progress_bar:
			progress_bar.visible = true
			progress_bar.value = interaction_progress * 100
	else:
		# Hide progress indication
		if using_player:
			var progress_bar = using_player.get_node_or_null("ProgressBar")
			if progress_bar:
				progress_bar.visible = false
