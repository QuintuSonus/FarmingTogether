# LevelManager.gd
extends Node3D

# Constants for tile types based on our GDD
enum TileType {
	REGULAR_GROUND,
	DIRT_GROUND,
	SOIL,
	WATER,
	MUD,
	DELIVERY
}

# Reference to the GridMap node
var grid_map: GridMap

# Level dimensions
var level_width: int = 12
var level_height: int = 8

# Dictionary to track tile states
var tile_states = {}

# Tile mesh IDs in the GridMap's MeshLibrary
const REGULAR_GROUND_MESH_ID = 0
const DIRT_GROUND_MESH_ID = 1
const SOIL_MESH_ID = 2
const WATER_MESH_ID = 3
const MUD_MESH_ID = 4
const DELIVERY_MESH_ID = 5

# Signal for when a tile changes state
signal tile_changed(position, old_type, new_type)

# Flag to force runtime generation (optional)
@export var force_runtime_generation: bool = false

func _ready():
	# Get reference to the GridMap
	grid_map = $GridMap
	
	# Check if there are already tiles placed in the editor
	var existing_tiles = grid_map.get_used_cells()
	
	if force_runtime_generation or existing_tiles.size() == 0:
		# No tiles placed in editor or forced generation - initialize with runtime generation
		print("No editor-placed tiles found or generation forced. Creating default level layout...")
		initialize_level()
	else:
		# Tiles already placed in editor - load them
		print("Editor-placed tiles found. Loading level from editor...")
		load_tile_states_from_editor()
	
	# Print debug info about tile states
	print_all_tile_states()
	print_level_state()

# Load tile states from tiles placed in the editor
func load_tile_states_from_editor():
	tile_states.clear()  # Clear any existing states
	
	# Get all cells that have been placed in the editor
	var placed_cells = grid_map.get_used_cells()
	print("Found " + str(placed_cells.size()) + " cells placed in the editor")
	
	# First, fill the level bounds with regular ground as a fallback
	for x in range(level_width):
		for z in range(level_height):
			var pos = Vector3i(x, 0, z)
			if not tile_states.has(pos):
				tile_states[pos] = TileType.REGULAR_GROUND
	
	# Now process all placed cells
	for cell_pos in placed_cells:
		var item = grid_map.get_cell_item(cell_pos)
		var tile_type = get_tile_type_from_mesh_id(item)
		
		# Store the tile type in our state dictionary
		tile_states[cell_pos] = tile_type
		
		# Check if cell is within our defined level bounds
		if cell_pos.x >= level_width or cell_pos.z >= level_height:
			print("Warning: Tile at ", cell_pos, " is outside defined level bounds!")
			
			# Update level dimensions if needed
			level_width = max(level_width, cell_pos.x + 1)
			level_height = max(level_height, cell_pos.z + 1)
			print("Level dimensions adjusted to ", level_width, "x", level_height)
	
	print("Level loaded from editor with " + str(tile_states.size()) + " tiles")

# Helper function to convert mesh IDs to tile types
func get_tile_type_from_mesh_id(mesh_id: int) -> int:
	match mesh_id:
		REGULAR_GROUND_MESH_ID: return TileType.REGULAR_GROUND
		DIRT_GROUND_MESH_ID: return TileType.DIRT_GROUND
		SOIL_MESH_ID: return TileType.SOIL
		WATER_MESH_ID: return TileType.WATER
		MUD_MESH_ID: return TileType.MUD
		DELIVERY_MESH_ID: return TileType.DELIVERY
		_: 
			print("Warning: Unknown mesh ID: ", mesh_id)
			return TileType.REGULAR_GROUND

# Set up initial level layout (only used if no editor tiles exist or forced)
func initialize_level():
	# Clear any existing tiles
	grid_map.clear()
	tile_states.clear()  # Make sure to clear the states too
	
	print("Initializing level with dimensions: ", level_width, "x", level_height)
	
	# Create a simple level layout
	# First, fill the entire level with regular ground
	for x in range(level_width):
		for z in range(level_height):
			var pos = Vector3i(x, 0, z)
			grid_map.set_cell_item(pos, REGULAR_GROUND_MESH_ID)
			tile_states[pos] = TileType.REGULAR_GROUND
	
	# Add some dirt tiles for farming
	for x in range(2, 6):
		for z in range(2, 6):
			var pos = Vector3i(x, 0, z)
			grid_map.set_cell_item(pos, DIRT_GROUND_MESH_ID)
			tile_states[pos] = TileType.DIRT_GROUND
	
	# Add water tiles on the right side
	for z in range(3, 5):
		var pos = Vector3i(8, 0, z)
		grid_map.set_cell_item(pos, WATER_MESH_ID)
		tile_states[pos] = TileType.WATER
	
	# Add a few mud tiles as obstacles
	grid_map.set_cell_item(Vector3i(6, 0, 1), MUD_MESH_ID)
	grid_map.set_cell_item(Vector3i(7, 0, 1), MUD_MESH_ID)
	tile_states[Vector3i(6, 0, 1)] = TileType.MUD
	tile_states[Vector3i(7, 0, 1)] = TileType.MUD
	
	# Add delivery tile
	grid_map.set_cell_item(Vector3i(10, 0, 4), DELIVERY_MESH_ID)
	tile_states[Vector3i(10, 0, 4)] = TileType.DELIVERY
	
	print("Level initialized with %d tiles" % tile_states.size())

# Function to change a dirt tile to soil (will be called when using hoe)
func convert_to_soil(grid_position: Vector3i) -> bool:
	print("convert_to_soil called for position: ", grid_position)
	print("Current tile type: ", get_tile_type(grid_position))
	print("Is dirt? ", is_tile_type(grid_position, TileType.DIRT_GROUND))
	
	if tile_states.has(grid_position) and tile_states[grid_position] == TileType.DIRT_GROUND:
		var old_type = tile_states[grid_position]
		grid_map.set_cell_item(grid_position, SOIL_MESH_ID)
		tile_states[grid_position] = TileType.SOIL
		
		# Emit signal that tile has changed
		emit_signal("tile_changed", grid_position, old_type, TileType.SOIL)
		print("Successfully converted to soil!")
		return true
	
	print("Failed to convert to soil.")
	return false

# Function to get the type of tile at a given position
func get_tile_type(grid_position: Vector3i) -> int:
	if tile_states.has(grid_position):
		return tile_states[grid_position]
	else:
		# Fallback to direct check from grid_map
		var direct_type = get_tile_type_direct(grid_position)
		
		# Update tile_states dictionary to match reality
		if direct_type >= 0:
			tile_states[grid_position] = direct_type
			
		return direct_type

# Function to check if a tile is of a specific type
func is_tile_type(grid_position: Vector3i, type: int) -> bool:
	return get_tile_type(grid_position) == type

# Function to check if a position is within the bounds of our level
func is_within_bounds(grid_position: Vector3i) -> bool:
	# Calculate absolute bounds - adjust these values as needed for your level
	var min_x = -50  # Minimum X coordinate
	var min_z = -50  # Minimum Z coordinate
	var max_x = level_width + 50  # Maximum X coordinate
	var max_z = level_height + 50  # Maximum Z coordinate
	
	# Check if position is within the expanded bounds
	return grid_position.x >= min_x and grid_position.x < max_x and \
		   grid_position.z >= min_z and grid_position.z < max_z

# Function to get grid position from world position
# Optional: Improve the world_to_grid function for better negative coordinate handling
func world_to_grid(world_position: Vector3) -> Vector3i:
	# Use consistent grid mapping based on actual tile size
	# For negative coordinates, we need to handle the floor() behavior correctly
	var grid_x = int(floor(world_position.x))
	var grid_z = int(floor(world_position.z))
	
	
	return Vector3i(grid_x, 0, grid_z)

# Function to get world position from grid position
func grid_to_world(grid_position: Vector3i) -> Vector3:
	# Use GridMap's mapping but add more precise centering for visual elements
	var world_pos = grid_map.map_to_local(grid_position)
	
	
	return world_pos

# Set a tile to a specific type
func set_tile_type(grid_position: Vector3i, type: int) -> bool:
	print("set_tile_type called for position: ", grid_position, " type: ", type)
	
	if !is_within_bounds(grid_position):
		print("Position out of bounds")
		return false
		
	var old_type = get_tile_type(grid_position)
	
	# Update the GridMap with the appropriate mesh ID
	var mesh_id = REGULAR_GROUND_MESH_ID  # Default
	
	match type:
		TileType.REGULAR_GROUND:
			mesh_id = REGULAR_GROUND_MESH_ID
		TileType.DIRT_GROUND:
			mesh_id = DIRT_GROUND_MESH_ID
		TileType.SOIL:
			mesh_id = SOIL_MESH_ID
		TileType.WATER:
			mesh_id = WATER_MESH_ID
		TileType.MUD:
			mesh_id = MUD_MESH_ID
		TileType.DELIVERY:
			mesh_id = DELIVERY_MESH_ID
	
	grid_map.set_cell_item(grid_position, mesh_id)
	tile_states[grid_position] = type
	
	print("Tile type set successfully. Old: ", old_type, " New: ", type)
	
	# Emit signal that tile has changed
	emit_signal("tile_changed", grid_position, old_type, type)
	return true

# Reset a soil tile back to dirt (e.g., after harvesting or when a plant withers)
func reset_soil_to_dirt(grid_position: Vector3i) -> bool:
	print("reset_soil_to_dirt called for position: ", grid_position)
	
	if is_tile_type(grid_position, TileType.SOIL):
		return set_tile_type(grid_position, TileType.DIRT_GROUND)
	
	print("Tile is not soil, cannot reset")
	return false

# Get neighboring tiles of a specific type
func get_neighbors_of_type(grid_position: Vector3i, type: int) -> Array:
	var neighbors = []
	
	# Check all 8 neighbors (4 adjacent + 4 diagonals)
	var neighbor_offsets = [
		Vector3i(1, 0, 0),   # Right
		Vector3i(-1, 0, 0),  # Left
		Vector3i(0, 0, 1),   # Front
		Vector3i(0, 0, -1),  # Back
		Vector3i(1, 0, 1),   # Front-Right
		Vector3i(-1, 0, 1),  # Front-Left
		Vector3i(1, 0, -1),  # Back-Right
		Vector3i(-1, 0, -1)  # Back-Left
	]
	
	for offset in neighbor_offsets:
		var neighbor_pos = grid_position + offset
		if is_within_bounds(neighbor_pos) and is_tile_type(neighbor_pos, type):
			neighbors.append(neighbor_pos)
	
	return neighbors

# Get all tiles of a specific type in the level
func get_all_tiles_of_type(type: int) -> Array:
	var tiles = []
	
	for pos in tile_states.keys():
		if tile_states[pos] == type:
			tiles.append(pos)
	
	return tiles

# Check if there is a water source within a certain range
func has_water_source_in_range(grid_position: Vector3i, range_tiles: int = 2) -> bool:
	for x in range(max(0, grid_position.x - range_tiles), min(level_width, grid_position.x + range_tiles + 1)):
		for z in range(max(0, grid_position.z - range_tiles), min(level_height, grid_position.z + range_tiles + 1)):
			var check_pos = Vector3i(x, 0, z)
			if is_tile_type(check_pos, TileType.WATER):
				return true
	
	return false

# Get the nearest tile of a specific type
func get_nearest_tile_of_type(world_position: Vector3, type: int) -> Vector3i:
	var grid_pos = world_to_grid(world_position)
	var tiles_of_type = get_all_tiles_of_type(type)
	
	var nearest_tile = null
	var nearest_distance = INF
	
	for tile_pos in tiles_of_type:
		var distance = grid_pos.distance_to(tile_pos)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_tile = tile_pos
	
	return nearest_tile if nearest_tile else Vector3i(-1, -1, -1)  # Return invalid position if none found

# Print all tile states for debugging
func print_all_tile_states():
	print("===== ALL TILE STATES =====")
	print("Total tiles tracked: ", tile_states.size())
	var type_counts = {
		TileType.REGULAR_GROUND: 0,
		TileType.DIRT_GROUND: 0,
		TileType.SOIL: 0,
		TileType.WATER: 0,
		TileType.MUD: 0,
		TileType.DELIVERY: 0
	}
	
	for pos in tile_states.keys():
		var type = tile_states[pos]
		if type_counts.has(type):
			type_counts[type] += 1
	
	for type in type_counts.keys():
		var type_name = TileType.keys()[type]
		print("Type ", type_name, " (", type, "): ", type_counts[type], " tiles")
	print("==========================")

# Debug function to print the current state of the level
func print_level_state():
	print("Level State:")
	for z in range(level_height):
		var row_string = ""
		for x in range(level_width):
			var pos = Vector3i(x, 0, z)
			var type = get_tile_type(pos)
			
			# Use a character to represent each tile type
			match type:
				TileType.REGULAR_GROUND:
					row_string += "R "
				TileType.DIRT_GROUND:
					row_string += "D "
				TileType.SOIL:
					row_string += "S "
				TileType.WATER:
					row_string += "W "
				TileType.MUD:
					row_string += "M "
				TileType.DELIVERY:
					row_string += "X "
				_:
					row_string += "? "
		
		print(row_string)
		
# Get tile type directly using the grid_map item
func get_tile_type_direct(grid_position: Vector3i) -> int:
	var item = grid_map.get_cell_item(grid_position)
	
	match item:
		REGULAR_GROUND_MESH_ID: return TileType.REGULAR_GROUND
		DIRT_GROUND_MESH_ID: return TileType.DIRT_GROUND
		SOIL_MESH_ID: return TileType.SOIL
		WATER_MESH_ID: return TileType.WATER
		MUD_MESH_ID: return TileType.MUD
		DELIVERY_MESH_ID: return TileType.DELIVERY
		-1: return -1  # No tile at this position
		_: return TileType.REGULAR_GROUND  # Default
		
# Add these methods to your existing LevelManager.gd script

# Reset the level for a new run
func reset_level():
	# Clear any existing plants
	remove_all_plants()
	
	# Reset all soil tiles back to dirt
	reset_all_soil_tiles()
	
	# Apply saved farm layout (now handled by Main.apply_saved_farm_layout)
	print("LevelManager: Level reset complete")

# Remove all plants from the level
func remove_all_plants():
	# Find and remove all plants
	var plants = get_tree().get_nodes_in_group("plants")
	for plant in plants:
		plant.queue_free()
	
	print("LevelManager: Removed " + str(plants.size()) + " plants")

# Reset all soil tiles back to dirt
func reset_all_soil_tiles():
	# Find all soil tiles and convert them back to dirt
	var soil_count = 0
	
	for x in range(level_width):
		for z in range(level_height):
			var pos = Vector3i(x, 0, z)
			if is_tile_type(pos, TileType.SOIL):
				set_tile_type(pos, TileType.DIRT_GROUND)
				soil_count += 1
	
	print("LevelManager: Reset " + str(soil_count) + " soil tiles to dirt")
