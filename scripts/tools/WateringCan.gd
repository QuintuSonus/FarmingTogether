# WateringCan.gd - Implementation of the Watering Can tool
extends Tool

class_name WateringCanTool

# Watering can-specific properties
@export var max_water: int = 5  # Number of plants that can be watered before refill
@export var current_water: int = 0
@export var watering_effect_scene: PackedScene  # Optional visual effect for watering

# Mesh and material references for visual feedback
@export var full_mesh: Mesh
@export var empty_mesh: Mesh
@export var full_material: Material
@export var empty_material: Material

# Override _ready to set up Watering Can-specific properties
func _ready():
	super._ready()  # Call the parent _ready function
	
	# Set Watering Can-specific properties
	tool_name = "Watering Can"
	tool_description = "Used to water plants and trigger growth"
	interaction_time = 0.0  # Instantaneous interaction
	
	# Update visual appearance based on water level
	update_appearance()

# Override perform_action to implement Watering Can-specific behavior
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
	
	# Check if we're at a water tile (for refill)
	if level_manager.is_tile_type(grid_position, level_manager.TileType.WATER):
		# Refill the watering can
		current_water = max_water
		print("Watering can refilled!")
		
		# Update appearance to show full watering can
		update_appearance()
		
		# Play sound effect
		# TODO: Add refill sound effect
		
		return true
	
	# Check if we're at a planted seed that needs watering
	elif level_manager.has_plant(grid_position) and level_manager.is_plant_need_water(grid_position):
		# Check if we have water
		if current_water <= 0:
			print("Watering can is empty! Refill at a water tile.")
			return false
		
		# Water the plant
		var success = level_manager.water_plant(grid_position)
		
		if success:
			# Reduce water level
			current_water -= 1
			
			# Update appearance based on remaining water
			update_appearance()
			
			# Play watering effect
			spawn_watering_effect(level_manager.grid_to_world(grid_position))
			
			# Play sound effect
			# TODO: Add watering sound effect
			
			print("Watered plant at: ", grid_position, " (Water remaining: ", current_water, ")")
			return true
	
	# If we reach here, the action wasn't successful
	print("Cannot use watering can at position: ", grid_position)
	return false

# Update the visual appearance based on water level
func update_appearance():
	if not mesh_instance:
		return
	
	if current_water <= 0:
		# Empty appearance
		if empty_mesh:
			mesh_instance.mesh = empty_mesh
		if empty_material:
			mesh_instance.material_override = empty_material
	else:
		# Full/partial appearance
		if full_mesh:
			mesh_instance.mesh = full_mesh
		if full_material:
			mesh_instance.material_override = full_material

# Spawn a visual effect for watering
func spawn_watering_effect(world_position):
	if watering_effect_scene:
		var effect = watering_effect_scene.instantiate()
		get_tree().current_scene.add_child(effect)
		effect.global_position = world_position
		effect.global_position.y = 0.1  # Slightly above ground
		
		# Auto-destroy effect after animation finishes
		if effect.has_method("set_one_shot"):
			effect.set_one_shot(true)
