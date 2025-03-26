# scripts/data/GameData.gd
class_name GameData
extends Resource

# Main data containers
var progression_data: ProgressionData
var farm_layout_data: FarmLayoutData
var upgrades_data: UpgradesData
var stats_data: StatsData

# Signals
signal data_changed

func _init():
	# Create data containers
	progression_data = ProgressionData.new()
	farm_layout_data = FarmLayoutData.new()
	upgrades_data = UpgradesData.new()
	stats_data = StatsData.new()

# Save the entire game data
func save(path: String = "user://game_data.tres") -> bool:
	# Save each data container
	progression_data.save("user://progression_data.tres")
	farm_layout_data.save("user://farm_layout_data.tres")
	upgrades_data.save("user://upgrades_data.tres")
	stats_data.save("user://stats_data.tres")
	
	# Save reference to this resource as well
	var err = ResourceSaver.save(self, path)
	if err == OK:
		print("GameData: Successfully saved game data")
		return true
	else:
		push_error("GameData: Failed to save game data. Error code: " + str(err))
		return false

# Load all game data
static func load_data(force_new: bool = false) -> GameData:
	var path = "user://game_data.tres"
	var game_data = GameData.new()
	
	if force_new:
		print("GameData: Force new requested - Creating new game data")
		return game_data
	
	# Try to load existing data
	if ResourceLoader.exists(path):
		var data = ResourceLoader.load(path)
		if data is GameData:
			# Load individual data components
			game_data.progression_data = ProgressionData.load_data()
			game_data.farm_layout_data = FarmLayoutData.load_data()
			game_data.upgrades_data = UpgradesData.load_data()
			game_data.stats_data = StatsData.load_data()
			
			print("GameData: Successfully loaded from " + path)
			return game_data
	
	# If we get here, create new data
	print("GameData: No save file found - Creating new game data")
	return game_data

# Reset all game data
func reset_all():
	progression_data.reset()
	farm_layout_data.reset()
	upgrades_data.reset()
	stats_data.reset()
	save()

# Individual data classes
class ProgressionData extends Resource:
	# Currency and progression
	@export var currency: int = 10000
	@export var current_level: int = 1
	@export var highest_level_reached: int = 1
	@export var run_count: int = 0
	@export var highest_score: int = 0
	
	# Unlocked items
	@export var unlocked_seeds: Array = ["carrot"]
	@export var unlocked_tools: Array = ["hoe", "watering_can", "basket"]
	@export var unlocked_tile_types: Array[int] = [0, 1, 5, 6, 7, 8]
	
	# Save this resource
	func save(path: String = "user://progression_data.tres"):
		var err = ResourceSaver.save(self, path)
		return err == OK
	
	# Static load method
	static func load_data() -> ProgressionData:
		var path = "user://progression_data.tres"
		if ResourceLoader.exists(path):
			var data = ResourceLoader.load(path)
			if data is ProgressionData:
				return data
		return ProgressionData.new()
	
	# Reset to defaults
	func reset():
		currency = 1000
		current_level = 1
		highest_level_reached = 1
		run_count = 0
		highest_score = 0
		unlocked_seeds = ["carrot"]
		unlocked_tools = ["hoe", "watering_can", "basket"]
		
		unlocked_tile_types = [0, 1, 5, 6, 7, 8]  # Reset to default tiles

class FarmLayoutData extends Resource:
	# Tile data - stores positions and types of special tiles
	# Format: { "x,z": tile_type }
	@export var tile_data: Dictionary = {}
	
	# Tool placement data - stores positions and types of placed tools
	# Format: { "x,z": tool_type }
	@export var tool_placement: Dictionary = {}
	
	# Store for the initial farm layout (set at game start)
	var initial_farm_layout = {}
	
	# Save this resource
	func save(path: String = "user://farm_layout_data.tres"):
		var err = ResourceSaver.save(self, path)
		return err == OK
	
	# Static load method
	static func load_data() -> FarmLayoutData:
		var path = "user://farm_layout_data.tres"
		if ResourceLoader.exists(path):
			var data = ResourceLoader.load(path)
			if data is FarmLayoutData:
				return data
		return FarmLayoutData.new()
	
	# Reset to defaults but keep initial layout
	func reset():
		tile_data.clear()
		tool_placement.clear()

class UpgradesData extends Resource:
	# Dictionary of purchased upgrades
	# Format: { "upgrade_id": level }
	@export var purchased_upgrades: Dictionary = {}
	
	# Dictionary of tile-specific upgrades
	# Format: { "x,z": { "upgrade_id": level } }
	@export var tile_upgrades: Dictionary = {}
	
	# Save this resource
	func save(path: String = "user://upgrades_data.tres"):
		var err = ResourceSaver.save(self, path)
		return err == OK
	
	# Static load method
	static func load_data() -> UpgradesData:
		var path = "user://upgrades_data.tres"
		if ResourceLoader.exists(path):
			var data = ResourceLoader.load(path)
			if data is UpgradesData:
				return data
		return UpgradesData.new()
	
	# Reset all upgrades
	func reset():
		purchased_upgrades.clear()
		tile_upgrades.clear()

class StatsData extends Resource:
	# Game statistics
	@export var stats: Dictionary = {
		"orders_completed": 0,
		"crops_harvested": 0,
		"tiles_tilled": 0,
		"total_earnings": 0,
		"total_score": 0
	}
	
	# Add to a stat
	func add_stat(stat_name: String, value: int = 1):
		if stats.has(stat_name):
			stats[stat_name] += value
		else:
			stats[stat_name] = value
	
	# Save this resource
	func save(path: String = "user://stats_data.tres"):
		var err = ResourceSaver.save(self, path)
		return err == OK
	
	# Static load method
	static func load_data() -> StatsData:
		var path = "user://stats_data.tres"
		if ResourceLoader.exists(path):
			var data = ResourceLoader.load(path)
			if data is StatsData:
				return data
		return StatsData.new()
	
	# Reset all stats
	func reset():
		stats = {
			"orders_completed": 0,
			"crops_harvested": 0,
			"tiles_tilled": 0,
			"total_earnings": 0,
			"total_score": 0
		}
