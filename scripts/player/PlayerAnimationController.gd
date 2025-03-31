# scripts/player/PlayerAnimationController.gd
class_name PlayerAnimationController
extends Node

# References
var player: CharacterBody3D = null:
	set(value):
		player = value
		if player:
			# Use call_deferred to ensure _initialize runs after node is fully ready
			call_deferred("_initialize")


@onready var animation_tree: AnimationTree = $"../AnimationTree" # Adjust path if needed
var state_machine # Reference to the state machine playback
var animation_player: AnimationPlayer = null
var is_initialized: bool = false

# --- Initialization ---

func _ready():
	# _initialize is now called deferred via the player setter
	pass

func _initialize():
	if is_initialized:
		return
	if not is_instance_valid(player):
		print("DEBUG: _initialize called but player is not valid yet.")
		call_deferred("_initialize") # Try again later
		return

	print("PlayerAnimationController: Initializing for AnimationTree...")

	# 1. Check AnimationTree node itself
	if not is_instance_valid(animation_tree):
		push_error("AnimationTree node NOT found or invalid! Check path relative to: " , get_path())
		print("DEBUG: Failed at AnimationTree validity check.")
		return
	print("DEBUG: AnimationTree node is valid.")

	# 2. Check/Assign AnimationPlayer
	# ... (Keep the AnimationPlayer check/assign block from previous version) ...
	var temp_anim_player_ref = null
	if not is_instance_valid(animation_tree.anim_player):
		print("DEBUG: AnimationTree.anim_player not assigned in editor. Trying to find...")
		temp_anim_player_ref = _find_animation_player()
		if is_instance_valid(temp_anim_player_ref):
			animation_tree.anim_player = animation_tree.get_path_to(temp_anim_player_ref)
			animation_player = temp_anim_player_ref
			print("DEBUG: Found and assigned AnimationPlayer: " + animation_player.name)
		else:
			push_error("Could not find AnimationPlayer to assign to AnimationTree!")
			print("DEBUG: Failed at finding AnimationPlayer.")
			return
	else:
		temp_anim_player_ref = animation_tree.get_node_or_null(animation_tree.anim_player)
		if is_instance_valid(temp_anim_player_ref) and temp_anim_player_ref is AnimationPlayer:
			animation_player = temp_anim_player_ref
			print("DEBUG: Got AnimationPlayer reference from AnimationTree.anim_player: " + animation_player.name)
		else:
			push_error("AnimationTree.anim_player path ('" + str(animation_tree.anim_player) + "') is invalid or not an AnimationPlayer!")
			print("DEBUG: Failed getting AnimationPlayer from assigned path.")
			return
	print("DEBUG: AnimationPlayer check passed.")


	# 3. Check Tree Root is StateMachine
	if not animation_tree.tree_root is AnimationNodeStateMachine:
		push_error("AnimationTree root is not an AnimationNodeStateMachine! It is: " + str(typeof(animation_tree.tree_root)))
		print("DEBUG: Failed at Tree Root type check.")
		return
	print("DEBUG: Tree Root is AnimationNodeStateMachine.")

	# --- MODIFIED: Removed await, added more prints ---
	print("DEBUG: Attempting to get StateMachine playback...")

	# 4. Get StateMachine Playback
	var temp_state_machine = animation_tree.get("parameters/playback")
	print("DEBUG: Result of get('parameters/playback'): ", temp_state_machine)

	if not temp_state_machine:
		push_error("Failed to get StateMachine playback from AnimationTree! Path 'parameters/playback' might be wrong or object not ready.")
		print("DEBUG: Failed getting StateMachine playback object (is null).")
		return # Exit if null

	print("DEBUG: Playback object retrieved (not null). Checking type...")
	if not temp_state_machine is AnimationNodeStateMachinePlayback:
		# It's not the expected type, but maybe still usable? Log warning.
		push_warning("Retrieved 'parameters/playback' but it's not AnimationNodeStateMachinePlayback type. Type is: " + str(typeof(temp_state_machine)))
		print("DEBUG: Playback object is NOT of type AnimationNodeStateMachinePlayback.")
		# Decide whether to return or try using it anyway. Let's try using it.
		# return # Optionally exit if type mismatch is critical
	else:
		print("DEBUG: Playback object type is AnimationNodeStateMachinePlayback.")

	print("DEBUG: Attempting to assign playback object to state_machine variable...")
	state_machine = temp_state_machine # Assign to our variable
	print("DEBUG: Assigned playback object to state_machine. state_machine is now: ", state_machine)

	if not state_machine:
		# This check should be redundant if the 'if not temp_state_machine' check passed, but for safety:
		push_error("state_machine variable is unexpectedly null after assignment!")
		print("DEBUG: state_machine variable is null after assignment!")
		return
	# --- END MODIFIED ---

	# 5. Activate Tree
	animation_tree.active = true
	print("DEBUG: AnimationTree activated.")

	is_initialized = true
	print("PlayerAnimationController initialized for AnimationTree.")

	## Set initial state based on current movement
	#_update_movement_state()
	#print("DEBUG: Called _update_movement_state.")

	# Check the state immediately
	if state_machine: # Check if variable holds an object
		print(">>> Current State Machine State (after init): ", state_machine.get_current_node())
	else:
		print("DEBUG: Cannot get initial state, state_machine is null/invalid?")


# Find the AnimationPlayer (keep this helper function)
func _find_animation_player() -> AnimationPlayer:
	# (Keep the existing _find_animation_player function code here)
	if not is_instance_valid(player): return null
	var anim_player_node = find_child("AnimationPlayer", true, false)
	if anim_player_node is AnimationPlayer: return anim_player_node
	if is_instance_valid(player):
		anim_player_node = player.find_child("AnimationPlayer", true, false)
		if anim_player_node is AnimationPlayer: return anim_player_node
		for child_name in ["Pivot", "Armature", "Model", "Mesh", "farmer"]:
			var model_node = player.find_child(child_name, true, false)
			if model_node:
				anim_player_node = model_node.find_child("AnimationPlayer", true, false)
				if anim_player_node is AnimationPlayer: return anim_player_node
	print("DEBUG (_find_animation_player): AnimationPlayer node not found.")
	return null


# --- State Updates ---
# (Keep _physics_process and _update_movement_state as they were)
#func _physics_process(_delta):
	#if not is_initialized: return
	#_update_movement_state()
#
#func _update_movement_state():
	#if not is_initialized or not is_instance_valid(player) or not player is CharacterBody3D:
		#return
#
	#var currently_moving = player.velocity.length_squared() > 0.01
	## --- DEBUG PRINT ---
		## --- END DEBUG ---

	#if is_instance_valid(animation_tree):
		## Ensure the path here EXACTLY matches your AnimationTree parameter
		#animation_tree.set("parameters/conditions/is_moving", currently_moving)
	## else: # Optional: Add warning if tree is invalid
		## print("DEBUG Anim: AnimationTree invalid in _update_movement_state")


# --- Animation Playback (Simplified & Fixed) ---
func play_action_animation(action_anim_name: String):
	# Ensure initialized and state_machine is valid
	if not is_initialized or not state_machine:
		print("DEBUG (play_action): Not initialized or state machine invalid.")
		return

	# Check if already in the target state to avoid unnecessary travel
	if state_machine.get_current_node() == action_anim_name:
		return

	print("AnimationTree: Travelling to action state -> " + action_anim_name)
	# Directly call travel. Godot's travel function will print a warning
	# if action_anim_name is not a valid state, but typically won't crash.
	state_machine.travel(action_anim_name)

	# Removed the problematic check:
	# if state_machine.has_node(action_anim_name): # <--- INCORRECT CHECK REMOVED
	#     if state_machine.get_current_node() == action_anim_name: return
	#     print("AnimationTree: Travelling to action state -> " + action_anim_name)
	#     state_machine.travel(action_anim_name)
	# else:
	#     print("AnimationTree: Action state not found: " + action_anim_name) # No longer needed if travel handles it

func stop_action_animation():
	if not is_initialized or not state_machine:
		print("DEBUG (stop_action): Not initialized or state machine invalid.")
		return

	var current_state = state_machine.get_current_node()
	# Define which states are considered "action" states that can be stopped/interrupted
	var action_states = ["Planting", "Hoe", "Watering", "Harvesting"] # Add any other action state names here

	# Only proceed if we are currently in an action state
	if not current_state in action_states:
		return

	print("Interrupting action animation state: " + current_state)

	# Determine the target state (Idle or Running)
	var target_state = "Idle"
	if is_instance_valid(player) and player is CharacterBody3D and player.velocity.length_squared() > 0.01:
		target_state = "RunningInPlace" # Ensure this state name matches your AnimationTree

	# Directly travel to the target state.
	# Godot's travel function will print a warning if target_state is invalid.
	print("AnimationTree: Travelling back to state -> " + target_state)
	state_machine.travel(target_state)

	# --- REMOVED THE PROBLEMATIC CHECK ---
	# if state_machine.has_node(target_state): # <--- INCORRECT CHECK REMOVED
	#     if state_machine.get_current_node() == current_state: # Check if still in the action state
	#         print("AnimationTree: Forcing travel back to state -> " + target_state)
	#         state_machine.travel(target_state)
	# else:
	#     print("AnimationTree: Cannot force travel back, target state '%s' not found." % target_state)
	# --- END REMOVED BLOCK ---


# --- Public Methods ---
func force_update_state():
	if not is_initialized: return
	#_update_movement_state()
