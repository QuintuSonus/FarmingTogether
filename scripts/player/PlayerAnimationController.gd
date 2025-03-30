# scripts/player/PlayerAnimationController.gd
class_name PlayerAnimationController
extends Node

# References
var player: CharacterBody3D = null:
	set(value):
		player = value
		# Initialize once player is set
		if player:
			initialize()

var animation_player: AnimationPlayer = null
var animation_tree: AnimationTree = null
var is_initialized: bool = false

# Animation states
enum AnimState {
	IDLE,
	RUN,
	PLANT,
	HARVEST,
	HOE,
	WATER
}

# Current state tracking
var current_state: AnimState = AnimState.IDLE
var is_playing_action_anim: bool = false
var transition_blend_time: float = 0.2  # Time to blend between animations

func _ready():
	# Initialization will happen when player reference is set
	pass

# Initialize after player reference is set
func initialize():
	if is_initialized:
		return
		
	print("PlayerAnimationController: Initializing with player reference")
	
	# Find the animation components
	animation_player = find_animation_player()
	animation_tree = find_animation_tree()
	
	# If we have an AnimationTree, set it active
	if animation_tree:
		animation_tree.active = true
		print("PlayerAnimationController: Found AnimationTree")
	elif animation_player:
		print("PlayerAnimationController: Found AnimationPlayer")
	else:
		push_error("PlayerAnimationController: No animation components found!")
		
	is_initialized = true
	print("PlayerAnimationController initialized")

# Find the AnimationPlayer in the hierarchy
func find_animation_player() -> AnimationPlayer:
	if not player:
		return null
		
	# Try to find in the player
	var anim_player = player.find_child("AnimationPlayer", true, false)
	
	# Look in the farmer model if not found directly
	if not anim_player:
		var farmer = player.find_child("farmer", true, false)
		if farmer:
			anim_player = farmer.find_child("AnimationPlayer", true, false)
	
	return anim_player

# Find AnimationTree if it exists
func find_animation_tree() -> AnimationTree:
	if not player:
		return null
		
	return player.find_child("AnimationTree", true, false)

# Process animations based on player state
func _process(_delta):
	if not is_initialized or not animation_player:
		return
	
	update_animation_state()

# Update the animation based on player state
func update_animation_state():
	var movement = player.get_node_or_null("PlayerMovement")
	var tool_handler = player.get_node_or_null("PlayerToolHandler")
	
	# Skip if currently playing an action animation
	if is_playing_action_anim:
		return
	
	# Determine the appropriate animation state
	var new_state = current_state
	
	# Check if moving
	if movement and movement.get_movement_vector().length() > 0.1:
		new_state = AnimState.RUN
	else:
		new_state = AnimState.IDLE
	
	# If state changed, play the new animation
	if new_state != current_state:
		play_animation_for_state(new_state)
		current_state = new_state

# Play animation for a given state
func play_animation_for_state(state: AnimState):
	if not is_initialized or not animation_player:
		return
	
	var anim_name = ""
	
	match state:
		AnimState.IDLE:
			anim_name = "Idle"
		AnimState.RUN:
			anim_name = "RunningInPlace"
		AnimState.PLANT:
			anim_name = "Planting"
		AnimState.HARVEST:
			anim_name = "Harvesting"
		AnimState.HOE:
			anim_name = "Hoe"
		AnimState.WATER:
			anim_name = "Watering"
	
	# Play the animation if it exists
	if animation_player.has_animation(anim_name):
		if animation_tree:
			# Use animation tree if available
			animation_tree.set("parameters/state/transition_request", anim_name)
		else:
			# Use animation player directly
			animation_player.play(anim_name, transition_blend_time)
		
		print("PlayerAnimationController: Playing animation " + anim_name)
	else:
		print("PlayerAnimationController: Animation not found: " + anim_name)

# Play action animations (for tool use, harvesting, etc.)
func play_action_animation(action_type: String):
	if not is_initialized or not animation_player:
		return
	
	var anim_name = ""
	
	match action_type:
		"plant":
			anim_name = "Planting"
			current_state = AnimState.PLANT
		"harvest":
			anim_name = "Harvesting"
			current_state = AnimState.HARVEST
		"hoe":
			anim_name = "Hoe"
			current_state = AnimState.HOE
		"water":
			anim_name = "Watering"
			current_state = AnimState.WATER
	
	if animation_player.has_animation(anim_name):
		is_playing_action_anim = true
		
		if animation_tree:
			# Use animation tree if available
			animation_tree.set("parameters/state/transition_request", anim_name)
		else:
			# Use animation player directly
			animation_player.play(anim_name, transition_blend_time)
		
		# Connect to the animation_finished signal only once
		if not animation_player.is_connected("animation_finished", Callable(self, "_on_action_animation_finished")):
			animation_player.connect("animation_finished", Callable(self, "_on_action_animation_finished"))
		
		print("PlayerAnimationController: Playing action animation " + anim_name)
	else:
		print("PlayerAnimationController: Action animation not found: " + anim_name)

# Handle when action animations finish
func _on_action_animation_finished(_anim_name):
	is_playing_action_anim = false
	
	# Disconnect the signal to avoid repeated calls
	if animation_player.is_connected("animation_finished", Callable(self, "_on_action_animation_finished")):
		animation_player.disconnect("animation_finished", Callable(self, "_on_action_animation_finished"))
	
	# Return to idle or run
	update_animation_state()
