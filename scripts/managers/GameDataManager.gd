# scripts/managers/GameDataManager.gd
class_name GameDataManager
extends Node

# Main data reference
var game_data: GameData

# Node references
var level_manager: Node = null

# Optimization properties
var batch_save_mode: bool = false
var needs_save: bool = false
var save_timer: float = 0.0
var autosave_interval: float = 2.0  # Seconds between autosaves

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

func _process(delta):
	# Only autosave in batch mode after the interval
	if batch_save_mode and needs_save:
		save_timer += delta
		if save_timer >= autosave_interval:
			save_timer = 0.0
			save_game_data()

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
	
	# Start batch operations
	begin_batch_operation()
	
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
	
	# End batch operations
	end_batch_operation()

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
	
	# Begin batch operation for better performance
	begin_batch_operation()
	
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
	
	# End batch operation
	end_batch_operation()
	
	print("GameDataManager: Default farm layout applied")
	
	# Save this as the initial layout too
	save_initial_farm_layout()

# Get currency value
func get_currency() -> int:
	return game_data.progression_data.currency

# Add currency
func add_currency(amount: int):
	if amount == 0:
		return
		
	game_data.progression_data.currency += amount
	needs_save = true
	
	# Debounced save
	if not has_meta("save_debounce"):
		set_meta("save_debounce", true)
		
		# Schedule a save after a short delay
		get_tree().create_timer(0.2).timeout.connect(func(): 
			if has_meta("save_debounce"): 
				remove_meta("save_debounce")
				if needs_save:
					save_game_data()
		)
	
	emit_signal("data_changed")

# Set the current level
func set_current_level(level: int):
	# Only save if it's actually changing
	if game_data.progression_data.current_level == level:
		return
		
	game_data.progression_data.current_level = level
	if level > game_data.progression_data.highest_level_reached:
		game_data.progression_data.highest_level_reached = level
	
	needs_save = true
	
	# Debounced save
	if not has_meta("save_debounce"):
		set_meta("save_debounce", true)
		
		# Schedule a save after a short delay
		get_tree().create_timer(0.2).timeout.connect(func(): 
			if has_meta("save_debounce"): 
				remove_meta("save_debounce")
				if needs_save:
					save_game_data()
		)
	
	emit_signal("data_changed")

# Begin batch operation mode
func begin_batch_operation():
	batch_save_mode = true
	save_timer = 0.0
	print("GameDataManager: Starting batch operation")

# End batch operation and save
func end_batch_operation():
	batch_save_mode = false
	if needs_save:
		save_game_data()
	print("GameDataManager: Ended batch operation and saved changes")

# Optimized save function
func save_game_data():
	if game_data:
		var start_time = Time.get_ticks_msec()
		game_data.save()
		needs_save = false
		var duration = Time.get_ticks_msec() - start_time
		print("GameDataManager: Game data saved in " + str(duration) + "ms")
		emit_signal("data_changed")
	else:
		push_error("GameDataManager: Cannot save - game_data is null")

# Add tool placement (with batch support)
func place_tool(x: int, z: int, tool_type: String, batch: bool = false) -> bool:
	var key = str(x) + "," + str(z)
	
	# Check if there's already a tool at this position
	if game_data.farm_layout_data.tool_placement.has(key):
		return false
	
	# Place the tool
	game_data.farm_layout_data.tool_placement[key] = tool_type
	needs_save = true
	
	print("GameDataManager: Placed tool ", tool_type, " at ", x, ",", z)
	
	# Save unless in batch mode
	if not batch and not batch_save_mode:
		save_game_data()
	
	emit_signal("data_changed")
	return true

# Remove a tool from a specific position
func remove_tool(x: int, z: int, batch: bool = false) -> bool:
	var key = str(x) + "," + str(z)
	
	if game_data.farm_layout_data.tool_placement.has(key):
		var tool_type = game_data.farm_layout_data.tool_placement[key]
		game_data.farm_layout_data.tool_placement.erase(key)
		
		needs_save = true
		print("GameDataManager: Removed tool ", tool_type, " from ", x, ",", z)
		
		# Save unless in batch mode
		if not batch and not batch_save_mode:
			save_game_data()
			
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
	needs_save = true
	save_game_data()
	emit_signal("data_changed")

# Reset progression data but keep farm layout
func reset_progression():
	game_data.progression_data.reset()
	game_data.upgrades_data.reset()
	game_data.stats_data.reset()
	
	needs_save = true
	save_game_data()
	emit_signal("data_changed")

# Add statistic with batch support
func add_stat(stat_name: String, value: int = 1, batch: bool = false):
	if value == 0:
		return
		
	game_data.stats_data.add_stat(stat_name, value)
	needs_save = true
	
	# Save unless in batch mode
	if not batch and not batch_save_mode:
		save_game_data()
	
# Is a seed type unlocked?
func is_seed_unlocked(seed_type: String) -> bool:
	return game_data.progression_data.unlocked_seeds.has(seed_type)

# Is a tool unlocked?
func is_tool_unlocked(tool_type: String) -> bool:
	return game_data.progression_data.unlocked_tools.has(tool_type)

# Set a tile in the data - optimized for batch operations
func set_tile(x: int, z: int, type: int, batch: bool = false):
	var key = str(x) + "," + str(z)
	var changed = false
	
	# If the tile is being reset to REGULAR_GROUND (0), remove it from the dictionary
	if type == 0:
		if game_data.farm_layout_data.tile_data.has(key):
			game_data.farm_layout_data.tile_data.erase(key)
			changed = true
	# Only update if the type is different or not present
	elif !game_data.farm_layout_data.tile_data.has(key) or game_data.farm_layout_data.tile_data[key] != type:
		game_data.farm_layout_data.tile_data[key] = type
		changed = true
	
	# Only mark as needing save if something actually changed
	if changed:
		needs_save = true
		
		# If in batch mode or explicit batch parameter, don't save immediately
		if batch or batch_save_mode:
			return
			
		# In regular mode, save after a short delay to batch multiple rapid changes
		if not has_meta("save_debounce"):
			set_meta("save_debounce", true)
			
			# Schedule a save after a short delay
			get_tree().create_timer(0.2).timeout.connect(func(): 
				if has_meta("save_debounce"): 
					remove_meta("save_debounce")
					if needs_save:
						save_game_data()
			)

# Get a tile from the data
func get_tile(x: int, z: int, default_type: int = 0) -> int:
	var key = str(x) + "," + str(z)
	if game_data.farm_layout_data.tile_data.has(key):
		return game_data.farm_layout_data.tile_data[key]
	return default_type

# Set level manager reference
func set_level_manager(manager):
	level_manager = manager
	print("GameDataManager: Level manager reference set")
