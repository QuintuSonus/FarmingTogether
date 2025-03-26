# scripts/player/PlayerMovement.gd
class_name PlayerMovement
extends Node

# Player controller reference
var player: CharacterBody3D = null

# Movement parameters
@export var normal_speed: float = 4.0
@export var mud_speed: float = 2.0
@export var move_acceleration: float = 8.0
@export var stop_acceleration: float = 8.0
@export var rotation_speed: float = 10.0
@export var controller_deadzone: float = 0.2

# State
var movement_disabled: bool = false
var input_prefix: String = "p1_"
var level_manager = null
var current_tile_type = null

func set_level_manager(manager):
	level_manager = manager

func _physics_process(delta):
	# Skip if movement is disabled
	if movement_disabled:
		return
	
	# Get movement vector
	var input_dir = get_movement_vector()
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	# Update speed based on current tile
	var current_speed = get_current_speed()
	
	# Apply movement
	if direction:
		# Get input strength for variable speed (for analog controls)
		var input_strength = input_dir.length()
		var target_speed = current_speed
		
		if input_strength < 0.99 and input_strength > controller_deadzone:
			target_speed = current_speed * input_strength
		
		# Accelerate towards target direction and speed
		player.velocity.x = move_toward(player.velocity.x, direction.x * target_speed, move_acceleration * delta)
		player.velocity.z = move_toward(player.velocity.z, direction.z * target_speed, move_acceleration * delta)
		
		# Rotate player to face movement direction
		var target_rotation = atan2(direction.x, direction.z)
		player.rotation.y = lerp_angle(player.rotation.y, target_rotation, rotation_speed * delta)
	else:
		# Slow down to a stop
		player.velocity.x = move_toward(player.velocity.x, 0, stop_acceleration * delta)
		player.velocity.z = move_toward(player.velocity.z, 0, stop_acceleration * delta)
	
	# Apply movement
	player.move_and_slide()

# Get current speed based on tile
func get_current_speed() -> float:
	update_player_speed_from_parameters()
	if not level_manager:
		return normal_speed
		
	# Use GridTracker to get current grid position
	var grid_tracker = player.get_node_or_null("PlayerGridTracker")
	if grid_tracker:
		var grid_pos = grid_tracker.current_grid_position
		current_tile_type = level_manager.get_tile_type(grid_pos)
		
		# Check for mud using enum from level_manager
		if current_tile_type == level_manager.TileType.MUD:
			return mud_speed
			
	return normal_speed
	
# Get movement vector from input based on player index
func get_movement_vector() -> Vector2:
	var input_dir = Input.get_vector(
		input_prefix + "move_left", 
		input_prefix + "move_right", 
		input_prefix + "move_up", 
		input_prefix + "move_down"
	)
	
	# Apply deadzone for controller input
	if input_dir.length() < controller_deadzone:
		input_dir = Vector2.ZERO
		
	return input_dir

# Update input prefix when player index changes
func set_player_index(index: int):
	input_prefix = "p" + str(index + 1) + "_"
	print("PlayerMovement: Updated input prefix to " + input_prefix)

func update_player_speed_from_parameters():
	# Try to get parameter manager
	var parameter_manager = get_parameter_manager()
	
	if parameter_manager:
		# Get the base capacity from parameters
		var new_speed = parameter_manager.get_value("player.movement_speed", normal_speed)
		
		# Update the capacity
		var old_speed = normal_speed
		normal_speed = new_speed
		
	else:
		print("PlayerSpeed: No parameter manager found, using default capacity: ", normal_speed)
		

func get_parameter_manager():
	var service_locator = get_node_or_null("/root/ServiceLocator")
	if service_locator and service_locator.has_method("get_service"):
		return service_locator.get_service("parameter_manager")
		print("parameters found")
	return null
