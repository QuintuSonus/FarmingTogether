# scripts/resources/FarmData.gd
class_name FarmData
extends Resource

# Currency and basic stats
@export var currency: int = 1000
@export var run_count: int = 0
@export var highest_score: int = 0

# Tile data - stores positions and types of special tiles
# Format: { "x,z": tile_type }
@export var tile_data: Dictionary = {}

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
