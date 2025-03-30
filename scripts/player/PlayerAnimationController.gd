# scripts/player/PlayerAnimationController.gd
class_name PlayerAnimationController
extends Node

# References
var player: CharacterBody3D = null:
	set(value):
		player = value
		# Initialize once player is set
		if player:
			_initialize() # Changed to private convention

var animation_player: AnimationPlayer = null
var animation_tree: AnimationTree = null
var state_machine # Reference to the state machine playback if using AnimationTree

var is_initialized: bool = false

# Animation states (simplified, potentially map directly to AnimationTree states)
var is_moving: bool = false
var is_playing_action_anim: bool = false
var current_action_anim_name: String = "" # Keep track of the action animation name

# Blend time for transitions
@export var transition_blend_time: float = 0.2

# --- Initialization ---

func _ready():
	# Initialization will happen when player reference is set via setter
	pass

# Initialize after player reference is set
func _initialize():
	if is_initialized or not is_instance_valid(player):
		return

	print("PlayerAnimationController: Initializing...")

	# Find the animation components
	animation_player = _find_animation_player()
	animation_tree = _find_animation_tree()

	if animation_tree:
		# Assuming the AnimationTree has a StateMachine root node named "StateMachine"
		# Adjust "parameters/StateMachine/playback" if your state machine node has a different path
		if animation_tree.tree_root is AnimationNodeStateMachine:
			state_machine = animation_tree.get("parameters/playback") # Common way to get state machine playback
			animation_tree.active = true
			print("PlayerAnimationController: Found and activated AnimationTree with StateMachine.")
		else:
			push_warning("PlayerAnimationController: Found AnimationTree, but root is not a StateMachine. Will fallback to AnimationPlayer.")
			animation_tree = null # Fallback to using AnimationPlayer directly
			_check_animation_player()
	elif animation_player:
		_check_animation_player()
	else:
		push_error("PlayerAnimationController: No AnimationPlayer or compatible AnimationTree found!")
		return # Cannot proceed without animation components

	is_initialized = true
	print("PlayerAnimationController initialized.")
	# Set initial state based on current movement
	_update_movement_state() # Call the corrected function


func _check_animation_player():
	if animation_player:
		print("PlayerAnimationController: Found AnimationPlayer.")
		# Ensure the animation player is processing
		if animation_player.playback_process_mode != AnimationPlayer.ANIMATION_PROCESS_PHYSICS:
			print("PlayerAnimationController: Setting AnimationPlayer process mode to PHYSICS.")
			animation_player.playback_process_mode = AnimationPlayer.ANIMATION_PROCESS_PHYSICS
	else:
		push_error("PlayerAnimationController: AnimationPlayer not found!")


# Find the AnimationPlayer in the hierarchy
func _find_animation_player() -> AnimationPlayer:
	if not is_instance_valid(player): return null

	# Prefer finding AnimationTree first, as it often contains the AnimationPlayer reference
	var anim_tree = player.find_child("AnimationTree", true, false)
	if anim_tree and anim_tree.has_meta("animation_player"):
		var player_path = anim_tree.get_meta("animation_player")
		var anim_player_node = anim_tree.get_node_or_null(player_path)
		if anim_player_node is AnimationPlayer:
			print("Found AnimationPlayer via AnimationTree meta")
			return anim_player_node

	# Try to find directly in the player
	var anim_player = player.find_child("AnimationPlayer", true, false)
	if anim_player is AnimationPlayer:
		print("Found AnimationPlayer directly on player")
		return anim_player

	# Look in common child names like "Pivot", "Armature", "Model", "Mesh" etc.
	for child_name in ["Pivot", "Armature", "Model", "Mesh", "farmer"]: # Add common model root names
		var model_node = player.find_child(child_name, true, false)
		if model_node:
			anim_player = model_node.find_child("AnimationPlayer", true, false)
			if anim_player is AnimationPlayer:
				print("Found AnimationPlayer within child: " + child_name)
				return anim_player

	print("AnimationPlayer node not found.")
	return null


# Find AnimationTree if it exists
func _find_animation_tree() -> AnimationTree:
	if not is_instance_valid(player): return null
	var anim_tree = player.find_child("AnimationTree", true, false)
	if anim_tree is AnimationTree:
		return anim_tree
	return null


# --- State Updates ---

func _physics_process(_delta):
	if not is_initialized or is_playing_action_anim:
		return # Don't update idle/run if an action is playing

	# Update movement state based on player velocity
	_update_movement_state()


func _update_movement_state():
	# Ensure player reference is valid and it's a CharacterBody3D
	if not is_instance_valid(player) or not player is CharacterBody3D:
		return

	var currently_moving = false
	# --- FIX APPLIED ---
	# Access velocity directly from the 'player' (CharacterBody3D) reference
	if player.velocity.length_squared() > 0.01:
	# --- END FIX ---
		currently_moving = true

	# Check if state changed
	if currently_moving != is_moving:
		is_moving = currently_moving
		# Only update animation if not currently playing an action
		# (This check might be redundant due to the check in _physics_process, but safe)
		if not is_playing_action_anim:
			_update_animation()


func _update_animation():
	# This function now purely decides between Idle and Run based on is_moving flag
	# It should only be called when not playing an action animation.
	if is_playing_action_anim:
		push_warning("_update_animation called while action animation is playing. Ignoring.")
		return

	var anim_name = "Idle" # Default to Idle
	if is_moving:
		anim_name = "RunningInPlace" # Or your run animation name

	_play_animation(anim_name)


# --- Animation Playback ---

# Play general state animations (Idle, Run)
func _play_animation(anim_name: String):
	if not is_initialized: return

	# Prevent playing Idle/Run if an action is supposed to be playing
	if is_playing_action_anim:
		# This case should ideally not happen if logic is correct, but acts as a safeguard
		# print("Attempted to play '%s' while action '%s' is active." % [anim_name, current_action_anim_name])
		return

	if state_machine:
		# Use AnimationTree State Machine travel function
		if state_machine.is_valid():
			if state_machine.get_current_node() != anim_name: # Avoid unnecessary travel
				if state_machine.has_node(anim_name):
					state_machine.travel(anim_name)
					# print("AnimationTree: Travelling to state " + anim_name)
				else:
					print("AnimationTree: State not found: " + anim_name)
		else:
			push_error("AnimationTree state machine reference is invalid!")

	elif animation_player:
		# Use AnimationPlayer directly
		if animation_player.has_animation(anim_name):
			if animation_player.is_playing() and animation_player.current_animation == anim_name:
				return # Already playing this animation

			animation_player.play(anim_name, transition_blend_time)
			# print("AnimationPlayer: Playing animation " + anim_name)
		else:
			print("AnimationPlayer: Animation not found: " + anim_name)


# Play action animations (for tool use, harvesting, etc.) - triggered externally
func play_action_animation(action_anim_name: String):
	if not is_initialized: return

	# If already playing an action, decide whether to interrupt or ignore
	if is_playing_action_anim:
		print("Warning: Received request to play action '%s' while '%s' is already playing. Ignoring." % [action_anim_name, current_action_anim_name])
		return # Or potentially interrupt by calling stop_action_animation() first? For now, ignore.

	var anim_name = action_anim_name
	current_action_anim_name = anim_name # Store the name

	if state_machine:
		if state_machine.is_valid() and state_machine.has_node(anim_name):
			print("AnimationTree: Triggering action state " + anim_name)
			is_playing_action_anim = true # Set flag *before* travelling
			state_machine.travel(anim_name)

			# Connect to finished signal if needed (e.g., if tree doesn't auto-return)
			# Be careful with state machine signals vs animation player signals
			_connect_finished_signal(anim_name)
		else:
			print("AnimationTree: Action state not found: " + anim_name)
			current_action_anim_name = "" # Reset if state not found

	elif animation_player:
		if animation_player.has_animation(anim_name):
			print("AnimationPlayer: Playing action animation " + anim_name)
			is_playing_action_anim = true # Set flag *before* playing
			animation_player.play(anim_name, -1, 1.0, false) # Play once

			_connect_finished_signal(anim_name)
		else:
			print("AnimationPlayer: Action animation not found: " + anim_name)
			current_action_anim_name = "" # Reset if anim not found
	else:
		print("No valid AnimationTree or AnimationPlayer to play action.")
		current_action_anim_name = "" # Reset if no player


# Helper to connect the animation_finished signal
func _connect_finished_signal(anim_name: String):
	if not animation_player: return # Cannot connect without AnimationPlayer

	# Disconnect first to ensure no duplicates if called rapidly
	if animation_player.is_connected("animation_finished", Callable(self, "_on_action_animation_finished")):
		animation_player.disconnect("animation_finished", Callable(self, "_on_action_animation_finished"))

	# Connect using ONE_SHOT
	animation_player.connect("animation_finished", Callable(self, "_on_action_animation_finished").bind(anim_name), CONNECT_ONE_SHOT)


# --- NEW FUNCTION ---
# Stop the currently playing action animation and transition back to Idle/Run
func stop_action_animation():
	if not is_playing_action_anim:
		# print("stop_action_animation called but no action was playing.")
		return # Nothing to stop

	print("Interrupting action animation: " + current_action_anim_name)

	# Clear the flag immediately
	is_playing_action_anim = false
	var stopped_anim_name = current_action_anim_name
	current_action_anim_name = "" # Clear stored name

	# Disconnect the finished signal manually since we're stopping early
	# (CONNECT_ONE_SHOT should handle this, but being explicit can prevent edge cases)
	if animation_player and animation_player.is_connected("animation_finished", Callable(self, "_on_action_animation_finished")):
		animation_player.disconnect("animation_finished", Callable(self, "_on_action_animation_finished"))


	if state_machine:
		# Force transition back to Idle or Run
		var target_state = "Idle"
		# Check player velocity again to decide target state
		if is_instance_valid(player) and player is CharacterBody3D and player.velocity.length_squared() > 0.01:
			target_state = "RunningInPlace"

		if state_machine.is_valid() and state_machine.has_node(target_state):
			print("AnimationTree: Forcing travel back to state " + target_state)
			state_machine.travel(target_state)
		else:
			print("AnimationTree: Cannot force travel back, state '%s' not found or state machine invalid." % target_state)
			# Fallback: Try stopping AnimationPlayer directly if state machine fails
			if animation_player:
				animation_player.stop() # Stop playback
				# Force playing the fallback animation directly
				_play_animation(target_state)


	elif animation_player:
		# Stop the animation player
		animation_player.stop() # Use stop() to cease playback immediately
		print("AnimationPlayer: Stopped animation " + stopped_anim_name)
		# Immediately trigger the update to Idle/Run
		_update_movement_state() # Re-evaluate movement and play Idle/Run

	else:
		print("No AnimationTree or AnimationPlayer to stop.")

# --- END NEW FUNCTION ---


# --- Signal Handlers ---

# Handle when action animations finish NATURALLY
func _on_action_animation_finished(finished_anim_name, expected_anim_name):
	# This function now only handles the case where the animation plays fully.
	# Check if the finished animation is the one we expected and if we were still in the action state.
	if is_playing_action_anim and finished_anim_name == expected_anim_name:
		print("Action animation finished naturally: " + finished_anim_name)
		is_playing_action_anim = false
		current_action_anim_name = "" # Clear stored name

		# Return to idle or run state based on current movement
		# This might be handled automatically by AnimationTree transitions back to Idle/Run.
		if not state_machine: # Or if your state machine requires manual update after action
			_update_movement_state() # Re-evaluate movement and play Idle/Run
		else:
			# If state machine doesn't auto-transition back, force it here
			# var current_state = state_machine.get_current_node()
			# if current_state == finished_anim_name: # Still stuck in action state?
			#	 var target_state = "Idle"
			#	 if is_moving: target_state = "RunningInPlace"
			#	 state_machine.travel(target_state)
			print("AnimationTree should handle transition back from action state.")
	# else:
		# This can happen if stop_action_animation was called, which is fine.
		# Or if a different animation finished unexpectedly.
		# print("_on_action_animation_finished called for '%s', but expected '%s' or action was already stopped." % [finished_anim_name, expected_anim_name])


# --- Public Methods ---

# Call this if movement is forced externally (e.g., knockback)
func force_update_state():
	if not is_initialized: return
	_update_movement_state()
