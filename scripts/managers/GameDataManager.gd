# scripts/managers/GameDataManager.gd
class_name GameDataManager
extends Node

# Main data reference
var game_data: GameData

# Node references
var level_manager: LevelManager = null # Changed type hint

# Optimization properties
var batch_save_mode: bool = false
var needs_save: bool = false
var save_timer: float = 0.0
var autosave_interval: float = 2.0  # Seconds between autosaves

# Signal when data changes
signal data_changed

func _ready():
	# Load or create game data
	game_data = GameData.load_data() # Assuming GameData class is defined elsewhere

	# Get reference to level manager (will be used for initial layouts)
	# Ensure LevelManager node exists and is of the correct type
	var lm_node = get_node_or_null("/root/Main/LevelManager")
	if lm_node is LevelManager:
		level_manager = lm_node
	else:
		lm_node = get_tree().get_root().find_child("LevelManager", true, false)
		if lm_node is LevelManager:
			level_manager = lm_node

	# Register with ServiceLocator if available
	var service_locator = get_node_or_null("/root/ServiceLocator")
	if service_locator:
		service_locator.register_service("game_data", game_data)
		service_locator.register_service("game_data_manager", self)

	print("GameDataManager: Initialized with game data")
	if level_manager:
		print("GameDataManager: LevelManager reference acquired.")
	else:
		print("GameDataManager: WARNING - LevelManager reference NOT acquired.")


func _process(delta):
	# Only autosave in batch mode after the interval
	if batch_save_mode and needs_save:
		save_timer += delta
		if save_timer >= autosave_interval:
			save_timer = 0.0
			save_game_data()

# --- REVISED: Save initial farm layout using actual bounds from LevelManager ---
func save_initial_farm_layout():
	if not level_manager:
		push_error("GameDataManager: Cannot save initial farm layout - level manager reference not found or invalid type.")
		return

	# Check if initial layout has already been saved
	if game_data.farm_layout_data.initial_farm_layout.size() > 0:
		print("GameDataManager: Initial farm layout already exists with " +
			  str(game_data.farm_layout_data.initial_farm_layout.size()) + " tiles")
		return

	print("GameDataManager: Saving initial farm layout from current level state")

	# Start batch operations
	begin_batch_operation()

	# --- Get actual bounds from LevelManager ---
	var actual_bounds: Rect2i
	if level_manager.has_method("get_actual_bounds"):
		actual_bounds = level_manager.get_actual_bounds()
	else:
		push_error("GameDataManager: LevelManager is missing get_actual_bounds() method!")
		end_batch_operation() # Ensure batch mode ends even on error
		return

	if actual_bounds.size.x == 0 or actual_bounds.size.y == 0:
		print("GameDataManager: No valid bounds found in LevelManager, skipping initial layout save.")
		end_batch_operation()
		return

	# Clear previous initial layout data just in case
	game_data.farm_layout_data.initial_farm_layout.clear()
	game_data.farm_layout_data.tile_data.clear() # Also clear current tile data to match initial state

	# Iterate over the ACTUAL bounds found in LevelManager
	for x in range(actual_bounds.position.x, actual_bounds.end.x):
		for z in range(actual_bounds.position.y, actual_bounds.end.y):
			var pos = Vector3i(x, 0, z)
			var tile_type = level_manager.get_tile_type(pos) # Get type from LevelManager

			# Only store non-default tiles (or if you want to store all, remove this check)
			if tile_type > -1 and tile_type != level_manager.TileType.REGULAR_GROUND:
				var key = str(x) + "," + str(z)
				game_data.farm_layout_data.initial_farm_layout[key] = tile_type
				game_data.farm_layout_data.tile_data[key] = tile_type # Save to current data too

	print("GameDataManager: Saved " + str(game_data.farm_layout_data.initial_farm_layout.size()) +
		  " non-default tiles in initial farm layout based on actual bounds.")

	# End batch operations (will save if changes were made)
	end_batch_operation()

# Apply saved farm layout from game data
func apply_saved_farm_layout():
	if not level_manager:
		push_error("GameDataManager: Cannot apply saved layout - level manager not found")
		return

	# Get development mode flag (assuming GameManager is parent)
	var dev_mode = false
	var game_manager = get_parent() # Adjust if GameManager isn't the direct parent
	if game_manager and "always_reset_on_startup" in game_manager:
		dev_mode = game_manager.always_reset_on_startup and OS.is_debug_build()

	# In development mode, just use the scene as-is (handled by GameManager potentially)
	if dev_mode:
		print("GameDataManager: Development mode - Scene layout should be used directly (no changes applied here)")
		return

	print("GameDataManager: Applying saved farm layout")

	# It might be safer to clear existing tiles first or ensure LevelManager handles overrides correctly
	# level_manager.clear_all_tiles() # Example: Add a function to LevelManager if needed

	# Apply all saved tiles
	var applied_count = 0
	for key in game_data.farm_layout_data.tile_data.keys():
		var coords = key.split(",")
		if coords.size() == 2:
			var x = int(coords[0])
			var z = int(coords[1])
			var type = game_data.farm_layout_data.tile_data[key]

			var pos = Vector3i(x, 0, z)
			if level_manager.set_tile_type(pos, type): # Use LevelManager to set type
				applied_count += 1
		else:
			push_warning("GameDataManager: Invalid key format in tile_data: " + key)

	print("GameDataManager: Applied saved farm layout with " +
		  str(applied_count) + " custom tiles") # Use applied_count for accuracy

# Apply default farm layout (for fresh start)
func apply_default_farm_layout():
	if not level_manager:
		push_error("GameDataManager: Cannot apply default layout - level manager not found")
		return

	print("GameDataManager: Applying default farm layout")

	# Begin batch operation for better performance
	begin_batch_operation()

	# Clear existing tiles (important before setting defaults)
	# Iterate over potential large area or get current bounds and clear within them
	var current_bounds = level_manager.get_actual_bounds()
	if current_bounds.size.x > 0 and current_bounds.size.y > 0:
		for x in range(current_bounds.position.x, current_bounds.end.x):
			for z in range(current_bounds.position.y, current_bounds.end.y):
				# Setting to REGULAR_GROUND effectively clears non-default tiles
				level_manager.set_tile_type(Vector3i(x, 0, z), level_manager.TileType.REGULAR_GROUND)


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

	# End batch operation (saves changes)
	end_batch_operation() # This will save the state set by LevelManager

	print("GameDataManager: Default farm layout applied")

	# Save this default state as the initial layout too (overwrites previous)
	# Ensure LevelManager's state is fully updated before calling this
	save_initial_farm_layout()


# Get currency value
func get_currency() -> int:
	return game_data.progression_data.currency

# Add currency
func add_currency(amount: int):
	if amount == 0: return
	game_data.progression_data.currency += amount
	needs_save = true
	_debounced_save() # Use helper for debounced save
	emit_signal("data_changed")

# Set the current level
func set_current_level(level: int):
	if game_data.progression_data.current_level == level and \
	   level <= game_data.progression_data.highest_level_reached:
		return # No change needed

	game_data.progression_data.current_level = level
	if level > game_data.progression_data.highest_level_reached:
		game_data.progression_data.highest_level_reached = level

	needs_save = true
	_debounced_save() # Use helper for debounced save
	emit_signal("data_changed")

# Begin batch operation mode
func begin_batch_operation():
	batch_save_mode = true
	save_timer = 0.0
	print("GameDataManager: Starting batch operation")

# End batch operation and save if needed
func end_batch_operation():
	batch_save_mode = false
	if needs_save:
		save_game_data() # Save immediately when batch ends
	print("GameDataManager: Ended batch operation")

# Optimized save function
func save_game_data():
	if game_data:
		var start_time = Time.get_ticks_msec()
		if game_data.save(): # Call the save method on the GameData resource
			needs_save = false
			var duration = Time.get_ticks_msec() - start_time
			print("GameDataManager: Game data saved in " + str(duration) + "ms")
			emit_signal("data_changed")
		else:
			push_error("GameDataManager: Failed to save GameData resource.")
	else:
		push_error("GameDataManager: Cannot save - game_data is null")

# --- Debounced Save Helper ---
func _debounced_save():
	# Don't schedule save if in batch mode
	if batch_save_mode:
		return

	# Schedule a save after a short delay if not already scheduled
	if not has_meta("save_pending"):
		set_meta("save_pending", true)
		get_tree().create_timer(0.3, false).timeout.connect(func():
			remove_meta("save_pending") # Allow scheduling again
			if needs_save: # Check if still needed when timer expires
				save_game_data()
		)


# Add tool placement (with batch support)
func place_tool(x: int, z: int, tool_type: String, batch: bool = false) -> bool:
	var key = str(x) + "," + str(z)
	if game_data.farm_layout_data.tool_placement.has(key): return false

	game_data.farm_layout_data.tool_placement[key] = tool_type
	needs_save = true
	print("GameDataManager: Placed tool ", tool_type, " at ", x, ",", z)

	if not batch: _debounced_save() # Use debounced save unless batching

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

		if not batch: _debounced_save() # Use debounced save unless batching

		emit_signal("data_changed")
		return true
	return false

# Get tool at a specific position
func get_tool_at(x: int, z: int) -> String:
	var key = str(x) + "," + str(z)
	return game_data.farm_layout_data.tool_placement.get(key, "")

# Get all placed tools
func get_all_placed_tools() -> Dictionary:
	return game_data.farm_layout_data.tool_placement.duplicate() # Return a copy

# Reset all game data
func reset_all_data():
	game_data.reset_all()
	needs_save = true
	save_game_data() # Save immediately after full reset
	emit_signal("data_changed")

# Reset progression data but keep farm layout
func reset_progression():
	game_data.progression_data.reset()
	game_data.upgrades_data.reset()
	game_data.stats_data.reset()
	# Keep game_data.farm_layout_data.tile_data (farm layout)
	# Keep game_data.farm_layout_data.tool_placement (tool placements)

	needs_save = true
	save_game_data() # Save immediately after progression reset
	emit_signal("data_changed")

# Add statistic with batch support
func add_stat(stat_name: String, value: int = 1, batch: bool = false):
	if value == 0: return
	game_data.stats_data.add_stat(stat_name, value)
	needs_save = true
	if not batch: _debounced_save() # Use debounced save unless batching

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

	# If the tile is being reset to REGULAR_GROUND (type 0, assumed)
	if type == 0: # Assuming 0 is REGULAR_GROUND
		if game_data.farm_layout_data.tile_data.has(key):
			game_data.farm_layout_data.tile_data.erase(key)
			changed = true
	# Only update if the type is different or not present
	elif game_data.farm_layout_data.tile_data.get(key, -1) != type: # Use get() with default
		game_data.farm_layout_data.tile_data[key] = type
		changed = true

	if changed:
		needs_save = true
		if not batch: _debounced_save() # Use debounced save unless batching

# Get a tile from the data
func get_tile(x: int, z: int, default_type: int = 0) -> int:
	var key = str(x) + "," + str(z)
	# Assuming 0 is REGULAR_GROUND, return it if key not found
	return game_data.farm_layout_data.tile_data.get(key, default_type)

# Set level manager reference (called from GameManager)
func set_level_manager(manager: LevelManager):
	level_manager = manager
	print("GameDataManager: Level manager reference set.")
