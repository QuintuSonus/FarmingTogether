# scripts/managers/CameraController.gd
class_name CameraController
extends Node

# Configuration for the camera
@export var camera_follow_player: bool = true
@export var camera_height: float = 10.0
@export var camera_distance: float = 5.0
@export var camera_angle: float = 0  # In degrees

# Multiplayer camera parameters
@export var camera_min_distance: float = 8.0  # Minimum distance for zoom
@export var camera_padding: float = 5.0  # Extra space around players

# References
var main_camera: Camera3D = null
var player_manager = null

func _ready():
	# Get reference to main camera
	main_camera = $"../Camera3D"
	if main_camera:
		main_camera.add_to_group("cameras")

func set_player_manager(manager):
	player_manager = manager

func _process(delta):
	# Update camera position to follow player(s) if enabled
	if camera_follow_player and main_camera and main_camera.current:
		update_camera_position(delta)

# Update camera to follow players
func update_camera_position(delta):
	var camera_targets = []
	
	# Get players to follow from player manager if available
	if player_manager and player_manager.has_method("get_players"):
		camera_targets = player_manager.get_players()
	elif player_manager and "players" in player_manager:
		camera_targets = player_manager.players
	# Fallback to direct player reference
	elif get_parent().has_node("Player"):
		camera_targets = [get_parent().get_node("Player")]
	
	# No targets to follow
	if camera_targets.size() == 0:
		return
	
	# Single player case - use simpler behavior
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
		main_camera.global_position = target_pos + rotated_offset
		main_camera.look_at(target_pos, Vector3.UP)
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
	var distance_for_width = width / (2.0 * tan(deg_to_rad(main_camera.fov) / 2.0))
	var distance_for_depth = depth / (2.0 * tan(deg_to_rad(main_camera.fov) / 2.0))
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
	main_camera.global_position = camera_pos
	main_camera.look_at(center, Vector3.UP)

# Activate main gameplay camera
func activate_main_camera():
	if main_camera:
		main_camera.current = true

# Update follow targets (called when players change)
func update_follow_targets(players):
	# Just ensure we have the latest references - actually following is handled in process
	# This is called by PlayerManager when players are added/removed
	print("CameraController: Updated follow targets with " + str(players.size()) + " players")
