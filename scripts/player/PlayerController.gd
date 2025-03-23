# scripts/player/PlayerController.gd
class_name PlayerController
extends CharacterBody3D

# Player identity
@export var player_index: int = 0:
	set(value):
		player_index = value
		_update_player_index(value)

# Components - use @onready as they'll be children of this node
@onready var movement: PlayerMovement = $PlayerMovement
@onready var tool_handler: PlayerToolHandler = $PlayerToolHandler
@onready var interaction: PlayerInteraction = $PlayerInteraction
@onready var grid_tracker: PlayerGridTracker = $PlayerGridTracker

# Simple access to frequently needed nodes
@onready var interaction_feedback = $InteractionFeedback

# Shared access to level manager - will be passed to components
var level_manager: Node = null



# Make current_tool directly accessible as a property with a getter
var current_tool: Tool:
	get:
		if tool_handler:
			return tool_handler.current_tool
		return null


func _ready():
	# Find the level manager - will be passed to components
	level_manager = get_node_or_null("/root/Main/LevelManager")
	if not level_manager:
		level_manager = get_tree().get_root().find_child("LevelManager", true, false)
		
	if not level_manager:
		push_error("Player: Could not find LevelManager!")
	
	# Configure components with required references
	movement.player = self
	tool_handler.player = self
	interaction.player = self
	grid_tracker.player = self
	
	# Pass level manager to components
	movement.set_level_manager(level_manager)
	grid_tracker.set_level_manager(level_manager)
	interaction.set_level_manager(level_manager)
	
	_update_player_index(player_index)
	
	add_to_group("players")

# Simple delegator method to get current tool
func get_current_tool():
	return tool_handler.current_tool

# Input handling - delegates to appropriate components
func _input(event):
	if movement.movement_disabled:
		return
		
	# Handle tool pickup/drop
	if event.is_action_pressed(movement.input_prefix + "interact"):
		if tool_handler.current_tool:
			tool_handler.drop_tool()
		elif interaction.interaction_manager:
			interaction.interaction_manager.start_interaction()
	
	# Handle tool usage
	if event.is_action_pressed(movement.input_prefix + "use_tool"):
		if tool_handler.current_tool and tool_handler.current_tool.has_method("use"):
			tool_handler.start_tool_use()
	elif event.is_action_released(movement.input_prefix + "use_tool"):
		if tool_handler.is_tool_use_in_progress:
			tool_handler.cancel_tool_use()

# Called by other systems to pick up a tool
func pick_up_tool(tool_obj):
	tool_handler.pick_up_tool(tool_obj)

# Used for visual feedback
func set_color(color: Color):
	$MeshInstance3D.material_override = StandardMaterial3D.new()
	$MeshInstance3D.material_override.albedo_color = color
	
func _update_player_index(index: int):
	if movement:
		movement.set_player_index(index)
