# scripts/tools/Basket.gd
class_name Basket
extends Tool

var contained_crops = {}  # Dictionary of crop_type: count

func _ready():
	super._ready()
	print("Basket initialized")
	# Add to a special group to identify basket tools
	add_to_group("basket_tools")

# Custom method to identify this as a basket - safer than overriding get_class()
func get_tool_type():
	return "Basket"

func add_crop(crop_type: String):
	print("Basket: Adding crop: " + crop_type)
	if contained_crops.has(crop_type):
		contained_crops[crop_type] += 1
	else:
		contained_crops[crop_type] = 1
	
	# Update visual appearance
	update_appearance()
	print("Basket: Now contains " + str(get_total_crops()) + " crops")
	
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
	print("Basket.use() called at position: " + str(target_position))
	var level_manager = get_node("/root/Main/LevelManager")
	
	# First check for harvestable plants at this position
	var found_harvestable_plant = false
	
	# Check both groups to be safe
	for group in ["plants", "interactables"]:
		for obj in get_tree().get_nodes_in_group(group):
			if obj is Plant and obj.current_stage == Plant.GrowthStage.HARVESTABLE:
				var plant_grid_pos = level_manager.world_to_grid(obj.global_position)
				print("Basket: Found harvestable plant at " + str(plant_grid_pos) + ", target is " + str(target_position))
				
				# Calculate direct grid position too
				var obj_direct_grid = Vector3i(
					int(floor(obj.global_position.x)),
					0,
					int(floor(obj.global_position.z))
				)
				
				if plant_grid_pos == target_position or obj_direct_grid == target_position:
					print("Basket: Position match - can harvest plant!")
					found_harvestable_plant = true
					return true
	
	if found_harvestable_plant:
		return true
		
	# Check if we're at a delivery tile with crops (original logic)
	if get_total_crops() > 0:
		if level_manager.is_tile_type(target_position, level_manager.TileType.DELIVERY):
			print("Basket: At delivery tile with crops - can deliver")
			return true
	
	print("Basket: Cannot use at this position")
	return false

func complete_use(target_position):
	print("Basket.complete_use() called at position: " + str(target_position))
	var level_manager = get_node("/root/Main/LevelManager")
	
	# First try to harvest any plants at this position
	var harvested = false
	
	for group in ["plants", "interactables"]:
		if harvested:
			break
			
		for obj in get_tree().get_nodes_in_group(group):
			if obj is Plant and obj.current_stage == Plant.GrowthStage.HARVESTABLE:
				var plant_grid_pos = level_manager.world_to_grid(obj.global_position)
				
				# Calculate direct grid position too
				var obj_direct_grid = Vector3i(
					int(floor(obj.global_position.x)),
					0,
					int(floor(obj.global_position.z))
				)
				
				if plant_grid_pos == target_position or obj_direct_grid == target_position:
					print("Basket: Harvesting plant " + obj.name + " of type " + obj.crop_type)
					add_crop(obj.crop_type)
					
					# Reset the tile
					level_manager.reset_soil_to_dirt(plant_grid_pos)
					
					# Remove the plant
					obj.queue_free()
					harvested = true
					return true
	
	# If we didn't harvest anything, try to deliver
	if level_manager.is_tile_type(target_position, level_manager.TileType.DELIVERY):
		print("Basket: At delivery tile")
		
		# Here we would check if the crops match an order
		# For now, just clear the basket if it has crops
		if get_total_crops() > 0:
			print("Basket: Delivering " + str(get_total_crops()) + " crops")
			clear_crops()
			return true
		else:
			print("Basket: Nothing to deliver")
	
	return false
