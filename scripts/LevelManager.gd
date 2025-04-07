# LevelManager.gd
class_name LevelManager
extends Node3D


# Constants for tile types based on our GDD
enum TileType {
	REGULAR_GROUND = 0,
	DIRT_GROUND = 1,
	DIRT_FERTILE = 2,     # New: Enhanced dirt with faster growth
	DIRT_PRESERVED = 3,   # New: Enhanced dirt with slower spoiling
	DIRT_PERSISTENT = 4,  # New: Enhanced dirt that stays as soil after harvest
	SOIL = 5,
	WATER = 6,
	MUD = 7,
	DELIVERY = 8,
	DELIVERY_EXPRESS = 10, # New: Enhanced delivery with bonus points
	SPRINKLER = 11        # New: Automatic watering of adjacent tiles
}

# Reference to the GridMap node
@onready var grid_map: GridMap = $GridMap # Use @onready for direct child

# Level dimensions (REVISED: Store actual bounds)
var _level_bounds: Rect2i = Rect2i(0, 0, 0, 0) # Stores min_x, min_z, width, height

# Dictionary to track tile states
var tile_states = {}

# Map tile types to mesh IDs in the MeshLibrary
const REGULAR_GROUND_MESH_ID = 0
const DIRT_GROUND_MESH_ID = 1
const DIRT_FERTILE_MESH_ID = 2
const DIRT_PRESERVED_MESH_ID = 3
const DIRT_PERSISTENT_MESH_ID = 4
const SOIL_MESH_ID = 5
const WATER_MESH_ID = 6
const MUD_MESH_ID = 7
const DELIVERY_MESH_ID = 8
const DELIVERY_EXPRESS_MESH_ID = 9
const SPRINKLER_MESH_ID = 10

var sprinkler_timer: float = 0.0
@export var sprinkler_interval: float = 30.0

var soil_properties = {} # Format: "x,z": {"source_type": original_dirt_type}

signal tile_changed(position, old_type, new_type)

@export var force_runtime_generation: bool = false

func _ready():
	# Check if there are already tiles placed in the editor
	var existing_tiles = grid_map.get_used_cells()

	if force_runtime_generation or existing_tiles.size() == 0:
		print("No editor-placed tiles found or generation forced. Creating default level layout...")
		initialize_level() # This will also calculate bounds
	else:
		print("Editor-placed tiles found. Loading level from editor...")
		load_tile_states_from_editor() # This now calculates bounds

	# Print debug info about tile states
	print("Level Bounds:", _level_bounds)
	print_all_tile_states()
	print_level_state() # Now uses actual bounds

func _process(delta):
	if get_all_tiles_of_type(TileType.SPRINKLER).size() > 0:
		sprinkler_timer += delta
		if sprinkler_timer >= sprinkler_interval:
			sprinkler_timer = 0.0
			activate_sprinklers()

# --- NEW: Helper function to calculate actual bounds ---
func _calculate_actual_bounds():
	if tile_states.is_empty():
		_level_bounds = Rect2i(0, 0, 0, 0)
		return

	var min_x = INF
	var min_z = INF
	var max_x = -INF
	var max_z = -INF

	for pos in tile_states.keys():
		min_x = min(min_x, pos.x)
		min_z = min(min_z, pos.z)
		max_x = max(max_x, pos.x)
		max_z = max(max_z, pos.z)

	if min_x == INF: # Handle case where dictionary might somehow be non-empty but contain no valid keys
		_level_bounds = Rect2i(0, 0, 0, 0)
	else:
		_level_bounds = Rect2i(min_x, min_z, max_x - min_x + 1, max_z - min_z + 1)
	print("Calculated actual bounds: ", _level_bounds)


# Load tile states from tiles placed in the editor
func load_tile_states_from_editor():
	tile_states.clear()
	var placed_cells = grid_map.get_used_cells()
	print("Found " + str(placed_cells.size()) + " cells placed in the editor")

	# Process all placed cells first
	for cell_pos in placed_cells:
		var item = grid_map.get_cell_item(cell_pos)
		var tile_type = get_tile_type_from_mesh_id(item)
		tile_states[cell_pos] = tile_type

	# --- REVISED: Calculate bounds AFTER loading all tiles ---
	_calculate_actual_bounds()

	# Optional: Fill missing cells within calculated bounds with REGULAR_GROUND if needed
	# for x in range(_level_bounds.position.x, _level_bounds.end.x):
	#	 for z in range(_level_bounds.position.y, _level_bounds.end.y):
	#		 var pos = Vector3i(x, 0, z)
	#		 if not tile_states.has(pos):
	#			 tile_states[pos] = TileType.REGULAR_GROUND
	#			 grid_map.set_cell_item(pos, REGULAR_GROUND_MESH_ID) # Add visual tile too

	print("Level loaded from editor with " + str(tile_states.size()) + " tiles")

# Helper function to convert mesh IDs to tile types
func get_tile_type_from_mesh_id(mesh_id: int) -> int:
	match mesh_id:
		REGULAR_GROUND_MESH_ID: return TileType.REGULAR_GROUND
		DIRT_GROUND_MESH_ID: return TileType.DIRT_GROUND
		DIRT_FERTILE_MESH_ID: return TileType.DIRT_FERTILE
		DIRT_PRESERVED_MESH_ID: return TileType.DIRT_PRESERVED
		DIRT_PERSISTENT_MESH_ID: return TileType.DIRT_PERSISTENT
		SOIL_MESH_ID: return TileType.SOIL
		WATER_MESH_ID: return TileType.WATER
		MUD_MESH_ID: return TileType.MUD
		DELIVERY_MESH_ID: return TileType.DELIVERY
		DELIVERY_EXPRESS_MESH_ID: return TileType.DELIVERY_EXPRESS
		SPRINKLER_MESH_ID: return TileType.SPRINKLER
		_:
			print("Warning: Unknown mesh ID: ", mesh_id)
			return TileType.REGULAR_GROUND # Fallback

# Set up initial level layout (only used if no editor tiles exist or forced)
func initialize_level():
	grid_map.clear()
	tile_states.clear()

	# Create a simple default layout (example)
	var default_width = 12
	var default_height = 8
	for x in range(default_width):
		for z in range(default_height):
			var pos = Vector3i(x, 0, z)
			var type_to_set = TileType.REGULAR_GROUND
			var mesh_id = REGULAR_GROUND_MESH_ID

			# Example dirt patch
			if x >= 2 and x < 6 and z >= 2 and z < 6:
				type_to_set = TileType.DIRT_GROUND
				mesh_id = DIRT_GROUND_MESH_ID
			# Example water
			elif x == 8 and z >= 3 and z < 5:
				type_to_set = TileType.WATER
				mesh_id = WATER_MESH_ID
			# Example delivery
			elif x == 10 and z == 4:
				type_to_set = TileType.DELIVERY
				mesh_id = DELIVERY_MESH_ID

			grid_map.set_cell_item(pos, mesh_id)
			tile_states[pos] = type_to_set

	# --- REVISED: Calculate bounds AFTER setting default tiles ---
	_calculate_actual_bounds()
	print("Level initialized with default layout, bounds: ", _level_bounds)


# Function to change a dirt tile to soil
func convert_to_soil(grid_position: Vector3i) -> bool:
	if not tile_states.has(grid_position): return false # Ensure tile exists

	var current_type = tile_states[grid_position]
	var is_dirt = (current_type == TileType.DIRT_GROUND or
				   current_type == TileType.DIRT_FERTILE or
				   current_type == TileType.DIRT_PRESERVED or
				   current_type == TileType.DIRT_PERSISTENT)

	if is_dirt:
		var old_type = current_type
		grid_map.set_cell_item(grid_position, SOIL_MESH_ID)
		tile_states[grid_position] = TileType.SOIL

		var key = str(grid_position.x) + "," + str(grid_position.z)
		soil_properties[key] = {"source_type": old_type}

		emit_signal("tile_changed", grid_position, old_type, TileType.SOIL)
		return true

	return false

# Function to get the type of tile at a given position
func get_tile_type(grid_position: Vector3i) -> int:
	if tile_states.has(grid_position):
		return tile_states[grid_position]
	else:
		# If not in our dictionary, assume it's outside the defined level or default ground
		# Returning -1 indicates "no tile" or "outside bounds"
		return -1 # Or return TileType.REGULAR_GROUND if you prefer

# Function to check if a tile is of a specific type
func is_tile_type(grid_position: Vector3i, type: int) -> bool:
	return get_tile_type(grid_position) == type

# --- REVISED: Check if position is within the calculated actual bounds ---
func is_within_bounds(grid_position: Vector3i) -> bool:
	if _level_bounds.size.x == 0 or _level_bounds.size.y == 0: # Check if bounds are valid
		return false # No valid bounds calculated
	return _level_bounds.has_point(Vector2i(grid_position.x, grid_position.z))

# Function to get grid position from world position (Unchanged, seems okay)
func world_to_grid(world_position: Vector3) -> Vector3i:
	var grid_x = int(floor(world_position.x))
	var grid_z = int(floor(world_position.z))
	return Vector3i(grid_x, 0, grid_z)

# Function to get world position from grid position (Unchanged, seems okay)
func grid_to_world(grid_position: Vector3i) -> Vector3:
	return grid_map.map_to_local(grid_position) + Vector3(0.5, 0, 0.5) # Add offset for center

# Set a tile to a specific type
func set_tile_type(grid_position: Vector3i, type: int) -> bool:
	# Allow setting tiles even outside initial bounds (e.g., editor)
	# Bounds will recalculate if needed elsewhere or upon load.

	var old_type = get_tile_type(grid_position) # Get type before changing

	var mesh_id = -1 # Default to invalid/clear

	match type:
		TileType.REGULAR_GROUND: mesh_id = REGULAR_GROUND_MESH_ID
		TileType.DIRT_GROUND: mesh_id = DIRT_GROUND_MESH_ID
		TileType.DIRT_FERTILE: mesh_id = DIRT_FERTILE_MESH_ID
		TileType.DIRT_PRESERVED: mesh_id = DIRT_PRESERVED_MESH_ID
		TileType.DIRT_PERSISTENT: mesh_id = DIRT_PERSISTENT_MESH_ID
		TileType.SOIL: mesh_id = SOIL_MESH_ID
		TileType.WATER: mesh_id = WATER_MESH_ID
		TileType.MUD: mesh_id = MUD_MESH_ID
		TileType.DELIVERY: mesh_id = DELIVERY_MESH_ID
		TileType.DELIVERY_EXPRESS: mesh_id = DELIVERY_EXPRESS_MESH_ID
		TileType.SPRINKLER: mesh_id = SPRINKLER_MESH_ID
		_:
			print("Warning: set_tile_type called with invalid type: ", type)
			# Decide whether to clear the tile or do nothing
			grid_map.set_cell_item(grid_position, -1) # Clear visual tile
			if tile_states.has(grid_position):
				tile_states.erase(grid_position)
			emit_signal("tile_changed", grid_position, old_type, -1)
			return false

	grid_map.set_cell_item(grid_position, mesh_id)
	tile_states[grid_position] = type

	# Check if setting this tile changes the bounds (relevant if called during gameplay/editing)
	# You might want a separate function `_update_bounds_if_needed(grid_position)`
	# For simplicity, we'll rely on recalculating bounds on load/init for now.

	emit_signal("tile_changed", grid_position, old_type, type)
	return true

# Reset a soil tile back to dirt
func reset_soil_to_dirt(grid_position: Vector3i) -> bool:
	var current_type = get_tile_type(grid_position)
	var key = str(grid_position.x) + "," + str(grid_position.z)
	var original_dirt_type = TileType.DIRT_GROUND

	if soil_properties.has(key):
		original_dirt_type = soil_properties[key].source_type
		if original_dirt_type == TileType.DIRT_PERSISTENT:
			return true # Persistent soil stays as soil
		soil_properties.erase(key)

	if current_type == TileType.SOIL:
		return set_tile_type(grid_position, original_dirt_type)

	return false

# Get neighboring tiles of a specific type (Unchanged, relies on is_within_bounds)
func get_neighbors_of_type(grid_position: Vector3i, type: int) -> Array:
	var neighbors = []
	var neighbor_offsets = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
		Vector3i(1, 0, 1), Vector3i(-1, 0, 1), Vector3i(1, 0, -1), Vector3i(-1, 0, -1)
	]
	for offset in neighbor_offsets:
		var neighbor_pos = grid_position + offset
		if is_within_bounds(neighbor_pos) and is_tile_type(neighbor_pos, type):
			neighbors.append(neighbor_pos)
	return neighbors

# Get all tiles of a specific type in the level (Unchanged, iterates dictionary)
func get_all_tiles_of_type(type: int) -> Array:
	var tiles = []
	for pos in tile_states.keys():
		if tile_states[pos] == type:
			tiles.append(pos)
	return tiles

# --- REVISED: Check water source in range using actual bounds ---
func has_water_source_in_range(grid_position: Vector3i, range_tiles: int = 2) -> bool:
	if _level_bounds.size.x == 0 or _level_bounds.size.y == 0: return false # No bounds

	var min_check_x = max(_level_bounds.position.x, grid_position.x - range_tiles)
	var max_check_x = min(_level_bounds.end.x - 1, grid_position.x + range_tiles) # Use end.x - 1 for inclusive max
	var min_check_z = max(_level_bounds.position.y, grid_position.z - range_tiles)
	var max_check_z = min(_level_bounds.end.y - 1, grid_position.z + range_tiles) # Use end.y - 1 for inclusive max

	for x in range(min_check_x, max_check_x + 1): # +1 to include max_check_x
		for z in range(min_check_z, max_check_z + 1): # +1 to include max_check_z
			var check_pos = Vector3i(x, 0, z)
			# Check the tile_states dictionary directly for efficiency
			if tile_states.has(check_pos) and tile_states[check_pos] == TileType.WATER:
				return true
	return false

# Get the nearest tile of a specific type (Unchanged, iterates dictionary)
func get_nearest_tile_of_type(world_position: Vector3, type: int) -> Vector3i:
	var grid_pos = world_to_grid(world_position)
	var tiles_of_type = get_all_tiles_of_type(type)
	var nearest_tile = Vector3i(-1,-1,-1) # Default invalid position
	var nearest_distance_sq = INF

	for tile_pos in tiles_of_type:
		var distance_sq = grid_pos.distance_squared_to(tile_pos)
		if distance_sq < nearest_distance_sq:
			nearest_distance_sq = distance_sq
			nearest_tile = tile_pos
	return nearest_tile

# Print all tile states for debugging (Unchanged, iterates dictionary)
func print_all_tile_states():
	print("===== ALL TILE STATES =====")
	print("Total tiles tracked: ", tile_states.size())
	# (Counting logic remains the same)
	var type_counts = {}
	for type_enum_val in TileType.values():
		type_counts[type_enum_val] = 0

	for pos in tile_states.keys():
		var type = tile_states[pos]
		if type_counts.has(type):
			type_counts[type] += 1
		else:
			type_counts[type] = 1 # Count unknown types too

	for type in type_counts.keys():
		var type_name = TileType.keys()[type] if type >= 0 and type < TileType.keys().size() else "UNKNOWN("+str(type)+")"
		if type_counts[type] > 0: # Only print types that exist
			print("Type ", type_name, " (", type, "): ", type_counts[type], " tiles")
	print("==========================")

# --- REVISED: Debug function to print the current state using actual bounds ---
func print_level_state():
	print("Level State (Bounds: %s):" % str(_level_bounds))
	if _level_bounds.size.x == 0 or _level_bounds.size.y == 0:
		print("(No tiles loaded or bounds not calculated)")
		return

	# Iterate using calculated actual bounds
	for z in range(_level_bounds.position.y, _level_bounds.end.y):
		var row_string = ""
		for x in range(_level_bounds.position.x, _level_bounds.end.x):
			var pos = Vector3i(x, 0, z)
			var type = get_tile_type(pos) # Uses the revised function

			match type:
				TileType.REGULAR_GROUND: row_string += "R "
				TileType.DIRT_GROUND: row_string += "D "
				TileType.DIRT_FERTILE: row_string += "F " # Added Fertile
				TileType.DIRT_PRESERVED: row_string += "P " # Added Preserved
				TileType.DIRT_PERSISTENT: row_string += "E " # Added pErsistent
				TileType.SOIL: row_string += "S "
				TileType.WATER: row_string += "W "
				TileType.MUD: row_string += "M "
				TileType.DELIVERY: row_string += "X "
				TileType.DELIVERY_EXPRESS: row_string += "X+" # Added Express
				TileType.SPRINKLER: row_string += "~ " # Added Sprinkler
				-1: row_string += ". " # Use '.' for empty/outside bounds
				_: row_string += "? " # Unknown type
		print(row_string)

# --- REVISED: Reset all soil tiles using actual bounds ---
func reset_all_soil_tiles():
	if _level_bounds.size.x == 0 or _level_bounds.size.y == 0: return # No bounds

	var soil_count = 0
	# Iterate using calculated actual bounds
	for x in range(_level_bounds.position.x, _level_bounds.end.x):
		for z in range(_level_bounds.position.y, _level_bounds.end.y):
			var pos = Vector3i(x, 0, z)
			# Check dictionary directly for efficiency
			if tile_states.has(pos) and tile_states[pos] == TileType.SOIL:
				# Use reset_soil_to_dirt which handles persistent soil etc.
				if reset_soil_to_dirt(pos):
					soil_count += 1

	print("LevelManager: Reset " + str(soil_count) + " soil tiles to their original dirt type")

# --- Utility function to get bounds (e.g., for GameDataManager) ---
func get_actual_bounds() -> Rect2i:
	return _level_bounds

# Activate all sprinklers in the level (Unchanged, uses get_all_tiles_of_type)
func activate_sprinklers():
	var sprinkler_tiles = get_all_tiles_of_type(TileType.SPRINKLER)
	if sprinkler_tiles.size() > 0:
		print("Activating " + str(sprinkler_tiles.size()) + " sprinklers")
		for pos in sprinkler_tiles:
			water_adjacent_tiles(pos)

# Water tiles adjacent to a position (Unchanged)
func water_adjacent_tiles(center_pos: Vector3i):
	var directions = [
		Vector3i(0, 0, -1), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0),
		Vector3i(-1, 0, -1), Vector3i(1, 0, 1), Vector3i(1, 0, -1), Vector3i(-1, 0, 1)
	]
	for dir in directions:
		var adjacent_pos = center_pos + dir
		if is_tile_type(adjacent_pos, TileType.SOIL):
			water_plants_at_position(adjacent_pos)

# Water any plants at a specific position (Unchanged)
func water_plants_at_position(grid_pos: Vector3i):
	for obj in get_tree().get_nodes_in_group("plants"):
		if obj is Plant and obj.current_stage == Plant.GrowthStage.SEED and not obj.is_watered:
			var plant_grid_pos = world_to_grid(obj.global_position)
			# Consider direct grid pos comparison as fallback
			var obj_direct_grid = Vector3i(int(floor(obj.global_position.x)), 0, int(floor(obj.global_position.z)))
			if plant_grid_pos == grid_pos or obj_direct_grid == grid_pos:
				if obj.water():
					print("Sprinkler watered plant at " + str(grid_pos))
				# Potentially break if only one plant per tile allowed
				break

# Reset the level for a new run (Unchanged)
func reset_level():
	remove_all_plants()
	reset_all_soil_tiles()
	print("LevelManager: Level reset complete")

# Remove all plants from the level (Unchanged)
func remove_all_plants():
	var plants = get_tree().get_nodes_in_group("plants")
	for plant in plants:
		plant.queue_free()
	print("LevelManager: Removed " + str(plants.size()) + " plants")

# --- Deprecated/Removed ---
# var level_width: int = 12 # Replaced by _level_bounds
# var level_height: int = 8 # Replaced by _level_bounds
# func get_tile_type_direct(grid_position: Vector3i) -> int: # Integrated into get_tile_type logic
