# res://scripts/player/PlayerToolHandler.gd
# Manages the player's currently held tool, tool belt (if upgraded),
# and handles the logic for starting, progressing, completing, or cancelling tool interactions
# based on the data-driven InteractionDefinition system.
class_name PlayerToolHandler
extends Node

# --- References ---
# Assuming this script is a direct child of the PlayerController node.
@onready var player = get_parent()
# Node3D used as the attachment point for the currently held tool. Assign in Inspector.
@export var tool_holder: Node3D = null
# Node3D used as the attachment point for the stored tool (on the back). Found automatically.
@onready var back_tool_holder = $"../BackToolHolder" if $"..".has_node("BackToolHolder") else null
# Reference to the animation controller to trigger tool usage animations. Found automatically.
@onready var animation_controller: PlayerAnimationController = owner.find_child("PlayerAnimationController") if owner else null


# --- Tool State ---
# The tool currently in the player's hand.
var current_tool: Tool = null
# The tool stored on the player's back (requires Tool Belt upgrade).
var stored_tool: Tool = null

# --- Refactored Tool Use State ---
# Flag indicating if a progress-based interaction is currently active.
var is_tool_use_in_progress: bool = false
# Stores the InteractionDefinition resource for the currently active interaction.
var current_interaction: InteractionDefinition = null
# Timestamp (milliseconds) when the current progress-based interaction started.
var tool_use_start_time: int = 0
# The grid position where the current interaction is targeted.
var tool_use_position: Vector3i
# Stores the calculated final duration for the current progress interaction (including upgrades).
var current_interaction_final_duration: float = 0.0

# --- Static State ---
# Dictionary to track which tiles are currently being interacted with by any player,
# preventing simultaneous interactions on the same tile.
# Key: String "x,z", Value: Player node instance.
static var tiles_being_used = {}

# --- Initialization ---
func _ready():
	# Ensure player reference is valid.
	if not is_instance_valid(player):
		push_error("PlayerToolHandler: Player reference invalid in _ready!")
	# Attempt to find animation controller if not found via owner.
	if not animation_controller and is_instance_valid(player):
		animation_controller = player.find_child("PlayerAnimationController")
	# Create the back tool holder node if the tool belt upgrade is active and the node doesn't exist.
	if tool_belt_enabled() and not back_tool_holder:
		create_back_tool_holder()

	# Assign tool_holder if not set in editor (example fallback)
	if not tool_holder and is_instance_valid(player):
		tool_holder = player.get_node_or_null("ToolHolder") # Adjust path if needed
		if not tool_holder:
			push_warning("PlayerToolHandler: tool_holder not assigned in Inspector and not found automatically.")


# --- Tool Belt and Holder Management ---

# Checks if the tool belt upgrade is active (allowing two tools).
func tool_belt_enabled() -> bool:
	var parameter_manager = get_parameter_manager()
	if parameter_manager:
		# Check the parameter controlling tool belt capacity.
		return parameter_manager.get_value("player.tool_belt_capacity", 1.0) > 1.0
	return false # Default to false if ParameterManager isn't available.

# Creates the Node3D used to hold the stored tool if it doesn't exist.
func create_back_tool_holder():
	if not is_instance_valid(player):
		push_error("Cannot create BackToolHolder, player reference is invalid.")
		return

	if player.has_node("BackToolHolder"):
		back_tool_holder = player.get_node("BackToolHolder")
		return

	var holder = Node3D.new()
	holder.name = "BackToolHolder"
	# Default position on the player's back (adjust as needed).
	holder.position = Vector3(0, 0.8, -0.2)
	holder.rotation_degrees = Vector3(0, 180, 0) # Face backwards
	player.add_child(holder)
	back_tool_holder = holder
	print("PlayerToolHandler: Created BackToolHolder")


# --- Tool Pickup / Drop / Swap Logic ---

# Handles picking up a tool instance.
func pick_up_tool(tool_obj: Tool):
	if not is_instance_valid(tool_obj):
		push_error("ERROR: Tool object to pick up is not valid!")
		return
	if not is_instance_valid(tool_holder):
		push_error("ERROR: ToolHolder node is not valid or not found!")
		return

	print("Attempting to pick up tool: " + tool_obj.name)

	# If holding a tool and tool belt is active & empty, store current tool first.
	if current_tool and tool_belt_enabled() and not stored_tool:
		print("Storing current tool (%s) in belt" % current_tool.name)
		store_current_tool()
	# Otherwise, if holding a tool, drop it before picking up the new one.
	elif current_tool:
		print("Dropping current tool (%s) before picking up new one" % current_tool.name)
		drop_tool()

	# --- Prepare Tool for Holding ---
	# Store original parent path for dropping later.
	var original_parent = tool_obj.get_parent()
	if is_instance_valid(original_parent):
		tool_obj.set_meta("original_parent_path", original_parent.get_path())
	else:
		tool_obj.set_meta("original_parent_path", null)

	# Disable physics/collision while holding.
	if tool_obj is RigidBody3D:
		tool_obj.set_meta("original_freeze", tool_obj.freeze)
		tool_obj.set_meta("original_collision_layer", tool_obj.collision_layer)
		tool_obj.set_meta("original_collision_mask", tool_obj.collision_mask)
		tool_obj.freeze = true
		tool_obj.collision_layer = 0
		tool_obj.collision_mask = 0
	elif tool_obj is CollisionObject3D:
		tool_obj.set_meta("original_collision_layer", tool_obj.collision_layer)
		tool_obj.set_meta("original_collision_mask", tool_obj.collision_mask)
		tool_obj.collision_layer = 0
		tool_obj.collision_mask = 0
		if tool_obj.has_method("set_monitoring"): tool_obj.set_monitoring(false)
		if tool_obj.has_method("set_monitorable"): tool_obj.set_monitorable(false)

	# Reparent the tool to the tool holder.
	if is_instance_valid(original_parent):
		original_parent.remove_child(tool_obj)
	tool_holder.add_child(tool_obj)

	# Set current tool reference.
	current_tool = tool_obj
	print("Tool (%s) added to tool holder." % current_tool.name)

	# Apply specific position/rotation adjustments for holding.
	apply_tool_specific_adjustments(tool_obj)
	tool_obj.visible = true # Ensure visibility.


# Applies specific local transforms to the tool when held.
func apply_tool_specific_adjustments(tool_obj: Tool):
	if not is_instance_valid(tool_obj): return

	# Reset first
	tool_obj.position = Vector3.ZERO
	tool_obj.rotation = Vector3.ZERO

	# Apply adjustments based on tool name (Adjust values as needed)
	# These values depend heavily on your tool models and tool_holder position/rotation.
	match tool_obj.name.get_slice(":", 0): # Use name or a more reliable identifier if available
		"Hoe":
			tool_obj.position = Vector3(0, 0, 0)
			tool_obj.rotation_degrees = Vector3(0, 0, 0)
		"WateringCan":
			tool_obj.position = Vector3(0, 0, 0)
			tool_obj.rotation_degrees = Vector3(66, -124, 68.6)
		"Basket":
			tool_obj.position = Vector3(0, 0, 0)
			tool_obj.rotation_degrees = Vector3(-77, 77.4, -92.2)
		"SeedBag", "SeedingBag": # Handle potential variations
			tool_obj.position = Vector3(0, 0, 0)
			tool_obj.rotation_degrees = Vector3(-74, 83.2, -85.1)
		_:
			tool_obj.position = Vector3.ZERO
			tool_obj.rotation = Vector3.ZERO
			print("Applied default adjustments for tool: " + tool_obj.name)

	#print("Applied adjustments for tool: " + tool_obj.name) # Optional Debug

# Stores the currently held tool onto the back holder.
func store_current_tool():
	if not current_tool or not tool_belt_enabled(): return false
	if not is_instance_valid(back_tool_holder):
		push_warning("Cannot store tool, BackToolHolder is invalid.")
		return false

	var tool_to_store = current_tool
	print("Storing tool (%s) on back." % tool_to_store.name)

	current_tool = null # Clear hand reference

	# Reparent from hand to back
	if tool_to_store.get_parent() == tool_holder:
		tool_holder.remove_child(tool_to_store)
	back_tool_holder.add_child(tool_to_store)

	# Apply back storage transform (adjust as needed)
	tool_to_store.position = Vector3(0, 0, 0.1) # Slightly away from back
	tool_to_store.rotation_degrees = Vector3(90, 0, 0) # Flat against back

	stored_tool = tool_to_store # Set back reference
	return true

# Swaps the tools between the hand and the back holder.
func swap_tools():
	if not tool_belt_enabled() or not (current_tool or stored_tool): return false # Need belt and at least one tool
	if not is_instance_valid(tool_holder) or not is_instance_valid(back_tool_holder):
		push_error("Cannot swap tools, holder nodes are invalid.")
		return false

	print("Swapping tools...")

	var tool_from_hand = current_tool
	var tool_from_back = stored_tool

	# Clear references temporarily
	current_tool = null
	stored_tool = null

	# Move tool from back to hand (if exists)
	if is_instance_valid(tool_from_back):
		if tool_from_back.get_parent() == back_tool_holder:
			back_tool_holder.remove_child(tool_from_back)
		tool_holder.add_child(tool_from_back)
		current_tool = tool_from_back
		apply_tool_specific_adjustments(current_tool) # Apply hand transform
		print("Moved %s from back to hand." % current_tool.name)

	# Move tool from hand to back (if exists)
	if is_instance_valid(tool_from_hand):
		if tool_from_hand.get_parent() == tool_holder:
			tool_holder.remove_child(tool_from_hand)
		back_tool_holder.add_child(tool_from_hand)
		# Apply back transform
		tool_from_hand.position = Vector3(0, 0, 0.1)
		tool_from_hand.rotation_degrees = Vector3(90, 0, 0)
		stored_tool = tool_from_hand
		print("Moved %s from hand to back." % stored_tool.name)

	return true

# Drops the currently held tool onto the ground.
func drop_tool():
	if not current_tool: return false

	var tool_to_drop = current_tool
	print("Dropping tool: %s" % tool_to_drop.name)

	# Unhighlight if applicable
	if tool_to_drop.has_method("set_highlighted"):
		tool_to_drop.set_highlighted(false)

	current_tool = null # Clear reference FIRST

	if not is_instance_valid(tool_to_drop): return false # Tool might have been freed elsewhere

	# Remove from tool holder
	if tool_to_drop.get_parent() == tool_holder:
		tool_holder.remove_child(tool_to_drop)

	# Determine parent to drop into (original or player's parent)
	var target_parent = player.get_parent() # Fallback
	var original_parent_path = tool_to_drop.get_meta("original_parent_path", null)
	if original_parent_path:
		var original_parent_node = get_node_or_null(original_parent_path)
		if is_instance_valid(original_parent_node): target_parent = original_parent_node
	if not is_instance_valid(target_parent):
		push_error("Cannot drop tool: No valid parent found.")
		return false # Avoid errors

	target_parent.add_child(tool_to_drop)

	# Position in front of player
	var drop_offset = player.global_transform.basis.z * 0.6 + Vector3.UP * 0.1
	tool_to_drop.global_position = player.global_position + drop_offset
	tool_to_drop.rotation = Vector3.ZERO # Reset rotation

	# Re-enable physics/collision
	if tool_to_drop is RigidBody3D:
		tool_to_drop.freeze = tool_to_drop.get_meta("original_freeze", false)
		tool_to_drop.collision_layer = tool_to_drop.get_meta("original_collision_layer", 1)
		tool_to_drop.collision_mask = tool_to_drop.get_meta("original_collision_mask", 1)
		tool_to_drop.apply_central_impulse(Vector3.UP * 0.5) # Small pop-up
	elif tool_to_drop is CollisionObject3D:
		tool_to_drop.collision_layer = tool_to_drop.get_meta("original_collision_layer", 1)
		tool_to_drop.collision_mask = tool_to_drop.get_meta("original_collision_mask", 1)
		if tool_to_drop.has_method("set_monitoring"): tool_to_drop.set_monitoring(true)
		if tool_to_drop.has_method("set_monitorable"): tool_to_drop.set_monitorable(true)

	# Clean up meta info
	tool_to_drop.remove_meta("original_parent_path")
	tool_to_drop.remove_meta("original_freeze")
	tool_to_drop.remove_meta("original_collision_layer")
	tool_to_drop.remove_meta("original_collision_mask")

	return true

# Drops both currently held and stored tools.
func drop_all_tools():
	print("Dropping all tools...")
	var dropped_current = false
	var dropped_stored = false
	if current_tool:
		dropped_current = drop_tool() # This clears current_tool

	if stored_tool:
		var tool_to_drop = stored_tool
		stored_tool = null # Clear reference

		if not is_instance_valid(tool_to_drop): return dropped_current

		print("Dropping stored tool: %s" % tool_to_drop.name)
		if tool_to_drop.get_parent() == back_tool_holder:
			back_tool_holder.remove_child(tool_to_drop)

		var target_parent = player.get_parent()
		var original_parent_path = tool_to_drop.get_meta("original_parent_path", null)
		if original_parent_path:
			var original_parent_node = get_node_or_null(original_parent_path)
			if is_instance_valid(original_parent_node): target_parent = original_parent_node
		if not is_instance_valid(target_parent):
			push_error("Cannot drop stored tool: No valid parent.")
			return dropped_current

		target_parent.add_child(tool_to_drop)
		var drop_offset = -player.global_transform.basis.z * 0.6 + Vector3.UP * 0.1 # Behind player
		tool_to_drop.global_position = player.global_position + drop_offset
		tool_to_drop.rotation = Vector3.ZERO

		# Re-enable physics/collision
		if tool_to_drop is RigidBody3D:
			tool_to_drop.freeze = tool_to_drop.get_meta("original_freeze", false)
			tool_to_drop.collision_layer = tool_to_drop.get_meta("original_collision_layer", 1)
			tool_to_drop.collision_mask = tool_to_drop.get_meta("original_collision_mask", 1)
			tool_to_drop.apply_central_impulse(Vector3.UP * 0.5)
		elif tool_to_drop is CollisionObject3D:
			tool_to_drop.collision_layer = tool_to_drop.get_meta("original_collision_layer", 1)
			tool_to_drop.collision_mask = tool_to_drop.get_meta("original_collision_mask", 1)
			if tool_to_drop.has_method("set_monitoring"): tool_to_drop.set_monitoring(true)
			if tool_to_drop.has_method("set_monitorable"): tool_to_drop.set_monitorable(true)

		# Clean up meta
		tool_to_drop.remove_meta("original_parent_path")
		# ... remove other meta ...
		dropped_stored = true

	return dropped_current or dropped_stored


# --- REFACTORED Tool Usage ---
func can_use_tool(tile_position):
	var grid_tracker = player.get_node_or_null("PlayerGridTracker")
	if not grid_tracker:
		push_error("PlayerToolHandler: PlayerGridTracker not found!")
		return

	var target_pos = grid_tracker.get_front_grid_position()

	# Ask the current tool for a valid interaction based on the target.
	var interaction_def: InteractionDefinition = current_tool.get_valid_interaction(target_pos)
	if interaction_def:
		return true
	else:
		return false
# Called when the player presses the 'use tool' action.
func start_tool_use():
	# Don't start if no tool held or already using one.
	if not is_instance_valid(current_tool) or is_tool_use_in_progress:
		return

	if not is_instance_valid(player): return

	# Get the target position from the grid tracker.
	var grid_tracker = player.get_node_or_null("PlayerGridTracker")
	if not grid_tracker:
		push_error("PlayerToolHandler: PlayerGridTracker not found!")
		return

	var target_pos = grid_tracker.get_front_grid_position()

	# Ask the current tool for a valid interaction based on the target.
	var interaction_def: InteractionDefinition = current_tool.get_valid_interaction(target_pos)

	# If no valid interaction is returned by the tool, do nothing.
	if not is_instance_valid(interaction_def):
		print("Tool %s has no valid interaction for target %s" % [current_tool.name, str(target_pos)])
		# TODO: Play a 'cannot use' sound or show feedback.
		return

	# Check if another player is already using this tile.
	var pos_key = "%d,%d" % [target_pos.x, target_pos.z]
	if tiles_being_used.has(pos_key) and tiles_being_used[pos_key] != player:
		print("Tool use conflict: Tile %s already in use." % pos_key)
		# TODO: Play conflict sound/feedback.
		return

	# Lock the tile for this player.
	tiles_being_used[pos_key] = player
	print("Player %d starting interaction '%s' with tool %s on tile %s" % [player.player_index if is_instance_valid(player) else -1, interaction_def.interaction_id, current_tool.name, pos_key])

	# Store the interaction details for progress tracking and completion.
	current_interaction = interaction_def
	tool_use_position = target_pos

	# Handle PROGRESS based interactions (start timer, disable movement, etc.).
	if current_interaction.interaction_type == InteractionDefinition.InteractionType.PROGRESS:
		is_tool_use_in_progress = true
		tool_use_start_time = Time.get_ticks_msec()

		# --- Get duration, applying upgrades ---
		var base_duration = current_interaction.duration
		var final_duration = base_duration
		var parameter_manager = get_parameter_manager()
		print(current_interaction.duration_parameter_id)
		print(parameter_manager)
		if current_interaction.duration_parameter_id != "" and parameter_manager:
			final_duration = parameter_manager.get_value(current_interaction.duration_parameter_id, base_duration)
			print("final_durationchech for duration")
		# Apply global speed multiplier
		final_duration /= current_tool.get_global_tool_speed_multiplier() # Divide because multiplier increases speed
		current_interaction_final_duration = max(0.1, final_duration) # Ensure minimum duration
		# --------------------------------------

		# Disable player movement during progress.
		var movement = player.get_node_or_null("PlayerMovement")
		if movement: movement.set_movement_disabled(true)

		# Show progress bar feedback.
		var interaction_feedback = player.get_node_or_null("InteractionFeedback")
		if interaction_feedback: interaction_feedback.show_progress(0.0)

		# Trigger the appropriate player animation.
		var interaction_animation_name = current_interaction.animation_name # TODO: Consider getting from interaction_def
		if animation_controller and interaction_animation_name != "":
			animation_controller.play_action_animation(interaction_animation_name)

	# Handle INSTANT interactions (complete immediately).
	elif current_interaction.interaction_type == InteractionDefinition.InteractionType.INSTANT:
		# Call the tool's effect function immediately.
		current_tool.complete_interaction_effect(target_pos, current_interaction.interaction_id)

		# Trigger Animation (optional short animation for instant actions).
		var interaction_animation_name = current_interaction.animation_name # TODO: Consider getting from interaction_def
		if animation_controller and interaction_animation_name != "":
			animation_controller.play_action_animation(interaction_animation_name)
			# Animation might finish after the effect; stop_action_animation handles return to Idle/Run.

		# Clear the tile lock immediately for instant actions.
		if tiles_being_used.has(pos_key) and tiles_being_used[pos_key] == player:
			tiles_being_used.erase(pos_key)
			# print("Cleared tile usage for instant action on %s" % pos_key) # Optional Debug

		# Reset interaction state (no longer needed).
		current_interaction = null
		# is_tool_use_in_progress remains false.


# Called every frame to update progress for active interactions.
func _process(delta):
	# Update tool use progress if in progress
	if is_tool_use_in_progress: # Check only this flag
		update_tool_use_progress(delta)


# Updates the progress of the current interaction.
func update_tool_use_progress(_delta): # Delta might not be needed if using ticks
	# Ensure a valid progress interaction is active.
	if not is_tool_use_in_progress or not is_instance_valid(current_interaction) or \
	   current_interaction.interaction_type != InteractionDefinition.InteractionType.PROGRESS:
		return

	# Use the calculated final duration (includes upgrades).
	var duration = current_interaction_final_duration
	if duration <= 0: # Prevent division by zero; complete immediately if duration is invalid.
		_on_tool_use_completed(tool_use_position)
		return

	# Calculate progress based on elapsed time.
	var elapsed_ms = Time.get_ticks_msec() - tool_use_start_time
	var progress = clamp(float(elapsed_ms) / (duration * 1000.0), 0.0, 1.0)

	# Update visual feedback (e.g., progress bar).
	var interaction_feedback = player.get_node_or_null("InteractionFeedback")
	if interaction_feedback: interaction_feedback.update_progress(progress)

	# Check if the interaction is complete.
	if progress >= 1.0:
		_on_tool_use_completed(tool_use_position)


# Called internally when a progress-based interaction reaches 100%.
func _on_tool_use_completed(position: Vector3i):
	# Ensure we were actually in a progress interaction and it's still valid.
	if not is_tool_use_in_progress or not is_instance_valid(current_interaction):
		# Reset state just in case something went wrong.
		is_tool_use_in_progress = false
		current_interaction = null
		var movement = player.get_node_or_null("PlayerMovement")
		if movement: movement.set_movement_disabled(false)
		return

	print("Tool interaction '%s' completed at position: %s" % [current_interaction.interaction_id, str(position)])

	# Hide progress feedback.
	var interaction_feedback = player.get_node_or_null("InteractionFeedback")
	if interaction_feedback: interaction_feedback.hide_progress()

	# Call the tool's specific effect function via the base Tool class method.
	if is_instance_valid(current_tool):
		current_tool.complete_interaction_effect(position, current_interaction.interaction_id)

	# Tell the animation controller to stop the action animation.
	if is_instance_valid(animation_controller):
		animation_controller.stop_action_animation()

	# Clear the tile usage lock.
	var pos_key = "%d,%d" % [position.x, position.z]
	if tiles_being_used.has(pos_key) and tiles_being_used[pos_key] == player:
		tiles_being_used.erase(pos_key)
		# print("Cleared tile usage lock for %s" % pos_key) # Optional Debug

	# Reset state variables *after* completion logic.
	is_tool_use_in_progress = false
	current_interaction = null
	# tool_use_position = Vector3i.ZERO # Optional reset

	# Re-enable player movement.
	var movement = player.get_node_or_null("PlayerMovement")
	if movement: movement.set_movement_disabled(false)


# Called when the player releases the 'use tool' action during a progress interaction.
func cancel_tool_use():
	# Can only cancel progress-based interactions that are in progress.
	if not is_tool_use_in_progress or not is_instance_valid(current_interaction):
		return

	print("Cancelling tool interaction '%s'." % current_interaction.interaction_id)

	# Hide progress feedback.
	var interaction_feedback = player.get_node_or_null("InteractionFeedback")
	if interaction_feedback: interaction_feedback.hide_progress()

	# Optional: Call a specific cancel effect on the tool if needed.
	# if is_instance_valid(current_tool) and current_tool.has_method("cancel_interaction_effect"):
	#     current_tool.cancel_interaction_effect(tool_use_position, current_interaction.interaction_id)

	# Clear the tile usage lock.
	var pos_key = "%d,%d" % [tool_use_position.x, tool_use_position.z]
	if tiles_being_used.has(pos_key) and tiles_being_used[pos_key] == player:
		tiles_being_used.erase(pos_key)
		# print("Cleared tile usage lock for cancelled action on %s" % pos_key) # Optional Debug

	# Reset state variables.
	is_tool_use_in_progress = false
	current_interaction = null
	# tool_use_position = Vector3i.ZERO # Optional reset

	# Re-enable player movement.
	var movement = player.get_node_or_null("PlayerMovement")
	if movement: movement.set_movement_disabled(false)

	# Tell the animation controller to stop the action animation.
	if is_instance_valid(animation_controller):
		animation_controller.stop_action_animation()


# --- Helper Functions ---

# Gets the appropriate animation name for the tool (can be refined).
func get_tool_animation_name(tool_node: Tool) -> String:
	if not is_instance_valid(tool_node): return ""
	# TODO: Consider getting this from InteractionDefinition if animations are interaction-specific.
	match tool_node.name.get_slice(":", 0): # Or use tool_node.get_class() or a tool_type property
		"Hoe": return "Hoe"
		"WateringCan": return "Watering"
		"SeedBag", "SeedingBag": return "Planting"
		"Basket": return "Harvesting"
		_: return "" # Default: no specific animation

# Clears references if a tool object is destroyed externally.
func clear_tool_reference(tool_obj):
	var cleared = false
	var check_id = tool_obj.get_instance_id() if is_instance_valid(tool_obj) else 0

	if current_tool and (not is_instance_valid(current_tool) or current_tool.get_instance_id() == check_id):
		current_tool = null
		cleared = true
	if stored_tool and (not is_instance_valid(stored_tool) or stored_tool.get_instance_id() == check_id):
		stored_tool = null
		cleared = true

	# if cleared: print("Tool reference cleared.") # Optional Debug
	return cleared

# Helper to get the ParameterManager (assuming Autoload).
func get_parameter_manager():
	var service_locator = get_node_or_null("/root/ServiceLocator")
	if service_locator and service_locator.has_method("get_service"):
		return service_locator.get_service("parameter_manager")
		print("parameters found")
	return null
