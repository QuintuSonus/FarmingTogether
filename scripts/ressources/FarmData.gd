# scripts/ressources/FarmData.gd
class_name FarmData
extends Resource

# Currency and basic stats
@export var currency: int = 1000
@export var run_count: int = 0
@export var highest_score: int = 0

# Tile data - stores positions and types of special tiles
# Format: { "x,z": tile_type }
@export var tile_data: Dictionary = {}

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
static func load_data(path: String = "user://farm_data.tres") -> FarmData:
	if ResourceLoader.exists(path):
		var data = ResourceLoader.load(path)
		if data is FarmData:
			print("FarmData: Successfully loaded from ", path)
			return data
			
	# Create new data if none exists
	print("FarmData: Creating new farm data")
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
