# Player.gd
extends CharacterBody3D

# Player movement parameters
@export var normal_speed: float = 4.0
@export var mud_speed: float = 2.0
@export var acceleration: float = 8.0
@export var rotation_speed: float = 10.0

# Node references
var level_manager: Node
var current_tool = null

# Track current tile information
var current_tile_type = null
var current_grid_position: Vector3i = Vector3i(0, 0, 0)

# Interaction parameters
@export var interaction_range: float = 1.5
@export var interaction_angle_degrees: float = 120.0
@export var interaction_visual_feedback: bool = true

# Called when the node enters the scene tree for the first time
func _ready():
	# Get a reference to the level manager
	level_manager = get_node("../LevelManager")

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

# Handle input events
func _input(event):
	# Tool pickup/drop interaction
	if event.is_action_pressed("interact"):
		# Try to interact with nearby objects
		interact()
	
	# Tool usage
	if event.is_action_pressed("use_tool"):
		# Try to use the currently held tool
		use_tool()

# Get the interactable object with highest priority in range
func get_best_interactable():
	# Cast a ray forward to find interactable objects
	var space_state = get_world_3d().direct_space_state
	var ray_origin = global_position + Vector3(0, 0.5, 0)  # Start ray from slightly above player center
	var forward_dir = -global_transform.basis.z  # Player's forward direction
	
	# Calculate interaction directions within the cone
	var interaction_angle_rad = deg_to_rad(interaction_angle_degrees / 2)
	var interactables = []
	
	# Create a physics ray query
	var query = PhysicsRayQueryParameters3D.new()
	query.from = ray_origin
	query.to = ray_origin + forward_dir * interaction_range
	query.collision_mask = 2  # Assuming interactable objects are on layer 2
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var obj = result.collider
		if obj.has_method("can_interact"):
			# Calculate angle between forward vector and object direction
			var dir_to_obj = (obj.global_position - global_position).normalized()
			var dot_product = forward_dir.dot(dir_to_obj)
			var angle = acos(dot_product)
			
			if angle <= interaction_angle_rad:
				# Calculate priority based on distance and angle
				var distance = global_position.distance_to(obj.global_position)
				var priority = 1.0 / (distance + 0.001)  # Avoid division by zero
				
				interactables.append({
					"object": obj,
					"distance": distance,
					"priority": priority
				})
	
	# Sort by priority and return the best one
	if interactables.size() > 0:
		interactables.sort_custom(func(a, b): return a.priority > b.priority)
		return interactables[0].object
	
	return null

# Interact with objects in range
func interact():
	var interactable = get_best_interactable()
	
	if interactable:
		if interactable.has_method("interact"):
			interactable.interact(self)
	elif current_tool:
		# Drop the current tool if no interactable is found
		drop_tool()

# Use the currently held tool
func use_tool():
	if current_tool and current_tool.has_method("use"):
		current_tool.use(self, current_grid_position)

# Pick up a tool
func pick_up_tool(tool_obj):
	if current_tool:
		# First drop the current tool
		drop_tool()
	
	# Attach the new tool to the player
	current_tool = tool_obj
	tool_obj.get_parent().remove_child(tool_obj)
	add_child(tool_obj)
	tool_obj.position = Vector3(0, 0.5, 0)  # Position the tool slightly above the player
	
	print("Picked up: ", tool_obj.name)

# Drop the currently held tool
func drop_tool():
	if current_tool:
		var tool_obj = current_tool
		remove_child(tool_obj)
		get_parent().add_child(tool_obj)
		
		# Place tool on the ground in front of the player
		var drop_pos = global_position - global_transform.basis.z * 1.0
		drop_pos.y = 0.1  # Place slightly above ground
		tool_obj.global_position = drop_pos
		
		current_tool = null
		print("Dropped tool")

# Called when player enters a tile
func _on_area_entered(area):
	# This could be used for additional interactions when moving onto specific tiles
	pass
