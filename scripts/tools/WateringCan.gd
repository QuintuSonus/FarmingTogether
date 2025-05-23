# scripts/tools/WateringCan.gd
class_name WateringCan
extends Tool

# Note: possible_interactions array is assigned in the editor Inspector
# Assign can_water_plant.tres and can_fill.tres here.

@export var water_capacity: float = 5.0
var current_water: float = 5.0

@onready var water_indicator = null
@export var watering_particles: GPUParticles3D
@export var watering_sfx_player: AudioStreamPlayer3D # Should be set to LOOP
@export var fill_sfx_player: AudioStreamPlayer3D

func _ready():
	super._ready()
	add_to_group("watering_can_tools")
	update_water_capacity_from_parameters()
	create_water_indicator()
	update_appearance()
	if watering_particles:
		watering_particles.emitting = false
	if watering_sfx_player:
		watering_sfx_player.stop()
	# print("WateringCan initialized...") # Optional debug
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
	water_indicator.position = Vector3(0, -0.574, 0)  # Slightly lower than center
	
	# Update the water level visualization
	update_water_level()

	
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
	var base_size = Vector3(0.3, 0.3, 0.3)  # Size at full capacity
	
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

func _effect_water_plant(target_position: Vector3i):
	var level_manager = get_node_or_null("/root/Main/LevelManager")
	if not level_manager or current_water <= 0: return

	var positions_to_water = [target_position]
	if has_hose_attachment():
		positions_to_water.append_array(get_adjacent_positions(target_position))

	var plants_watered = 0
	var all_plants = get_tree().get_nodes_in_group("plants")

	for pos in positions_to_water:
		for obj in all_plants:
			if obj is Plant and obj.current_stage == Plant.GrowthStage.SEED and not obj.is_watered:
				var obj_grid_pos = level_manager.world_to_grid(obj.global_position)
				if obj_grid_pos == pos:
					if obj.water():
						plants_watered += 1
					break # Only water one plant per tile in the area effect

	if plants_watered > 0:
		current_water -= 1
		update_appearance()
		print("WateringCan effect 'water_plant': Used 1 water, %d plants watered." % plants_watered)


func _effect_fill_can(_target_position: Vector3i): # Target position might not be needed here
	var old_water = current_water
	current_water = water_capacity
	update_appearance()
	print("WateringCan effect 'fill_can': REFILLED from %f to %f" % [old_water, current_water])

func start_progress_effects(interaction_id: String):
	if interaction_id=="water_plant":
		watering_particles.emitting=true
		watering_sfx_player.play()
	if interaction_id=="fill_can":
		fill_sfx_player.play()
	# Base implementation does nothing. Override in specific tools like WateringCan.
	pass

# Called by PlayerToolHandler when a progress interaction stops (completed or canceled).
func stop_progress_effects(interaction_id: String):
	if interaction_id=="water_plant":
		watering_particles.emitting=false
		watering_sfx_player.stop()
	
	if interaction_id=="fill_can":
		fill_sfx_player.stop()
	# Base implementation does nothing. Override in specific tools.
	pass
