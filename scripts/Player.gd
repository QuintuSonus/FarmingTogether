# scripts/Player.gd
extends CharacterBody3D

# Player movement parameters
@export var normal_speed: float = 4.0
@export var mud_speed: float = 2.0
@export var acceleration: float = 8.0
@export var rotation_speed: float = 10.0

# Node references
var level_manager: Node
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

# Called when the node enters the scene tree for the first time
func _ready():
	# Get a reference to the level manager
	level_manager = get_node("../LevelManager")
	
	# Connect signals
	interaction_manager.connect("interaction_started", _on_interaction_started)
	interaction_manager.connect("interaction_completed", _on_interaction_completed)
	interaction_manager.connect("interaction_canceled", _on_interaction_canceled)
	interaction_manager.connect("potential_interactable_changed", _on_potential_interactable_changed)
	
	# Setup tile highlighter
	tile_highlighter = $TileHighlighter
	
	if not tile_highlighter:
		# Create and add the TileHighlighter node if it doesn't exist
		var highlighter_scene = load("res://scenes/ui/TileHighlighter.tscn")
		if highlighter_scene:
			tile_highlighter = highlighter_scene.instantiate()
			add_child(tile_highlighter)
	
	print("Player initialized")

# Handle physics updates
func _physics_process(delta):
	# Get input direction
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	# Update current grid position
	if level_manager:
		current_grid_position = level_manager.world_to_grid(global_position)
		current_tile_type = level_manager.get_tile_type(current_grid_position)
	
	# Determine current speed based on tile type
	var current_speed = normal_speed
	if current_tile_type == level_manager.TileType.MUD:
		current_speed = mud_speed
	
	# Set velocity based on input
	if direction:
		# Gradually accelerate in the input direction
		velocity.x = move_toward(velocity.x, direction.x * current_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, acceleration * delta)
		
		# Rotate player to face movement direction
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)
	else:
		# Gradually slow down to a stop
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0, acceleration * delta)
	
	# Apply movement
	move_and_slide()
	
	# Update interaction progress if in progress
	if Input.is_action_pressed("interact"):
		interaction_manager.update_interaction(delta)
	
	# Update tool use progress if in progress
	if is_tool_use_in_progress and not tool_use_completed:
		update_tool_use_progress(delta)
	
	# Update tile highlighting
	if tile_highlighter:
		update_tile_highlight()

# Update the tool use progress
func update_tool_use_progress(delta):
	print("Updating tool use progress. Duration:", tool_use_duration)
	
	if is_tool_use_in_progress and not tool_use_completed and tool_use_duration > 0:
		var elapsed = (Time.get_ticks_msec() - tool_use_start_time) / 1000.0
		var progress = clamp(elapsed / tool_use_duration, 0.0, 1.0)
		
		print("Progress calculation: elapsed=", elapsed, ", progress=", progress)
		
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
	if !level_manager or !tile_targeting_point:
		return
	
	# Calculate the forward point more precisely
	var forward_point = global_position + (global_transform.basis.z.normalized() * 1.0)
	
	# Convert directly to grid position - this is the tile we want to interact with
	front_grid_position = level_manager.world_to_grid(forward_point)
	
	# Also get player's current grid position
	current_grid_position = level_manager.world_to_grid(global_position)
		
	# Check if this tile is within bounds
	if level_manager.is_within_bounds(front_grid_position):
		# Get world position of this grid cell for highlighting
		var highlight_pos = level_manager.grid_to_world(front_grid_position)
		# Center the highlight on the tile
		highlight_pos.x += 0
		highlight_pos.z += 0
		
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
	# Tool pickup/drop (E key)
	if event.is_action_pressed("interact"):
		if current_tool:
			drop_tool()
		else:
			interaction_manager.start_interaction()
	
	# Tool usage (Space key)
	if event.is_action_pressed("use_tool"):
		if current_tool and current_tool.has_method("use"):
			start_tool_use()
	elif event.is_action_released("use_tool"):
		if is_tool_use_in_progress:
			cancel_tool_use()

# New function to handle tool use completion
func _on_tool_use_completed(position):
	print("Player: Tool use completed at position ", position)
	
	# Hide progress bar
	if interaction_feedback:
		interaction_feedback.hide_progress()
	
	# Complete the tool use
	if current_tool and current_tool.has_method("complete_use"):
		var success = current_tool.complete_use(position)
		print("Player: Tool use completion result: ", success)
	else:
		print("Player: No tool or no complete_use method")

# Get the current tool being held
func get_current_tool():
	
	return current_tool
	
func start_tool_use():
	if not current_tool or is_tool_use_in_progress:
		return
	
	var target_pos = front_grid_position
	print("Attempting to use tool at position:", target_pos)
	
	var can_use = current_tool.use(target_pos)
	print("Tool.use() result:", can_use)
	
	if can_use:
		print("Tool type:", current_tool.get_class())
		print("Has get_usage_interaction_type:", current_tool.has_method("get_usage_interaction_type"))
		
		if current_tool.has_method("get_usage_interaction_type"):
			print("Usage interaction type:", current_tool.get_usage_interaction_type())
		
		# Use the tool's usage-specific methods
		if current_tool.has_method("get_usage_interaction_type") and current_tool.get_usage_interaction_type() == Interactable.InteractionType.PROGRESS_BASED:
			# Get duration - use a default of 1.0 if method not found
			var duration = 1.0
			if current_tool.has_method("get_usage_duration"):
				duration = current_tool.get_usage_duration()
			
			print("Starting progress-based tool use with duration:", duration)
			
			# Setup progress tracking
			is_tool_use_in_progress = true
			tool_use_completed = false
			tool_use_start_time = Time.get_ticks_msec()
			tool_use_position = target_pos
			tool_use_duration = duration
			
			# Show initial progress
			if interaction_feedback:
				interaction_feedback.show_progress(0.0)
				print("Progress bar shown at 0%")
		else:
			# Instant tool use
			print("Completing instantaneous tool use")
			current_tool.complete_use(target_pos)

# NEW: Cleaner method to cancel tool use
func cancel_tool_use():
	if is_tool_use_in_progress and not tool_use_completed:
		if interaction_feedback:
			interaction_feedback.hide_progress()
	
	is_tool_use_in_progress = false
	tool_use_completed = false
	tool_use_position = null
# Update interaction progress callback
func update_interaction_progress(progress):
	if interaction_feedback:
		interaction_feedback.update_progress(progress)

# Pick up a tool
func pick_up_tool(tool_obj):
	print("Player: Picking up tool: ", tool_obj.name)
	
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
	tool_holder.add_child(tool_obj)
	
	# Reset transform relative to holder
	tool_obj.position = Vector3.ZERO
	tool_obj.rotation = Vector3.ZERO
	
	# Store reference to current tool
	current_tool = tool_obj
	
	print("Picked up: ", tool_obj.name)

# Drop the current tool
func drop_tool():
	# VERY SIMPLIFIED DROP LOGIC WITH THOROUGH ERROR CHECKING
	if not current_tool:
		print("No tool to drop")
		return false
	
	print("Player: Dropping tool: ", current_tool.name)
	
	# Store reference to the tool
	var tool_obj = current_tool
	
	# Clear the tool reference FIRST
	current_tool = null
	
	# Make sure the tool still exists 
	if not is_instance_valid(tool_obj):
		print("Tool is no longer valid - abandoning drop")
		return false
	
	# Remove from tool holder if it's there
	if tool_obj.get_parent() == tool_holder:
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
	
	print("Tool successfully dropped")
	return true

# Signal handlers
func _on_interaction_started(actor, interactable):
	print("Player: Interaction started with ", interactable.name)
	if interactable.has_method("get_interaction_duration"):
		interaction_feedback.show_progress(0.0)

func _on_interaction_completed(actor, interactable):
	print("Player: Interaction completed with ", interactable.name)
	interaction_feedback.hide_progress()

func _on_interaction_canceled(actor, interactable):
	print("Player: Interaction canceled with ", interactable.name if interactable else "null")
	interaction_feedback.hide_progress()

func _on_potential_interactable_changed(interactable):
	if interactable and interactable.has_method("get_interaction_prompt"):
		interaction_feedback.show_prompt(interactable.get_interaction_prompt())
	else:
		interaction_feedback.hide_prompt()

# Optional area detection functions (if you're using Area3D for interaction)
func _on_interaction_area_body_entered(body):
	# Additional interaction logic if needed
	pass

func _on_interaction_area_body_exited(body):
	# Additional interaction logic if needed
	pass
