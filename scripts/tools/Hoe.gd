# scripts/tools/Hoe.gd
class_name Hoe
extends Tool

# Note: possible_interactions array is assigned in the editor Inspector

func _ready():
	super._ready()
	# print("Hoe initialized with capabilities:", get_capabilities()) # Optional debug

# --- Keep get_capabilities ---
func get_capabilities() -> int:
	return ToolCapabilities.Capability.TILL_SOIL

# --- REMOVE: get_usage_interaction_type, get_usage_duration ---
# --- REMOVE: use, complete_use (logic moved to _effect_...) ---

# --- NEW: Implement effect functions defined in InteractionDefinition ---

func _effect_till_soil(target_position: Vector3i):
	var level_manager = get_node_or_null("/root/Main/LevelManager")
	if not level_manager: return false

	# Check for spoiled plant first (moved from old 'use')
	for obj in get_tree().get_nodes_in_group("plants"):
		if obj is Plant and obj.current_stage == Plant.GrowthStage.SPOILED:
			var plant_grid_pos = level_manager.world_to_grid(obj.global_position)
			if plant_grid_pos == target_position:
				print("Hoe removing spoiled plant")
				obj.queue_free()
				# Ensure tile becomes soil after removing spoiled plant
				if not level_manager.is_tile_type(target_position, level_manager.TileType.SOIL):
					level_manager.set_tile_type(target_position, level_manager.TileType.SOIL)
				return # Done for this interaction

	# If no spoiled plant, convert dirt to soil
	var result = level_manager.convert_to_soil(target_position)
	print("Hoe effect 'till_soil' completed, result:", result)


func get_parameter_manager():
	var service_locator = get_node_or_null("/root/ServiceLocator")
	if service_locator and service_locator.has_method("get_service"):
		return service_locator.get_service("parameter_manager")
		print("parameters found")
	return null
