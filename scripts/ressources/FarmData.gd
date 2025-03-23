# scripts/ressources/FarmData.gd
class_name FarmData
extends Resource

# Currency and basic stats
@export var currency: int = 1000
@export var run_count: int = 0
@export var highest_score: int = 0

@export var current_level: int = 1
@export var highest_level_reached: int = 1


# Tile data - stores positions and types of special tiles
# Format: { "x,z": tile_type }
@export var tile_data: Dictionary = {}

# NEW: Tool placement data - stores positions and types of placed tools
# Format: { "x,z": tool_type }
@export var tool_placement: Dictionary = {}

# Store for the initial farm layout (set at game start)
var initial_farm_layout = {}

# Costs of different tile types
var tile_prices = {
	"regular": 0,
	"dirt": 100,
	"soil": 150,
	"water": 250,
	"mud": 150,
	"delivery": 300
}

# NEW: Costs of different tool types
var tool_prices = {
	"hoe": 150,
	"watering_can": 200,
	"basket": 250,
	"carrot_seeds": 100,
	"tomato_seeds": 150
}

# Unlocked items
@export var unlocked_seeds: Array = ["carrot"]
@export var unlocked_tools: Array = ["hoe", "watering_can", "basket"]

# Statistics
@export var stats: Dictionary = {
	"orders_completed": 0,
	"crops_harvested": 0,
	"tiles_tilled": 0,
	"total_earnings": 0
}

# Initialize with default values
func _init():
	# Set default values if not already set
	if currency == 0:
		currency = 1000
	
	# Ensure arrays are initialized
	if unlocked_seeds.size() == 0:
		unlocked_seeds = ["carrot"]
	
	if unlocked_tools.size() == 0:
		unlocked_tools = ["hoe", "watering_can", "basket"]

# Set a tile in the data - properly handles negative coordinates
func set_tile(x: int, z: int, type: int):
	var key = str(x) + "," + str(z)
	
	# If the tile is being reset to REGULAR_GROUND (0), remove it from the dictionary
	if type == 0:
		if tile_data.has(key):
			tile_data.erase(key)
			print("FarmData: Removed regular ground tile at ", x, ",", z, " from saved data")
	else:
		tile_data[key] = type
		print("FarmData: Saved tile type ", type, " at ", x, ",", z)

# Get a tile from the data - properly handles negative coordinates
func get_tile(x: int, z: int, default_type: int = 0) -> int:
	var key = str(x) + "," + str(z)
	if tile_data.has(key):
		return tile_data[key]
	return default_type

# NEW: Place a tool at a specific position
func place_tool(x: int, z: int, tool_type: String) -> bool:
	var key = str(x) + "," + str(z)
	
	# Check if there's already a tool at this position
	if tool_placement.has(key):
		return false
	
	# Place the tool
	tool_placement[key] = tool_type
	print("FarmData: Placed tool ", tool_type, " at ", x, ",", z)
	return true

# NEW: Remove a tool from a specific position
func remove_tool(x: int, z: int) -> bool:
	var key = str(x) + "," + str(z)
	
	if tool_placement.has(key):
		var tool_type = tool_placement[key]
		tool_placement.erase(key)
		print("FarmData: Removed tool ", tool_type, " from ", x, ",", z)
		return true
	
	return false

# NEW: Get tool at a specific position
func get_tool_at(x: int, z: int) -> String:
	var key = str(x) + "," + str(z)
	if tool_placement.has(key):
		return tool_placement[key]
	return ""

# NEW: Get the cost of a specific tool
func get_tool_cost(tool_type: String) -> int:
	if tool_prices.has(tool_type):
		return tool_prices[tool_type]
	return 0

# NEW: Try to purchase a tool
func try_purchase_tool(tool_type: String) -> bool:
	var cost = get_tool_cost(tool_type)
	if cost <= currency:
		currency -= cost
		
		# Update statistics
		if not stats.has("money_spent_on_tools"):
			stats["money_spent_on_tools"] = 0
		stats["money_spent_on_tools"] += cost
		
		return true
	return false

# Get the cost of converting to a specific tile type
func get_tile_cost(type_name: String) -> int:
	if tile_prices.has(type_name):
		return tile_prices[type_name]
	return 0

# Try to purchase a tile conversion
func try_purchase_tile(type_name: String) -> bool:
	var cost = get_tile_cost(type_name)
	if cost <= currency:
		currency -= cost
		
		# Update statistics
		if not stats.has("money_spent"):
			stats["money_spent"] = 0
		stats["money_spent"] += cost
		
		return true
	return false

# Check if a seed type is unlocked
func is_seed_unlocked(seed_type: String) -> bool:
	return unlocked_seeds.has(seed_type)

# Check if a tool is unlocked
func is_tool_unlocked(tool_type: String) -> bool:
	return unlocked_tools.has(tool_type)

# Add a new seed type
func unlock_seed(seed_type: String, cost: int = 0) -> bool:
	# Check if we can afford it and don't already have it
	if unlocked_seeds.has(seed_type):
		return false
		
	if cost > 0:
		if currency < cost:
			return false
		currency -= cost
	
	unlocked_seeds.append(seed_type)
	return true

# Add a new tool
func unlock_tool(tool_type: String, cost: int = 0) -> bool:
	# Check if we can afford it and don't already have it
	if unlocked_tools.has(tool_type):
		return false
		
	if cost > 0:
		if currency < cost:
			return false
		currency -= cost
	
	unlocked_tools.append(tool_type)
	return true

# Get all soil tiles
func get_soil_tiles() -> Array:
	var soil_tiles = []
	
	for key in tile_data.keys():
		# Soil type is typically 2 in TileType enum
		if tile_data[key] == 2:
			var coords = key.split(",")
			var x = int(coords[0])
			var z = int(coords[1])
			soil_tiles.append(Vector3i(x, 0, z))
	
	return soil_tiles

# Get all delivery tiles
func get_delivery_tiles() -> Array:
	var delivery_tiles = []
	
	for key in tile_data.keys():
		# Delivery type is typically 5 in TileType enum
		if tile_data[key] == 5:
			var coords = key.split(",")
			var x = int(coords[0])
			var z = int(coords[1])
			delivery_tiles.append(Vector3i(x, 0, z))
	
	return delivery_tiles

# NEW: Get all placed tools
func get_all_placed_tools() -> Dictionary:
	return tool_placement.duplicate()

# Update statistics
func add_stat(stat_name: String, value: int = 1):
	if stats.has(stat_name):
		stats[stat_name] += value
	else:
		stats[stat_name] = value

# Add run score
func add_run_score(score: int):
	add_stat("total_score", score)
	highest_score = max(highest_score, score)
	run_count += 1

# Save this resource
func save(path: String = "user://farm_data.tres"):
	var err = ResourceSaver.save(self, path)
	if err == OK:
		print("FarmData: Successfully saved to ", path)
		return true
	else:
		push_error("FarmData: Failed to save data. Error code: " + str(err))
		return false

# Static method to load farm data
static func load_data(force_new: bool = false) -> FarmData:
	var path = "user://farm_data.tres"
	
	# Check if we should create new data regardless of whether a save exists
	if force_new:
		print("FarmData: Force new requested - Creating new farm data instead of loading")
		var new_data = FarmData.new()
		return new_data
	
	# Normal load path - check if save file exists
	if ResourceLoader.exists(path):
		var data = ResourceLoader.load(path)
		if data is FarmData:
			print("FarmData: Successfully loaded from ", path)
			return data
			
	# Create new data if none exists
	print("FarmData: No save file found - Creating new farm data")
	var new_data = FarmData.new()
	return new_data

# Debug method to print all non-default tiles
func print_all_tiles():
	print("=== FARM DATA TILES ===")
	print("Total tiles stored: ", tile_data.size())
	
	var sorted_keys = tile_data.keys()
	sorted_keys.sort()
	
	for key in sorted_keys:
		var type = tile_data[key]
		print(key, ": Type ", type)
	
	print("=====================")

# Debug method to print all placed tools
func print_all_tools():
	print("=== FARM DATA TOOLS ===")
	print("Total tools placed: ", tool_placement.size())
	
	var sorted_keys = tool_placement.keys()
	sorted_keys.sort()
	
	for key in sorted_keys:
		var tool_type = tool_placement[key]
		print(key, ": Tool ", tool_type)
	
	print("======================")

# Save the initial farm layout from the scene
func save_initial_farm_layout(level_manager):
	if not level_manager:
		push_error("FarmData: Cannot save initial farm layout - level manager is null")
		return false
		
	print("FarmData: Saving initial farm layout from Main.tscn")
	initial_farm_layout.clear()
	
	# Get level dimensions
	var level_width = level_manager.level_width
	var level_height = level_manager.level_height
	
	# Save all non-default tiles (anything that's not REGULAR_GROUND)
	for x in range(-50, level_width + 50):
		for z in range(-50, level_height + 50):
			var pos = Vector3i(x, 0, z)
			var tile_type = level_manager.get_tile_type(pos)
			
			# Only store non-default tiles
			if tile_type != level_manager.TileType.REGULAR_GROUND:
				var key = str(x) + "," + str(z)
				initial_farm_layout[key] = tile_type
				print("FarmData: Saved initial tile at " + key + " with type " + str(tile_type))
	
	print("FarmData: Saved " + str(initial_farm_layout.size()) + " tiles in initial farm layout")
	
	# Also save this to disk
	save()
	return true

# Reset farm to initial layout
func reset_to_initial_layout(level_manager):
	if not level_manager:
		push_error("FarmData: Cannot reset to initial farm layout - level manager is null")
		return false
		
	if initial_farm_layout.size() == 0:
		push_error("FarmData: No initial farm layout saved!")
		return false
		
	print("FarmData: Resetting to initial farm layout")
	
	# Clear all tiles first (set everything to REGULAR_GROUND)
	for x in range(-50, 50):
		for z in range(-50, 50):
			var pos = Vector3i(x, 0, z)
			level_manager.set_tile_type(pos, level_manager.TileType.REGULAR_GROUND)
			
			# Also clear from our tile_data
			var key = str(x) + "," + str(z)
			if tile_data.has(key):
				tile_data.erase(key)
	
	# Now restore initial layout
	for key in initial_farm_layout:
		var coords = key.split(",")
		var x = int(coords[0])
		var z = int(coords[1])
		var type = initial_farm_layout[key]
		
		# Set the tile in the level
		var pos = Vector3i(x, 0, z)
		level_manager.set_tile_type(pos, type)
		
		# Also update our tile_data
		tile_data[key] = type
	
	print("FarmData: Reset " + str(initial_farm_layout.size()) + " tiles to initial layout")
	save()
	return true

# Reset progression but keep initial farm layout
func reset_progression():
	print("FarmData: Resetting all progression data")
	
	# Reset currency and stats
	currency = 1000
	run_count = 0
	highest_score = 0
	
	# Clear all custom tile data but keep initial layout
	tile_data.clear()
	
	# NEW: Clear all tool placements
	tool_placement.clear()
	
	# Reset unlocked items to initial state
	unlocked_seeds = ["carrot"]
	unlocked_tools = ["hoe", "watering_can", "basket"]
	
	# Reset all statistics
	stats = {
		"orders_completed": 0,
		"crops_harvested": 0,
		"tiles_tilled": 0,
		"total_earnings": 0
	}
	
	# Save the reset data
	save()
	
	return true

# Static method to perform a complete reset
static func reset_all():
	var farm_data = FarmData.new()
	farm_data.save()
	return farm_data
	
# Unlocked crop types (start with carrots)
@export var unlocked_crops: Dictionary = {
	"carrot": {
		"unlocked": true,
		"growth_time": 20.0,
		"value": 1.0,
		"color": Color(1.0, 0.5, 0.0)  # Orange
	},
	"tomato": {
		"unlocked": false,
		"growth_time": 30.0,
		"value": 1.5,
		"color": Color(0.9, 0.1, 0.1)  # Red
	}
	# Future crops can be added here
}

# Cost scaling for upgrades based on how many you already have
var upgrade_scaling = {
	"dirt": 1.0,  # No scaling
	"water": 1.2,  # 20% increase per water tile
	"delivery": 1.5  # 50% increase per delivery tile
}

# Get all unlocked crop types
func get_unlocked_crops() -> Array:
	var crops = []
	for crop_name in unlocked_crops:
		if unlocked_crops[crop_name].unlocked:
			crops.append(crop_name)
	return crops

# Check if a crop is unlocked
func is_crop_unlocked(crop_type: String) -> bool:
	if unlocked_crops.has(crop_type):
		return unlocked_crops[crop_type].unlocked
	return false

# Unlock a new crop type
func unlock_crop(crop_type: String, cost: int = 0) -> bool:
	# Check if we can afford it and don't already have it
	if not unlocked_crops.has(crop_type) or unlocked_crops[crop_type].unlocked:
		return false
		
	if cost > 0:
		if currency < cost:
			return false
		currency -= cost
	
	# Unlock the crop
	unlocked_crops[crop_type].unlocked = true
	
	# Also automatically unlock the seed if crop names match seed names
	if crop_type in ["carrot", "tomato"]:
		unlocked_seeds.append(crop_type)
	
	return true

# Calculate the cost of a tile based on how many of that type you already have
func get_scaled_tile_cost(type_name: String) -> int:
	var base_cost = get_tile_cost(type_name)
	if base_cost == 0:
		return 0
	
	# Count existing tiles of this type
	var existing_count = 0
	var tile_type_id = -1
	
	# Convert type name to tile type ID
	match type_name:
		"dirt": tile_type_id = 1  # DIRT_GROUND
		"soil": tile_type_id = 2  # SOIL
		"water": tile_type_id = 3  # WATER
		"mud": tile_type_id = 4    # MUD
		"delivery": tile_type_id = 5  # DELIVERY
	
	# Count tiles
	if tile_type_id >= 0:
		for key in tile_data:
			if tile_data[key] == tile_type_id:
				existing_count += 1
	
	# Apply scaling if defined
	var scale_factor = 1.0
	if upgrade_scaling.has(type_name):
		scale_factor = pow(upgrade_scaling[type_name], existing_count)
	
	# Calculate final cost (rounded to nearest 10)
	var scaled_cost = round(base_cost * scale_factor / 10) * 10
	return int(scaled_cost)

# Calculate recommended upgrades based on current farm state
func get_recommended_upgrades() -> Dictionary:
	var recommendations = {}
	
	# Count tile types
	var dirt_count = 0
	var water_count = 0
	var delivery_count = 0
	
	for key in tile_data:
		match tile_data[key]:
			1: dirt_count += 1     # DIRT_GROUND
			3: water_count += 1    # WATER
			5: delivery_count += 1 # DELIVERY
	
	# Recommend based on current level and existing infrastructure
	if current_level == 1:
		if dirt_count < 4:
			recommendations["dirt_tiles"] = {
				"name": "Dirt Tiles",
				"priority": 1,
				"cost": get_scaled_tile_cost("dirt"),
				"reason": "Expand your farming area"
			}
		
		if not unlocked_crops["tomato"].unlocked:
			recommendations["tomato_seeds"] = {
				"name": "Tomato Seeds",
				"priority": 2,
				"cost": 150,
				"reason": "Higher value crop"
			}
	
	elif current_level >= 2:
		if dirt_count < 6:
			recommendations["dirt_tiles"] = {
				"name": "More Dirt",
				"priority": 1,
				"cost": get_scaled_tile_cost("dirt"),
				"reason": "Larger farm area"
			}
		
		if water_count < 2:
			recommendations["water_tile"] = {
				"name": "Water Source",
				"priority": 2,
				"cost": get_scaled_tile_cost("water"),
				"reason": "More efficient watering"
			}
	
	return recommendations

# Advanced stats for progression tracking
func update_level_stats(level: int, score: int, orders_completed: int):
	# Track level-specific stats
	var level_key = "level_" + str(level) + "_completed"
	add_stat(level_key, 1)
	
	# Track high score for this level
	var high_score_key = "level_" + str(level) + "_high_score"
	if not stats.has(high_score_key) or stats[high_score_key] < score:
		stats[high_score_key] = score
	
	# Update general stats
	add_stat("total_score", score)
	add_stat("orders_completed", orders_completed)
	
	# Save changes
	save()
