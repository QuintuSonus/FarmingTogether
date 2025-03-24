# scripts/managers/FarmLayoutManager.gd
class_name FarmLayoutManager
extends Node

var level_manager = null
var farm_data: FarmData = null

func _ready():
	# Load or create farm data
	farm_data = FarmData.load_data()

func set_level_manager(manager):
	level_manager = manager

# Get the current farm data
func get_farm_data() -> FarmData:
	return farm_data

# Save the initial farm layout from the scene
func save_initial_farm_layout():
	if not level_manager:
		push_error("FarmLayoutManager: Cannot save initial farm layout - level manager not found")
		return
		
	# Only save initial layout if it hasn't been saved before
	if farm_data.initial_farm_layout.size() == 0:
		print("FarmLayoutManager: Saving initial farm layout from Main.tscn")
		farm_data.save_initial_farm_layout(level_manager)
	else:
		print("FarmLayoutManager: Initial farm layout already saved (" + 
			  str(farm_data.initial_farm_layout.size()) + " tiles)")

# Apply saved farm layout from farm data
func apply_saved_farm_layout():
	# Check requirements
	if not level_manager:
		push_error("FarmLayoutManager: Cannot apply saved layout - level manager not found")
		return
	
	# Get development mode flag
	var dev_mode = false
	var game_manager = get_parent()
	if game_manager:
	# Check if the property exists on the game manager
		if "always_reset_on_startup" in game_manager:
			dev_mode = game_manager.always_reset_on_startup and OS.is_debug_build()
	
	# In development mode, just use the scene as-is
	if dev_mode:
		print("FarmLayoutManager: Development mode - Using scene's layout directly (no changes)")
		return
	
	# Apply all saved tiles
	for key in farm_data.tile_data.keys():
		var coords = key.split(",")
		var x = int(coords[0])
		var z = int(coords[1])
		var type = farm_data.tile_data[key]
		
		var pos = Vector3i(x, 0, z)
		level_manager.set_tile_type(pos, type)
	
	print("FarmLayoutManager: Applied saved farm layout with " + str(farm_data.tile_data.size()) + " custom tiles")

# Apply default farm layout (for fresh start)
func apply_default_farm_layout():
	if not level_manager:
		push_error("FarmLayoutManager: Cannot apply default layout - level manager not found")
		return
		
	print("FarmLayoutManager: Applying default farm layout")
	
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
	
	print("FarmLayoutManager: Default farm layout applied")
