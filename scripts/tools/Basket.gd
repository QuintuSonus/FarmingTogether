# Basket.gd - Implementation of the Basket tool
extends Tool

class_name BasketTool

# Basket-specific properties
@export var max_capacity: int = 6  # Maximum number of crops the basket can hold
@export var harvesting_effect_scene: PackedScene  # Optional visual effect for harvesting

# Contents of the basket
var contents = []  # Array of {type: SeedType, count: int}

# Visual references for contents
@export var carrot_display: Node3D
@export var tomato_display: Node3D

# Override _ready to set up Basket-specific properties
func _ready():
	super._ready()  # Call the parent _ready function
	
	# Set Basket-specific properties
	tool_name = "Basket"
	tool_description = "Used to harvest and deliver crops"
	interaction_time = 0.0  # Instantaneous interaction
	
	# Initialize empty content displays
	update_content_display()

# Override perform_action to implement Basket-specific behavior
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
	
	# Check if we're at a delivery tile
	if level_manager.is_tile_type(grid_position, level_manager.TileType.DELIVERY):
		# Try to deliver contents
		return deliver_crops(player)
	
	# Check if we're at a harvestable plant
	elif level_manager.has_plant(grid_position) and level_manager.is_plant_harvestable(grid_position):
		# Try to harvest the plant
		return harvest_plant(player, grid_position)
	
	# If we reach here, the action wasn't successful
	print("Cannot use basket at position: ", grid_position)
	return false

# Harvest a plant and add it to the basket
func harvest_plant(player, grid_position):
	var level_manager = player.level_manager
	
	# Check for space in the basket
	if get_total_crops() >= max_capacity:
		print("Basket is full!")
		return false
	
	# Get plant information
	var plant_type = level_manager.get_plant_type(grid_position)
	if plant_type == null:
		return false
	
	# Harvest the plant
	var success = level_manager.harvest_plant(grid_position)
	
	if success:
		# Add crop to basket
		add_crop(plant_type)
		
		# Play harvesting effect
		spawn_harvesting_effect(level_manager.grid_to_world(grid_position))
		
		# Play sound effect
		# TODO: Add harvesting sound effect
		
		print("Harvested " + get_crop_name(plant_type) + " at: " + str(grid_position))
		return true
	
	return false

# Deliver crops (if at delivery tile)
func deliver_crops(player):
	# Check if we have any crops to deliver
	if contents.size() == 0:
		print("Basket is empty!")
		return false
	
	# Get order manager from the level
	var order_manager = player.get_parent().get_node_or_null("OrderManager")
	if not order_manager:
		print("Order manager not found!")
		return false
	
	# Try to fulfill an order with our current basket contents
	var order_fulfilled = order_manager.fulfill_order(contents)
	
	if order_fulfilled:
		# Clear basket contents
		contents.clear()
		
		# Update visual display
		update_content_display()
		
		# Play delivery success effect/sound
		# TODO: Add delivery success effect/sound
		
		print("Order delivered successfully!")
		return true
	else:
		# Play delivery failed effect/sound
		# TODO: Add delivery failed effect/sound
		
		print("No matching order found for current basket contents!")
		return false

# Add a crop to the basket
func add_crop(crop_type):
	# Check if we already have this type of crop
	for content in contents:
		if content.type == crop_type:
			# Increment count
			content.count += 1
			update_content_display()
			return
	
	# If not found, add new entry
	contents.append({
		"type": crop_type,
		"count": 1
	})
	
	# Update visual display
	update_content_display()

# Get total number of crops in the basket
func get_total_crops() -> int:
	var total = 0
	for content in contents:
		total += content.count
	return total

# Get human-readable name for a crop type
func get_crop_name(crop_type) -> String:
	match crop_type:
		SeedBagTool.SeedType.CARROT:
			return "Carrot"
		SeedBagTool.SeedType.TOMATO:
			return "Tomato"
		_:
			return "Unknown Crop"

# Update the visual display of contents in the basket
func update_content_display():
	# This would be implemented with actual meshes and models
	# For now we'll just update visibility of placeholder nodes
	
	var has_carrots = false
	var has_tomatoes = false
	var carrot_count = 0
	var tomato_count = 0
	
	# Count crops by type
	for content in contents:
		match content.type:
			SeedBagTool.SeedType.CARROT:
				has_carrots = true
				carrot_count = content.count
			SeedBagTool.SeedType.TOMATO:
				has_tomatoes = true
				tomato_count = content.count
	
	# Update carrot display
	if carrot_display:
		carrot_display.visible = has_carrots
		# You could also scale or update a label to show count
	
	# Update tomato display
	if tomato_display:
		tomato_display.visible = has_tomatoes
		# You could also scale or update a label to show count
	
	# Print current contents (for debugging)
	print("Basket contents:")
	for content in contents:
		print("- " + get_crop_name(content.type) + ": " + str(content.count))

# Spawn a visual effect for harvesting
func spawn_harvesting_effect(world_position):
	if harvesting_effect_scene:
		var effect = harvesting_effect_scene.instantiate()
		get_tree().current_scene.add_child(effect)
		effect.global_position = world_position
		effect.global_position.y = 0.1  # Slightly above ground
		
		# Auto-destroy effect after animation finishes
		if effect.has_method("set_one_shot"):
			effect.set_one_shot(true)

# Get a descriptive string of the basket's contents
func get_contents_description() -> String:
	if contents.size() == 0:
		return "Empty"
	
	var description = ""
	for content in contents:
		if description.length() > 0:
			description += ", "
		description += str(content.count) + " " + get_crop_name(content.type)
	
	return description
