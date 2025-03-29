# scripts/PlayerManager.gd
extends Node3D

# References
@export var player_scene: PackedScene
@export var max_players: int = 2
@export var spawn_positions: Array[Vector3] = [Vector3(4, 1.5, 2), Vector3(5, 1.5, 4)]
@export var player_colors: Array[Color] = [Color(0.2, 0.8, 0.2), Color(0.2, 0.2, 0.8)]

# Player tracking
var players = []
var active_player_count = 0
var player_nodes = {}

func _ready():
	# Find player scene if not set
	if not player_scene:
		player_scene = load("res://scenes/Player.tscn")
		if not player_scene:
			push_error("PlayerManager: Could not load Player scene!")
			return
	
	# Start with player 1
	active_player_count = 1
	
	# Create initial player
	add_player(0)
	
	# Log information
	print("PlayerManager ready - press START on second controller to join")

func add_player(player_index: int):
	if player_index >= max_players or player_nodes.has(player_index):
		return  # Can't add more than max players or duplicate index
		
	var new_player = player_scene.instantiate()
	add_child(new_player)
	
	# Configure the player
	new_player.player_index = player_index
	new_player.global_position = spawn_positions[player_index] if player_index < spawn_positions.size() else Vector3(0, 1, 0)
	
	# Set player color for visual differentiation
	if player_index < player_colors.size() and new_player.has_method("set_color"):
		new_player.set_color(player_colors[player_index])
	
	# Register the player
	player_nodes[player_index] = new_player
	players.append(new_player)
	
	print("Player " + str(player_index) + " added")
	
	# Notify camera system
	_on_players_changed()

func remove_player(player_index: int):
	if not player_nodes.has(player_index):
		return
		
	var player = player_nodes[player_index]
	players.erase(player)
	player_nodes.erase(player_index)
	player.queue_free()
	
	print("Player " + str(player_index) + " removed")
	
	# Notify camera system
	_on_players_changed()

func _on_players_changed():
	# Update camera to follow all players
	var main = get_node("/root/Main")
	if main and main.has_method("update_follow_targets"):
		main.update_follow_targets(players)

func _process(_delta):
	# Check for player join/leave input
	_check_join_leave_input()

func _check_join_leave_input():
	# Add second player with START button on controller 2
	if Input.is_action_just_pressed("p2_join") and not player_nodes.has(1):
		add_player(1)
		print("Player 2 joined!")
	
	# Remove second player with SELECT button
	if Input.is_action_just_pressed("p2_leave") and player_nodes.has(1):
		remove_player(1)
		print("Player 2 left!")
