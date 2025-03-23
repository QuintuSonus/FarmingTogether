# scripts/Main.gd
extends Node3D

# Configuration for the camera
@export var camera_follow_player: bool = true
@export var camera_height: float = 10.0
@export var camera_distance: float = 5.0
@export var camera_angle: float = -60.0  # In degrees

# Multiplayer camera parameters
@export var camera_min_distance: float = 8.0  # Minimum distance for zoom
@export var camera_padding: float = 5.0  # Extra space around players

# Reference to nodes
var player: CharacterBody3D
var camera: Camera3D
var camera_targets = []  # Array of players to follow

func _ready():
	# Called when the scene is added to the tree
	print("Farm Together: Harvest Rush - 3D Level initialized")
	
	# Get references to camera
	camera = $Camera3D
	
	# Get player references - either direct player or from PlayerManager
	var player_manager = get_node_or_null("PlayerManager")
	if player_manager and player_manager.players.size() > 0:
		# Get players from PlayerManager
		camera_targets = player_manager.players
		print("Main: Following " + str(camera_targets.size()) + " players from PlayerManager")
	else:
		# Try to get direct player reference as fallback
		player = get_node_or_null("Player")
		if player:
			camera_targets = [player]
			print("Main: Following single player")
		else:
			print("Main: No players found to follow")
	
	# Set up the camera
	setup_camera()

func _process(delta):
	# Update camera position to follow player if enabled
	if camera_follow_player and camera:
		update_camera_position(delta)

# Update targets from PlayerManager
func update_follow_targets(targets: Array):
	camera_targets = targets
	print("Camera now following ", camera_targets.size(), " players")

# Configure the camera for top-down view
func setup_camera():
	if camera:
		# Set camera projection
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 50.0  # Tighter FOV for more orthographic-like view
		
		# Initial positioning
		update_camera_position(0)

# Update camera to follow players
func update_camera_position(delta):
	if camera_targets.size() == 0:
		return  # No targets to follow
	
	# Single player case - use existing behavior
	if camera_targets.size() == 1 and camera_targets[0]:
		var target_pos = camera_targets[0].global_position
		
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
		return
	
	# Multiple players - calculate bounding box
	var min_pos = Vector3(INF, INF, INF)
	var max_pos = Vector3(-INF, -INF, -INF)
	var center = Vector3.ZERO
	var valid_targets = 0
	
	for target in camera_targets:
		if target and is_instance_valid(target):
			var pos = target.global_position
			min_pos.x = min(min_pos.x, pos.x)
			min_pos.z = min(min_pos.z, pos.z)
			max_pos.x = max(max_pos.x, pos.x)
			max_pos.z = max(max_pos.z, pos.z)
			center += pos
			valid_targets += 1
	
	if valid_targets == 0:
		return  # No valid targets
	
	center /= valid_targets
	
	# Calculate required distance based on player spread
	var width = max_pos.x - min_pos.x + camera_padding * 2
	var depth = max_pos.z - min_pos.z + camera_padding * 2
	
	# Calculate distance needed to keep all players in view
	var distance_for_width = width / (2.0 * tan(deg_to_rad(camera.fov) / 2.0))
	var distance_for_depth = depth / (2.0 * tan(deg_to_rad(camera.fov) / 2.0))
	var required_distance = max(distance_for_width, distance_for_depth)
	required_distance = max(required_distance, camera_min_distance)
	
	# Calculate camera position
	var angle_rad = deg_to_rad(camera_angle)
	var camera_pos = center + Vector3(
		required_distance * sin(angle_rad),
		camera_height,
		required_distance * cos(angle_rad)
	)
	
	# Set camera position and look at center of players
	camera.global_position = camera_pos
	camera.look_at(center, Vector3.UP)

# For debugging - visualize the camera frustum and player bounding box
func debug_draw_camera_view():
	# This would draw debug lines to visualize the camera view and player bounds
	# Implementation would depend on your debug drawing utilities
	pass
