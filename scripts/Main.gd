extends Node3D

# Configuration for the camera
@export var camera_follow_player: bool = true
@export var camera_height: float = 10.0
@export var camera_distance: float = 5.0
@export var camera_angle: float = -60.0  # In degrees

# Reference to nodes
var player: CharacterBody3D
var camera: Camera3D

func _ready():
	# Called when the scene is added to the tree
	print("Farm Together: Harvest Rush - 3D Level initialized")
	
	# Get references to player and camera
	player = $Player
	camera = $Camera3D
	
	# Set up the camera
	setup_camera()
	
	# Set up input maps programmatically (optional)
	# setup_input_map()

func _process(delta):
	# Update camera position to follow player if enabled
	if camera_follow_player and player and camera:
		update_camera_position(delta)

# Configure the camera for top-down view
func setup_camera():
	if camera:
		# Set camera projection
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 50.0  # Tighter FOV for more orthographic-like view
		
		# Initial positioning
		update_camera_position(0)

# Update camera to follow player
func update_camera_position(delta):
	# Calculate target position based on player position and camera settings
	var target_pos = player.global_position
	
	# Offset the camera by distance and height
	var camera_offset = Vector3(0, camera_height, camera_distance)
	
	# Apply rotation based on camera angle
	var angle_rad = deg_to_rad(camera_angle)
	var rotated_offset = Vector3(
		camera_offset.z * sin(angle_rad),
		camera_offset.y,
		camera_offset.z * cos(angle_rad)
	)
	
	# Set camera position and look at player
	camera.global_position = target_pos + rotated_offset
	camera.look_at(target_pos, Vector3.UP)

# Setup input maps programmatically (optional)
# This would call the setup_input_map function from our input_map artifact
func setup_input_map():
	# Import code from our input map configuration
	pass
