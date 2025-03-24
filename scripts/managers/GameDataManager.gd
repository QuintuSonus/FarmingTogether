# scripts/managers/GameDataManager.gd
class_name GameDataManager
extends Node

# Main data reference
var game_data: GameData

# Node references
var level_manager: Node = null

# Signal when data changes
signal data_changed

func _ready():
	# Load or create game data
	game_data = GameData.load_data()
	
	# Get reference to level manager (will be used for initial layouts)
	level_manager = get_node_or_null("/root/Main/LevelManager")
	if not level_manager:
		level_manager = get_tree().get_root().find_child("LevelManager", true, false)
	
	# Register with ServiceLocator if available
	var service_locator = get_node_or_null("/root/ServiceLocator")
	if service_locator:
		service_locator.register_service("game_data", game_data)
		service_locator.register_service("game_data_manager", self)
	
	print("GameDataManager: Initialized with game data")

# Save the initial farm layout from the scene
func save_initial_farm_layout():
	if not level_manager:
		push_error("GameDataManager: Cannot save initial farm layout - level manager not found")
		return
	
	# Check if initial layout has already been saved
	if game_data.farm_layout_data.initial_farm_layout.size() > 0:
		print("GameDataManager: Initial farm layout already exists with " + 
			  str(game_data.farm_layout_data.initial_farm_layout.size()) + " tiles")
		return
		
	print("GameDataManager: Saving initial farm layout from Main.tscn")
	
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
				game_data.farm_layout_data.initial_farm_layout[key] = tile_type
				game_data.farm_layout_data.tile_data[key] = tile_type
	
	print("GameDataManager: Saved " + str(game_data.farm_layout_data.initial_farm_layout.size()) + 
		  " tiles in initial farm layout")
	
	# Save to disk
	game_data.save()

# Apply saved farm layout from game data
func apply_saved_farm_layout():
	if not level_manager:
		push_error("GameDataManager: Cannot apply saved layout - level manager not found")
		return
	
	# Get development mode flag
	var dev_mode = false
	var game_manager = get_parent()
	if game_manager and "always_reset_on_startup" in game_manager:
		dev_mode = game_manager.always_reset_on_startup and OS.is_debug_build()
	
	# In development mode, just use the scene as-is
	if dev_mode:
		print("GameDataManager: Development mode - Using scene's layout directly (no changes)")
		return
	
	print("GameDataManager: Applying saved farm layout")
	
	# Apply all saved tiles
	for key in game_data.farm_layout_data.tile_data.keys():
		var coords = key.split(",")
		var x = int(coords[0])
		var z = int(coords[1])
		var type = game_data.farm_layout_data.tile_data[key]
		
		var pos = Vector3i(x, 0, z)
		level_manager.set_tile_type(pos, type)
	
	print("GameDataManager: Applied saved farm layout with " + 
		  str(game_data.farm_layout_data.tile_data.size()) + " custom tiles")

# Apply default farm layout (for fresh start)
func apply_default_farm_layout():
	if not level_manager:
		push_error("GameDataManager: Cannot apply default layout - level manager not found")
		return
		
	print("GameDataManager: Applying default farm layout")
	
	# Clear all tiles to regular ground
	for x in range(-10, 20):
		for z in range(-10, 20):
			var pos = Vector3i(x, 0, z)
			level_manager.set_tile_type(pos, level_manager.TileType.REGULAR_GROUND)
	
	# Add some basic dirt tiles for farming
	for x in range(2, 6):
		for z in range(2, 6):
			var pos = Vector3i(x, 0, z)
			level_manager.set_tile_type(pos, level_manager.TileType.DIRT_GROUND)
	
	# Add water tiles on the right side
	for z in range(3, 5):
		var pos = Vector3i(8, 0, z)
		level_manager.set_tile_type(pos, level_manager.TileType.WATER)
	
	# Add a delivery tile
	level_manager.set_tile_type(Vector3i(10, 0, 4), level_manager.TileType.DELIVERY)
	
	print("GameDataManager: Default farm layout applied")
	
	# Save this as the initial layout too
	save_initial_farm_layout()

# Get currency value
func get_currency() -> int:
	return game_data.progression_data.currency

# Add currency
func add_currency(amount: int):
	game_data.progression_data.currency += amount
	game_data.save()
	emit_signal("data_changed")

# Set the current level
func set_current_level(level: int):
	game_data.progression_data.current_level = level
	if level > game_data.progression_data.highest_level_reached:
		game_data.progression_data.highest_level_reached = level
	game_data.save()
	emit_signal("data_changed")

# Add tool placement
func place_tool(x: int, z: int, tool_type: String) -> bool:
	var key = str(x) + "," + str(z)
	
	# Check if there's already a tool at this position
	if game_data.farm_layout_data.tool_placement.has(key):
		return false
	
	# Place the tool
	game_data.farm_layout_data.tool_placement[key] = tool_type
	game_data.save()
	print("GameDataManager: Placed tool ", tool_type, " at ", x, ",", z)
	emit_signal("data_changed")
	return true

# Remove a tool from a specific position
func remove_tool(x: int, z: int) -> bool:
	var key = str(x) + "," + str(z)
	
	if game_data.farm_layout_data.tool_placement.has(key):
		var tool_type = game_data.farm_layout_data.tool_placement[key]
		game_data.farm_layout_data.tool_placement.erase(key)
		game_data.save()
		print("GameDataManager: Removed tool ", tool_type, " from ", x, ",", z)
		emit_signal("data_changed")
		return true
	
	return false

# Get tool at a specific position
func get_tool_at(x: int, z: int) -> String:
	var key = str(x) + "," + str(z)
	if game_data.farm_layout_data.tool_placement.has(key):
		return game_data.farm_layout_data.tool_placement[key]
	return ""

# Get all placed tools
func get_all_placed_tools() -> Dictionary:
	return game_data.farm_layout_data.tool_placement.duplicate()

# Reset all game data
func reset_all_data():
	game_data.reset_all()
	emit_signal("data_changed")

# Reset progression data but keep farm layout
func reset_progression():
	game_data.progression_data.reset()
	game_data.upgrades_data.reset()
	game_data.stats_data.reset()
	game_data.save()
	emit_signal("data_changed")

# Add statistic
func add_stat(stat_name: String, value: int = 1):
	game_data.stats_data.add_stat(stat_name, value)
	game_data.save()
	
# Is a seed type unlocked?
func is_seed_unlocked(seed_type: String) -> bool:
	return game_data.progression_data.unlocked_seeds.has(seed_type)

# Is a tool unlocked?
func is_tool_unlocked(tool_type: String) -> bool:
	return game_data.progression_data.unlocked_tools.has(tool_type)

# Set a tile in the data
func set_tile(x: int, z: int, type: int):
	var key = str(x) + "," + str(z)
	
	# If the tile is being reset to REGULAR_GROUND (0), remove it from the dictionary
	if type == 0:
		if game_data.farm_layout_data.tile_data.has(key):
			game_data.farm_layout_data.tile_data.erase(key)
			print("GameDataManager: Removed regular ground tile at ", x, ",", z, " from saved data")
	else:
		game_data.farm_layout_data.tile_data[key] = type
		print("GameDataManager: Saved tile type ", type, " at ", x, ",", z)
	
	game_data.save()
	emit_signal("data_changed")

# Get a tile from the data
func get_tile(x: int, z: int, default_type: int = 0) -> int:
	var key = str(x) + "," + str(z)
	if game_data.farm_layout_data.tile_data.has(key):
		return game_data.farm_layout_data.tile_data[key]
	return default_type

func set_level_manager(manager):
	level_manager = manager
	print("GameDataManager: Level manager reference set")
