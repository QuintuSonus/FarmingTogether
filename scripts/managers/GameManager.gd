# scripts/managers/GameManager.gd
class_name GameManager
extends Node3D

# Core game state
var game_running: bool = false
var current_level: int = 1
var current_score: int = 0

# Configuration
@export var always_reset_on_startup: bool = true

# Component references
@onready var camera_controller = $CameraController
@onready var farm_layout_manager = $FarmLayoutManager
@onready var tool_manager = $ToolManager
@onready var ui_manager = $UIManager

# Node references - will be assigned in _ready()
var level_manager: Node = null
var order_manager: Node = null
var player_manager: Node = null
var level_editor = null

func _ready():
	# Initialize references to main nodes
	level_manager = $LevelManager
	order_manager = $OrderManager if has_node("OrderManager") else null
	player_manager = $PlayerManager if has_node("PlayerManager") else null
	
	# Load level editor
	var editor_scene = load("res://scenes/editor/LevelEditor.tscn")
	if editor_scene:
		level_editor = editor_scene.instantiate()
		add_child(level_editor)
		
		# Connect editor signals
		level_editor.connect("editor_closed", Callable(self, "_on_editor_closed"))
		level_editor.connect("editor_saved", Callable(self, "_on_editor_saved"))
		level_editor.connect("editor_canceled", Callable(self, "_on_editor_canceled"))
		
		print("GameManager: Level editor loaded")
	else:
		push_error("GameManager: Failed to load LevelEditor scene!")
	
	# Reset game data if development flag is set
	if always_reset_on_startup and OS.is_debug_build():
		print("DEVELOPMENT MODE: Resetting all game data on startup")
		reset_all_game_data()

	# Initialize components with required references
	farm_layout_manager.set_level_manager(level_manager)
	
	if camera_controller:
		camera_controller.set_player_manager(player_manager)
	
	if tool_manager:
		tool_manager.set_level_manager(level_manager)
	
	# Save initial farm layout
	farm_layout_manager.save_initial_farm_layout()
	
	# Apply saved farm layout if it exists
	farm_layout_manager.apply_saved_farm_layout()
	
	# Connect order manager signals
	if order_manager:
		order_manager.connect("level_time_updated", Callable(self, "_on_level_time_updated"))
	
	# Add debug button for editor testing (only in debug mode)
	if OS.is_debug_build():
		add_debug_ui()
	
	# Show gameplay UI
	ui_manager.show_gameplay_ui()
	
	# Start the game
	start_game()
	
	print("GameManager: Game initialized")

# Start the game
func start_game():
	game_running = true
	
	# Ensure the correct camera is active
	camera_controller.activate_main_camera()
	
	# In development mode, use the scene exactly as-is
	if not (always_reset_on_startup and OS.is_debug_build()):
		# Only apply saved farm layout in normal (non-development) mode
		farm_layout_manager.apply_saved_farm_layout()
	
	# Start order generation
	if order_manager:
		print("GameManager: Starting order manager")
	
	print("GameManager: Game started")

# Handle level completion
func on_level_completed(score: int, currency_earned: int):
	# Update farm data with earned currency
	var farm_data = farm_layout_manager.get_farm_data()
	farm_data.currency += currency_earned
	farm_data.save()
	
	# Update game state
	game_running = false
	current_score += score
	
	print("GameManager: Level completed with score " + str(score) + " and earned " + str(currency_earned) + " currency")
	
	# Wait a moment before showing editor
	await get_tree().create_timer(1.0).timeout
	
	# Hide gameplay UI
	ui_manager.hide_gameplay_ui()
	
	# Show editor
	if level_editor:
		level_editor.start_editing()
	else:
		push_error("GameManager: No level editor to show!")

# Start a new run
func start_next_level():
	print("GameManager: Starting level " + str(current_level + 1))
	
	# Increment level counter
	current_level += 1
	
	# Update game state
	game_running = true
	
	# Reset level state
	if level_manager and level_manager.has_method("reset_level"):
		level_manager.reset_level()
	
	# Reset order system
	if order_manager and order_manager.has_method("reset_orders"):
		order_manager.current_level = current_level
		order_manager.reset_orders()
		
	# Update farm layout using saved farm data
	farm_layout_manager.apply_saved_farm_layout()
	
	# Reset player position
	var player_nodes = get_tree().get_nodes_in_group("players")
	for player in player_nodes:
		if player:
			player.global_position = Vector3(4, 1, 2)  # Default spawn position
	
	# Ensure main camera is active
	camera_controller.activate_main_camera()
	
	# MAKE SURE EDITOR IS HIDDEN
	if level_editor and level_editor.visible:
		level_editor.visible = false
		
	# Show gameplay UI - call after a small delay to ensure everything is ready
	ui_manager.show_gameplay_ui()

# Reset all game data
func reset_all_game_data():
	# Create a new farm data with default values and save it
	var farm_data = FarmData.new()
	farm_data.save()
	
	# Apply the default farm layout
	farm_layout_manager.apply_default_farm_layout()
	
	print("GameManager: Game data has been completely reset")

# Reset progression
func reset_progression():
	print("GameManager: Resetting all progression")
	
	# Load farm data
	var farm_data = farm_layout_manager.get_farm_data()
	
	# Reset progression data (currency, stats, etc)
	farm_data.reset_progression()
	
	# Reset level state
	if level_manager and level_manager.has_method("reset_level"):
		level_manager.reset_level()
	
	# Reset order system
	if order_manager and order_manager.has_method("reset_orders"):
		order_manager.reset_orders()
		
	# Reset to initial farm layout
	farm_data.reset_to_initial_layout(level_manager)
	
	# Reset player position
	var player_nodes = get_tree().get_nodes_in_group("players")
	for player in player_nodes:
		if player:
			player.global_position = Vector3(4, 1, 2)  # Default spawn position
	
	# Show gameplay UI
	ui_manager.show_gameplay_ui()
	
	# Start the game
	start_game()
	
	print("GameManager: Progression reset complete")

# Signal handlers for level editor
func _on_editor_closed():
	print("GameManager: Editor closed")
	
	# Reset camera to game view
	camera_controller.activate_main_camera()
	
	# Respawn tools
	tool_manager.spawn_saved_tools()
	
	# Show gameplay UI
	ui_manager.show_gameplay_ui()
	
	# Resume the game
	game_running = true

func _on_editor_saved():
	print("GameManager: Editor changes saved")
	tool_manager.spawn_saved_tools()

func _on_editor_canceled():
	print("GameManager: Editor changes canceled")
	tool_manager.spawn_saved_tools()

# Signal handler for order manager
func _on_level_time_updated(time_remaining):
	# Update UI if needed
	pass

# Add debug UI for editor testing
func add_debug_ui():
	var ui_layer = ui_manager.get_ui_layer()
	if not ui_layer:
		return
	
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
	
	print("GameManager: Added debug UI")

# Debug handlers
func _on_debug_open_editor():
	if level_editor:
		# Hide gameplay UI
		ui_manager.hide_gameplay_ui()
		level_editor.start_editing()

func _on_debug_complete_level():
	on_level_completed(100, 250)  # Test score and currency values

# Input handling
func _input(event):
	# Debug: Press F1 to toggle editor mode
	if OS.is_debug_build() and (event.is_action_pressed("ui_debug_editor") or 
	   (event is InputEventKey and event.keycode == KEY_F1 and event.pressed)):
		if level_editor:
			if level_editor.visible:
				level_editor.stop_editing()
				# Show gameplay UI
				ui_manager.show_gameplay_ui()
			else:
				# Hide gameplay UI
				ui_manager.hide_gameplay_ui()
				level_editor.start_editing()
