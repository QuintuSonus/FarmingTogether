# scripts/editor/LevelEditor.gd
extends Node3D

# References
var level_manager: LevelManager = null # Changed type hint for clarity
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
var farm_bounds: Rect2 = Rect2(-8, -8, 20, 20)  # Keeps track of potentially expanded bounds (used for highlighting range)

# --- NEW: Variables for UI Hover and Initial Bounds ---
var is_mouse_over_ui: bool = false # Flag to track if mouse is over the EditorUI
var initial_grid_bounds: Rect2i = Rect2i() # Stores the Rect2i bounds of the initial GridMap layout

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
			
		# --- NEW: Connect UI mouse signals ---
		# Ensure the EditorUI control node has mouse_filter set to PASS or STOP in the inspector
		# or set it here if needed: editor_ui.mouse_filter = Control.MOUSE_FILTER_PASS
		if not editor_ui.is_connected("mouse_entered", Callable(self, "_on_EditorUI_mouse_entered")):
			editor_ui.connect("mouse_entered", Callable(self, "_on_EditorUI_mouse_entered"))
		if not editor_ui.is_connected("mouse_exited", Callable(self, "_on_EditorUI_mouse_exited")):
			editor_ui.connect("mouse_exited", Callable(self, "_on_EditorUI_mouse_exited"))
	
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
			if not game_data_manager.is_connected("data_changed", Callable(self, "_on_game_data_changed")):
				game_data_manager.connect("data_changed", Callable(self, "_on_game_data_changed"))

	# Initially hide editor (will be shown by Main when appropriate)
	hide()
	
	print("LevelEditor: Initialized with UI hidden")
	
	# Initialize the upgrades list 
	initialize_upgrades()

# --- NEW: Signal handlers for UI mouse hover ---
func _on_EditorUI_mouse_entered():
	is_mouse_over_ui = true
	# Optional: Hide highlighter immediately when mouse enters UI
	if tile_highlighter and tile_highlighter.visible:
		tile_highlighter.visible = false
	# print("Mouse entered UI") # Debug

func _on_EditorUI_mouse_exited():
	is_mouse_over_ui = false
	# print("Mouse exited UI") # Debug

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
			push_warning("LevelEditor: LevelManager found, but GridMap node is missing!")
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

# --- NEW: Calculate and store initial bounds ---
# Calculates the bounding box of the tiles present on the GridMap when the editor starts.
func calculate_initial_farm_bounds():
	if not grid_map:
		initial_grid_bounds = Rect2i(0,0,0,0) # Default empty bounds
		push_warning("LevelEditor: Cannot calculate initial bounds - GridMap reference not found.")
		return

	var used_cells = grid_map.get_used_cells()
	if used_cells.size() == 0:
		initial_grid_bounds = Rect2i(0,0,1,1) # Default to a single tile at origin if map is empty
		print("LevelEditor: No initial tiles found on GridMap. Defaulting initial bounds to origin.")
		return

	var min_x = INF
	var min_z = INF
	var max_x = -INF
	var max_z = -INF

	# Iterate through all cells that have a tile placed in the editor
	for cell in used_cells:
		min_x = min(min_x, cell.x)
		min_z = min(min_z, cell.z)
		max_x = max(max_x, cell.x)
		max_z = max(max_z, cell.z)

	# Create a Rect2i representing the bounds (position is min corner, size is width/height)
	initial_grid_bounds = Rect2i(min_x, min_z, max_x - min_x + 1, max_z - min_z + 1)
	print("LevelEditor: Calculated initial farm bounds: ", initial_grid_bounds)


# Calculate farm bounds from existing tiles (Used for highlight range, can be dynamic)
func calculate_farm_bounds():
	if not level_manager:
		return
	
	var min_x = 0; var min_z = 0; var max_x = 0; var max_z = 0
	var found_tiles = false
	
	# Use LevelManager's bounds if available, otherwise check a wide area
	if level_manager.has_method("get_actual_bounds"):
		var lm_bounds = level_manager.get_actual_bounds()
		if lm_bounds.size.x > 0 and lm_bounds.size.y > 0:
			min_x = lm_bounds.position.x
			min_z = lm_bounds.position.y
			max_x = lm_bounds.end.x
			max_z = lm_bounds.end.y
			found_tiles = true
	
	if not found_tiles: # Fallback check if LevelManager bounds not available
		min_x = INF; min_z = INF; max_x = -INF; max_z = -INF
		for x in range(-20, 20):
			for z in range(-20, 20):
				var pos = Vector3i(x, 0, z)
				var tile_type = level_manager.get_tile_type(pos)
				if tile_type != -1: # Consider any valid tile
					min_x = min(min_x, x)
					min_z = min(min_z, z)
					max_x = max(max_x, x + 1)
					max_z = max(max_z, z + 1)
					found_tiles = true
		if not found_tiles:
			min_x = 0; min_z = 0; max_x = 1; max_z = 1 # Default if still no tiles

	# Add padding around the bounds for highlight range
	min_x -= 2; min_z -= 2; max_x += 2; max_z += 2
	
	farm_bounds = Rect2(min_x, min_z, max_x - min_x, max_z - min_z)
	print("LevelEditor: Calculated dynamic farm bounds (for highlight): ", farm_bounds)

# Called when editor is activated
func start_editing():
	print("LevelEditor: start_editing called")
	
	# Ensure GridMap reference is valid before calculating bounds
	if not grid_map:
		push_error("LevelEditor: GridMap reference is null in start_editing!")
		# Attempt to get it again if connect_nodes was deferred
		if level_manager and level_manager.has_node("GridMap"):
			grid_map = level_manager.get_node("GridMap")
		if not grid_map:
			push_error("LevelEditor: Cannot start editing - GridMap still not found!")
			return

	# --- NEW: Calculate and store initial bounds ---
	calculate_initial_farm_bounds() 
	
	# Calculate dynamic bounds (used for highlight range)
	calculate_farm_bounds() 
	
	# --- (Rest of the start_editing logic remains the same) ---
	if not level_manager: # Check LevelManager again after potential deferred connection
		push_error("LevelEditor: Cannot start editing - LevelManager reference missing!")
		return
		
	if not game_data:
		print("LevelEditor: game_data is null, trying to get from ServiceLocator")
		var service_locator = get_node_or_null("/root/ServiceLocator")
		if service_locator:
			game_data = service_locator.get_service("game_data")
			game_data_manager = service_locator.get_service("game_data_manager")
		if not game_data:
			push_error("LevelEditor: Cannot start editing - game data not found!")
			return
	
	show()
	if editor_ui:
		editor_ui.visible = true
		if editor_ui.has_method("update_currency_display"):
			editor_ui.update_currency_display()
	
	hide_game_ui()
	pause_gameplay()
	
	if editor_camera:
		editor_camera.current = true
	
	save_original_state() # Saves state *within initial bounds* potentially
	
	is_editing = true
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
	elif main_camera: # Fallback for Camera3D
		main_camera.current = true

	# Remove all editor-placed tools
	remove_editor_tools()
	
	# Set editor as inactive
	is_editing = false
	
	print("LevelEditor: Stopped editing mode and restored game UI")


# --- (find_gameplay_nodes, find_game_ui_elements, hide_game_ui, restore_game_ui, pause_gameplay, resume_gameplay remain the same) ---
func find_gameplay_nodes():
	var main = get_node("/root/Main")
	if not main: return
	gameplay_nodes.clear()
	original_process_modes.clear()
	if not main_camera: # Find main camera if not set already
		main_camera = main.get_node_or_null("Camera3D")
		if not main_camera:
			for camera in get_tree().get_nodes_in_group("cameras"):
				if camera != editor_camera: main_camera = camera; break
	var key_nodes = ["Player", "OrderManager", "PlayerManager"] # Add other key nodes
	for node_name in key_nodes:
		var node = main.get_node_or_null(node_name)
		if node: gameplay_nodes.append(node)
	gameplay_nodes.append_array(get_tree().get_nodes_in_group("plants"))
	var tools = get_tree().get_nodes_in_group("tools") # Assuming tools are grouped
	for tool_node in tools: gameplay_nodes.append(tool_node)
	print("LevelEditor: Found " + str(gameplay_nodes.size()) + " gameplay nodes")

func find_game_ui_elements():
	game_ui_elements.clear()
	game_ui_visibility_states.clear()
	var ui_layer_node = get_node_or_null("/root/Main/UILayer") # Adjust path if needed
	if ui_layer_node:
		for child in ui_layer_node.get_children():
			if "Debug" not in child.name and child.name != "EditorUI": game_ui_elements.append(child)
	# Explicitly add known UI roots if needed
	var order_ui = get_node_or_null("/root/Main/UILayer/OrderUI")
	if order_ui and not game_ui_elements.has(order_ui): game_ui_elements.append(order_ui)
	print("LevelEditor: Found " + str(game_ui_elements.size()) + " game UI elements")

func hide_game_ui():
	if game_ui_elements.size() == 0: find_game_ui_elements()
	for ui_element in game_ui_elements:
		if is_instance_valid(ui_element):
			game_ui_visibility_states[ui_element] = ui_element.visible
			ui_element.visible = false
	print("LevelEditor: Hid " + str(game_ui_visibility_states.size()) + " game UI elements")

func restore_game_ui():
	for ui_element in game_ui_visibility_states:
		if is_instance_valid(ui_element):
			ui_element.visible = game_ui_visibility_states[ui_element]
	game_ui_visibility_states.clear()
	print("LevelEditor: Restored game UI elements")

func pause_gameplay():
	if gameplay_nodes.size() == 0: find_gameplay_nodes()
	for node in gameplay_nodes:
		if is_instance_valid(node) and node.has_method("set_process_mode"): # Check method exists
			original_process_modes[node] = node.process_mode
			node.process_mode = Node.PROCESS_MODE_DISABLED
	print("LevelEditor: Paused " + str(original_process_modes.size()) + " gameplay nodes")

func resume_gameplay():
	for node in original_process_modes:
		if is_instance_valid(node) and node.has_method("set_process_mode"):
			node.process_mode = original_process_modes[node]
	original_process_modes.clear()
	print("LevelEditor: Resumed gameplay nodes")


# Save original tile states for cancel operation
func save_original_state():
	original_tile_states.clear()
	if not level_manager: return
	
	# Iterate over the *initial* bounds to save the state within that area
	if initial_grid_bounds.size.x <= 0 or initial_grid_bounds.size.y <= 0:
		print("LevelEditor: Cannot save original state - initial bounds invalid.")
		return

	for x in range(initial_grid_bounds.position.x, initial_grid_bounds.end.x):
		for z in range(initial_grid_bounds.position.y, initial_grid_bounds.end.y):
			var pos = Vector3i(x, 0, z)
			var tile_type = level_manager.get_tile_type(pos)
			original_tile_states[pos] = tile_type # Store all types within initial bounds

	print("LevelEditor: Saved original state of " + str(original_tile_states.size()) + " tiles within initial bounds.")

# Set up the highlight mesh
func setup_highlight_mesh():
	# Check if we already have tile_highlighter and highlight_mesh from the scene
	if not tile_highlighter:
		tile_highlighter = Node3D.new(); tile_highlighter.name = "TileHighlighter"
		add_child(tile_highlighter); print("LevelEditor: Created new TileHighlighter")
	if not highlight_mesh:
		highlight_mesh = MeshInstance3D.new(); highlight_mesh.name = "MeshInstance3D"
		tile_highlighter.add_child(highlight_mesh); print("LevelEditor: Created new highlight mesh")
	
	var plane = PlaneMesh.new(); plane.size = Vector2(0.95, 0.95)
	highlight_mesh.mesh = plane
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0, 1, 0, 0.5) # Default green
	highlight_mesh.material_override = material
	tile_highlighter.visible = false
	print("LevelEditor: Highlight mesh set up")

# Select a tile type
func select_tile_type(type_name: String):
	selected_tile_type = type_name
	selected_tool_type = "none"
	is_placing_tool = false
	# UI update handled by EditorUI
	print("LevelEditor: Selected tile type: " + type_name)

# Select a tool type for placement
func select_tool_type(tool_type: String):
	selected_tool_type = tool_type
	selected_tile_type = "none"
	is_placing_tool = true
	# UI update handled by EditorUI
	print("LevelEditor: Selected tool type: " + tool_type)

# Check if a tile can be placed (Affordability)
func can_place_tile(grid_pos: Vector3i, type_name: String) -> bool:
	# Don't replace with same type (optional check, LevelManager might handle this)
	# var current_type = level_manager.get_tile_type(grid_pos)
	# var new_type = tile_type_mapping.get(type_name, -1)
	# if current_type == new_type: return false
	
	var cost = get_tile_cost(type_name)
	if not game_data or not game_data.progression_data: return false
	return game_data.progression_data.currency >= cost

# Place a tile at the given position (Bounds check happens in _input)
func place_tile(grid_pos: Vector3i, type_name: String) -> bool:
	if not level_manager or not grid_map: return false
	
	var new_type = tile_type_mapping.get(type_name, -1)
	if new_type == -1: return false # Invalid type name
	
	# Affordability check
	var cost = get_tile_cost(type_name)
	if not game_data or not game_data.progression_data or game_data.progression_data.currency < cost:
		print("LevelEditor: Can't afford tile type " + type_name)
		return false
	
	# Deduct currency
	game_data.progression_data.currency -= cost
	
	# Update the tile via LevelManager
	if level_manager.set_tile_type(grid_pos, new_type):
		# Update game data persistence
		if game_data_manager:
			game_data_manager.set_tile(grid_pos.x, grid_pos.z, new_type)
			
		# Special logic for unlocking seeds when placing dispensers
		if type_name == "tomato_dispenser":
			if game_data and game_data.progression_data:
				if not game_data.progression_data.unlocked_seeds.has("tomato"):
					game_data.progression_data.unlocked_seeds.append("tomato")
					print("LevelEditor: Unlocked 'tomato' seeds.")
					# Notify OrderManager if needed
					var order_manager = get_node_or_null("/root/Main/OrderManager")
					if order_manager and order_manager.has_method("update_available_crops"):
						order_manager.update_available_crops()
		
		# Update UI
		if editor_ui and editor_ui.has_method("update_currency_display"):
			editor_ui.update_currency_display()
		
		print("LevelEditor: Placed " + type_name + " tile at " + str(grid_pos))
		return true
	else:
		# Refund if set_tile_type failed (e.g., invalid type)
		game_data.progression_data.currency += cost
		return false

# Get the cost of a tile type
func get_tile_cost(type_name: String) -> int:
	return tile_prices.get(type_name, 99999) # Return high cost if not found

# Check if a tool can be placed (Affordability and Occupancy)
func can_place_tool(grid_pos: Vector3i, tool_type: String) -> bool:
	# Handle remove tool case
	if tool_type == "remove_tool":
		var tool_at_pos = game_data_manager.get_tool_at(grid_pos.x, grid_pos.z) if game_data_manager else ""
		return tool_at_pos != ""
	
	# Check if position already has a tool
	var has_tool = game_data_manager.get_tool_at(grid_pos.x, grid_pos.z) != "" if game_data_manager else false
	if has_tool: return false
	
	# Check affordability
	var cost = get_tool_cost(tool_type)
	if not game_data or not game_data.progression_data: return false
	return game_data.progression_data.currency >= cost

# Get the cost of a tool type
func get_tool_cost(tool_type: String) -> int:
	return tool_prices.get(tool_type, 99999) # Return high cost if not found

# Place a tool at the given position (Bounds check happens in _input)
func place_tool(grid_pos: Vector3i, tool_type: String) -> bool:
	if tool_type == "remove_tool":
		return remove_tool_at(grid_pos)
	
	if not game_data or not game_data.progression_data or not game_data_manager: return false
	
	# Check occupancy and affordability again (redundant if checked before calling, but safe)
	if not can_place_tool(grid_pos, tool_type):
		print("LevelEditor: Cannot place tool (occupied or cannot afford)")
		return false
		
	var cost = get_tool_cost(tool_type)
	game_data.progression_data.currency -= cost
	
	# Place the tool in game data
	if game_data_manager.place_tool(grid_pos.x, grid_pos.z, tool_type):
		spawn_tool(grid_pos, tool_type) # Spawn visual representation
		# Update UI
		if editor_ui and editor_ui.has_method("update_currency_display"):
			editor_ui.update_currency_display()
		print("LevelEditor: Placed " + tool_type + " at " + str(grid_pos))
		return true
	else:
		# Refund if placement failed
		game_data.progression_data.currency += cost
		return false

# Remove a tool at the given position
func remove_tool_at(grid_pos: Vector3i) -> bool:
	if not game_data_manager: return false
	var tool_type = game_data_manager.get_tool_at(grid_pos.x, grid_pos.z)
	if tool_type == "": return false
	
	# Remove from game data
	if game_data_manager.remove_tool(grid_pos.x, grid_pos.z):
		# Find and remove the visual tool object
		var tool_key = "editor_tool_" + str(grid_pos.x) + "_" + str(grid_pos.z)
		var tool_node = get_node_or_null(tool_key)
		if tool_node: tool_node.queue_free()
		print("LevelEditor: Removed " + tool_type + " from " + str(grid_pos))
		# Optional: Refund part of the cost?
		# game_data.progression_data.currency += get_tool_cost(tool_type) * 0.5 # Example refund
		# if editor_ui: editor_ui.update_currency_display()
		return true
	return false

# Spawn a tool visual in the world
func spawn_tool(grid_pos: Vector3i, tool_type: String):
	if not tool_scenes.has(tool_type):
		push_error("LevelEditor: No scene path for tool type: " + tool_type); return
	var scene_path = tool_scenes[tool_type]
	var tool_scene = load(scene_path)
	if not tool_scene:
		push_error("LevelEditor: Failed to load tool scene: " + scene_path); return
	
	var tool_instance = tool_scene.instantiate()
	var tool_key = "editor_tool_" + str(grid_pos.x) + "_" + str(grid_pos.z)
	tool_instance.name = tool_key
	add_child(tool_instance) # Add as child of LevelEditor
	
	var world_pos = level_manager.grid_to_world(grid_pos) # Use LevelManager conversion
	tool_instance.global_position = world_pos + Vector3(0, 0.1, 0) # Place slightly above ground
	tool_instance.add_to_group("editor_tools")
	print("LevelEditor: Spawned visual for " + tool_type + " at " + str(world_pos))

# Spawn all tools saved in game data
func spawn_saved_tools():
	remove_editor_tools() # Clear existing visuals
	if not game_data_manager: return
	var tool_placement = game_data_manager.get_all_placed_tools()
	for key in tool_placement:
		var coords = key.split(","); var x = int(coords[0]); var z = int(coords[1])
		var tool_type = tool_placement[key]
		spawn_tool(Vector3i(x, 0, z), tool_type)
	print("LevelEditor: Spawned visuals for " + str(tool_placement.size()) + " saved tools")

# Remove all editor-placed tool visuals
func remove_editor_tools():
	var editor_tools = get_tree().get_nodes_in_group("editor_tools")
	for tool_node in editor_tools:
		tool_node.queue_free()
	# print("LevelEditor: Removed " + str(editor_tools.size()) + " editor tool visuals") # Less verbose

# --- MODIFIED: Input handling with UI hover and bounds check ---
func _input(event):
	if not is_editing or not visible:
		return

	# --- NEW: Check if mouse is over UI ---
	# We use the is_mouse_over_ui flag updated by signals
	if is_mouse_over_ui and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# If mouse is over UI during a click, consume the event and do nothing else
		# This prevents placing tiles/tools behind the UI.
		# print("Input blocked: Mouse over UI") # Debug
		get_viewport().set_input_as_handled() # Optional: prevent other controls from getting the click
		return 

	# Handle mouse click for tile/tool placement (only if mouse is NOT over UI)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_viewport().get_mouse_position()
		var from = editor_camera.project_ray_origin(mouse_pos)
		var to = from + editor_camera.project_ray_normal(mouse_pos) * 1000 # Increased ray length
		
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		query.collide_with_areas = false # Usually only need bodies (GridMap)
		query.collide_with_bodies = true
		# query.collision_mask = 1 # Optional: Target specific physics layer for the ground/GridMap
		var result = space_state.intersect_ray(query)
		
		if result and result.has("position"):
			var hit_pos = result.position
			var grid_pos = level_manager.world_to_grid(hit_pos)
			
			# --- MODIFIED: Use initial bounds check for placement ---
			if is_position_in_initial_bounds(grid_pos): 
				if is_placing_tool:
					if selected_tool_type != "none":
						# Place tool (affordability checked inside place_tool)
						place_tool(grid_pos, selected_tool_type)
				else:
					if selected_tile_type != "none":
						# Place tile (affordability checked inside place_tile)
						place_tile(grid_pos, selected_tile_type)
			else:
				# Click was outside the allowed initial area
				print("LevelEditor: Cannot place - Position " + str(grid_pos) + " is outside initial farm bounds: " + str(initial_grid_bounds))
				# Optionally provide feedback (e.g., sound, temporary message)
		else:
			# Raycast didn't hit anything relevant
			# print("LevelEditor: Click raycast missed GridMap/ground.") # Debug
			pass
	
	# Update highlights on mouse movement
	if event is InputEventMouseMotion:
		# --- NEW: Only update highlight if mouse is NOT over UI ---
		if not is_mouse_over_ui:
			update_highlights()
		# else: # Highlight is hidden automatically when mouse enters UI via _on_EditorUI_mouse_entered


# --- NEW: Helper method to check if a position is within the *initial* farm bounds ---
func is_position_in_initial_bounds(grid_pos: Vector3i) -> bool:
	# Check if initial_grid_bounds has a valid size (width and height > 0)
	if initial_grid_bounds.size.x <= 0 or initial_grid_bounds.size.y <= 0:
		# If no initial bounds were set (e.g., empty map), placement is disallowed.
		# print("Warning: Initial grid bounds are invalid or not set. Placement disallowed.") # Debug
		return false 
		
	# Use Rect2i's has_point method to check if the grid position is within the bounds
	return initial_grid_bounds.has_point(Vector2i(grid_pos.x, grid_pos.z))


# Helper method to check if a position is within the *dynamic* farm bounds (used for highlight range)
func is_position_in_bounds(grid_pos: Vector3i) -> bool:
	# Check if farm_bounds has a valid size
	if farm_bounds.size.x <= 0 or farm_bounds.size.y <= 0:
		return false
	# Use Rect2's has_point method (note: farm_bounds is Rect2, not Rect2i)
	return farm_bounds.has_point(Vector2(grid_pos.x, grid_pos.z))

# Update highlighters based on selected mode (tile or tool)
func update_highlights():
	if not tile_highlighter or not highlight_mesh or not editor_camera or not level_manager:
		tile_highlighter.visible = false # Ensure hidden if refs are bad
		return
	
	if is_placing_tool:
		update_tool_highlight()
	else:
		update_tile_highlight()

# Update the tile highlighter
func update_tile_highlight():
	var mouse_pos = get_viewport().get_mouse_position()
	var from = editor_camera.project_ray_origin(mouse_pos)
	var to = from + editor_camera.project_ray_normal(mouse_pos) * 1000
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false; query.collide_with_bodies = true
	# query.collision_mask = 1 # Optional layer mask
	var result = space_state.intersect_ray(query)
	
	if result and result.has("position"):
		var hit_pos = result.position
		var grid_pos = level_manager.world_to_grid(hit_pos)
		
		# Check if the hit position is within the dynamic bounds for highlighting range
		if is_position_in_bounds(grid_pos):
			var world_pos = level_manager.grid_to_world(grid_pos)
			tile_highlighter.global_position = world_pos + Vector3(0, 0.01, 0) # Slightly above ground
			tile_highlighter.visible = true
			
			# Determine color based on affordability AND if it's within initial bounds
			var can_afford_and_in_initial_bounds = false
			if selected_tile_type != "none" and is_position_in_initial_bounds(grid_pos):
				can_afford_and_in_initial_bounds = can_place_tile(grid_pos, selected_tile_type)

			var material = highlight_mesh.material_override
			if material:
				material.albedo_color = Color(0, 1, 0, 0.5) if can_afford_and_in_initial_bounds else Color(1, 0, 0, 0.5)
			return # Keep highlighter visible

	# Hide highlighter if no valid hit or outside dynamic bounds
	tile_highlighter.visible = false

# Update the tool placement highlighter
func update_tool_highlight():
	var mouse_pos = get_viewport().get_mouse_position()
	var from = editor_camera.project_ray_origin(mouse_pos)
	var to = from + editor_camera.project_ray_normal(mouse_pos) * 1000
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false; query.collide_with_bodies = true
	# query.collision_mask = 1 # Optional layer mask
	var result = space_state.intersect_ray(query)
	
	if result and result.has("position"):
		var hit_pos = result.position
		var grid_pos = level_manager.world_to_grid(hit_pos)
		
		# Check if the hit position is within the dynamic bounds for highlighting range
		if is_position_in_bounds(grid_pos):
			var world_pos = level_manager.grid_to_world(grid_pos)
			tile_highlighter.global_position = world_pos + Vector3(0, 0.01, 0)
			tile_highlighter.visible = true
			
			# Determine color based on validity AND if it's within initial bounds
			var can_afford_and_in_initial_bounds = false
			var can_remove_in_initial_bounds = false

			if is_position_in_initial_bounds(grid_pos): # Check initial bounds first
				if selected_tool_type == "remove_tool":
					can_remove_in_initial_bounds = can_place_tool(grid_pos, selected_tool_type) # can_place_tool handles remove check
				elif selected_tool_type != "none":
					can_afford_and_in_initial_bounds = can_place_tool(grid_pos, selected_tool_type)

			var material = highlight_mesh.material_override
			if material:
				if selected_tool_type == "remove_tool":
					material.albedo_color = Color(1, 0.5, 0, 0.5) if can_remove_in_initial_bounds else Color(0.5, 0.5, 0.5, 0.3)
				elif can_afford_and_in_initial_bounds:
					material.albedo_color = Color(0, 1, 0, 0.5)
				else:
					material.albedo_color = Color(1, 0, 0, 0.5) # Red if outside initial bounds or cannot afford/place
			return # Keep highlighter visible

	# Hide highlighter if no valid hit or outside dynamic bounds
	tile_highlighter.visible = false


# Cancel editing and revert changes
func cancel_editing():
	# Restore original state from saved dictionary
	if level_manager:
		# First, clear tiles that were added beyond the original state
		var current_tiles = level_manager.tile_states.keys() # Assuming LevelManager tracks state
		for pos in current_tiles:
			if not original_tile_states.has(pos):
				level_manager.set_tile_type(pos, level_manager.TileType.REGULAR_GROUND) # Or -1 to clear mesh
				
		# Then, restore the original tiles
		for pos in original_tile_states:
			var type = original_tile_states[pos]
			level_manager.set_tile_type(pos, type)
			
	# Reload game data to revert currency/tool placements etc.
	if game_data_manager and game_data_manager.has_method("load_game_data"): # Assuming GDM handles loading
		game_data_manager.load_game_data() 
	elif game_data and game_data.has_method("load_data"): # Fallback to GameData static load
		game_data = GameData.load_data()
		if game_data_manager: game_data_manager.game_data = game_data # Update GDM reference
		
	print("LevelEditor: Canceled changes, reverted state.")
	stop_editing()
	emit_signal("editor_canceled")

# Save changes
func save_changes():
	# Save game data (includes tile/tool placements, currency)
	if game_data_manager and game_data_manager.has_method("save_game_data"):
		game_data_manager.save_game_data()
	elif game_data and game_data.has_method("save"):
		game_data.save()
		
	print("LevelEditor: Saved changes.")
	stop_editing()
	emit_signal("editor_saved")

# Start the next run
func start_next_level():
	save_changes() # Save editor changes before starting
	var main = get_node_or_null("/root/Main")
	if main and main.has_method("start_next_level"):
		main.start_next_level()
	else:
		push_error("LevelEditor: Could not find Main.start_next_level()")

# Handle visibility changes
func _on_visibility_changed():
	if editor_ui: editor_ui.visible = visible
	if visible and not is_editing: start_editing()
	elif not visible and is_editing: stop_editing()

# Reset the farm progression (uses GameDataManager)
func reset_farm_progression():
	print("LevelEditor: Resetting farm progression via GameDataManager")
	if game_data_manager and game_data_manager.has_method("reset_progression"):
		game_data_manager.reset_progression()
		# Apply default layout after reset
		if game_data_manager.has_method("apply_default_farm_layout"):
			game_data_manager.apply_default_farm_layout()
			# Recalculate initial bounds based on the new default layout
			calculate_initial_farm_bounds() 
			# Also update dynamic bounds
			calculate_farm_bounds()
	
	remove_editor_tools() # Remove visuals
	if editor_ui: editor_ui.update_currency_display()
	
	var popup = AcceptDialog.new(); popup.title = "Farm Reset"
	popup.dialog_text = "Farm progression has been reset!"; popup.dialog_hide_on_ok = true
	get_tree().root.add_child(popup); popup.popup_centered()
	
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
	# Update the info panel and handle purchase logic
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
			
