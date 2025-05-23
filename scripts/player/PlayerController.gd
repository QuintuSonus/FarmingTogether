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
@onready var animation_controller: PlayerAnimationController = $PlayerAnimationController

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

# Add a property for stored_tool as well
var stored_tool: Tool:
	get:
		if tool_handler:
			return tool_handler.stored_tool
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

	# Set up animation controller if it exists
	if animation_controller:
		animation_controller.player = self

	# Pass level manager to components
	movement.set_level_manager(level_manager)
	grid_tracker.set_level_manager(level_manager)
	interaction.set_level_manager(level_manager)

	_update_player_index(player_index)

	add_to_group("players")

# Simple delegator method to get current tool
func get_current_tool():
	return tool_handler.current_tool

# Simple delegator method to get stored tool
func get_stored_tool():
	return tool_handler.stored_tool

# Input handling - delegates to appropriate components
func _input(event):
	var potential_interactable = null
	var front_tile_type = -1 # Default invalid
	if interaction.interaction_manager and interaction.interaction_manager.potential_interactable and is_instance_valid(interaction.interaction_manager.potential_interactable):
		potential_interactable = interaction.interaction_manager.potential_interactable
	
	# Get front tile type for dispenser check
	if grid_tracker:
		front_tile_type = grid_tracker.get_front_tile_type()
		
	if movement.movement_disabled and not tool_handler.is_tool_use_in_progress: # Allow cancelling tool use even if movement is disabled
		return
	
	# Handle tool pickup/drop
	if event.is_action_pressed(movement.input_prefix + "interact"):
		# --- MODIFIED INTERACTION LOGIC ---
		print("PlayerController", front_tile_type)
		if potential_interactable is Tool:
			# Priority 1: Pick up a tool on the ground
			tool_handler.pick_up_tool(potential_interactable)
		elif front_tile_type == LevelManager.TileType.CARROT_DISPENSER or front_tile_type == LevelManager.TileType.TOMATO_DISPENSER:
			print("PlayerController", front_tile_type)
			# Priority 2: Interact with a dispenser tile (triggers pickup logic inside handler)
			tool_handler.pick_up_tool(null) # Pass null to indicate tile interaction
		elif current_tool:
			# Priority 3: If holding a tool and not targeting a tool/dispenser, drop the tool
			tool_handler.drop_tool()
		elif interaction.interaction_manager:
			# Priority 4: If no tool held and not targeting tool/dispenser, try standard interaction
			interaction.interaction_manager.start_interaction()

	# Handle tool belt swapping
	if event.is_action_pressed(movement.input_prefix + "swap_tool"):
		if tool_handler.tool_belt_enabled():
			# Swap tools if we have a stored tool
			if tool_handler.stored_tool:
				tool_handler.swap_tools()
			# Otherwise store the current tool if we have one
			elif tool_handler.current_tool:
				tool_handler.store_current_tool()

			# Play a sound effect for tool swapping (if available)
			var audio_player = get_node_or_null("ToolSwapAudio")
			if audio_player:
				audio_player.play()

	# Handle tool usage START
	if event.is_action_pressed(movement.input_prefix + "use_tool"):
		# Delegate starting tool use entirely to the handler
		# The handler will check if a tool exists and call the animation controller
		if tool_handler:
			tool_handler.start_tool_use()

	# Handle tool usage CANCEL / FINISH (for held actions)
	elif event.is_action_released(movement.input_prefix + "use_tool"):
		# Delegate cancelling tool use to the handler
		if tool_handler and tool_handler.is_tool_use_in_progress:
			tool_handler.cancel_tool_use() # Or potentially complete if it's a hold-to-finish action

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

# Clear references to a tool (used when a tool is destroyed)
func clear_tool_reference(tool_obj):
	if tool_handler:
		return tool_handler.clear_tool_reference(tool_obj)
	return false
