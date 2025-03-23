# scripts/Main.gd
extends Node3D

# Configuration for the camera
@export var camera_follow_player: bool = true
@export var camera_height: float = 10.0
@export var camera_distance: float = 5.0
@export var camera_angle: float = -60.0  # In degrees

# Multiplayer camera parameters
@export var camera_min_distance: float = 8.0  # Minimum distance for zoom
@export var camera_padding: float = 5.0  # Extra space around players

# Game state
var game_running: bool = false
var current_level: int = 1
var current_score: int = 0

# Level editor reference
var level_editor = null

# Keep track of the main camera
var main_camera = null

# Reference to key nodes
var level_manager: Node = null
var order_manager: Node = null
var player_manager: Node = null
var ui_layer: CanvasLayer = null

func _ready():
	# Initialize references to main nodes
	level_manager = $LevelManager
	order_manager = $OrderManager if has_node("OrderManager") else null
	player_manager = $PlayerManager if has_node("PlayerManager") else null
	ui_layer = $UILayer if has_node("UILayer") else null
	
	# Get reference to main camera
	main_camera = $Camera3D
	if main_camera:
		main_camera.add_to_group("cameras")
	
	# Load level editor
	var editor_scene = load("res://scenes/editor/LevelEditor.tscn")
	if editor_scene:
		level_editor = editor_scene.instantiate()
		add_child(level_editor)
		
		# Connect editor signals
		level_editor.connect("editor_closed", Callable(self, "_on_editor_closed"))
		level_editor.connect("editor_saved", Callable(self, "_on_editor_saved"))
		level_editor.connect("editor_canceled", Callable(self, "_on_editor_canceled"))
		
		print("Main: Level editor loaded")
	else:
		push_error("Main: Failed to load LevelEditor scene!")
	
	# Add debug button for editor testing (only in debug mode)
	if OS.is_debug_build():
		add_debug_ui()
	
	# NEW: Save the initial farm layout from Main.tscn
	save_initial_farm_layout()
	# Apply saved farm layout if it exists
	apply_saved_farm_layout()
	
	# Set up camera
	setup_camera()
	
	# Connect order manager signals
	if order_manager:
		order_manager.connect("level_time_updated", Callable(self, "_on_level_time_updated"))
	
	# Show gameplay UI
	show_gameplay_ui()
	
	# Start the game
	start_game()
	
	print("Main: Game initialized")

# Set up the camera
func setup_camera():
	if camera_follow_player and main_camera:
		update_camera_position(0)

# Process frame update
func _process(delta):
	# Update camera position to follow player if enabled
	if game_running and camera_follow_player and main_camera and main_camera.current:
		update_camera_position(delta)

# Update camera to follow players
func update_camera_position(delta):
	var camera_targets = []
	
	# Get players to follow from player manager if available
	if player_manager and player_manager.has_method("get_players"):
		camera_targets = player_manager.get_players()
	elif player_manager and player_manager.has("players"):
		camera_targets = player_manager.players
	# Fallback to direct player reference
	elif has_node("Player"):
		camera_targets = [$Player]
	
	# No targets to follow
	if camera_targets.size() == 0:
		return
	
	# Single player case - use existing behavior
	if camera_targets.size() == 1 and camera_targets[0]:
		var target_pos = camera_targets[0].global_position
		
		# Offset the camera by distance and height
		var camera_offset = Vector3(0, camera_height, camera_distance)
		
		# Apply rotation based on camera angle
		var angle_rad = deg_to_rad(camera_angle)
		var rotated_offset = Vector3(
			camera_offset.z * sin(angle_rad),
			camera_offset.y,
			camera_offset.z * cos(angle_rad)
		)
		
		# Set camera position and look at player
		main_camera.global_position = target_pos + rotated_offset
		main_camera.look_at(target_pos, Vector3.UP)
		return
	
	# Multiple players - calculate bounding box
	var min_pos = Vector3(INF, INF, INF)
	var max_pos = Vector3(-INF, -INF, -INF)
	var center = Vector3.ZERO
	var valid_targets = 0
	
	for target in camera_targets:
		if target and is_instance_valid(target):
			var pos = target.global_position
			min_pos.x = min(min_pos.x, pos.x)
			min_pos.z = min(min_pos.z, pos.z)
			max_pos.x = max(max_pos.x, pos.x)
			max_pos.z = max(max_pos.z, pos.z)
			center += pos
			valid_targets += 1
	
	if valid_targets == 0:
		return  # No valid targets
	
	center /= valid_targets
	
	# Calculate required distance based on player spread
	var width = max_pos.x - min_pos.x + camera_padding * 2
	var depth = max_pos.z - min_pos.z + camera_padding * 2
	
	# Calculate distance needed to keep all players in view
	var distance_for_width = width / (2.0 * tan(deg_to_rad(main_camera.fov) / 2.0))
	var distance_for_depth = depth / (2.0 * tan(deg_to_rad(main_camera.fov) / 2.0))
	var required_distance = max(distance_for_width, distance_for_depth)
	required_distance = max(required_distance, camera_min_distance)
	
	# Calculate camera position
	var angle_rad = deg_to_rad(camera_angle)
	var camera_pos = center + Vector3(
		required_distance * sin(angle_rad),
		camera_height,
		required_distance * cos(angle_rad)
	)
	
	# Set camera position and look at center of players
	main_camera.global_position = camera_pos
	main_camera.look_at(center, Vector3.UP)

# Helper function to show gameplay UI
func show_gameplay_ui():
	if ui_layer:
		# Show all gameplay UI elements
		for child in ui_layer.get_children():
			# Skip debug buttons in release builds
			if not OS.is_debug_build() and ("debug" in child.name.to_lower() or "editor" in child.name.to_lower()):
				continue
				
			# Skip the level editor UI if it somehow got added to UILayer
			if "editorui" in child.name.to_lower():
				continue
				
			# Show all other UI elements
			child.visible = true
		
		print("Main: Showed gameplay UI")

# Helper function to hide gameplay UI
func hide_gameplay_ui():
	if ui_layer:
		# Hide all gameplay UI elements
		var hidden_count = 0
		for child in ui_layer.get_children():
			# Skip debug buttons
			if "debug" in child.name.to_lower() or "editor" in child.name.to_lower():
				continue
				
			child.visible = false
			hidden_count += 1
		
		print("Main: Hid " + str(hidden_count) + " gameplay UI elements")

# Start the game
func start_game():
	game_running = true
	
	# Ensure the correct camera is active
	if main_camera:
		main_camera.current = true
	
	# Start order generation
	if order_manager:
		# This would normally be more complex, but for now,
		# just make sure it's properly initialized
		print("Main: Starting order manager")
	
	print("Main: Game started")

# Apply saved farm layout from farm data
func apply_saved_farm_layout():
	if not level_manager:
		return
		
	var farm_data = FarmData.load_data()
	
	# Apply all saved tiles
	for key in farm_data.tile_data.keys():
		var coords = key.split(",")
		var x = int(coords[0])
		var z = int(coords[1])
		var type = farm_data.tile_data[key]
		
		var pos = Vector3i(x, 0, z)
		level_manager.set_tile_type(pos, type)
	
	print("Main: Applied saved farm layout with " + str(farm_data.tile_data.size()) + " custom tiles")

# Function to show the editor when level is completed
func on_level_completed(score: int, currency_earned: int):
	# Update farm data with earned currency
	var farm_data = FarmData.load_data()
	farm_data.currency += currency_earned
	farm_data.save()
	
	# Update game state
	game_running = false
	current_level += 1
	current_score += score
	
	print("Main: Level completed with score " + str(score) + " and earned " + str(currency_earned) + " currency")
	
	# Wait a moment before showing editor
	await get_tree().create_timer(1.0).timeout
	
	# Hide gameplay UI
	hide_gameplay_ui()
	
	# Ensure main camera reference is current
	if main_camera == null:
		main_camera = $Camera3D
	
	# Show editor
	if level_editor:
		level_editor.start_editing()
	else:
		push_error("Main: No level editor to show!")

# Start a new run
func start_next_run():
	print("Main: Starting new run")
	
	# Update game state
	game_running = true
	
	# Reset level state
	if level_manager and level_manager.has_method("reset_level"):
		level_manager.reset_level()
	
	# Reset or restart order system
	if order_manager and order_manager.has_method("reset_orders"):
		order_manager.reset_orders()
		
	# Update farm layout using saved farm data
	apply_saved_farm_layout()
	
	# Reset player position
	var player_nodes = get_tree().get_nodes_in_group("players")
	for player in player_nodes:
		if player:
			player.global_position = Vector3(4, 1, 2)  # Default spawn position
	
	# Ensure main camera is active again
	if main_camera:
		main_camera.current = true
		
	# Show gameplay UI
	show_gameplay_ui()

# Add debug UI for editor testing
func add_debug_ui():
	if not ui_layer:
		ui_layer = CanvasLayer.new()
		ui_layer.name = "UILayer"
		add_child(ui_layer)
	
	var debug_button = Button.new()
	debug_button.text = "Open Editor"
	debug_button.position = Vector2(10, 50)
	debug_button.size = Vector2(120, 40)
	debug_button.connect("pressed", Callable(self, "_on_debug_open_editor"))
	
	var end_level_button = Button.new()
	end_level_button.text = "Complete Level"
	end_level_button.position = Vector2(10, 100)
	end_level_button.size = Vector2(120, 40)
	end_level_button.connect("pressed", Callable(self, "_on_debug_complete_level"))
	
	ui_layer.add_child(debug_button)
	ui_layer.add_child(end_level_button)
	
	print("Main: Added debug UI")

# Debug handlers
func _on_debug_open_editor():
	if level_editor:
		# Hide gameplay UI
		hide_gameplay_ui()
		level_editor.start_editing()

func _on_debug_complete_level():
	on_level_completed(100, 250)  # Test score and currency values

# Signal handlers for level editor
func _on_editor_closed():
	print("Main: Editor closed")
	
	# Reset camera to game view if needed
	if main_camera:
		main_camera.current = true
	
	# Show gameplay UI
	show_gameplay_ui()
	
	# Resume the game
	game_running = true

func _on_editor_saved():
	print("Main: Editor changes saved")

func _on_editor_canceled():
	print("Main: Editor changes canceled")

# Signal handlers for game events
func _on_level_time_updated(time_remaining):
	# Update UI if needed
	pass

# Input handling
func _input(event):
	# Debug: Press F1 to toggle editor mode
	if OS.is_debug_build() and (event.is_action_pressed("ui_debug_editor") or 
	   (event is InputEventKey and event.keycode == KEY_F1 and event.pressed)):
		if level_editor:
			if level_editor.visible:
				level_editor.stop_editing()
				# Show gameplay UI
				show_gameplay_ui()
			else:
				# Hide gameplay UI
				hide_gameplay_ui()
				level_editor.start_editing()
				
func reset_progression():
	print("Main: Resetting all progression")
	
	# Load farm data
	var farm_data = FarmData.load_data()
	
	# Reset progression data (currency, stats, etc)
	farm_data.reset_progression()
	
	# Reset level state
	if level_manager and level_manager.has_method("reset_level"):
		level_manager.reset_level()
	
	# Reset order system
	if order_manager and order_manager.has_method("reset_orders"):
		order_manager.reset_orders()
		
	# Reset to initial farm layout from Main.tscn
	farm_data.reset_to_initial_layout(level_manager)
	
	# Reset player position
	var player_nodes = get_tree().get_nodes_in_group("players")
	for player in player_nodes:
		if player:
			player.global_position = Vector3(4, 1, 2)  # Default spawn position
	
	# Show gameplay UI
	show_gameplay_ui()
	
	# Start the game
	start_game()
	
	print("Main: Progression reset complete")

# Apply default farm layout (for fresh start)
func apply_default_farm_layout():
	if not level_manager:
		return
		
	print("Main: Applying default farm layout")
	
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
	
	print("Main: Default farm layout applied")

func save_initial_farm_layout():
	if not level_manager:
		push_error("Main: Cannot save initial farm layout - level manager not found")
		return
		
	# Load farm data
	var farm_data = FarmData.load_data()
	
	# Only save initial layout if it hasn't been saved before
	# This ensures we don't overwrite with a modified layout during gameplay
	if farm_data.initial_farm_layout.size() == 0:
		print("Main: Saving initial farm layout from Main.tscn")
		farm_data.save_initial_farm_layout(level_manager)
	else:
		print("Main: Initial farm layout already saved (" + 
			  str(farm_data.initial_farm_layout.size()) + " tiles)")
