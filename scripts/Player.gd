# scripts/Player.gd
extends CharacterBody3D

# Player movement parameters
@export var normal_speed: float = 4.0
@export var mud_speed: float = 2.0
@export var move_acceleration: float = 8.0
@export var stop_acceleration: float = 8.0
@export var rotation_speed: float = 10.0
@export var controller_deadzone: float = 0.2  # Deadzone for controller input

# Multiplayer properties
# We use a backing variable and setter/getter to handle updates to player_index
var _player_index: int = 0
var player_index: int:
	get:
		return _player_index
	set(value):
		_player_index = value
		_update_input_prefix()

var input_prefix = "p1_"  # Default to player 1 inputs
var movement_disabled = false

# Node references
var level_manager: Node = null
var current_tool = null
@onready var interaction_manager = $InteractionManager
@onready var interaction_feedback = $InteractionFeedback
@onready var tool_holder = $ToolHolder

@onready var tile_targeting_point = $TileTargetingPoint 

# Tile highlighter and position tracking
var tile_highlighter = null
var current_tile_type = null
var current_grid_position: Vector3i = Vector3i(0, 0, 0)
var front_grid_position: Vector3i = Vector3i(0, 0, 0)

# Interaction state tracking
var is_tool_use_in_progress = false
var tool_use_completed = false
var tool_use_start_time = 0
var tool_use_position = null
var tool_use_duration = 0.0

# Constants for tile types (duplicated from LevelManager to avoid dependency issues)
enum TileType {
	REGULAR_GROUND,
	DIRT_GROUND,
	SOIL,
	WATER,
	MUD,
	DELIVERY
}

# Static dictionary to track which tiles are being used by tools
static var tiles_being_used = {}

# Helper method to update input prefix when player_index changes
func _update_input_prefix():
	if _player_index == 1:
		input_prefix = "p2_"
	else:
		input_prefix = "p1_"
	print("Player " + str(_player_index) + " input prefix updated to: " + input_prefix)

# Called when the node enters the scene tree for the first time
func _ready():
	# Make sure input prefix is set correctly based on player_index
	_update_input_prefix()
	
	print("Player " + str(_player_index) + " initialized with input prefix: " + input_prefix)
	
	# Get a reference to the level manager - more robust version
	level_manager = get_node_or_null("../LevelManager")
	
	# If not found, try to find it in the scene tree
	if not level_manager:
		# Try to find it from the root
		level_manager = get_node_or_null("/root/Main/LevelManager")
		
		# If still not found, search the whole scene
		if not level_manager:
			level_manager = get_tree().get_root().find_child("LevelManager", true, false)
			
		if level_manager:
			print("Player: Found LevelManager via scene tree search")
		else:
			push_error("Player: Could not find LevelManager!")
	
	# Connect signals
	if interaction_manager:
		interaction_manager.connect("interaction_started", _on_interaction_started)
		interaction_manager.connect("interaction_completed", _on_interaction_completed)
		interaction_manager.connect("interaction_canceled", _on_interaction_canceled)
		interaction_manager.connect("potential_interactable_changed", _on_potential_interactable_changed)
	else:
		push_error("Player: InteractionManager node not found!")
	
	# Setup tile highlighter
	tile_highlighter = $TileHighlighter
	
	if not tile_highlighter:
		# Create and add the TileHighlighter node if it doesn't exist
		var highlighter_scene = load("res://scenes/ui/TileHighlighter.tscn")
		if highlighter_scene:
			tile_highlighter = highlighter_scene.instantiate()
			add_child(tile_highlighter)
	
	print("Player initialized")
	
	add_to_group("players")

# Handle physics updates
func _physics_process(delta):
	# Skip movement processing if disabled
	if movement_disabled:
		# Still update interaction progress if in progress
		if interaction_manager and Input.is_action_pressed(input_prefix + "interact"):
			interaction_manager.update_interaction(delta)
		
		# Update tool use progress if in progress
		if is_tool_use_in_progress and not tool_use_completed:
			update_tool_use_progress(delta)
		
		# Make sure velocity is zero while interactions are in progress
		velocity = Vector3.ZERO
		
		# Update tile highlighting
		if tile_highlighter:
			update_tile_highlight()
			
		return  # Skip the rest of movement processing
	
	# Regular movement processing (existing code)
	# Get input direction - works with both keyboard and controller
	var input_dir = get_movement_vector()
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	# Update current grid position
	if level_manager:
		current_grid_position = level_manager.world_to_grid(global_position)
		current_tile_type = level_manager.get_tile_type(current_grid_position)
	
	# Determine current speed based on tile type
	var current_speed = normal_speed
	if level_manager and current_tile_type != null:
		# Check for mud using local enum to avoid dependency issues
		if current_tile_type == TileType.MUD:
			current_speed = mud_speed
	
	# Set velocity based on input
	if direction:
		# Apply the magnitude of the joystick to control variable speed
		var input_strength = input_dir.length()
		var target_speed = current_speed
		
		# If using controller (analog input), apply input strength for variable speed
		if input_strength < 0.99 and input_strength > controller_deadzone:
			target_speed = current_speed * input_strength
		
		# Gradually accelerate in the input direction
		velocity.x = move_toward(velocity.x, direction.x * target_speed, move_acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * target_speed, move_acceleration * delta)
		
		# Rotate player to face movement direction
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)
	else:
		# Gradually slow down to a stop
		velocity.x = move_toward(velocity.x, 0, stop_acceleration * delta)
		velocity.z = move_toward(velocity.z, 0, stop_acceleration * delta)
	
	# Apply movement
	move_and_slide()
	
	# Update interaction progress if in progress
	if interaction_manager and Input.is_action_pressed(input_prefix + "interact"):
		interaction_manager.update_interaction(delta)
	
	# Update tool use progress if in progress
	if is_tool_use_in_progress and not tool_use_completed:
		update_tool_use_progress(delta)
	
	# Update tile highlighting
	if tile_highlighter:
		update_tile_highlight()

# Get movement vector from input (keyboard or controller)
func get_movement_vector() -> Vector2:
	var input_dir = Input.get_vector(
		input_prefix + "move_left", 
		input_prefix + "move_right", 
		input_prefix + "move_up", 
		input_prefix + "move_down"
	)
	
	# Apply deadzone for controller input to prevent drift
	if input_dir.length() < controller_deadzone:
		input_dir = Vector2.ZERO
		
	return input_dir

# Update the tool use progress
func update_tool_use_progress(delta):
	if is_tool_use_in_progress and not tool_use_completed and tool_use_duration > 0:
		var elapsed = (Time.get_ticks_msec() - tool_use_start_time) / 1000.0
		var progress = clamp(elapsed / tool_use_duration, 0.0, 1.0)
		
		# Update progress bar
		if interaction_feedback:
			interaction_feedback.update_progress(progress)
		
		# Check if complete
		if progress >= 1.0 and not tool_use_completed:
			print("Tool use complete!")
			tool_use_completed = true
			_on_tool_use_completed(tool_use_position)

# Update the tile highlight based on player position and direction
func update_tile_highlight():
	if !level_manager or !tile_targeting_point or !tile_highlighter:
		return
	
	# Calculate the forward point more precisely
	var forward_point = tile_targeting_point.global_position
	
	# Convert directly to grid position - this is the tile we want to interact with
	front_grid_position = level_manager.world_to_grid(forward_point)
	
	# Also get player's current grid position
	current_grid_position = level_manager.world_to_grid(global_position)
		
	# Check if this tile is within bounds - using the improved is_within_bounds function
	if level_manager.is_within_bounds(front_grid_position):
		# Get world position of this grid cell for highlighting
		var highlight_pos = level_manager.grid_to_world(front_grid_position)
		
		# Important: Center the highlight on the tile exactly for visual consistency
		# We'll add 0.5 to X and Z to center on the tile (since grid cells are 1x1)
		highlight_pos.x = float(front_grid_position.x) + 0.5
		highlight_pos.z = float(front_grid_position.z) + 0.5
		
		# Check if the current tool can interact with this tile
		var can_interact = false
		if current_tool and current_tool.has_method("use"):
			can_interact = current_tool.use(front_grid_position)
			
			# Update highlighter with interaction status
			tile_highlighter.highlight_tile(highlight_pos, can_interact)
		else:
			# No tool, use neutral highlight
			tile_highlighter.highlight_neutral(highlight_pos)
	else:
		# Hide highlighter if no valid tile in front
		tile_highlighter.hide_highlight()

# Handle input events
func _input(event):
	# Tool pickup/drop (E key or X button)
	if event.is_action_pressed(input_prefix + "interact"):
		if current_tool:
			drop_tool()
		elif interaction_manager:
			interaction_manager.start_interaction()
	
	# Tool usage (Space key or Square button)
	if event.is_action_pressed(input_prefix + "use_tool"):
		if current_tool and current_tool.has_method("use"):
			start_tool_use()
	elif event.is_action_released(input_prefix + "use_tool"):
		if is_tool_use_in_progress:
			cancel_tool_use()

# Function to start using a tool
func start_tool_use():
	if not current_tool or is_tool_use_in_progress:
		return
	
	var target_pos = front_grid_position
	
	# Check if another player is already using a tool on this tile
	var pos_key = str(target_pos.x) + "," + str(target_pos.z)
	if tiles_being_used.has(pos_key) and tiles_being_used[pos_key] != self:
		print("Tool use conflict: Another player is already using a tool on this tile")
		return
	
	var can_use = current_tool.use(target_pos)
	
	if can_use:
		# Mark this tile as being used by this player
		tiles_being_used[pos_key] = self
		
		# Use the tool's usage-specific methods
		if current_tool.has_method("get_usage_interaction_type") and current_tool.get_usage_interaction_type() == 1: # 1 = Progress_Based
			# Get duration - use a default of 1.0 if method not found
			var duration = 1.0
			if current_tool.has_method("get_usage_duration"):
				duration = current_tool.get_usage_duration()
			
			# Setup progress tracking
			is_tool_use_in_progress = true
			tool_use_completed = false
			tool_use_start_time = Time.get_ticks_msec()
			tool_use_position = target_pos
			tool_use_duration = duration
			
			# Disable movement during progress-based tool use
			movement_disabled = true
			
			# Show initial progress
			if interaction_feedback:
				interaction_feedback.show_progress(0.0)
		else:
			# Instant tool use
			current_tool.complete_use(target_pos)
			
			# Clear the tile usage immediately for instant tools
			if tiles_being_used.has(pos_key) and tiles_being_used[pos_key] == self:
				tiles_being_used.erase(pos_key)

# New function to handle tool use completion
func _on_tool_use_completed(position):
	# Hide progress bar
	if interaction_feedback:
		interaction_feedback.hide_progress()
	
	# Complete the tool use
	if current_tool and current_tool.has_method("complete_use"):
		var success = current_tool.complete_use(position)
	
	# Reset the tool use state
	is_tool_use_in_progress = false
	# Keep tool_use_completed as true since it was actually completed
	tool_use_position = null
	
	# Clear the tile usage
	var pos_key = str(position.x) + "," + str(position.z)
	if tiles_being_used.has(pos_key) and tiles_being_used[pos_key] == self:
		tiles_being_used.erase(pos_key)
	
	movement_disabled = false

# Cleaner method to cancel tool use
func cancel_tool_use():
	if is_tool_use_in_progress and not tool_use_completed:
		if interaction_feedback:
			interaction_feedback.hide_progress()
			
		movement_disabled = false
		
		# Clear the tile usage
		if tool_use_position:
			var pos_key = str(tool_use_position.x) + "," + str(tool_use_position.z)
			if tiles_being_used.has(pos_key) and tiles_being_used[pos_key] == self:
				tiles_being_used.erase(pos_key)
	
	is_tool_use_in_progress = false
	tool_use_completed = false
	tool_use_position = null

# Get the current tool being held
func get_current_tool():
	return current_tool

# Update interaction progress callback
func update_interaction_progress(progress):
	if interaction_feedback:
		interaction_feedback.update_progress(progress)

# Pick up a tool
func pick_up_tool(tool_obj):
	if not is_instance_valid(tool_obj):
		return
		
	if current_tool:
		# First drop the current tool
		drop_tool()
	
	# Get the original parent to restore when dropping
	tool_obj.original_parent = tool_obj.get_parent()
	
	# Disable physics on the tool
	if tool_obj is RigidBody3D:
		# Store original physics properties to restore later
		tool_obj.original_freeze = tool_obj.freeze
		tool_obj.freeze = true
		
		# Store original collision settings
		tool_obj.original_collision_layer = tool_obj.collision_layer
		tool_obj.original_collision_mask = tool_obj.collision_mask
		
		# Disable collision
		tool_obj.collision_layer = 0
		tool_obj.collision_mask = 0
	
	# Attach the tool to the tool holder
	if tool_obj.get_parent():
		tool_obj.get_parent().remove_child(tool_obj)
		
	if tool_holder:
		tool_holder.add_child(tool_obj)
		
		# Reset transform relative to holder
		tool_obj.position = Vector3.ZERO
		tool_obj.rotation = Vector3.ZERO
		
		# Store reference to current tool
		current_tool = tool_obj
	else:
		push_error("Player: ToolHolder node not found!")

# Drop the current tool
func drop_tool():
	# Simplified drop logic with error checking
	if not current_tool:
		return false
	
	# Store reference to the tool
	var tool_obj = current_tool
	
	# First, unhighlight the tool if it's currently highlighted
	if tool_obj.has_method("set_highlighted"):
		tool_obj.set_highlighted(false)
	
	# Clear the tool reference FIRST
	current_tool = null
	
	# Make sure the tool still exists 
	if not is_instance_valid(tool_obj):
		return false
	
	# Remove from tool holder if it's there
	if tool_holder and tool_obj.get_parent() == tool_holder:
		tool_holder.remove_child(tool_obj)
	
	# Get a parent to add it to
	var target_parent = get_parent()  # Default to player's parent
	
	# Try to use the original parent if available
	if tool_obj.get("original_parent") != null:
		var original = tool_obj.get("original_parent")
		if is_instance_valid(original):
			target_parent = original
	
	# Add to parent if not already in scene
	if not tool_obj.is_inside_tree():
		target_parent.add_child(tool_obj)
	
	# Position in front of player
	var drop_pos = global_position + global_transform.basis.z * 1.0
	drop_pos.y = 1.0  # Slightly above ground
	tool_obj.global_position = drop_pos
	
	# Re-enable physics
	if tool_obj is RigidBody3D:
		# Reset collision
		tool_obj.collision_layer = 1 << 1  # Layer 2
		tool_obj.collision_mask = 1  # Layer 1
		
		# Set not frozen
		tool_obj.freeze = false
		
		# Add impulse
		tool_obj.apply_central_impulse(Vector3(0, 0.5, 0))
	
	# Force update of interaction manager to forget about this tool
	if interaction_manager and interaction_manager.potential_interactable == tool_obj:
		interaction_manager.potential_interactable = null
		interaction_manager.emit_signal("potential_interactable_changed", null)
	
	return true

# Set player color for visual differentiation
func set_color(color: Color):
	var mesh = $MeshInstance3D
	if mesh:
		var material = StandardMaterial3D.new()
		material.albedo_color = color
		mesh.material_override = material

# Signal handlers
func _on_interaction_started(actor, interactable):
	if not is_instance_valid(interactable):
		return
		
	if interactable.has_method("get_interaction_duration") and interaction_feedback:
		interaction_feedback.show_progress(0.0)
		# Disable movement during progress-based interactions
		if interactable.get_interaction_type() == 1: # 1 = PROGRESS_BASED
			movement_disabled = true

func _on_interaction_completed(actor, interactable):
	if interaction_feedback:
		interaction_feedback.hide_progress()
	# Re-enable movement
	movement_disabled = false

func _on_interaction_canceled(actor, interactable):
	if interaction_feedback:
		interaction_feedback.hide_progress()
	movement_disabled = false

func _on_potential_interactable_changed(interactable):
	if not interaction_feedback:
		return
		
	if interactable and interactable.has_method("get_interaction_prompt"):
		interaction_feedback.show_prompt(interactable.get_interaction_prompt())
	else:
		interaction_feedback.hide_prompt()

# Helper function to get player's front grid position
func get_front_grid_position() -> Vector3i:
	return front_grid_position

# Debug method to verify input is working
func debug_input():
	print("Player " + str(player_index) + " using prefix: " + input_prefix)
	print("  Move actions: " + 
		  input_prefix + "move_left: " + str(Input.is_action_pressed(input_prefix + "move_left")) + ", " +
		  input_prefix + "move_right: " + str(Input.is_action_pressed(input_prefix + "move_right")) + ", " +
		  input_prefix + "move_up: " + str(Input.is_action_pressed(input_prefix + "move_up")) + ", " +
		  input_prefix + "move_down: " + str(Input.is_action_pressed(input_prefix + "move_down")))
		
func clear_tool_reference(tool_obj):
	if current_tool == tool_obj:
		print("Player " + str(player_index) + ": Clearing reference to tool: " + str(tool_obj.name if is_instance_valid(tool_obj) else "unknown"))
		current_tool = null
		return true
	return false
