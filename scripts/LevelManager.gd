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

func _ready():
	# Get reference to the GridMap
	grid_map = $GridMap
	
	# Initialize our level
	initialize_level()

# Set up initial level layout
func initialize_level():
	# Clear any existing tiles
	grid_map.clear()
	
	# Create a simple level layout
	# First, fill the entire level with regular ground
	for x in range(level_width):
		for z in range(level_height):
			grid_map.set_cell_item(Vector3i(x, 0, z), REGULAR_GROUND_MESH_ID)
			
			# Track the state of each tile
			tile_states[Vector3i(x, 0, z)] = TileType.REGULAR_GROUND
	
	# Add some dirt tiles for farming
	for x in range(2, 6):
		for z in range(2, 6):
			grid_map.set_cell_item(Vector3i(x, 0, z), DIRT_GROUND_MESH_ID)
			tile_states[Vector3i(x, 0, z)] = TileType.DIRT_GROUND
	
	# Add water tiles on the right side
	for z in range(3, 5):
		grid_map.set_cell_item(Vector3i(8, 0, z), WATER_MESH_ID)
		tile_states[Vector3i(8, 0, z)] = TileType.WATER
	
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
	if tile_states.has(grid_position) and tile_states[grid_position] == TileType.DIRT_GROUND:
		var old_type = tile_states[grid_position]
		grid_map.set_cell_item(grid_position, SOIL_MESH_ID)
		tile_states[grid_position] = TileType.SOIL
		
		# Emit signal that tile has changed
		emit_signal("tile_changed", grid_position, old_type, TileType.SOIL)
		return true
	return false

# Function to get the type of tile at a given position
func get_tile_type(grid_position: Vector3i) -> int:
	if tile_states.has(grid_position):
		return tile_states[grid_position]
	# Default to regular ground if position is not in our dictionary
	return TileType.REGULAR_GROUND

# Function to check if a tile is of a specific type
func is_tile_type(grid_position: Vector3i, type: int) -> bool:
	if tile_states.has(grid_position):
		return tile_states[grid_position] == type
	return false

# Function to check if a position is within the bounds of our level
func is_within_bounds(grid_position: Vector3i) -> bool:
	return grid_position.x >= 0 and grid_position.x < level_width and \
		   grid_position.z >= 0 and grid_position.z < level_height

# Function to get grid position from world position
func world_to_grid(world_position: Vector3) -> Vector3i:
	# GridMap has built-in methods for this
	return grid_map.local_to_map(world_position)

# Function to get world position from grid position
func grid_to_world(grid_position: Vector3i) -> Vector3:
	# GridMap has built-in methods for this
	return grid_map.map_to_local(grid_position)

# Set a tile to a specific type
func set_tile_type(grid_position: Vector3i, type: int) -> bool:
	if !is_within_bounds(grid_position):
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
	
	# Emit signal that tile has changed
	emit_signal("tile_changed", grid_position, old_type, type)
	return true

# Reset a soil tile back to dirt (e.g., after harvesting or when a plant withers)
func reset_soil_to_dirt(grid_position: Vector3i) -> bool:
	if is_tile_type(grid_position, TileType.SOIL):
		return set_tile_type(grid_position, TileType.DIRT_GROUND)
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
		
		print(row_string)
