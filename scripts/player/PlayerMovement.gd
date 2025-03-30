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
var movement_disabled: bool = false # Already exists - good!
var input_prefix: String = "p1_"
var level_manager = null
var current_tile_type = null

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

# --- NEW FUNCTION ---
# Function to enable/disable movement externally (called by PlayerToolHandler)
func set_movement_disabled(disabled: bool):
	"""
	Enables or disables player movement processing.
	Optionally stops current velocity when disabled.
	"""
	movement_disabled = disabled
	print("PlayerMovement: Movement disabled set to: %s" % disabled)
	# Optional: If disabled, immediately stop horizontal movement
	if disabled and is_instance_valid(player):
		player.velocity.x = 0.0
		player.velocity.z = 0.0
		# Consider if you want to stop vertical velocity too, or let gravity handle it
		# player.velocity.y = 0.0
# --- END NEW FUNCTION ---

func _physics_process(delta):
	# Ensure player reference is valid (could become invalid during gameplay)
	if not is_instance_valid(player):
		# Optionally try to re-acquire owner if it became valid?
		# Or just disable processing to prevent errors.
		if owner is CharacterBody3D:
			player = owner
		else:
			set_physics_process(false) # Disable if player is truly gone
			push_warning("PlayerMovement: Player node became invalid. Disabling physics process.")
			return

	# Skip if movement is disabled (Already correctly implemented!)
	if movement_disabled:
		# Even if disabled, you might want gravity or other effects
		# For example, if you have gravity:
		# if not player.is_on_floor():
		#	 player.velocity.y -= project_settings.get_setting("physics/3d/default_gravity") * delta
		# player.move_and_slide() # Apply gravity/floor check
		return # Skip rest of movement logic

	# Get movement vector
	var input_dir = get_movement_vector()
	# Use player's basis for direction relative to player facing, if needed,
	# or global direction if camera controls orientation. Assuming global for now.
	# var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized() # Local
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized() # Global

	# Update speed based on current tile
	var current_speed = get_current_speed()

	# Apply movement
	if direction != Vector3.ZERO: # Check against Vector3.ZERO for clarity
		# Get input strength for variable speed (for analog controls)
		var input_strength = input_dir.length()
		var target_speed = current_speed

		# Apply strength scaling only if above deadzone
		# The check input_strength < 0.99 might be unnecessary unless you want specific behaviour near max input
		if input_strength > controller_deadzone: # Simplified check
			target_speed = current_speed * input_strength
		else:
			target_speed = 0 # Ensure speed is 0 if within deadzone but direction is somehow non-zero

		# Accelerate towards target direction and speed
		# Using lerp might feel smoother for acceleration than move_toward
		# player.velocity.x = lerp(player.velocity.x, direction.x * target_speed, move_acceleration * delta)
		# player.velocity.z = lerp(player.velocity.z, direction.z * target_speed, move_acceleration * delta)
		# Using move_toward as per original code:
		player.velocity.x = move_toward(player.velocity.x, direction.x * target_speed, move_acceleration * delta)
		player.velocity.z = move_toward(player.velocity.z, direction.z * target_speed, move_acceleration * delta)

		# Rotate player to face movement direction
		# Ensure direction is not zero before calculating atan2
		var target_rotation = atan2(direction.x, direction.z)
		# Use lerp_angle for smooth rotation interpolation
		player.rotation.y = lerp_angle(player.rotation.y, target_rotation, rotation_speed * delta)
	else:
		# Slow down to a stop (Decelerate)
		# Using lerp might feel smoother here too
		# player.velocity.x = lerp(player.velocity.x, 0.0, stop_acceleration * delta)
		# player.velocity.z = lerp(player.velocity.z, 0.0, stop_acceleration * delta)
		# Using move_toward as per original code:
		player.velocity.x = move_toward(player.velocity.x, 0.0, stop_acceleration * delta)
		player.velocity.z = move_toward(player.velocity.z, 0.0, stop_acceleration * delta)

	# Apply gravity (Example - uncomment and adjust if needed)
	# var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	# if not player.is_on_floor():
	#	 player.velocity.y -= gravity * delta

	# Apply movement using move_and_slide
	player.move_and_slide()

# Get current speed based on tile
func get_current_speed() -> float:
	# Update speed from parameters first (if they can change dynamically)
	update_player_speed_from_parameters()

	if not is_instance_valid(level_manager):
		return normal_speed

	# Use GridTracker to get current grid position
	# Ensure player reference is valid before getting child node
	if not is_instance_valid(player):
		return normal_speed

	var grid_tracker = player.get_node_or_null("PlayerGridTracker")
	if grid_tracker and grid_tracker.has_method("get_current_grid_position"): # Check method exists
		var grid_pos = grid_tracker.get_current_grid_position() # Assuming this method exists and returns correct type
		# Ensure level_manager has the expected methods/properties
		if level_manager.has_method("get_tile_type") and level_manager.has_meta("TileType"):
			current_tile_type = level_manager.get_tile_type(grid_pos)
			var tile_enum = level_manager.get_meta("TileType") # Assuming TileType is stored in meta or accessible directly

			# Check for mud using enum from level_manager
			# Ensure the enum value MUD exists
			if tile_enum and tile_enum.has("MUD") and current_tile_type == tile_enum.MUD:
				return mud_speed
		else:
			push_warning("LevelManager is missing 'get_tile_type' method or 'TileType' metadata.")

	return normal_speed

# Get movement vector from input based on player index
func get_movement_vector() -> Vector2:
	# Corrected input actions based on common naming conventions (up/down for forward/backward)
	var input_dir = Input.get_vector(
		input_prefix + "move_left",
		input_prefix + "move_right",
		input_prefix + "move_up", # Usually mapped to W or Up Arrow
		input_prefix + "move_down" # Usually mapped to S or Down Arrow
	)

	# Apply deadzone for controller input
	if input_dir.length_squared() < controller_deadzone * controller_deadzone: # Use length_squared for efficiency
		input_dir = Vector2.ZERO

	return input_dir

# Update input prefix when player index changes
func set_player_index(index: int):
	# Ensure index is non-negative
	if index < 0:
		push_warning("Invalid player index provided: %d. Using default." % index)
		input_prefix = "p1_"
	else:
		input_prefix = "p" + str(index + 1) + "_"
	print("PlayerMovement: Updated input prefix to " + input_prefix)

func update_player_speed_from_parameters():
	# Try to get parameter manager
	var parameter_manager = get_parameter_manager()

	if parameter_manager:
		# Get the base speed from parameters, using current normal_speed as fallback
		var new_speed = parameter_manager.get_value("player.movement_speed", normal_speed)

		# Update the speed if it changed
		if new_speed != normal_speed:
			print("PlayerMovement: Updating normal_speed from %f to %f via ParameterManager." % [normal_speed, new_speed])
			normal_speed = new_speed
		# No need for old_speed variable unless used elsewhere

	# Removed noisy print statement for when parameter manager isn't found
	# else:
		# print("PlayerMovement: No parameter manager found, using default speed: ", normal_speed)


func get_parameter_manager():
	# Check node exists before getting it
	if get_tree().root.has_node("ServiceLocator"):
		var service_locator = get_node("/root/ServiceLocator")
		# Check methods exist before calling
		if service_locator and service_locator.has_method("get_service") and service_locator.has_method("has_service") :
			if service_locator.has_service("parameter_manager"):
				# print("Parameter manager service found.") # Optional debug print
				return service_locator.get_service("parameter_manager")
			# else:
				# print("Parameter manager service NOT registered in ServiceLocator.") # Optional debug print
	# else:
		# print("ServiceLocator node not found at /root/ServiceLocator.") # Optional debug print
	return null
