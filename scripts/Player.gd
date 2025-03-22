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

# Tile highlighter and position tracking
var tile_highlighter = null
var current_tile_type = null
var current_grid_position: Vector3i = Vector3i(0, 0, 0)
var front_grid_position: Vector3i = Vector3i(0, 0, 0)

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
	
	# Update tile highlighting
	if tile_highlighter:
		update_tile_highlight()

# Update the tile highlight based on player position and direction
func update_tile_highlight():
	if !level_manager:
		return
	
	# Get the forward direction
	var forward_dir = global_transform.basis.z.normalized()
	
	# Calculate a position in front of the player
	var front_pos = global_position + forward_dir * 1.5  # Look 1.5 units ahead
	
	# Convert to grid position
	front_grid_position = level_manager.world_to_grid(front_pos)
	
	# Make sure the detected tile is different from the player's current tile
	if front_grid_position == current_grid_position:
		# Try looking further ahead
		front_pos = global_position + forward_dir * 2.0
		front_grid_position = level_manager.world_to_grid(front_pos)
	
	# Check if this tile is within bounds
	if level_manager.is_within_bounds(front_grid_position):
		# Get world position of this grid cell for highlighting
		var highlight_pos = level_manager.grid_to_world(front_grid_position)
		
		# Check if the current tool can interact with this tile
		var can_interact = false
		if current_tool and current_tool.has_method("use"):
			# Make sure position is Vector3i
			var pos = Vector3i(front_grid_position.x, front_grid_position.y, front_grid_position.z)
			can_interact = current_tool.use(pos)
			
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
	# Tool pickup/drop interaction (E key)
	if event.is_action_pressed("interact"):
		print("Player: INTERACT button pressed (E)")
		interaction_manager.start_interaction("interact")
	
	# Tool usage (Space key)
	if event.is_action_pressed("use_tool"):
		print("Player: USE TOOL button pressed (Space)")
		# Only handle tool usage if we have a tool
		if current_tool and current_tool.has_method("use"):
			# Make sure position is Vector3i
			var pos = Vector3i(front_grid_position.x, front_grid_position.y, front_grid_position.z)
			var can_use = current_tool.use(pos)
			
			print("Player: Tool can be used: ", can_use, " at position ", pos)
			
			if can_use:
				# For progress-based tools like Hoe
				if current_tool.has_method("get_interaction_type") and current_tool.get_interaction_type() == Interactable.InteractionType.PROGRESS_BASED:
					print("Player: Starting progress-based tool use")
					
					# Show progress feedback
					if interaction_feedback:
						interaction_feedback.show_progress(0.0)
					
					# Create a timer for tool use
					var duration = current_tool.get_interaction_duration() if current_tool.has_method("get_interaction_duration") else 1.0
					
					# Create a timer to handle progress
					var progress_timer = Timer.new()
					progress_timer.wait_time = 0.05  # Update roughly 20 times per second
					progress_timer.autostart = true
					add_child(progress_timer)
					
					# Create a timer for completion
					var completion_timer = Timer.new()
					completion_timer.wait_time = duration
					completion_timer.one_shot = true
					completion_timer.autostart = true
					add_child(completion_timer)
					
					# Track elapsed time
					var elapsed_time = 0.0
					
					# Connect signals
					progress_timer.timeout.connect(func():
						elapsed_time += progress_timer.wait_time
						var progress = min(elapsed_time / duration, 1.0)
						if interaction_feedback:
							interaction_feedback.update_progress(progress)
					)
					
					completion_timer.timeout.connect(func():
						# Clean up timers
						progress_timer.queue_free()
						completion_timer.queue_free()
						# Complete the tool use
						_on_tool_use_completed(pos)
					)
					
					# Store the timers for potential cancellation
					set_meta("progress_timer", progress_timer)
					set_meta("completion_timer", completion_timer)
				else:
					# Instant tools like watering can
					print("Player: Completing instantaneous tool use")
					current_tool.complete_use(pos)
	
	# Cancel interaction if key released (for canceling ongoing tool use)
	if event.is_action_released("use_tool"):
		# Only cancel if we were in the middle of using a tool
		if interaction_feedback and interaction_feedback.progress_bar.visible:
			print("Player: Tool use canceled")
			
			# Clean up timers if they exist
			if has_meta("progress_timer"):
				var progress_timer = get_meta("progress_timer")
				if is_instance_valid(progress_timer):
					progress_timer.queue_free()
				remove_meta("progress_timer")
				
			if has_meta("completion_timer"):
				var completion_timer = get_meta("completion_timer")
				if is_instance_valid(completion_timer):
					completion_timer.queue_free()
				remove_meta("completion_timer")
				
			interaction_feedback.hide_progress()

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
	if current_tool:
		print("Player: Dropping tool: ", current_tool.name)
		
		var tool_obj = current_tool
		current_tool = null
		
		# Remove from tool holder
		tool_holder.remove_child(tool_obj)
		
		# Add back to original parent or main scene
		var target_parent = tool_obj.get("original_parent")
		if target_parent == null:
			target_parent = get_parent()
		target_parent.add_child(tool_obj)
		
		# Position the tool in front of the player
		var drop_pos = global_position + global_transform.basis.z * 1.0
		drop_pos.y = 1  # Slightly above ground to prevent clipping
		tool_obj.global_position = drop_pos
		
		# Re-enable physics
		if tool_obj is RigidBody3D:
			# Restore original freeze state if property exists
			if "original_freeze" in tool_obj:
				tool_obj.freeze = tool_obj.original_freeze
			else:
				tool_obj.freeze = false
				
			# Restore original collision settings
			if "original_collision_layer" in tool_obj:
				tool_obj.collision_layer = tool_obj.original_collision_layer
			else:
				tool_obj.collision_layer = 1 << 1  # Layer 2
				
			if "original_collision_mask" in tool_obj:
				tool_obj.collision_mask = tool_obj.original_collision_mask
			else:
				tool_obj.collision_mask = 1  # Layer 1
			
			# Add a small upward impulse to prevent clipping with the ground
			tool_obj.apply_central_impulse(Vector3(0, 0.5, 0))
		
		print("Dropped tool")

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
