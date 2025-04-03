# scripts/managers/GameManager.gd
class_name GameManager
extends Node3D

# Core game state
var game_running: bool = false
var current_level: int = 1
var current_level_score: int = 0 # NEW: Centralized score tracking

# Configuration
@export var always_reset_on_startup: bool = true

# Timer Management
var level_timer: float = 0.0
var level_time_limit: float = 180 # Default, will be updated

# Component references
@onready var camera_controller = $CameraController
@onready var game_data_manager = $GameDataManager
@onready var tool_manager = $ToolManager
@onready var ui_manager = $UIManager

# Game data reference
var game_data: GameData = null

# Node references - will be assigned in _ready()
var level_manager: Node = null
var order_manager: Node = null # Still needed for bonus logic
var player_manager: Node = null
var level_editor = null

# UI layer for overlays
var ui_layer: CanvasLayer = null

# Signals
signal score_changed(new_score)
signal level_time_updated(time_remaining)

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

	# Register services
	if service_locator:
		if level_manager:
			service_locator.register_service("level_manager", level_manager)
		# Keep OrderManager registered if other systems need it
		if order_manager:
			service_locator.register_service("order_manager", order_manager)

	# --- REMOVED old OrderManager signal connections for level completion ---
	# if order_manager:
	#    order_manager.connect("level_completed", Callable(self, "on_level_completed")) # REMOVED
	#    order_manager.connect("level_failed", Callable(self, "on_level_failed"))       # REMOVED
		# Keep time update if OrderManager still manages its own timers for orders
		# order_manager.connect("level_time_updated", Callable(self, "_on_level_time_updated")) # REMOVED if GameManager handles level timer

	# Add debug button for editor testing (only in debug mode)
	if OS.is_debug_build():
		add_debug_ui()

	# Update UI with current level info (score/requirement handled by UI connecting to score_changed)
	if ui_manager and order_manager: # Check order_manager exists if using its properties
		# Let UI update itself based on signals now
		pass
		# ui_manager.update_level_display(current_level, 0, get_required_score()) # Old way

	# Start the game
	start_game()

	print("GameManager: Game initialized")

# --- NEW: Score Management ---
func add_score(amount: int):
	if amount == 0: return
	current_level_score += amount
	emit_signal("score_changed", current_level_score)
	print("GameManager: Score is now %d (+%d)" % [current_level_score, amount])
	# Optional: Update stats if desired
	# if game_data_manager: game_data_manager.add_stat("score_earned_this_run", amount)

func get_required_score() -> int:
	if game_data and game_data.progression_data:
		# Access the requirements dictionary added to ProgressionData
		return game_data.progression_data.level_score_requirements.get(current_level, 1000) # Default if level not found
	push_warning("GameManager: Could not find game_data or progression_data to get score requirement.")
	return 1000 # Default fallback

func reset_level_score():
	current_level_score = 0
	emit_signal("score_changed", current_level_score)
	print("GameManager: Level score reset to 0.")

# --- NEW/MODIFIED: Level Timer and Completion ---
func update_level_time_limit():
	 # Set time limit based on current level
	level_time_limit = 180.0 + (current_level * 30.0) # Level 1: 3:30, Level 2: 4:00, etc.
	level_time_limit = min(level_time_limit, 180.0) # Cap at 8 minutes
	print("GameManager: Time limit for level %d set to %.1f seconds" % [current_level, level_time_limit])

func _process(delta):
	# Update level timer if game is running
	if game_running:
		level_timer += delta
		emit_signal("level_time_updated", level_time_limit - level_timer)

		# Check if level time has run out
		if level_timer >= level_time_limit:
			game_running = false # Stop timer processing immediately
			check_level_completion_by_score()

func check_level_completion_by_score():
	print("Level Timer Finished! Checking score...")
	var required_score = get_required_score()
	print("Score: %d / Required: %d" % [current_level_score, required_score])
	if current_level_score >= required_score:
		on_level_completed_score()
	else:
		on_level_failed_score()

func on_level_completed_score():
	game_running = false # Ensure game stops
	print("GameManager: Level " + str(current_level) + " PASSED (Score Requirement Met)")
# Check if game_data and necessary nested properties exist
	if game_data and game_data.progression_data:
		# 1. Get current currency BEFORE adding rewards
		var old_currency = float(game_data.progression_data.currency) # Convert to float for calculation

		# 2. Get the score earned this level
		var score_earned = float(current_level_score) # Use float score

		# 3. Calculate interest (10% of old currency)
		var interest_earned = old_currency * 0.10

		# 4. Calculate the new total currency
		# Formula: New = Old + Score + Interest
		# Using floor() to round down the interest ensures currency remains an integer
		# Change floor() to round() or ceil() if you prefer different rounding,
		# or change the currency variable in GameData.gd to float if you want decimals.
		var new_currency = int(floor(old_currency + score_earned + interest_earned))

		# 5. Update the persistent currency value
		game_data.progression_data.currency = new_currency

		print("GameManager: Currency updated.")
		print("  Old Currency: ", old_currency)
		print("  Score Earned: ", score_earned)
		print("  Interest Earned: ", interest_earned)
		print("  New Total Currency: ", new_currency)

	else:
		push_warning("GameManager: Cannot update currency - game_data or progression_data is missing!")
	# Update game data stats
	if game_data_manager and game_data:
		 # Example: Update highest score if needed
		if game_data.progression_data.highest_score < current_level_score:
			game_data.progression_data.highest_score = current_level_score
		game_data_manager.add_stat("levels_completed", 1)
		 # Add current score to a total career score stat if desired
		 # game_data_manager.add_stat("total_career_score", current_level_score)
		game_data.save() # Save changes

	await get_tree().create_timer(1.0).timeout # Wait a moment
	if ui_manager: ui_manager.hide_gameplay_ui()
	if level_editor: level_editor.start_editing()
	else: push_error("GameManager: No level editor to show after level completion!")


func on_level_failed_score():
	game_running = false # Ensure game stops
	print("GameManager: Level " + str(current_level) + " FAILED (Score Requirement Not Met)")

	# Standard level failure logic (Retry/Editor dialog)
	if ui_manager: ui_manager.hide_gameplay_ui()

	# Show retry dialog
	var dialog = ConfirmationDialog.new()
	dialog.title = "Level Failed"
	dialog.dialog_text = "You didn't reach the required score of %d.\nYour score: %d.\nTry again?" % [get_required_score(), current_level_score]
	dialog.get_ok_button().text = "Retry Level"
	dialog.get_cancel_button().text = "Farm Editor"
	dialog.dialog_hide_on_ok = true
	# Ensure signals are connected correctly if these methods exist
	dialog.confirmed.connect(self._on_retry_level)
	dialog.canceled.connect(self._on_show_editor)
	if ui_layer: 
		ui_layer.add_child(dialog) 
	else: 
		add_child(dialog)
	dialog.popup_centered()


# --- MODIFIED Game Flow Functions ---
func start_game():
	# Load current level from game data
	if game_data and game_data.progression_data:
		current_level = game_data.progression_data.current_level

	update_level_time_limit() # Set timer based on current level
	reset_level_score()       # Reset score for the new run
	level_timer = 0.0         # Reset timer
	game_running = true

	# Ensure the correct camera is active
	if camera_controller: camera_controller.activate_main_camera()

	# Apply layout (respecting dev mode)
	if not (always_reset_on_startup and OS.is_debug_build()):
		if game_data_manager: game_data_manager.apply_saved_farm_layout()
	else:
		 # Ensure default layout in dev mode if needed, or just use scene as is
		print("GameManager: Dev mode, using scene layout.")


	# Reset and Start order generation (if OrderManager still handles orders)
	if order_manager:
		order_manager.current_level = current_level # Ensure OM knows current level
		order_manager.reset_orders() # Resets its internal state for new orders
		print("GameManager: Starting order manager for level " + str(current_level))

	# Spawn tools
	if tool_manager:
		tool_manager.spawn_saved_tools()

	# UI should update based on signals (score_changed, level_time_updated)
	if ui_manager:
		ui_manager.show_gameplay_ui()

	print("GameManager: Game started at level " + str(current_level))


func start_next_level():
	print("GameManager: Starting next level...")

	# Increment level counter
	current_level += 1

	# Update game data
	if game_data_manager:
		game_data_manager.set_current_level(current_level)

	# --- Core Level Reset Logic ---
	update_level_time_limit()
	reset_level_score()
	level_timer = 0.0
	game_running = true

	

	# Reset order system internal state for the new level
	if order_manager and order_manager.has_method("reset_orders"):
		order_manager.current_level = current_level # Update level in OM
		order_manager.reset_orders()
		# Update available crops if needed based on new unlocks
		if order_manager.has_method("update_available_crops"):
			order_manager.update_available_crops()

	# Apply saved farm layout (persists between levels)
	if game_data_manager:
		game_data_manager.apply_saved_farm_layout()
		
# Reset level state (tiles, plants)
	if level_manager and level_manager.has_method("reset_level"):
		level_manager.reset_level()
	# Reset player position
	var player_nodes = get_tree().get_nodes_in_group("players")
	for player in player_nodes:
		if player and is_instance_valid(player):
			 # TODO: Define a better spawn point, maybe from LevelData?
			player.global_position = Vector3(4, 1.5, 2)

	# Ensure main camera is active
	if camera_controller: camera_controller.activate_main_camera()

	# Ensure editor is hidden
	if level_editor and level_editor.visible: level_editor.hide()

	# Spawn tools based on saved data
	if tool_manager: tool_manager.spawn_saved_tools()

	# Show gameplay UI (should update automatically via signals)
	if ui_manager: ui_manager.show_gameplay_ui()
	# --- End Core Level Reset Logic ---

	print("GameManager: Started level " + str(current_level))


func retry_level():
	print("GameManager: Retrying level " + str(current_level))

	# --- Core Level Reset Logic (Same as start_next_level but without incrementing) ---
	update_level_time_limit()
	reset_level_score()
	level_timer = 0.0
	game_running = true

	if level_manager and level_manager.has_method("reset_level"):
		level_manager.reset_level()

	if order_manager and order_manager.has_method("reset_orders"):
		# Don't need to set current_level as it hasn't changed
		order_manager.reset_orders()
		# Update available crops if needed
		if order_manager.has_method("update_available_crops"):
			order_manager.update_available_crops()


	# Re-apply the SAME saved farm layout
	if game_data_manager:
		game_data_manager.apply_saved_farm_layout()

	# Reset player position
	var player_nodes = get_tree().get_nodes_in_group("players")
	for player in player_nodes:
		if player and is_instance_valid(player):
			player.global_position = Vector3(4, 1.5, 2) # Use same spawn

	if camera_controller: camera_controller.activate_main_camera()
	if level_editor and level_editor.visible: level_editor.hide()
	if tool_manager: tool_manager.spawn_saved_tools()
	if ui_manager: ui_manager.show_gameplay_ui()
	# --- End Core Level Reset Logic ---

	print("GameManager: Retrying level " + str(current_level))


# --- Data Reset Functions (Keep as is) ---
func reset_all_game_data():
	if game_data_manager:
		game_data_manager.reset_all_data()
		# Apply the default farm layout after full reset
		game_data_manager.apply_default_farm_layout()
	print("GameManager: Game data has been completely reset")
	# Optionally reload scene after full reset
	# get_tree().reload_current_scene()

func reset_progression():
	print("GameManager: Resetting all progression (excluding farm layout)")
	if game_data_manager:
		game_data_manager.reset_progression() # Resets currency, stats, upgrades

	# Reset level state
	if level_manager and level_manager.has_method("reset_level"):
		level_manager.reset_level()
	# Reset orders
	if order_manager and order_manager.has_method("reset_orders"):
		order_manager.reset_orders()
	# Respawn tools based on potentially empty data
	if tool_manager:
		tool_manager.spawn_saved_tools()

	# Reset score and timer for level 1 start
	current_level = 1 # Reset to level 1
	if game_data_manager: game_data_manager.set_current_level(current_level)
	update_level_time_limit()
	reset_level_score()
	level_timer = 0.0
	game_running = true # Start game immediately after reset

	# Update UI
	if ui_manager:
		ui_manager.show_gameplay_ui()
		# Signals should handle updating labels correctly now

	print("GameManager: Progression reset complete, starting level 1.")


# --- Signal handlers for level editor (Keep as is) ---
func _on_editor_closed():
	print("GameManager: Editor closed")
	# Resume gameplay logic (now handled in start_next_level)
	# This might need adjustment if editor can be closed without starting next level
	if camera_controller: camera_controller.activate_main_camera()
	if tool_manager: tool_manager.spawn_saved_tools() # Respawn tools based on saved editor changes
	if ui_manager: ui_manager.show_gameplay_ui()
	# Should we resume timer? Depends on game flow. Assume start_next_level handles it.
	# game_running = true

func _on_editor_saved():
	print("GameManager: Editor changes saved")
	# Changes are saved by editor, ToolManager will spawn correctly on next level start
	if tool_manager: tool_manager.spawn_saved_tools()

func _on_editor_canceled():
	print("GameManager: Editor changes canceled")
	# Revert might happen in editor, ToolManager will spawn correctly
	if tool_manager: tool_manager.spawn_saved_tools()

# --- REMOVED: _on_level_time_updated (now handled by emitting signal) ---

# --- Dialog response handlers (Keep as is) ---
func _on_retry_level():
	retry_level()

func _on_show_editor():
	if level_editor:
		level_editor.start_editing()

# --- Debug UI (Keep as is, but _on_debug_complete_level needs change) ---
func add_debug_ui():
	# ... (keep existing button creation) ...
	if not ui_layer: return

	var debug_button = Button.new()
	debug_button.text = "Open Editor"
	debug_button.position = Vector2(10, 50); debug_button.size = Vector2(120, 40)
	debug_button.connect("pressed", Callable(self, "_on_debug_open_editor"))

	var end_level_button = Button.new()
	end_level_button.text = "Win Level" # Changed text
	end_level_button.position = Vector2(10, 100); end_level_button.size = Vector2(120, 40)
	end_level_button.connect("pressed", Callable(self, "_on_debug_win_level")) # Changed connection

	var fail_level_button = Button.new() # NEW Fail button
	fail_level_button.text = "Fail Level"
	fail_level_button.position = Vector2(10, 150); fail_level_button.size = Vector2(120, 40)
	fail_level_button.connect("pressed", Callable(self, "_on_debug_fail_level"))

	var reset_button = Button.new()
	reset_button.text = "Reset Data"
	reset_button.position = Vector2(10, 200); reset_button.size = Vector2(120, 40)
	reset_button.connect("pressed", Callable(self, "_on_debug_reset_data"))

	ui_layer.add_child(debug_button)
	ui_layer.add_child(end_level_button)
	ui_layer.add_child(fail_level_button) # Add fail button
	ui_layer.add_child(reset_button)

	print("GameManager: Added debug UI")


# Debug handlers
func _on_debug_open_editor():
	if level_editor:
		if ui_manager: ui_manager.hide_gameplay_ui()
		game_running = false # Pause game when opening editor manually
		level_editor.start_editing()

func _on_debug_win_level():
	# Simulate winning by setting score above requirement and ending timer
	current_level_score = get_required_score() + 100 # Ensure score is enough
	level_timer = level_time_limit # Force timer end
	game_running = false # Stop timer processing
	check_level_completion_by_score() # Trigger completion check

func _on_debug_fail_level():
	# Simulate failing by setting score below requirement and ending timer
	current_level_score = get_required_score() - 100 # Ensure score is not enough
	level_timer = level_time_limit # Force timer end
	game_running = false # Stop timer processing
	check_level_completion_by_score() # Trigger completion check


func _on_debug_reset_data():
	reset_all_game_data()
	get_tree().reload_current_scene()

# Input handling (Keep as is)
func _input(event):
	if OS.is_debug_build() and (event.is_action_pressed("ui_debug_editor") or \
	   (event is InputEventKey and event.keycode == KEY_F1 and event.pressed)):
		if level_editor:
			if level_editor.visible:
				level_editor.stop_editing()
				if ui_manager: ui_manager.show_gameplay_ui()
				# Decide if game should resume here or wait for start_next_level
				# game_running = true
			else:
				if ui_manager: ui_manager.hide_gameplay_ui()
				game_running = false # Pause game
				level_editor.start_editing()
