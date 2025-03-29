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
	
	 # Update water capacity based on parameter system
	update_water_capacity_from_parameters()
	
	# Create a water level indicator
	create_water_indicator()
	
	# Update the appearance based on initial water level
	update_appearance()
	
	print("WateringCan initialized with ", current_water, "/", water_capacity, " water")

# Custom method to identify this as a watering can
func get_tool_type():
	return "WateringCan"

func get_capabilities() -> int:
	return ToolCapabilities.Capability.WATER_PLANTS
	
# Add this new function
func update_water_capacity_from_parameters():
	# Try to get parameter manager
	var parameter_manager = get_parameter_manager()
	
	if parameter_manager:
		# Get the base capacity from parameters
		var new_capacity = parameter_manager.get_value("tool.watering_can.capacity", water_capacity)
		
		# Update the capacity
		var old_capacity = water_capacity
		water_capacity = new_capacity
		
		# If current water is also at the old max, increase it too
		current_water = water_capacity
			
		print("WateringCan: Updated capacity from ", old_capacity, " to ", water_capacity)
	else:
		print("WateringCan: No parameter manager found, using default capacity: ", water_capacity)
		update_appearance()
	
	
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
	water_indicator.position = Vector3(0, 0, 0)  # Slightly lower than center
	
	# Update the water level visualization
	update_water_level()

func use(target_position: Vector3i) -> bool:
	var level_manager = get_node("/root/Main/LevelManager")
	
	# If we're on a water tile, always allow refill action
	if level_manager.is_tile_type(target_position, level_manager.TileType.WATER):
		return true
	
	# Check if we have water
	if current_water <= 0:
		return false
	
	# Get positions to check
	var positions_to_check = [target_position]
	
	# If hose attachment is active, add adjacent tiles
	if has_hose_attachment():
		positions_to_check.append_array(get_adjacent_positions(target_position))
	
	# Check for plants needing water at all relevant positions
	var plants_to_water = []
	
	for pos in positions_to_check:
		for obj in get_tree().get_nodes_in_group("plants"):
			if obj is Plant and obj.current_stage == Plant.GrowthStage.SEED and not obj.is_watered:
				var obj_grid_pos = level_manager.world_to_grid(obj.global_position)
				var obj_direct_grid = Vector3i(
					int(floor(obj.global_position.x)),
					0,
					int(floor(obj.global_position.z))
				)
				
				if (obj_grid_pos == pos or obj_direct_grid == pos) and not plants_to_water.has(obj):
					plants_to_water.append(obj)
	
	return plants_to_water.size() > 0

func complete_use(target_position: Vector3i) -> bool:
	var level_manager = get_node("/root/Main/LevelManager")
	
	# If on water tile, refill
	if level_manager.is_tile_type(target_position, level_manager.TileType.WATER):
		var old_water = current_water
		current_water = water_capacity
		print("WateringCan: REFILLED from ", old_water, " to ", current_water)
		update_appearance()
		return true
	
	# Check if we have water
	if current_water <= 0:
		return false
	
	# Get positions to water
	var positions_to_water = [target_position]
	
	# If hose attachment is active, add adjacent tiles
	if has_hose_attachment():
		positions_to_water.append_array(get_adjacent_positions(target_position))
		print("WateringCan: Hose attachment active - watering " + str(positions_to_water.size()) + " tiles")
	
	# Find all plants at the positions
	var plants_watered = 0
	var all_interactables = get_tree().get_nodes_in_group("plants")
	
	# Try to water plants at all relevant positions
	for pos in positions_to_water:
		var plants_at_position = []
		
		for obj in all_interactables:
			if obj is Plant and obj.current_stage == Plant.GrowthStage.SEED and not obj.is_watered:
				var obj_grid_pos = level_manager.world_to_grid(obj.global_position)
				var obj_direct_grid = Vector3i(
					int(floor(obj.global_position.x)),
					0,
					int(floor(obj.global_position.z))
				)
				
				if (obj_grid_pos == pos or obj_direct_grid == pos) and not plants_at_position.has(obj):
					plants_at_position.append(obj)
		
		# Water the first plant at this position (avoid duplicates)
		if plants_at_position.size() > 0:
			print("Watering plant at position " + str(pos))
			if plants_at_position[0].water():
				plants_watered += 1

				# Only use water if we successfully watered something
	# Only use 1 water total if any plants were watered
	if plants_watered > 0 and current_water > 0:
		current_water -= 1
		update_appearance()
		print("WateringCan: Used 1 water to water " + str(plants_watered) + " plants")
		return true
	
	return plants_watered > 0

func get_interaction_type():
	return Interactable.InteractionType.INSTANTANEOUS
	
# Update the visual appearance based on water level
func update_appearance():
	if not water_indicator or not water_indicator.has_node("WaterMesh"):
		return
		
	var water_mesh = water_indicator.get_node("WaterMesh")
	
	# Update water level visualization
	update_water_level()
	
	## Change watering can color based on water level
	#var can_material = StandardMaterial3D.new()
	#
	#if current_water <= 0:
		## Empty - brown/copper color
		#can_material.albedo_color = Color(0.6, 0.4, 0.2)
	#else:
		## Has water - blue tint
		#var blue_amount = min(current_water / water_capacity, 1.0) * 0.5
		#can_material.albedo_color = Color(0.3, 0.4 + blue_amount, 0.7 + blue_amount)
	#
	## Apply to mesh
	#if mesh_instance:
		#mesh_instance.set_surface_override_material(0, can_material)
	
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
	water_mesh.position.y = 0 + (base_size.y * fill_percent / 2)
	
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

func get_parameter_manager():
	var service_locator = get_node_or_null("/root/ServiceLocator")
	if service_locator and service_locator.has_method("get_service"):
		return service_locator.get_service("parameter_manager")
		print("parameters found")
	return null
	
func has_hose_attachment() -> bool:
	var parameter_manager = get_parameter_manager()
	if parameter_manager:
		return parameter_manager.get_value("tool.watering_can.area_effect", 0.0) > 0.0
	return false

# Get adjacent tile positions
func get_adjacent_positions(center_position: Vector3i) -> Array:
	var adjacent_positions = []
	
	# Define the four adjacent directions (up, right, down, left)
	var directions = [
		Vector3i(0, 0, -1),  # North
		Vector3i(1, 0, 0),   # East
		Vector3i(0, 0, 1),   # South
		Vector3i(-1, 0, 0)   # West
	]
	
	for dir in directions:
		adjacent_positions.append(center_position + dir)
	
	return adjacent_positions
