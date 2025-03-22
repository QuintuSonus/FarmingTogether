# scripts/tools/WateringCan.gd
class_name WateringCan
extends Tool

@export var water_capacity: float = 5.0  # Number of uses
var current_water: float = 5.0

func _ready():
	super._ready()  # Call parent's _ready function

func use(target_position):
	# Check if we have water
	if current_water <= 0:
		return false
		
	# Get all nodes in the "interactables" group
	for obj in get_tree().get_nodes_in_group("interactables"):
		# Check if it's a plant in the SEED stage
		if obj is Plant and obj.current_stage == Plant.GrowthStage.SEED and not obj.is_watered:
			# Check if it's at our target position
			var obj_grid_pos = get_node("/root/Main/LevelManager").world_to_grid(obj.global_position)
			if obj_grid_pos == target_position:
				return true
	
	# If we're on a water tile, refill
	var level_manager = get_node("/root/Main/LevelManager")
	if level_manager.is_tile_type(target_position, level_manager.TileType.WATER):
		return true
		
	return false

func get_interaction_type():
	return Interactable.InteractionType.INSTANTANEOUS

func complete_use(target_position):
	var level_manager = get_node("/root/Main/LevelManager")
	
	# If on water tile, refill
	if level_manager.is_tile_type(target_position, level_manager.TileType.WATER):
		current_water = water_capacity
		# Play refill sound
		return true
	
	# Try to water plants at this position
	for obj in get_tree().get_nodes_in_group("interactables"):
		if obj is Plant and obj.current_stage == Plant.GrowthStage.SEED and not obj.is_watered:
			var obj_grid_pos = level_manager.world_to_grid(obj.global_position)
			if obj_grid_pos == target_position:
				if obj.water():
					current_water -= 1
					return true
	
	return false
