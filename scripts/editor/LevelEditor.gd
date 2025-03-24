# scripts/editor/LevelEditor.gd
extends Node3D

# References
var level_manager: Node = null
var grid_map: GridMap = null
var farm_data: FarmData = null
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
	"carrot_seeds": "res://scenes/tools/CarrotSeedDispenser.tscn",
	"tomato_seeds": "res://scenes/tools/TomatoSeedDispenser.tscn"
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
	"regular": 0,  # REGULAR_GROUND
	"dirt": 1,     # DIRT_GROUND
	"soil": 2,     # SOIL
	"water": 3,    # WATER
	"mud": 4,      # MUD
	"delivery": 5  # DELIVERY
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
	
	# Connect UI signals
	if editor_ui:
		# Connect tile selection buttons
		var buttons = {
			"RegularButton": "regular",
			"DirtButton": "dirt",
			"SoilButton": "soil",
			"WaterButton": "water",
			"MudButton": "mud",
			"DeliveryButton": "delivery"
		}
		
		for button_name in buttons:
			var button = editor_ui.find_child(button_name)
			if button:
				button.connect("pressed", Callable(self, "select_tile_type").bind(buttons[button_name]))
		
		# Connect action buttons
		var cancel_button = editor_ui.find_child("CancelButton")
		if cancel_button:
			cancel_button.connect("pressed", Callable(self, "cancel_editing"))
			
		var save_button = editor_ui.find_child("SaveButton")
		if save_button:
			save_button.connect("pressed", Callable(self, "save_changes"))
			
		var start_button = editor_ui.find_child("StartButton")
		if start_button:
			start_button.connect("pressed", Callable(self, "start_next_level"))
	
	# Set up highlight mesh
	setup_highlight_mesh()
	
	# Load or create farm data
	farm_data = FarmData.load_data()
	
	# Initially hide editor (will be shown by Main when appropriate)
	hide()
	
	print("LevelEditor: Initialized with UI hidden")

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
	if not level_manager or not grid_map:
		push_error("LevelEditor: Cannot start editing - missing references!")
		return
	
	# Calculate farm bounds to include all existing tiles
	calculate_farm_bounds()
	
	# Show editor and UI
	show()
	if editor_ui:
		editor_ui.visible = true
	
	# Hide game UI
	hide_game_ui()
	
	# Pause gameplay
	pause_gameplay()
	
	# Switch to editor camera
	if editor_camera:
		editor_camera.current = true
	
	# Store original tile states
	save_original_state()
	
	# Update currency display
	update_currency_display()
	
	# Set editor as active
	is_editing = true
	
	# Spawn existing tools from farm data
	spawn_saved_tools()
	
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
				
				# Also update farm_data
				farm_data.set_tile(x, z, tile_type)
	
	print("LevelEditor: Saved original state of " + str(original_tile_states.size()) + " tiles")

# Update the currency display
func update_currency_display():
	if editor_ui:
		# Update currency label
		if editor_ui.has_method("update_currency"):
			editor_ui.update_currency(farm_data.currency)
		
		# Also update button states based on affordability
		if editor_ui.has_method("update_button_states"):
			editor_ui.update_button_states(farm_data.currency)

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
	selected_tile_type = type_name
	selected_tool_type = "none"
	is_placing_tool = false
	
	# Update UI
	if editor_ui:
		# Update the tile label
		if editor_ui.has_method("update_selected_tile"):
			editor_ui.update_selected_tile(type_name)
		
		# Also update the tool label if it exists
		if editor_ui.has_method("update_selected_tool"):
			editor_ui.update_selected_tool("None")
	
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
	var cost = farm_data.get_tile_cost(type_name)
	return farm_data.currency >= cost

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
	
	# Try to purchase the tile
	if not farm_data.try_purchase_tile(type_name):
		print("LevelEditor: Can't afford tile of type " + type_name)
		return false
	
	# Update the tile
	if level_manager.set_tile_type(grid_pos, new_type):
		# Update our farm data - handle negative coordinates correctly
		farm_data.set_tile(grid_pos.x, grid_pos.z, new_type)
		
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
		update_currency_display()
		
		print("LevelEditor: Placed " + type_name + " tile at " + str(grid_pos))
		return true
	
	return false

# Check if a tool can be placed at a specific position
func can_place_tool(grid_pos: Vector3i, tool_type: String) -> bool:
	# Don't place if removing tools
	if tool_type == "remove_tool":
		return farm_data.get_tool_at(grid_pos.x, grid_pos.z) != ""
	
	# Check if position already has a tool
	if farm_data.get_tool_at(grid_pos.x, grid_pos.z) != "":
		return false
	
	# Check if player can afford it
	var cost = farm_data.get_tool_cost(tool_type)
	return farm_data.currency >= cost

# Place a tool at the given position
# Update the place_tool function in LevelEditor.gd to handle seed unlocking:

# Place a tool at the given position
func place_tool(grid_pos: Vector3i, tool_type: String) -> bool:
	if tool_type == "remove_tool":
		return remove_tool_at(grid_pos)
	
	# Check if position already has a tool
	if farm_data.get_tool_at(grid_pos.x, grid_pos.z) != "":
		print("LevelEditor: Position already has a tool")
		return false
	
	# Try to purchase the tool
	if not farm_data.try_purchase_tool(tool_type):
		print("LevelEditor: Can't afford tool of type " + tool_type)
		return false
	
	# Place the tool in farm data
	if farm_data.place_tool(grid_pos.x, grid_pos.z, tool_type):
		# Spawn the actual tool object
		spawn_tool(grid_pos, tool_type)
		
		# IMPORTANT: Also unlock the corresponding seed for seed dispensers
		if tool_type == "carrot_seeds":
			farm_data.unlock_seed("carrot")
			print("LevelEditor: Unlocked carrot seeds")
		elif tool_type == "tomato_seeds":
			farm_data.unlock_seed("tomato")
			print("LevelEditor: Unlocked tomato seeds")
			
		# Save the updated farm data
		farm_data.save()
		
		# Update UI
		update_currency_display()
		
		print("LevelEditor: Placed " + tool_type + " at " + str(grid_pos))
		return true
	
	return false

# Remove a tool at the given position
func remove_tool_at(grid_pos: Vector3i) -> bool:
	# Check if there's a tool at this position
	var tool_type = farm_data.get_tool_at(grid_pos.x, grid_pos.z)
	if tool_type == "":
		return false
	
	# Remove from farm data
	if farm_data.remove_tool(grid_pos.x, grid_pos.z):
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

# Spawn all tools saved in farm data
func spawn_saved_tools():
	# Clear any existing editor tools first
	remove_editor_tools()
	
	# Get all placed tools from farm data
	var tool_placement = farm_data.get_all_placed_tools()
	
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
func _input(event):
	if not is_editing or not visible:
		return
	
	# Handle mouse input for tile/tool placement
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
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
					var has_tool = farm_data.get_tool_at(grid_pos.x, grid_pos.z) != ""
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
	
	# Reload original farm data
	farm_data = FarmData.load_data()
	
	print("LevelEditor: Canceled changes")
	
	# Stop editing
	stop_editing()
	
	# Emit signal
	emit_signal("editor_canceled")

# Save changes
func save_changes():
	# Save farm data
	farm_data.save()
	
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
	
	# Reset FarmData progression
	if farm_data:
		farm_data.reset_progression()
	else:
		# Create new farm data if none exists
		farm_data = FarmData.load_data()
		farm_data.reset_progression()
	
	# Reset to initial farm layout
	if level_manager:
		var success = farm_data.reset_to_initial_layout(level_manager)
		if not success:
			push_error("LevelEditor: Failed to reset to initial farm layout!")
	
	# Remove all tools
	remove_editor_tools()
	
	# Update currency display
	update_currency_display()
	
	# Show success message
	var popup = AcceptDialog.new()
	popup.title = "Farm Reset"
	popup.dialog_text = "Farm has been reset to its original layout!"
	popup.dialog_hide_on_ok = true
	get_tree().root.add_child(popup)
	popup.popup_centered()

# Helper method to set tile type that works during reset
func set_tile_type(grid_position: Vector3i, type: int) -> bool:
	if not level_manager:
		return false
		
	# Use the LevelManager's method to set the tile
	var result = level_manager.set_tile_type(grid_position, type)
	
	# Also update the farm data directly
	if farm_data and result:
		farm_data.set_tile(grid_position.x, grid_position.z, type)
		
	return result
