# scripts/managers/SprinklerManager.gd
class_name SprinklerManager
extends Node

# References
var level_manager = null
var game_data = null
var sprinkler_scene = preload("res://scenes/upgrades/Sprinkler.tscn")

# Tracking installed sprinklers
var active_sprinklers = {}  # Dictionary of "x,z" -> sprinkler node

func _ready():
	# Find level manager
	level_manager = get_node_or_null("/root/Main/LevelManager")
	if not level_manager:
		level_manager = get_tree().get_root().find_child("LevelManager", true, false)
		
	# Get game data reference
	var service_locator = get_node_or_null("/root/ServiceLocator")
	if service_locator:
		game_data = service_locator.get_service("game_data")
	
	# Register with service locator
	if service_locator:
		service_locator.register_service("sprinkler_manager", self)
	
	print("SprinklerManager initialized")
	
	# Load existing sprinklers
	call_deferred("load_existing_sprinklers")

# Load sprinklers from saved tile upgrades
func load_existing_sprinklers():
	if not game_data or not game_data.upgrades_data or not level_manager:
		push_error("SprinklerManager: Cannot load existing sprinklers - missing data references")
		return
	
	print("SprinklerManager: Loading existing sprinklers")
	
	var count = 0
	
	# Go through all tile upgrades looking for sprinklers
	for pos_key in game_data.upgrades_data.tile_upgrades:
		var tile_upgrades = game_data.upgrades_data.tile_upgrades[pos_key]
		
		# Check if this tile has a sprinkler upgrade
		if tile_upgrades.has("sprinkler_system") and tile_upgrades["sprinkler_system"] > 0:
			# Get grid coordinates from key
			var coords = pos_key.split(",")
			if coords.size() >= 2:
				var grid_pos = Vector3i(int(coords[0]), 0, int(coords[1]))
				
				# Create sprinkler at this position
				create_sprinkler(grid_pos)
				count += 1
	
	print("SprinklerManager: Loaded ", count, " existing sprinklers")

# Create a new sprinkler at a grid position
func create_sprinkler(grid_pos: Vector3i) -> bool:
	if not level_manager or not sprinkler_scene:
		push_error("SprinklerManager: Cannot create sprinkler - missing references")
		return false
	
	# Check if a sprinkler already exists at this position
	var pos_key = str(grid_pos.x) + "," + str(grid_pos.z)
	if active_sprinklers.has(pos_key) and is_instance_valid(active_sprinklers[pos_key]):
		print("SprinklerManager: Sprinkler already exists at ", grid_pos)
		return false
	
	# Get world position
	var world_pos = level_manager.grid_to_world(grid_pos)
	world_pos.y = 0.25  # Set slightly above ground
	
	# Create the sprinkler
	var sprinkler = sprinkler_scene.instantiate()
	add_child(sprinkler)
	
	# Position it
	sprinkler.global_position = world_pos
	
	# Store reference
	active_sprinklers[pos_key] = sprinkler
	
	print("SprinklerManager: Created sprinkler at ", grid_pos)
	return true

# Remove a sprinkler at a specific position
func remove_sprinkler(grid_pos: Vector3i) -> bool:
	var pos_key = str(grid_pos.x) + "," + str(grid_pos.z)
	
	if active_sprinklers.has(pos_key):
		var sprinkler = active_sprinklers[pos_key]
		
		if is_instance_valid(sprinkler):
			sprinkler.queue_free()
			
		active_sprinklers.erase(pos_key)
		print("SprinklerManager: Removed sprinkler at ", grid_pos)
		return true
	
	return false

# Clear all active sprinklers (used when resetting level)
func clear_all_sprinklers():
	print("SprinklerManager: Clearing all sprinklers")
	
	for pos_key in active_sprinklers:
		var sprinkler = active_sprinklers[pos_key]
		if is_instance_valid(sprinkler):
			sprinkler.queue_free()
	
	active_sprinklers.clear()
