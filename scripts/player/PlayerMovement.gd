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

# --- Gravity ---
# Get gravity value from project settings
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready():
	# Get player reference from owner if not set externally
	if not is_instance_valid(player) and owner is CharacterBody3D:
		player = owner
	# Ensure player reference is valid before proceeding
	if not is_instance_valid(player):
		push_error("PlayerMovement: Invalid player reference in _ready()!")
		set_physics_process(false) # Disable physics process if player is missing

func set_level_manager(manager):
	level_manager = manager

# Function to enable/disable movement externally
func set_movement_disabled(disabled: bool):
	movement_disabled = disabled
	print("PlayerMovement: Movement disabled set to: %s" % disabled)
	if disabled and is_instance_valid(player):
		player.velocity.x = 0.0
		player.velocity.z = 0.0

func _physics_process(delta):
	if not is_instance_valid(player):
		if owner is CharacterBody3D:
			player = owner
		else:
			set_physics_process(false)
			push_warning("PlayerMovement: Player node became invalid. Disabling physics process.")
			return

	# --- Apply Gravity ---
	# Add the gravity.
	if not player.is_on_floor():
		player.velocity.y -= gravity * delta
	# --- End Gravity ---

	# Skip horizontal movement if disabled
	if movement_disabled:
		# Still need move_and_slide to apply gravity and check floor state
		player.move_and_slide()
		return

	# Get movement vector
	var input_dir = get_movement_vector()
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized() # Global

	# Update speed based on current tile
	var current_speed = get_current_speed()

	# Apply movement
	if direction != Vector3.ZERO:
		var input_strength = input_dir.length()
		var target_speed = current_speed

		if input_strength > controller_deadzone:
			target_speed = current_speed * input_strength
		else:
			target_speed = 0

		# Accelerate towards target direction and speed
		player.velocity.x = move_toward(player.velocity.x, direction.x * target_speed, move_acceleration * delta)
		player.velocity.z = move_toward(player.velocity.z, direction.z * target_speed, move_acceleration * delta)

		# Rotate player to face movement direction
		var target_rotation = atan2(direction.x, direction.z)
		player.rotation.y = lerp_angle(player.rotation.y, target_rotation, rotation_speed * delta)
	else:
		# Slow down to a stop (Decelerate)
		player.velocity.x = move_toward(player.velocity.x, 0.0, stop_acceleration * delta)
		player.velocity.z = move_toward(player.velocity.z, 0.0, stop_acceleration * delta)

	# Apply movement and gravity
	player.move_and_slide()

# Get current speed based on tile
func get_current_speed() -> float:
	update_player_speed_from_parameters() # Update speeds from ParameterManager if applicable

	if not is_instance_valid(level_manager):
		return normal_speed

	if not is_instance_valid(player):
		return normal_speed

	var grid_tracker = player.get_node_or_null("PlayerGridTracker")
	if grid_tracker and grid_tracker.has_method("get_current_grid_position"):
		var grid_pos = grid_tracker.get_current_grid_position()
		if level_manager.has_method("get_tile_type"): # Check method exists
			current_tile_type = level_manager.get_tile_type(grid_pos)
			# Assuming LevelManager has TileType enum accessible or defined
			if current_tile_type == level_manager.TileType.MUD: # Check for MUD tile type
				return mud_speed
		else:
			push_warning("LevelManager is missing 'get_tile_type' method.")

	return normal_speed


# Get movement vector from input based on player index
func get_movement_vector() -> Vector2:
	var input_dir = Input.get_vector(
		input_prefix + "move_left",
		input_prefix + "move_right",
		input_prefix + "move_up",
		input_prefix + "move_down"
	)

	if input_dir.length_squared() < controller_deadzone * controller_deadzone:
		input_dir = Vector2.ZERO

	return input_dir

# Update input prefix when player index changes
func set_player_index(index: int):
	if index < 0:
		push_warning("Invalid player index provided: %d. Using default." % index)
		input_prefix = "p1_"
	else:
		input_prefix = "p" + str(index + 1) + "_"
	print("PlayerMovement: Updated input prefix to " + input_prefix)

func update_player_speed_from_parameters():
	var parameter_manager = get_parameter_manager()
	if parameter_manager:
		var new_speed = parameter_manager.get_value("player.movement_speed", normal_speed)
		if new_speed != normal_speed:
			print("PlayerMovement: Updating normal_speed from %f to %f via ParameterManager." % [normal_speed, new_speed])
			normal_speed = new_speed
		# Update mud speed too if needed
		var new_mud_speed = parameter_manager.get_value("player.mud_speed", mud_speed)
		if new_mud_speed != mud_speed:
			print("PlayerMovement: Updating mud_speed from %f to %f via ParameterManager." % [mud_speed, new_mud_speed])
			mud_speed = new_mud_speed


func get_parameter_manager():
	if get_tree().root.has_node("ServiceLocator"):
		var service_locator = get_node("/root/ServiceLocator")
		if service_locator and service_locator.has_method("get_service") and service_locator.has_method("has_service") :
			if service_locator.has_service("parameter_manager"):
				return service_locator.get_service("parameter_manager")
	return null
