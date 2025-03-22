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

# Track current tile information
var current_tile_type = null
var current_grid_position: Vector3i = Vector3i(0, 0, 0)

# Called when the node enters the scene tree for the first time
func _ready():
	# Get a reference to the level manager
	level_manager = get_node("../LevelManager")
	
	# Connect signals
	interaction_manager.connect("interaction_started", _on_interaction_started)
	interaction_manager.connect("interaction_completed", _on_interaction_completed)
	interaction_manager.connect("interaction_canceled", _on_interaction_canceled)
	interaction_manager.connect("potential_interactable_changed", _on_potential_interactable_changed)

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
	if Input.is_action_pressed("interact") or Input.is_action_pressed("use_tool"):
		interaction_manager.update_interaction(delta)

# Handle input events
func _input(event):
	# Tool pickup/drop interaction
	if event.is_action_pressed("interact"):
		interaction_manager.start_interaction("interact")
	
	# Tool usage
	if event.is_action_pressed("use_tool"):
		if current_tool and current_tool.has_method("use"):
			if current_tool.use(current_grid_position):
				# Start a progress-based interaction for tool use
				var interaction_type = current_tool.get_interaction_type()
				if interaction_type == Interactable.InteractionType.PROGRESS_BASED:
					interaction_manager.start_interaction("use_tool")
	
	# Cancel interaction if key released during progress-based interaction
	if event.is_action_released("interact") or event.is_action_released("use_tool"):
		interaction_manager.cancel_interaction()

# Pick up a tool
func pick_up_tool(tool_obj):
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

# Replace the drop_tool function with this corrected version:
func drop_tool():
	if current_tool:
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
	if interactable.has_method("get_interaction_duration"):
		interaction_feedback.show_progress(0.0)

func _on_interaction_completed(actor, interactable):
	interaction_feedback.hide_progress()
	
	# Special handling for tool use completion
	if interactable == current_tool and current_tool.has_method("complete_use"):
		current_tool.complete_use(current_grid_position)

func _on_interaction_canceled(actor, interactable):
	interaction_feedback.hide_progress()

func _on_potential_interactable_changed(interactable):
	if interactable and interactable.has_method("get_interaction_prompt"):
		interaction_feedback.show_prompt(interactable.get_interaction_prompt())
	else:
		interaction_feedback.hide_prompt()
