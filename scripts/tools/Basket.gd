# scripts/tools/Basket.gd
class_name Basket
extends Tool

var contained_crops = {}  # Dictionary of crop_type: count

func add_crop(crop_type: String):
	if contained_crops.has(crop_type):
		contained_crops[crop_type] += 1
	else:
		contained_crops[crop_type] = 1
	
	# Update visual appearance
	update_appearance()
	
func get_crop_count(crop_type: String) -> int:
	return contained_crops.get(crop_type, 0)
	
func get_total_crops() -> int:
	var total = 0
	for crop in contained_crops.values():
		total += crop
	return total
	
func clear_crops():
	contained_crops.clear()
	update_appearance()
	
func update_appearance():
	# Update the mesh/material based on contained crops
	# This would be implemented to show crops in the basket
	pass

func use(target_position):
	# Check if we're at a delivery tile with crops
	if get_total_crops() > 0:
		var level_manager = get_node("/root/Main/LevelManager")
		if level_manager.is_tile_type(target_position, level_manager.TileType.DELIVERY):
			return true
	return false

func complete_use(target_position):
	var level_manager = get_node("/root/Main/LevelManager")
	
	# Deliver crops if at delivery tile
	if level_manager.is_tile_type(target_position, level_manager.TileType.DELIVERY):
		# Here we would check if the crops match an order
		# For now, just clear the basket
		var delivered = get_total_crops() > 0
		clear_crops()
		return delivered
	
	return false
