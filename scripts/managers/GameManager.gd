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
@onready var game_data_manager = $GameDataManager
@onready var tool_manager = $ToolManager
@onready var ui_manager = $UIManager

# Game data reference
var game_data: GameData = null

# Node references - will be assigned in _ready()
var level_manager: Node = null
var order_manager: Node = null
var player_manager: Node = null
var level_editor = null

# UI layer for overlays
var ui_layer: CanvasLayer = null

func _ready():
	# Register with ServiceLocator
		
	var service_locator = get_node_or_null("/root/ServiceLocator")
	if service_locator:
		service_locator.register_service("game_manager", self)
	
	# Initialize references to main nodes
	
	level_manager = $LevelManager
	order_manager = $OrderManager if has_node("OrderManager") else null
	player_manager = $PlayerManager if has_node("PlayerManager") else null
	ui_layer = $UILayer if has_node("UILayer") else null
	
	# Get game data
	if game_data_manager:
		game_data = game_data_manager.game_data
		
		# Register game data with service locator
		if service_locator:
			service_locator.register_service("game_data", game_data)
	
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
	if game_data_manager:
		game_data_manager.set_level_manager(level_manager)
	
	if camera_controller:
		camera_controller.set_player_manager(player_manager)
	
	if tool_manager:
		tool_manager.set_level_manager(level_manager)
	
	# Save initial farm layout
	if game_data_manager:
		game_data_manager.save_initial_farm_layout()
	
		## Apply saved farm layout if it exists
		#game_data_manager.apply_saved_farm_layout()
	
	# Register services
	if service_locator:
		if level_manager:
			service_locator.register_service("level_manager", level_manager)
		if order_manager:
			service_locator.register_service("order_manager", order_manager)
	
	# Connect order manager signals
	if order_manager:
		order_manager.connect("level_completed", Callable(self, "on_level_completed"))
		order_manager.connect("level_failed", Callable(self, "on_level_failed"))
		order_manager.connect("level_time_updated", Callable(self, "_on_level_time_updated"))
	
	# Add debug button for editor testing (only in debug mode)
	if OS.is_debug_build():
		add_debug_ui()
	
	# Update UI with current level
	if ui_manager:
		var completed_orders = 0
		var required = 3  # Default
		if order_manager:
			completed_orders = order_manager.orders_completed_this_run
			required = order_manager.required_orders
			
			# Update order manager's current level
			order_manager.current_level = current_level
			
		ui_manager.update_level_display(current_level, completed_orders, required)
		
		# Show gameplay UI
		ui_manager.show_gameplay_ui()
	#if level_editor:
	## Pass game_data directly to the editor
		#if game_data:
			#print("GameManager: Passing game_data directly to level_editor")
			#level_editor.game_data = game_data
	#
	#if game_data_manager:
		#print("GameManager: Passing game_data_manager directly to level_editor")
		#level_editor.game_data_manager = game_data_manager
	# Start the game
	var sprinkler_manager = $SprinklerManager
	if sprinkler_manager:
		print("GameManager: Found SprinklerManager")
		if service_locator:
			service_locator.register_service("sprinkler_manager", sprinkler_manager)
	else:
		push_error("GameManager: SprinklerManager not found")
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
		if game_data_manager:
			game_data_manager.apply_saved_farm_layout()
	
	# Make sure correct level is set
	if game_data and game_data.progression_data:
		current_level = game_data.progression_data.current_level
		
		# Update order manager's current level if needed
		if order_manager:
			order_manager.current_level = current_level
	
	# Start order generation
	if order_manager:
		# Reset orders for this level
		order_manager.reset_orders()
		print("GameManager: Starting order manager for level " + str(current_level))
	
	# Spawn tools
	if tool_manager:
		tool_manager.spawn_saved_tools()
	
	print("GameManager: Game started at level " + str(current_level))

# Handle level completion
func on_level_completed(score: int, currency_earned: int):
	# Update game data with earned currency
	if game_data_manager:
		game_data_manager.add_currency(currency_earned)
	
	# Update game state
	game_running = false
	current_score += score
	
	print("GameManager: Level " + str(current_level) + " completed with score " + str(score) + 
		  " and earned " + str(currency_earned) + " currency")
	
	# Update statistics
	if game_data_manager:
		game_data_manager.add_stat("levels_completed", 1)
		game_data_manager.add_stat("total_score", score)
	
	# Wait a moment before showing editor
	await get_tree().create_timer(1.0).timeout
	
	# Hide gameplay UI
	if ui_manager:
		ui_manager.hide_gameplay_ui()
	
	print("GameManager: Level completed, editor reference exists: " + str(level_editor != null))
	# Show editor
	if level_editor:
		level_editor.start_editing()
	else:
		push_error("GameManager: No level editor to show!")

# Handle level failure
func on_level_failed():
	print("GameManager: Level " + str(current_level) + " failed")
	
	# Update game state
	game_running = false
	
	# Hide gameplay UI
	if ui_manager:
		ui_manager.hide_gameplay_ui()
	
	# Show retry dialog
	var dialog = ConfirmationDialog.new()
	dialog.title = "Level Failed"
	dialog.dialog_text = "You didn't complete enough orders. Try again?"
	dialog.get_ok_button().text = "Retry Level"
	dialog.get_cancel_button().text = "Farm Editor"
	dialog.dialog_hide_on_ok = true
	
	# Connect dialog signals
	dialog.confirmed.connect(self._on_retry_level)
	dialog.canceled.connect(self._on_show_editor)
	
	# Add to UI layer
	if ui_layer:
		ui_layer.add_child(dialog)
	else:
		add_child(dialog)
		
	dialog.popup_centered()

# Start a new run
func start_next_level():
	print("GameManager: Starting level " + str(current_level + 1))
	
	# Increment level counter
	current_level += 1
	
	# Update game data
	if game_data_manager:
		game_data_manager.set_current_level(current_level)
	
	# Update game state
	game_running = true
	
	# Reset level state
	if level_manager and level_manager.has_method("reset_level"):
		level_manager.reset_level()
	
	# Reset order system
	if order_manager and order_manager.has_method("reset_orders"):
		order_manager.current_level = current_level
		order_manager.reset_orders()
	
	if order_manager and order_manager.has_method("update_available_crops"):
		order_manager.update_available_crops()
		print("GameManager: Updated order manager's available crops after editor save")
		
	# Update farm layout using saved farm data
	if game_data_manager:
		game_data_manager.apply_saved_farm_layout()
	
	# Reset player position
	var player_nodes = get_tree().get_nodes_in_group("players")
	for player in player_nodes:
		if player:
			player.global_position = Vector3(4, 1, 2)  # Default spawn position
	
	# Ensure main camera is active
	if camera_controller:
		camera_controller.activate_main_camera()
	
	# MAKE SURE EDITOR IS HIDDEN
	if level_editor and level_editor.visible:
		level_editor.visible = false
	
	# Spawn tools
	if tool_manager:
		tool_manager.spawn_saved_tools()
	
	# Update UI
	if ui_manager:
		var completed_orders = 0
		var required = 3  # Default
		if order_manager:
			completed_orders = order_manager.orders_completed_this_run
			required = order_manager.required_orders
		ui_manager.update_level_display(current_level, completed_orders, required)
		
		# Show gameplay UI - call after a small delay to ensure everything is ready
		ui_manager.show_gameplay_ui()

# Retry the current level
func retry_level():
	print("GameManager: Retrying level " + str(current_level))
	
	# Update game state
	game_running = true
	
	# Reset level state
	if level_manager and level_manager.has_method("reset_level"):
		level_manager.reset_level()
	
	# Reset order system
	if order_manager and order_manager.has_method("reset_orders"):
		order_manager.reset_orders()
		
	# Update farm layout using saved farm data
	if game_data_manager:
		game_data_manager.apply_saved_farm_layout()
	
	# Reset player position
	var player_nodes = get_tree().get_nodes_in_group("players")
	for player in player_nodes:
		if player:
			player.global_position = Vector3(4, 1, 2)  # Default spawn position
	
	# Ensure main camera is active
	if camera_controller:
		camera_controller.activate_main_camera()
	
	# Spawn tools
	if tool_manager:
		tool_manager.spawn_saved_tools()
	
	# Show gameplay UI
	if ui_manager:
		ui_manager.show_gameplay_ui()

# Reset all game data
func reset_all_game_data():
	# Create a new game data with default values and save it
	if game_data_manager:
		game_data_manager.reset_all_data()
		
		# Apply the default farm layout
		game_data_manager.apply_default_farm_layout()
	
	print("GameManager: Game data has been completely reset")

# Reset progression
func reset_progression():
	print("GameManager: Resetting all progression")
	
	if game_data_manager:
		game_data_manager.reset_progression()
	
	# Reset level state
	if level_manager and level_manager.has_method("reset_level"):
		level_manager.reset_level()
	
	# Reset order system
	if order_manager and order_manager.has_method("reset_orders"):
		order_manager.reset_orders()
		
	# Spawn tools
	if tool_manager:
		tool_manager.spawn_saved_tools()
		
	# Update UI
	if ui_manager:
		ui_manager.update_level_display(1, 0, 3)
	
	# Show gameplay UI
	if ui_manager:
		ui_manager.show_gameplay_ui()
	
	# Start the game
	start_game()
	
	print("GameManager: Progression reset complete")

# Signal handlers for level editor
func _on_editor_closed():
	print("GameManager: Editor closed")
	
	# Reset camera to game view
	if camera_controller:
		camera_controller.activate_main_camera()
	
	# Respawn tools
	if tool_manager:
		tool_manager.spawn_saved_tools()
	
	# Show gameplay UI
	if ui_manager:
		ui_manager.show_gameplay_ui()
	
	# Resume the game
	game_running = true

func _on_editor_saved():
	print("GameManager: Editor changes saved")
	if tool_manager:
		tool_manager.spawn_saved_tools()

func _on_editor_canceled():
	print("GameManager: Editor changes canceled")
	if tool_manager:
		tool_manager.spawn_saved_tools()

# Signal handler for order manager
func _on_level_time_updated(time_remaining):
	# Update UI if needed
	pass

# Dialog response handlers
func _on_retry_level():
	retry_level()

func _on_show_editor():
	if level_editor:
		level_editor.start_editing()

# Add debug UI for editor testing
func add_debug_ui():
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
	
	var reset_button = Button.new()
	reset_button.text = "Reset Data"
	reset_button.position = Vector2(10, 150)
	reset_button.size = Vector2(120, 40)
	reset_button.connect("pressed", Callable(self, "_on_debug_reset_data"))
	
	ui_layer.add_child(debug_button)
	ui_layer.add_child(end_level_button)
	ui_layer.add_child(reset_button)
	
	print("GameManager: Added debug UI")

# Debug handlers
func _on_debug_open_editor():
	if level_editor:
		# Hide gameplay UI
		if ui_manager:
			ui_manager.hide_gameplay_ui()
		level_editor.start_editing()

func _on_debug_complete_level():
	on_level_completed(100, 250)  # Test score and currency values

func _on_debug_reset_data():
	reset_all_game_data()
	# Restart the game
	get_tree().reload_current_scene()

# Input handling
func _input(event):
	# Debug: Press F1 to toggle editor mode
	if OS.is_debug_build() and (event.is_action_pressed("ui_debug_editor") or 
	   (event is InputEventKey and event.keycode == KEY_F1 and event.pressed)):
		if level_editor:
			if level_editor.visible:
				level_editor.stop_editing()
				# Show gameplay UI
				if ui_manager:
					ui_manager.show_gameplay_ui()
			else:
				# Hide gameplay UI
				if ui_manager:
					ui_manager.hide_gameplay_ui()
				level_editor.start_editing()
