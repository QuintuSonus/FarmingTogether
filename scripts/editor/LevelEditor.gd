# scripts/editor/LevelEditor.gd
extends Node3D

# References
var level_manager: Node = null
var grid_map: GridMap = null
var game_data: GameData = null
var game_data_manager = null
var editor_ui: Control = null
var tile_highlighter: Node3D = null
var highlight_mesh: MeshInstance3D = null
var editor_camera: Camera3D = null

# Editor state
var selected_tile_type: String = "none"
var selected_tool_type: String = "none"
var is_editing: bool = false
var is_placing_tool: bool = false
var original_tile_states: Dictionary = {}
var farm_bounds: Rect2 = Rect2(-8, -8, 20, 20)  # Expanded bounds to include negative coordinates

# Tool scene references
var tool_scenes = {
	"hoe": "res://scenes/tools/Hoe.tscn",
	"watering_can": "res://scenes/tools/WateringCan.tscn",
	"basket": "res://scenes/tools/Basket.tscn",
}

# Game state management
var gameplay_nodes = []
var original_process_modes = {}
var main_camera = null

# Game UI references and state
var game_ui_elements = []
var game_ui_visibility_states = {}

# Signals
signal editor_closed
signal editor_saved
signal editor_canceled
signal purchase_made(type_name, cost)

# Conversion mapping between tile type name and TileType enum
var tile_type_mapping = {
	"regular": 0,        # REGULAR_GROUND
	"dirt": 1,           # DIRT_GROUND
	"dirt_fertile": 2,   # DIRT_FERTILE
	"dirt_preserved": 3, # DIRT_PRESERVED
	"dirt_persistent": 4,# DIRT_PERSISTENT
	"soil": 5,           # SOIL
	"water": 6,          # WATER
	"mud": 7,            # MUD
	"delivery": 8,       # DELIVERY
	"delivery_express": 10, # DELIVERY_EXPRESS
	"sprinkler": 11,      # SPRINKLER
	"carrot_dispenser": 12,
	"tomato_dispenser": 13
}

# Costs of different tile types
var tile_prices = {
	"regular": 0,
	"dirt": 100,
	"dirt_fertile": 150,
	"dirt_preserved": 200,
	"dirt_persistent": 250,
	"soil": 150,
	"water": 250,
	"mud": 150,
	"delivery": 300,
	"delivery_express": 400,
	"sprinkler": 500,
	"carrot_dispenser": 100,
	"tomato_dispenser": 150
}

# Costs of different tool types
var tool_prices = {
	"hoe": 150,
	"watering_can": 200,
	"basket": 250,
}

func _ready():
	# Get references to nodes
	editor_ui = $EditorUI
	editor_camera = $EditorCamera
	
	# Get references to child nodes in EditorUI
	if editor_ui:
		# Make sure UI is initially hidden
		editor_ui.visible = false
		
		tile_highlighter = editor_ui.find_child("TileHighlighter")
		if tile_highlighter:
			highlight_mesh = tile_highlighter.find_child("MeshInstance3D")
	
	# Level manager might not be available immediately (if created by Main)
	call_deferred("connect_nodes")
	
	# Set up highlight mesh
	setup_highlight_mesh()
	
	# Get game data
	var service_locator = get_node_or_null("/root/ServiceLocator")
	if service_locator:
		game_data = service_locator.get_service("game_data")
		game_data_manager = service_locator.get_service("game_data_manager")
		
		if game_data_manager and game_data_manager.has_signal("data_changed"):
			game_data_manager.connect("data_changed", Callable(self, "_on_game_data_changed"))
	# Initially hide editor (will be shown by Main when appropriate)
	hide()
	
	print("LevelEditor: Initialized with UI hidden")
	
	 # Initialize the upgrades list 


# Connect to all required nodes after they are available in the scene
func connect_nodes():
	# Find level manager
	level_manager = get_node_or_null("/root/Main/LevelManager")
	if not level_manager:
		level_manager = get_tree().get_root().find_child("LevelManager", true, false)
	
	if level_manager:
		print("LevelEditor: Found LevelManager")
		
		# Get GridMap reference
		if level_manager.has_node("GridMap"):
			grid_map = level_manager.get_node("GridMap")
			print("LevelEditor: Found GridMap")
	else:
		push_error("LevelEditor: Could not find LevelManager!")
	
	# Get game data references if not already set
	if not game_data:
		var service_locator = get_node_or_null("/root/ServiceLocator")
		if service_locator:
			game_data = service_locator.get_service("game_data")
			game_data_manager = service_locator.get_service("game_data_manager")
	
	# Find main camera
	main_camera = get_node_or_null("/root/Main/Camera3D")
	if not main_camera:
		for camera in get_tree().get_nodes_in_group("cameras"):
			if camera != editor_camera:
				main_camera = camera
				break
	
	if main_camera:
		print("LevelEditor: Found main camera: " + main_camera.name)

# Calculate farm bounds from existing tiles
func calculate_farm_bounds():
	if not level_manager:
		return
	
	# Start with a small area around the origin
	var min_x = 0
	var min_z = 0
	var max_x = 12
	var max_z = 8
	
	# Track if we found any tiles
	var found_tiles = false
	
	# Check for tiles in a larger area to find actual bounds
	for x in range(-20, 20):
		for z in range(-20, 20):
			var pos = Vector3i(x, 0, z)
			var tile_type = level_manager.get_tile_type(pos)
			
			# Only consider non-regular tiles for bounds calculation
			if tile_type != 0:  # Not REGULAR_GROUND
				min_x = min(min_x, x)
				min_z = min(min_z, z)
				max_x = max(max_x, x + 1)
				max_z = max(max_z, z + 1)
				found_tiles = true
	
	# Add padding around the bounds
	min_x -= 2
	min_z -= 2
	max_x += 2
	max_z += 2
	
	# Update farm_bounds
	farm_bounds = Rect2(min_x, min_z, max_x - min_x, max_z - min_z)
	
	print("LevelEditor: Calculated farm bounds: ", farm_bounds)

# Called when editor is activated
func start_editing():
	print("LevelEditor: start_editing called")
	
	# DIAGNOSTIC #1: Check references
	print("LevelEditor: DIAGNOSTIC - level_manager exists: " + str(level_manager != null))
	print("LevelEditor: DIAGNOSTIC - grid_map exists: " + str(grid_map != null))
	
	if not level_manager or not grid_map:
		push_error("LevelEditor: Cannot start editing - missing references!")
		return
		
	print("LevelEditor: References check passed")
	
	# DIAGNOSTIC #2: Check game data
	print("LevelEditor: DIAGNOSTIC - game_data exists: " + str(game_data != null))
	
	# Make sure we have game data
	if not game_data:
		print("LevelEditor: game_data is null, trying to get from ServiceLocator")
		var service_locator = get_node_or_null("/root/ServiceLocator")
		if service_locator:
			print("LevelEditor: ServiceLocator found")
			game_data = service_locator.get_service("game_data")
			game_data_manager = service_locator.get_service("game_data_manager")
			print("LevelEditor: After ServiceLocator - game_data exists: " + str(game_data != null))
		else:
			print("LevelEditor: ServiceLocator NOT found")
		
		if not game_data:
			push_error("LevelEditor: Cannot start editing - game data not found!")
			return
	
	print("LevelEditor: Game data check passed")
	
	# DIAGNOSTIC #3: Check for farm bounds calculation
	print("LevelEditor: About to calculate farm bounds")
	
	# Protect against errors in calculate_farm_bounds
	if not level_manager:
		print("LevelEditor: level_manager became null before calculate_farm_bounds")
		return
		
	# Calculate farm bounds to include all existing tiles
	calculate_farm_bounds()
	
	print("LevelEditor: Farm bounds calculated")
	
	# DIAGNOSTIC #4: Check UI components
	print("LevelEditor: DIAGNOSTIC - editor_ui exists: " + str(editor_ui != null))
	
	# Show editor and UI
	show()
	if editor_ui:
		editor_ui.visible = true
		print("LevelEditor: Made editor UI visible")
		if editor_ui.has_method("update_currency_display"):
			editor_ui.update_currency_display()
			print("LevelEditor: Updated currency display")
		else:
			print("LevelEditor: editor_ui does not have update_currency_display method")
	else:
		print("LevelEditor: editor_ui is null, cannot show UI")
		
	initialize_upgrades()
	# DIAGNOSTIC #5: Check game UI hiding
	print("LevelEditor: About to hide game UI")
	
	# Hide game UI
	hide_game_ui()
	
	print("LevelEditor: Game UI hidden")
	
	# DIAGNOSTIC #6: Check gameplay pausing
	print("LevelEditor: About to pause gameplay")
	
	# Pause gameplay
	pause_gameplay()
	
	print("LevelEditor: Gameplay paused")
	
	# DIAGNOSTIC #7: Check camera
	print("LevelEditor: DIAGNOSTIC - editor_camera exists: " + str(editor_camera != null))
	
	# Switch to editor camera
	if editor_camera:
		editor_camera.current = true
		print("LevelEditor: Switched to editor camera")
	else:
		print("LevelEditor: editor_camera is null, cannot switch camera")
	
	# Store original tile states
	save_original_state()
	
	print("LevelEditor: Original state saved")
	
	# Set editor as active
	is_editing = true
	
	# Spawn existing tools from game data
	spawn_saved_tools()
	initialize_tile_buttons()
	
	print("LevelEditor: Started editing mode with UI visible")

# Called when editor is deactivated
func stop_editing():
	# Hide editor and UI
	hide()
	if editor_ui:
		editor_ui.visible = false
	
	# Restore game UI
	restore_game_ui()
	
	# Resume gameplay
	resume_gameplay()
	
	# Reset to game camera
	if editor_camera:
		editor_camera.current = false
	if main_camera and main_camera.has_method("make_current"):
		main_camera.make_current()
	
	# Remove all editor-placed tools
	remove_editor_tools()
	
	# Set editor as inactive
	is_editing = false
	
	print("LevelEditor: Stopped editing mode and restored game UI")

# Find and store references to gameplay nodes
func find_gameplay_nodes():
	var main = get_node("/root/Main")
	
	# Clear previous references
	gameplay_nodes.clear()
	original_process_modes.clear()
	
	# Find main camera if not set already
	if not main_camera:
		main_camera = main.get_node_or_null("Camera3D")
		if not main_camera:
			# Try to find any camera that isn't the editor camera
			for camera in get_tree().get_nodes_in_group("cameras"):
				if camera != editor_camera:
					main_camera = camera
					break
	
	# Store references to key gameplay nodes
	var key_nodes = ["Player", "OrderManager", "PlayerManager"]
	for node_name in key_nodes:
		var node = main.get_node_or_null(node_name)
		if node:
			gameplay_nodes.append(node)
	
	# Add all plants
	var plants = get_tree().get_nodes_in_group("plants")
	gameplay_nodes.append_array(plants)
	
	# Add all tools
	var tools = get_tree().get_nodes_in_group("tools")
	for tool_node in tools:
		if tool_node.has_method("get_tool_type"):
			gameplay_nodes.append(tool_node)
	
	print("LevelEditor: Found " + str(gameplay_nodes.size()) + " gameplay nodes to manage")

# Find and store references to game UI elements
func find_game_ui_elements():
	# Clear previous references
	game_ui_elements.clear()
	game_ui_visibility_states.clear()
	
	# Get the main UI layer
	var ui_layer = get_node_or_null("/root/Main/UILayer")
	if ui_layer:
		# Add all direct UI children except debug buttons
		for child in ui_layer.get_children():
			# Skip any debug buttons (assuming they have "Debug" in the name)
			if "Debug" not in child.name and child.name != "EditorUI":
				game_ui_elements.append(child)
	
	# Specifically look for OrderUI which is a common gameplay UI element
	var order_ui = get_node_or_null("/root/Main/UILayer/OrderUI")
	if order_ui and not game_ui_elements.has(order_ui):
		game_ui_elements.append(order_ui)
	
	print("LevelEditor: Found " + str(game_ui_elements.size()) + " game UI elements to manage")

# Hide all game UI elements
func hide_game_ui():
	# Find UI elements if we haven't yet
	if game_ui_elements.size() == 0:
		find_game_ui_elements()
	
	# Store current visibility states and hide UI
	for ui_element in game_ui_elements:
		if is_instance_valid(ui_element):
			game_ui_visibility_states[ui_element] = ui_element.visible
			ui_element.visible = false
	
	print("LevelEditor: Hid " + str(game_ui_visibility_states.size()) + " game UI elements")

# Restore visibility of game UI elements
func restore_game_ui():
	# Restore previous visibility states
	for ui_element in game_ui_visibility_states:
		if is_instance_valid(ui_element):
			ui_element.visible = game_ui_visibility_states[ui_element]
	
	# Clear the dictionary
	game_ui_visibility_states.clear()
	
	print("LevelEditor: Restored game UI elements")

# Pause all gameplay elements
func pause_gameplay():
	# Find gameplay nodes if we haven't yet
	if gameplay_nodes.size() == 0:
		find_gameplay_nodes()
	
	# Store original process modes and set to disabled
	for node in gameplay_nodes:
		if is_instance_valid(node):
			original_process_modes[node] = node.process_mode
			node.process_mode = Node.PROCESS_MODE_DISABLED
	
	print("LevelEditor: Paused " + str(original_process_modes.size()) + " gameplay nodes")

# Resume all gameplay elements
func resume_gameplay():
	# Restore original process modes
	for node in original_process_modes:
		if is_instance_valid(node):
			node.process_mode = original_process_modes[node]
	
	# Clear the dictionaries
	original_process_modes.clear()
	
	print("LevelEditor: Resumed gameplay nodes")

# Save original tile states for cancel operation
func save_original_state():
	original_tile_states.clear()
	
	for x in range(farm_bounds.position.x, farm_bounds.position.x + farm_bounds.size.x):
		for z in range(farm_bounds.position.y, farm_bounds.position.y + farm_bounds.size.y):
			var pos = Vector3i(x, 0, z)
			var tile_type = level_manager.get_tile_type(pos)
			
			# Only store non-default tiles to save memory
			if tile_type != 0:  # Not REGULAR_GROUND
				original_tile_states[pos] = tile_type
				
				# Also update game_data
				if game_data_manager:
					game_data_manager.set_tile(x, z, tile_type)
	
	print("LevelEditor: Saved original state of " + str(original_tile_states.size()) + " tiles")

# Set up the highlight mesh
func setup_highlight_mesh():
	# Check if we already have tile_highlighter and highlight_mesh from the scene
	if not tile_highlighter:
		# Create a new one if not found
		tile_highlighter = Node3D.new()
		tile_highlighter.name = "TileHighlighter"
		add_child(tile_highlighter)
		print("LevelEditor: Created new TileHighlighter")
	
	if not highlight_mesh:
		# Create a new mesh if not found
		highlight_mesh = MeshInstance3D.new()
		highlight_mesh.name = "MeshInstance3D"
		tile_highlighter.add_child(highlight_mesh)
		print("LevelEditor: Created new highlight mesh")
	
	# Create a plane mesh for highlighting
	var plane = PlaneMesh.new()
	plane.size = Vector2(0.95, 0.95)  # Slightly smaller than tile
	highlight_mesh.mesh = plane
	
	# Create material
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0, 1, 0, 0.5)  # Semi-transparent green
	highlight_mesh.material_override = material
	
	# Hide initially
	tile_highlighter.visible = false
	
	print("LevelEditor: Highlight mesh set up")

# Select a tile type
func select_tile_type(type_name: String):
	print("LevelEditor: Selecting tile type: " + type_name)
	selected_tile_type = type_name
	selected_tool_type = "none"
	is_placing_tool = false
	
	# The UI update is now handled by EditorUI directly, so we don't need
	# to call editor_ui methods from here
	
	print("LevelEditor: Selected tile type: " + type_name)

# Select a tool type for placement
func select_tool_type(tool_type: String):
	selected_tool_type = tool_type
	selected_tile_type = "none"
	is_placing_tool = true
	
	# Update UI
	if editor_ui:
		# Update the tool label
		if editor_ui.has_method("update_selected_tool"):
			editor_ui.update_selected_tool(tool_type)
		
		# Also update the tile label if it exists
		if editor_ui.has_method("update_selected_tile"):
			editor_ui.update_selected_tile("None")
	
	print("LevelEditor: Selected tool type: " + tool_type)

# Check if a tile can be placed
func can_place_tile(grid_pos: Vector3i, type_name: String) -> bool:
	# Don't replace with same type
	var current_type = level_manager.get_tile_type(grid_pos)
	var new_type = tile_type_mapping.get(type_name, 0)
	
	if current_type == new_type:
		return false
	
	# Check if player can afford it
	var cost = get_tile_cost(type_name)
	if not game_data or not game_data.progression_data:
		return false
		
	return game_data.progression_data.currency >= cost

# Place a tile at the given position
func place_tile(grid_pos: Vector3i, type_name: String) -> bool:
	if not level_manager or not grid_map:
		return false
	
	# Get current tile type
	var current_type = level_manager.get_tile_type(grid_pos)
	var new_type = tile_type_mapping.get(type_name, 0)
	
	# Don't replace with same type
	if current_type == new_type:
		return false
	
	# Check if we can afford it
	if not game_data or not game_data.progression_data:
		return false
		
	var cost = get_tile_cost(type_name)
	if game_data.progression_data.currency < cost:
		print("LevelEditor: Can't afford tile of type " + type_name)
		return false
	
	# Deduct currency
	game_data.progression_data.currency -= cost
	
	# Update the tile
	if level_manager.set_tile_type(grid_pos, new_type):
		# Update game data
		if game_data_manager:
			game_data_manager.set_tile(grid_pos.x, grid_pos.z, new_type)
		
		if type_name == "tomato_dispenser":
			if game_data and game_data.progression_data:
				if not game_data.progression_data.unlocked_seeds.has("tomato"):
					game_data.progression_data.unlocked_seeds.append("tomato")
					print("LevelEditor: Unlocked 'tomato' seeds.")
					# Notify OrderManager to update its available crops
					var order_manager = get_node_or_null("/root/Main/OrderManager") # Adjust path if needed
					if order_manager and order_manager.has_method("update_available_crops"):
						order_manager.update_available_crops()
						print("LevelEditor: Notified OrderManager to update crops.")
					elif ServiceLocator.get_instance() and ServiceLocator.get_instance().has_service("order_manager"):
						order_manager = ServiceLocator.get_instance().get_service("order_manager")
						if order_manager and order_manager.has_method("update_available_crops"):
							order_manager.update_available_crops()
							print("LevelEditor: Notified OrderManager (via ServiceLocator) to update crops.")
		
		
		# Expand farm bounds if needed
		if grid_pos.x < farm_bounds.position.x or grid_pos.x >= farm_bounds.position.x + farm_bounds.size.x or \
		   grid_pos.z < farm_bounds.position.y or grid_pos.z >= farm_bounds.position.y + farm_bounds.size.y:
			var min_x = min(farm_bounds.position.x, grid_pos.x - 1)
			var min_z = min(farm_bounds.position.y, grid_pos.z - 1)
			var max_x = max(farm_bounds.position.x + farm_bounds.size.x, grid_pos.x + 2)
			var max_z = max(farm_bounds.position.y + farm_bounds.size.y, grid_pos.z + 2)
			farm_bounds = Rect2(min_x, min_z, max_x - min_x, max_z - min_z)
			print("LevelEditor: Expanded farm bounds to: ", farm_bounds)
		
		# Update UI
		if editor_ui:
			editor_ui.update_currency_display()
		
		print("LevelEditor: Placed " + type_name + " tile at " + str(grid_pos))
		return true
	
	return false

# Get the cost of a tile type
func get_tile_cost(type_name: String) -> int:
	if tile_prices.has(type_name):
		return tile_prices[type_name]
	return 0

# Check if a tool can be placed at a specific position
func can_place_tool(grid_pos: Vector3i, tool_type: String) -> bool:
	# Don't place if removing tools
	if tool_type == "remove_tool":
		var tool_at_pos = ""
		if game_data_manager:
			tool_at_pos = game_data_manager.get_tool_at(grid_pos.x, grid_pos.z)
		return tool_at_pos != ""
	
	# Check if position already has a tool
	var has_tool = false
	if game_data_manager:
		has_tool = game_data_manager.get_tool_at(grid_pos.x, grid_pos.z) != ""
	
	if has_tool:
		return false
	
	# Check if player can afford it
	var cost = get_tool_cost(tool_type)
	if not game_data or not game_data.progression_data:
		return false
		
	return game_data.progression_data.currency >= cost

# Get the cost of a tool type
func get_tool_cost(tool_type: String) -> int:
	if tool_prices.has(tool_type):
		return tool_prices[tool_type]
	return 0

# Place a tool at the given position
func place_tool(grid_pos: Vector3i, tool_type: String) -> bool:
	if tool_type == "remove_tool":
		return remove_tool_at(grid_pos)
	
	if not game_data or not game_data.progression_data:
		return false
	
	# Check if position already has a tool
	var has_tool = false
	if game_data_manager:
		has_tool = game_data_manager.get_tool_at(grid_pos.x, grid_pos.z) != ""
	
	if has_tool:
		print("LevelEditor: Position already has a tool")
		return false
	
	# Check if we can afford it
	var cost = get_tool_cost(tool_type)
	if game_data.progression_data.currency < cost:
		print("LevelEditor: Can't afford tool of type " + tool_type)
		return false
	
	# Deduct currency
	game_data.progression_data.currency -= cost
	
	# Place the tool in game data
	var success = false
	if game_data_manager:
		success = game_data_manager.place_tool(grid_pos.x, grid_pos.z, tool_type)
	
	if success:
		# Spawn the actual tool object
		spawn_tool(grid_pos, tool_type)
		# NEW CODE: Unlock the corresponding seed type for seed dispensers
		if tool_type == "tomato_seeds" and not game_data.progression_data.unlocked_seeds.has("tomato"):
			game_data.progression_data.unlocked_seeds.append("tomato")
			print("LevelEditor: Unlocked tomato seeds")
		# Update UI
		if editor_ui:
			editor_ui.update_currency_display()
		
		print("LevelEditor: Placed " + tool_type + " at " + str(grid_pos))
		return true
	
	return false

# Remove a tool at the given position
func remove_tool_at(grid_pos: Vector3i) -> bool:
	# Check if there's a tool at this position
	var tool_type = ""
	if game_data_manager:
		tool_type = game_data_manager.get_tool_at(grid_pos.x, grid_pos.z)
	
	if tool_type == "":
		return false
	
	# Remove from game data
	var success = false
	if game_data_manager:
		success = game_data_manager.remove_tool(grid_pos.x, grid_pos.z)
	
	if success:
		# Find and remove the tool object
		var tool_key = "editor_tool_" + str(grid_pos.x) + "_" + str(grid_pos.z)
		var tool_node = get_node_or_null(tool_key)
		if tool_node:
			tool_node.queue_free()
		
		print("LevelEditor: Removed " + tool_type + " from " + str(grid_pos))
		return true
	
	return false

# Spawn a tool in the world
func spawn_tool(grid_pos: Vector3i, tool_type: String):
	# Get the scene path for this tool type
	if not tool_scenes.has(tool_type):
		push_error("LevelEditor: No scene path for tool type: " + tool_type)
		return
	
	var scene_path = tool_scenes[tool_type]
	var tool_scene = load(scene_path)
	
	if not tool_scene:
		push_error("LevelEditor: Failed to load tool scene: " + scene_path)
		return
	
	# Create the tool instance
	var tool_instance = tool_scene.instantiate()
	
	# Give it a unique name based on position
	var tool_key = "editor_tool_" + str(grid_pos.x) + "_" + str(grid_pos.z)
	tool_instance.name = tool_key
	
	# Add to the scene
	add_child(tool_instance)
	
	# Position the tool at the grid position
	var world_pos = Vector3(grid_pos.x + 0.5, 0.75, grid_pos.z + 0.5)  # Center on tile and elevate
	tool_instance.global_position = world_pos
	
	# Add to group for easy cleanup
	tool_instance.add_to_group("editor_tools")
	
	print("LevelEditor: Spawned " + tool_type + " at " + str(world_pos))

# Spawn all tools saved in game data
func spawn_saved_tools():
	# Clear any existing editor tools first
	remove_editor_tools()
	
	if not game_data_manager:
		return
	
	# Get all placed tools from game data
	var tool_placement = game_data_manager.get_all_placed_tools()
	
	# Spawn each tool
	for key in tool_placement:
		var coords = key.split(",")
		var x = int(coords[0])
		var z = int(coords[1])
		var tool_type = tool_placement[key]
		
		# Spawn the tool
		spawn_tool(Vector3i(x, 0, z), tool_type)
	
	print("LevelEditor: Spawned " + str(tool_placement.size()) + " saved tools")

# Remove all editor-placed tools
func remove_editor_tools():
	var editor_tools = get_tree().get_nodes_in_group("editor_tools")
	for tool_node in editor_tools:
		tool_node.queue_free()
	
	print("LevelEditor: Removed " + str(editor_tools.size()) + " editor tools")

# Process input for tile/tool placement
func _unhandled_input(event):
	if not is_editing or not visible:
		return
	
	# Handle mouse input for tile/tool placement
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if get_viewport().get_gui_at_point(event.position) != null:
			print("Click detected over GUI, ignoring in LevelEditor.") # Optional debug print
			return 
		var mouse_pos = get_viewport().get_mouse_position()
		var from = editor_camera.project_ray_origin(mouse_pos)
		var to = from + editor_camera.project_ray_normal(mouse_pos) * 100
		
		# Raycast to find intersected tile
		var space_state = get_viewport().get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		var result = space_state.intersect_ray(query)
		
		if result and result.has("position"):
			var pos = result.position
			var grid_pos = level_manager.world_to_grid(pos)
			
			# Check if in farm bounds - this now handles negative coordinates
			if is_position_in_bounds(grid_pos):
				if is_placing_tool:
					# Place selected tool type
					if selected_tool_type != "none":
						place_tool(grid_pos, selected_tool_type)
				else:
					# Place selected tile type
					if selected_tile_type != "none":
						place_tile(grid_pos, selected_tile_type)
			else:
				print("LevelEditor: Position " + str(grid_pos) + " is outside farm bounds: " + str(farm_bounds))
	
	# Update highlights on mouse movement
	if event is InputEventMouseMotion:
		update_highlights()

# Helper method to check if a position is within farm bounds
func is_position_in_bounds(grid_pos: Vector3i) -> bool:
	return grid_pos.x >= farm_bounds.position.x and grid_pos.x < farm_bounds.position.x + farm_bounds.size.x and \
		   grid_pos.z >= farm_bounds.position.y and grid_pos.z < farm_bounds.position.y + farm_bounds.size.y

# Update highlighters based on selected mode (tile or tool)
func update_highlights():
	if is_placing_tool:
		update_tool_highlight()
	else:
		update_tile_highlight()

# Update the tile highlighter
func update_tile_highlight():
	if not tile_highlighter or not highlight_mesh or not editor_camera or not level_manager:
		return
	
	var mouse_pos = get_viewport().get_mouse_position()
	var from = editor_camera.project_ray_origin(mouse_pos)
	var to = from + editor_camera.project_ray_normal(mouse_pos) * 100
	
	# Raycast to find intersected tile
	var space_state = get_viewport().get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	# Add this line right after the above code:
	query.collision_mask = 0xFFFF & ~(1 << 9)  # Ignore layer 10 (index 9)
	var result = space_state.intersect_ray(query)
	
	if result and result.has("position"):
		var pos = result.position
		var grid_pos = level_manager.world_to_grid(pos)
		
		# Check if in farm bounds
		if is_position_in_bounds(grid_pos):
			# Position highlighter
			var world_pos = level_manager.grid_to_world(grid_pos)
			world_pos.y = 0.8  # Slightly above the ground
			tile_highlighter.global_position = world_pos - Vector3(0.5,0,0.5)
			
			# Show highlighter
			tile_highlighter.visible = true
			
			# Change color based on affordability
			var material = highlight_mesh.material_override
			if material:
				if selected_tile_type != "none" and can_place_tile(grid_pos, selected_tile_type):
					material.albedo_color = Color(0, 1, 0, 0.5)  # Green = can place
				else:
					material.albedo_color = Color(1, 0, 0, 0.5)  # Red = can't place
			
			return
	
	# Hide highlighter if no valid tile
	tile_highlighter.visible = false

# Update the tool placement highlighter
func update_tool_highlight():
	if not tile_highlighter or not highlight_mesh or not editor_camera or not level_manager:
		return
	
	var mouse_pos = get_viewport().get_mouse_position()
	var from = editor_camera.project_ray_origin(mouse_pos)
	var to = from + editor_camera.project_ray_normal(mouse_pos) * 100
	
	# Raycast to find intersected tile
	var space_state = get_viewport().get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var result = space_state.intersect_ray(query)
	
	if result and result.has("position"):
		var pos = result.position
		var grid_pos = level_manager.world_to_grid(pos)
		
		# Check if in farm bounds
		if is_position_in_bounds(grid_pos):
			# Position highlighter
			var world_pos = level_manager.grid_to_world(grid_pos)
			world_pos.y = 0.3  # Slightly above the ground
			tile_highlighter.global_position = world_pos
			
			# Show highlighter
			tile_highlighter.visible = true
			
			# Change color based on can place
			var material = highlight_mesh.material_override
			if material:
				# Special case for remove tool
				if selected_tool_type == "remove_tool":
					var has_tool = false
					if game_data_manager:
						has_tool = game_data_manager.get_tool_at(grid_pos.x, grid_pos.z) != ""
					
					if has_tool:
						material.albedo_color = Color(1, 0.5, 0, 0.5)  # Orange = can remove
					else:
						material.albedo_color = Color(0.5, 0.5, 0.5, 0.3)  # Gray = nothing to remove
				elif selected_tool_type != "none" and can_place_tool(grid_pos, selected_tool_type):
					material.albedo_color = Color(0, 1, 0, 0.5)  # Green = can place
				else:
					material.albedo_color = Color(1, 0, 0, 0.5)  # Red = can't place
			
			return
	
	# Hide highlighter if no valid tile
	tile_highlighter.visible = false

# Cancel editing and revert changes
func cancel_editing():
	# Restore original state
	for pos in original_tile_states:
		var type = original_tile_states[pos]
		level_manager.set_tile_type(pos, type)
	
	# Reload game data
	var service_locator = get_node_or_null("/root/ServiceLocator")
	if service_locator:
		game_data = service_locator.get_service("game_data")
	
	print("LevelEditor: Canceled changes")
	
	# Stop editing
	stop_editing()
	
	# Emit signal
	emit_signal("editor_canceled")

# Save changes
func save_changes():
	# Save game data
	if game_data:
		game_data.save()
	
	print("LevelEditor: Saved changes")
	
	# Stop editing
	stop_editing()
	
	# Emit signal
	emit_signal("editor_saved")

# Start the next run
func start_next_level():
	# Save changes first
	save_changes()
	
	# Tell Main to start a new run
	var main = get_node_or_null("/root/Main")
	if main and main.has_method("start_next_level"):
		main.start_next_level()
		print("properly started next level")
	else:
		push_error("LevelEditor: Could not find Main.start_next_level()")

# Handle visibility changes
func _on_visibility_changed():
	# Make sure UI visibility matches editor visibility
	if editor_ui:
		editor_ui.visible = visible
	
	# This ensures gameplay is paused/resumed when visibility changes directly
	if visible and not is_editing:
		# If becoming visible but not in editing mode, start editing properly
		start_editing()
	elif not visible and is_editing:
		# If becoming hidden while in editing mode, stop editing properly
		stop_editing()

# Reset the farm progression
func reset_farm_progression():
	print("LevelEditor: Resetting all farm progression")
	
	# Reset GameData progression
	if game_data_manager and game_data_manager.has_method("reset_progression"):
		game_data_manager.reset_progression()
	
	# Reset to initial farm layout
	if level_manager:
		# Reset to default layout if no initial layout exists
		if not game_data or not game_data.farm_layout_data or game_data.farm_layout_data.initial_farm_layout.size() == 0:
			if game_data_manager and game_data_manager.has_method("apply_default_farm_layout"):
				game_data_manager.apply_default_farm_layout()
	
	# Remove all tools
	remove_editor_tools()
	
	# Update currency display
	if editor_ui:
		editor_ui.update_currency_display()
	
	# Show success message
	var popup = AcceptDialog.new()
	popup.title = "Farm Reset"
	popup.dialog_text = "Farm has been reset to its original layout!"
	popup.dialog_hide_on_ok = true
	get_tree().root.add_child(popup)
	popup.popup_centered()
	
# Add this function to your LevelEditor.gd:

func initialize_upgrades():
	print("LevelEditor: Initializing upgrades panel")
	
	# Check if we have editor_ui and it has the upgrades panel
	if not editor_ui:
		print("LevelEditor: Cannot initialize upgrades - editor_ui is null")
		return
	
	# Get the upgrade system reference
	var upgrade_system = null
	
	# Try through service locator first
	var service_locator = get_node_or_null("/root/ServiceLocator")
	if service_locator:
		upgrade_system = service_locator.get_service("upgrade_system")
		print("LevelEditor: Got upgrade_system from ServiceLocator: " + str(upgrade_system != null))
	
		
	# If we have an upgrade system, populate the UI
	if upgrade_system:
		populate_upgrade_panels(upgrade_system)
	else:
		print("LevelEditor: No upgrade system found")

# Function to populate the upgrade panels
func populate_upgrade_panels(upgrade_system):
	print("LevelEditor: Populating upgrade panels")
	
	# Look for the upgrade tabs in the editor UI
	var upgrade_tabs = find_upgrade_tabs()
	if not upgrade_tabs or upgrade_tabs.is_empty():
		print("LevelEditor: No upgrade tabs found in editor UI")
		return
	
	# Get all available upgrades from the registry
	var registry = null
	if upgrade_system.has_method("get_upgrade_registry"):
		registry = upgrade_system.get_upgrade_registry()
	elif "upgrade_registry" in upgrade_system:
		registry = upgrade_system.upgrade_registry
	
	if not registry:
		print("LevelEditor: No upgrade registry found")
		return
	
	# Get available upgrades
	var all_upgrades = {}
	if registry.has_method("get_all_upgrades"):
		all_upgrades = registry.get_all_upgrades()
	else:
		print("LevelEditor: Registry doesn't have get_all_upgrades method")
		return
	
	print("LevelEditor: Found " + str(all_upgrades.size()) + " upgrades in registry")
	
	# Get current upgrade levels
	var current_levels = {}
	if upgrade_system.has_method("get_all_upgrade_levels"):
		current_levels = upgrade_system.get_all_upgrade_levels()
	else:
		# Build manually by checking each upgrade
		for upgrade_id in all_upgrades.keys():
			var level = 0
			if upgrade_system.has_method("get_upgrade_level"):
				level = upgrade_system.get_upgrade_level(upgrade_id)
			current_levels[upgrade_id] = level
	
	# Get player currency
	var currency = 1000  # Default
	if game_data and game_data.progression_data:
		currency = game_data.progression_data.currency
	
	# Now populate each tab based on upgrade type
	populate_tab_with_upgrades(upgrade_tabs["tile_upgrades"], all_upgrades, current_levels, currency, UpgradeData.UpgradeType.TILE)
	populate_tab_with_upgrades(upgrade_tabs["tool_upgrades"], all_upgrades, current_levels, currency, UpgradeData.UpgradeType.TOOL)
	populate_tab_with_upgrades(upgrade_tabs["player_upgrades"], all_upgrades, current_levels, currency, UpgradeData.UpgradeType.PLAYER)
	
	print("LevelEditor: Upgrade panels populated")

# Helper function to find upgrade tabs in the UI
func find_upgrade_tabs():
	var result = {}
	
	# Check if EditorUI exists and has the structure we need
	if not editor_ui:
		return result
	
	# Look for the tabs container
	var left_panel = editor_ui.find_child("LeftPanel")
	if not left_panel:
		return result
	
	var tab_container = left_panel.find_child("TabContainer")
	if not tab_container:
		return result
	
	# Find the Upgrades tab
	var upgrades_tab = null
	for child in tab_container.get_children():
		if "Upgrades" in child.name:
			upgrades_tab = child
			break
	
	if not upgrades_tab:
		return result
	
	# Now find the category tabs
	var category_tabs = upgrades_tab.find_child("CategoryTabs")
	if not category_tabs:
		return result
	
	# Search for the upgrade list for each category
	for child in category_tabs.get_children():
		var list = child.find_child("UpgradesList")
		if not list:
			continue
			
		if "Tile" in child.name:
			result["tile_upgrades"] = list
		elif "Tool" in child.name:
			result["tool_upgrades"] = list
		elif "Player" in child.name:
			result["player_upgrades"] = list
	
	return result

# Helper function to populate an upgrade tab
func populate_tab_with_upgrades(tab, all_upgrades, current_levels, currency, type):
	if not tab:
		return
		
	# Clear any existing items
	for child in tab.get_children():
		child.queue_free()
	
	# Get upgrade item scene
	var upgrade_item_scene = load("res://scenes/editor/UpgradeItem.tscn")
	if not upgrade_item_scene:
		print("LevelEditor: Failed to load UpgradeItem scene")
		return
	
	# Add items for each upgrade of this type
	var items_added = 0
	for upgrade_id in all_upgrades.keys():
		var upgrade = all_upgrades[upgrade_id]
		if upgrade.type != type:
			continue
			
		# Create the item
		var item = upgrade_item_scene.instantiate()
		tab.add_child(item)
		
		# Set up the item
		var level = current_levels.get(upgrade_id, 0)
		item.initialize(upgrade, level, currency)
		
		# Connect signal for selection
		if item.has_signal("upgrade_selected"):
			item.connect("upgrade_selected", Callable(self, "_on_upgrade_selected"))
		
		items_added += 1
	
	print("LevelEditor: Added " + str(items_added) + " items to " + str(type) + " upgrade tab")

# Called when an upgrade is selected
func _on_upgrade_selected(upgrade_id, upgrade_data):
	var upgrade_lists = find_upgrade_tabs() # Use your existing helper
	var list_to_clear = null
	match upgrade_data.type:
		UpgradeData.UpgradeType.TILE:
			list_to_clear = upgrade_lists.get("tile_upgrades")
		UpgradeData.UpgradeType.TOOL:
			list_to_clear = upgrade_lists.get("tool_upgrades")
		UpgradeData.UpgradeType.PLAYER:
			list_to_clear = upgrade_lists.get("player_upgrades")

	# Iterate through items in the correct list and deselect them
	if list_to_clear:
		for item in list_to_clear.get_children():
			if item is UpgradeItem and item.upgrade_id != upgrade_id: # Don't deselect the one just clicked
				if item.has_method("set_selected"):
					item.set_selected(false) # Tell item to use default style# Update the info panel and handle purchase logic
	var info_panel = find_upgrade_info_panel()
	if not info_panel:
		return
		
	# Set panel info
	set_upgrade_info(info_panel, upgrade_data)
	
	# Store the currently selected upgrade ID for purchase
	set_meta("selected_upgrade_id", upgrade_id)
	
	# Enable purchase button if affordable and not maxed
	var purchase_button = info_panel.find_child("PurchaseButton")
	if purchase_button:
		var currency = game_data.progression_data.currency if game_data and game_data.progression_data else 0
		var current_level = 0
		var upgrade_system = get_upgrade_system()
		if upgrade_system and upgrade_system.has_method("get_upgrade_level"):
			current_level = upgrade_system.get_upgrade_level(upgrade_id)
		
		var affordable = currency >= upgrade_data.cost
		var not_maxed = current_level < upgrade_data.max_level
		
		purchase_button.disabled = not (affordable and not_maxed)
		
		# Connect purchase button
		if not purchase_button.is_connected("pressed", Callable(self, "_on_purchase_button_pressed")):
			purchase_button.connect("pressed", Callable(self, "_on_purchase_button_pressed"))

# Helper function to find the upgrade info panel
func find_upgrade_info_panel():
	if not editor_ui:
		return null
	
	var left_panel = editor_ui.find_child("LeftPanel")
	if not left_panel:
		return null
	
	var tab_container = left_panel.find_child("TabContainer")
	if not tab_container:
		return null
	
	var upgrades_tab = null
	for child in tab_container.get_children():
		if "Upgrades" in child.name:
			upgrades_tab = child
			break
	
	if not upgrades_tab:
		return null
	
	return upgrades_tab.find_child("UpgradeInfoPanel")

# Helper function to set upgrade info in the panel
func set_upgrade_info(panel, upgrade_data):
	var title_label = panel.find_child("TitleLabel")
	var description_label = panel.find_child("DescriptionLabel")
	var price_label = panel.find_child("PriceLabel")
	
	if title_label:
		title_label.text = upgrade_data.name
	
	if description_label:
		description_label.text = upgrade_data.description
	
	if price_label:
		price_label.text = "Cost: " + str(upgrade_data.cost)

# Called when purchase button is pressed
func _on_purchase_button_pressed():
	if not has_meta("selected_upgrade_id"):
		return
		
	var upgrade_id = get_meta("selected_upgrade_id")
	var upgrade_system = get_upgrade_system()
	
	if not upgrade_system:
		print("LevelEditor: No upgrade system found for purchase")
		return
	
	# Try to purchase the upgrade
	if upgrade_system.has_method("purchase_upgrade"):
		var success = upgrade_system.purchase_upgrade(upgrade_id)
		if success:
			print("LevelEditor: Successfully purchased upgrade: " + upgrade_id)
			
			# Refresh the UI
			call_deferred("initialize_upgrades")
			
			# Update currency display
			if editor_ui and editor_ui.has_method("update_currency_display"):
				editor_ui.update_currency_display()
		else:
			print("LevelEditor: Failed to purchase upgrade: " + upgrade_id)
	else:
		print("LevelEditor: Upgrade system doesn't have purchase_upgrade method")

# Helper function to get the upgrade system
func get_upgrade_system():
	# Try through service locator first
	var service_locator = get_node_or_null("/root/ServiceLocator")
	if service_locator:
		var system = service_locator.get_service("upgrade_system")
		if system:
			return system
	
	# Try direct node lookup
	var system = get_node_or_null("/root/Main/UpgradeSystem")
	if not system:
		system = get_node_or_null("/root/Main/MinimalUpgradeSystem")
	
	if system:
		return system
	
	# Check if it's a property on the game manager
	var game_manager = get_node_or_null("/root/Main")
	if game_manager and "upgrade_system" in game_manager:
		return game_manager.upgrade_system
	
	return null

# Get the reverse mapping (type to name)
func get_tile_name_from_type(type_id: int) -> String:
	for name in tile_type_mapping:
		if tile_type_mapping[name] == type_id:
			return name
	return "unknown"

# Get available tile types based on unlocked tiles
func get_available_tile_types() -> Array:
	var available_tiles = []
	var basic_tiles = ["regular", "dirt", "soil", "water", "mud", "delivery","carrot_dispenser", "tomato_dispenser"]
	available_tiles.append_array(basic_tiles)

	# Check for special tiles with the upgrade system (existing logic)
	var upgrade_system = get_upgrade_system()
	if upgrade_system:
		var upgrade_to_tile_map = {
			"fertile_soil": "dirt_fertile",
			"preservation_mulch": "dirt_preserved",
			"persistent_soil": "dirt_persistent",
			"express_delivery": "delivery_express",
			"sprinkler_system": "sprinkler"
		}
		for upgrade_id in upgrade_to_tile_map:
			var level = 0
			if upgrade_system.has_method("get_upgrade_level"):
				level = upgrade_system.get_upgrade_level(upgrade_id)
			if level > 0:
				available_tiles.append(upgrade_to_tile_map[upgrade_id])

	return available_tiles


# Replace update_tile_buttons() in LevelEditor.gd with this simplified version
# Instead, add this function that delegates to EditorUI:
func update_tile_buttons():
	print("LevelEditor: Delegating update_tile_buttons to EditorUI")
	
	if editor_ui and editor_ui.has_method("update_tile_buttons_visibility"):
		var available_tiles = get_available_tile_types()
		editor_ui.update_tile_buttons_visibility(available_tiles)
	else:
		print("LevelEditor: Cannot update tile buttons - editor_ui reference is invalid")
				
func initialize_tile_buttons():
	print("LevelEditor: Initializing tile buttons")
	update_tile_buttons()
	
func find_tile_tab():
	if not editor_ui:
		return null
		
	# First try directly through TabContainer
	var tab_container = editor_ui.find_child("TabContainer", true, false)
	if tab_container:
		for child in tab_container.get_children():
			if "Tiles" in child.name:
				return child
	
	# If not found, try secondary approach
	var left_panel = editor_ui.find_child("LeftPanel", true, false) 
	if left_panel:
		tab_container = left_panel.find_child("TabContainer", true, false)
		if tab_container:
			for child in tab_container.get_children():
				if "Tiles" in child.name:
					return child
					
	return null
	
	
# Update refresh_after_upgrade to delegate to EditorUI
func refresh_after_upgrade():
	print("LevelEditor: Refreshing UI after upgrade purchase")
	
	# Update game data reference
	if not game_data:
		var service_locator = get_node_or_null("/root/ServiceLocator")
		if service_locator:
			game_data = service_locator.get_service("game_data")
	
	# Tell EditorUI to update
	if editor_ui:
		# Update currency display
		if editor_ui.has_method("update_currency_display"):
			editor_ui.update_currency_display()
			
		# Update button visibility
		if editor_ui.has_method("update_tile_buttons_visibility"):
			var available_tiles = get_available_tile_types()
			editor_ui.update_tile_buttons_visibility(available_tiles)
	
func _on_game_data_changed():
	# Update tile buttons to reflect changes in game data
	if is_visible() and is_editing:
		update_tile_buttons()
		
		# Also update currency display
		if editor_ui and editor_ui.has_method("update_currency_display"):
			editor_ui.update_currency_display()
			
