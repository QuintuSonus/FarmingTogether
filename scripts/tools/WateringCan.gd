# scripts/tools/WateringCan.gd
class_name WateringCan
extends Tool

@export var water_capacity: float = 5.0  # Number of uses
var current_water: float = 5.0

@onready var mesh_instance = $MeshInstance3D
@onready var water_indicator = null

func _ready():
	super._ready()  # Call parent's _ready function
	
	# Add to special group for identification
	add_to_group("watering_can_tools")
	
	# Create a water level indicator
	create_water_indicator()
	
	# Update the appearance based on initial water level
	update_appearance()
	
	print("WateringCan initialized with ", current_water, "/", water_capacity, " water")

# Custom method to identify this as a watering can
func get_tool_type():
	return "WateringCan"

# Create a visual indicator for water level
func create_water_indicator():
	# Check if we already have a water indicator
	water_indicator = get_node_or_null("WaterIndicator")
	if water_indicator:
		return
		
	# Create a new node for the water indicator
	water_indicator = Node3D.new()
	water_indicator.name = "WaterIndicator"
	add_child(water_indicator)
	
	# Create a small blue cube to represent water
	var water_mesh = MeshInstance3D.new()
	water_mesh.name = "WaterMesh"
	water_mesh.mesh = BoxMesh.new()
	
	# Create blue material for water
	var water_material = StandardMaterial3D.new()
	water_material.albedo_color = Color(0.0, 0.4, 0.8, 0.8)  # Blue water color
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mesh.material_override = water_material
	
	water_indicator.add_child(water_mesh)
	
	# Position the indicator inside the watering can
	water_indicator.position = Vector3(0, -0.1, 0)  # Slightly lower than center
	
	# Update the water level visualization
	update_water_level()

func use(target_position):
	print("\n===== WATERING CAN USE ATTEMPT =====")
	print("WateringCan: Use attempted at grid position ", target_position)
	print("WateringCan: Current water level: ", current_water, "/", water_capacity)
	
	# Get the level manager
	var level_manager = get_node("/root/Main/LevelManager")
	
	# If we're on a water tile, always allow refill action
	if level_manager.is_tile_type(target_position, level_manager.TileType.WATER):
		print("WateringCan: Water tile detected - can refill")
		return true
	
	# Check if we have water
	if current_water <= 0:
		print("WateringCan: Cannot use - empty!")
		return false
	
	# DETAILED DEBUG: Print all plants in the scene
	print("\nWateringCan: --- Checking all plants in scene ---")
	var plants_found = 0
	for obj in get_tree().get_nodes_in_group("interactables"):
		if obj is Plant:
			plants_found += 1
			var obj_grid_pos = level_manager.world_to_grid(obj.global_position)
			var stage_name = ["SEED", "GROWING", "HARVESTABLE", "SPOILED"][obj.current_stage]
			print("  Plant at ", obj_grid_pos, " (world: ", obj.global_position, ") - Type: ", obj.crop_type, 
				", Stage: ", stage_name, ", Watered: ", obj.is_watered)
	print("WateringCan: Total plants found: ", plants_found)
	
	# If no plants at all, the issue is likely with plant creation
	if plants_found == 0:
		print("WateringCan: WARNING - No plants found in scene!")
	
	# NEW: Count plants at target position needing water
	var plants_to_water = []
	
	# Look for plants at the target position
	for group_name in ["plants", "interactables"]:
		for obj in get_tree().get_nodes_in_group(group_name):
			if obj is Plant:
				# Check if it's a plant in the SEED stage that needs water
				if obj.current_stage == Plant.GrowthStage.SEED and not obj.is_watered:
					# Check if it's at our target position
					var obj_grid_pos = level_manager.world_to_grid(obj.global_position)
					
					# Calculate direct grid cell for this position to be sure
					var obj_direct_grid = Vector3i(
						int(floor(obj.global_position.x)),
						0,
						int(floor(obj.global_position.z))
					)
					
					# Try both grid position checks
					if (obj_grid_pos == target_position or obj_direct_grid == target_position) and not plants_to_water.has(obj):
						plants_to_water.append(obj)
	
	if plants_to_water.size() > 0:
		print("WateringCan: Found " + str(plants_to_water.size()) + " plants to water at position " + str(target_position))
		return true
	else:
		print("WateringCan: No valid plants found at position ", target_position)
		return false

func complete_use(target_position):
	print("\n===== WATERING CAN COMPLETE_USE =====")
	print("WateringCan: Completing use at grid position ", target_position)
	
	var level_manager = get_node("/root/Main/LevelManager")
	
	# If on water tile, refill
	if level_manager.is_tile_type(target_position, level_manager.TileType.WATER):
		var old_water = current_water
		current_water = water_capacity
		print("WateringCan: REFILLED from ", old_water, " to ", current_water)
		
		# Update appearance
		update_appearance()
		
		# Play refill sound (to be implemented)
		return true
	
	# Check if we have water
	if current_water <= 0:
		print("WateringCan: ERROR - Tried to use empty watering can")
		return false
	
	# Try to water plants at this position - check BOTH groups
	var all_interactables = []
	
	# Combine plants from both groups (in case something is only in one)
	for obj in get_tree().get_nodes_in_group("plants"):
		if obj is Plant and not all_interactables.has(obj):
			all_interactables.append(obj)
			
	for obj in get_tree().get_nodes_in_group("interactables"):
		if obj is Plant and not all_interactables.has(obj):
			all_interactables.append(obj)
	
	print("\nWateringCan: Found " + str(all_interactables.size()) + " plants to check for watering")
	
	# NEW: Find all plants at target position
	var plants_to_water = []
	
	for obj in all_interactables:
		if obj.current_stage == Plant.GrowthStage.SEED and not obj.is_watered:
			var obj_grid_pos = level_manager.world_to_grid(obj.global_position)
			
			# Calculate direct position too (alternative calculation)
			var obj_direct_grid = Vector3i(
				int(floor(obj.global_position.x)),
				0,
				int(floor(obj.global_position.z))
			)
			
			# Try both position comparisons
			var position_matches = (obj_grid_pos == target_position or obj_direct_grid == target_position)
			
			if position_matches and not plants_to_water.has(obj):
				plants_to_water.append(obj)
	
	# NEW: Water all plants at target position
	if plants_to_water.size() > 0:
		print("WateringCan: Found " + str(plants_to_water.size()) + " plants to water")
		
		# NEW: Remove duplicates - keep just one plant
		if plants_to_water.size() > 1:
			print("WARNING: Multiple plants at same position - keeping only one")
			var to_keep = plants_to_water[0]
			
			# Remove all others
			for i in range(1, plants_to_water.size()):
				print("  Removing duplicate plant " + str(i))
				plants_to_water[i].queue_free()
			
			# Keep only the first plant in our array
			plants_to_water = [to_keep]
		
		# Water the remaining plant
		print("Watering plant: " + plants_to_water[0].name)
		if plants_to_water[0].water():
			current_water -= 1
			print("SUCCESS - Plant watered! Water remaining: " + str(current_water))
			
			# Update appearance
			update_appearance()
			return true
		else:
			print("ERROR: Plant could not be watered")
			return false
	else:
		print("WateringCan: No plants to water at position " + str(target_position))
		return false

func get_interaction_type():
	return Interactable.InteractionType.INSTANTANEOUS
	
# Update the visual appearance based on water level
func update_appearance():
	if not water_indicator or not water_indicator.has_node("WaterMesh"):
		return
		
	var water_mesh = water_indicator.get_node("WaterMesh")
	
	# Update water level visualization
	update_water_level()
	
	# Change watering can color based on water level
	var can_material = StandardMaterial3D.new()
	
	if current_water <= 0:
		# Empty - brown/copper color
		can_material.albedo_color = Color(0.6, 0.4, 0.2)
	else:
		# Has water - blue tint
		var blue_amount = min(current_water / water_capacity, 1.0) * 0.5
		can_material.albedo_color = Color(0.3, 0.4 + blue_amount, 0.7 + blue_amount)
	
	# Apply to mesh
	if mesh_instance:
		mesh_instance.set_surface_override_material(0, can_material)
	
	# Update water level label
	update_water_label()
	
# Update the water level indicator mesh
func update_water_level():
	if not water_indicator or not water_indicator.has_node("WaterMesh"):
		return
		
	var water_mesh = water_indicator.get_node("WaterMesh")
	
	if current_water <= 0:
		# No water, hide the indicator
		water_mesh.visible = false
		return
		
	# Show the water
	water_mesh.visible = true
	
	# Scale water mesh based on current water level
	var fill_percent = current_water / water_capacity
	var base_size = Vector3(0.4, 0.4, 0.4)  # Size at full capacity
	
	water_mesh.mesh.size = Vector3(
		base_size.x, 
		base_size.y * fill_percent, 
		base_size.z
	)
	
	# Position the water to sit at the bottom of the can
	water_mesh.position.y = -0.2 + (base_size.y * fill_percent / 2)
	
# Update the water level text label
func update_water_label():
	var label = get_node_or_null("WaterLevelLabel")
	if label:
		label.text = str(int(current_water)) + "/" + str(int(water_capacity))
		
		# Color based on water level
		if current_water <= 0:
			label.modulate = Color(0.8, 0.2, 0.2)  # Red for empty
		elif current_water < water_capacity * 0.25:
			label.modulate = Color(0.9, 0.6, 0.1)  # Orange for low
		else:
			label.modulate = Color(0.1, 0.8, 1.0)  # Blue for normal
