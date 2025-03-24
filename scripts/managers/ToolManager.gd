# scripts/managers/ToolManager.gd
class_name ToolManager
extends Node

var level_manager = null
var game_data_manager = null

# Reference to tool scenes
var tool_scenes = {
	"hoe": "res://scenes/tools/Hoe.tscn",
	"watering_can": "res://scenes/tools/WateringCan.tscn",
	"basket": "res://scenes/tools/Basket.tscn",
	"carrot_seeds": "res://scenes/tools/CarrotSeedDispenser.tscn",
	"tomato_seeds": "res://scenes/tools/TomatoSeedDispenser.tscn"
}

func _ready():
	# Get farm data
	game_data_manager = get_parent().get_node_or_null("GameDataManager")
	if not game_data_manager:
		push_error("ToolManager: GameDataManager not found")

func set_level_manager(manager):
	level_manager = manager

# Spawn default tools at strategic positions
func spawn_default_tools():
	# Clear any existing tools
	remove_player_tools()
	
	# Spawn default tools at strategic positions
	spawn_tool(Vector3i(4, 0, 4), "hoe")
	spawn_tool(Vector3i(5, 0, 4), "basket") 
	spawn_tool(Vector3i(6, 0, 4), "watering_can")
	
	# Add seed dispensers too
	spawn_tool(Vector3i(-2, 0, 2), "carrot_seeds")
	spawn_tool(Vector3i(-2, 0, 4), "tomato_seeds")
	
	print("ToolManager: Spawned default tools")

# Spawn all tools saved in farm data
func spawn_saved_tools():
	# Clear any existing player-placed tools first
	remove_player_tools()
	
	# Get all placed tools from farm data
	if game_data_manager == null:
		# Try to get game data manager from service locator
		var service_locator = get_node_or_null("/root/ServiceLocator")
		if service_locator and service_locator.has_service("game_data_manager"):
			game_data_manager = service_locator.get_service("game_data_manager")
		else:
			push_error("ToolManager: GameDataManager not found")
			return
	
	var tool_placement = game_data_manager.get_all_placed_tools()
	
	# Spawn each tool
	for key in tool_placement:
		var coords = key.split(",")
		var x = int(coords[0])
		var z = int(coords[1])
		var tool_type = tool_placement[key]
		
		# Spawn the tool
		spawn_tool(Vector3i(x, 0, z), tool_type)
	
	print("ToolManager: Spawned " + str(tool_placement.size()) + " saved tools")

# Remove all player-placed tools
func remove_player_tools():
	var player_tools = get_tree().get_nodes_in_group("player_tools")
	for tool_node in player_tools:
		tool_node.queue_free()
	
	print("ToolManager: Removed " + str(player_tools.size()) + " player tools")

# Spawn a tool in the world
func spawn_tool(grid_pos: Vector3i, tool_type: String):
	# Get the scene path for this tool type
	if not tool_scenes.has(tool_type):
		push_error("ToolManager: No scene path for tool type: " + tool_type)
		return
	
	var scene_path = tool_scenes[tool_type]
	var tool_scene = load(scene_path)
	
	if not tool_scene:
		push_error("ToolManager: Failed to load tool scene: " + scene_path)
		return
	
	# Create the tool instance
	var tool_instance = tool_scene.instantiate()
	
	# Give it a unique name based on position
	var tool_key = "player_tool_" + str(grid_pos.x) + "_" + str(grid_pos.z)
	tool_instance.name = tool_key
	
	# Add to the scene
	get_parent().add_child(tool_instance)
	
	# Position the tool at the grid position
	var world_pos = Vector3(grid_pos.x + 0.5, 0.75, grid_pos.z + 0.5)  # Center on tile and elevate
	tool_instance.global_position = world_pos
	
	# Add to group for easy cleanup
	tool_instance.add_to_group("player_tools")
	
	print("ToolManager: Spawned " + tool_type + " at " + str(world_pos))
