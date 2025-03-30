# scripts/player/PlayerToolHandler.gd
class_name PlayerToolHandler
extends Node

# References
var player: CharacterBody3D = null
@export var tool_holder: Node3D = null

@onready var back_tool_holder = $"../BackToolHolder" if $"..".has_node("BackToolHolder") else null
# Get animation controller reference reliably
@onready var animation_controller: PlayerAnimationController = owner.find_child("PlayerAnimationController") if owner else null


# Tool state
var current_tool = null
var stored_tool = null # Second tool slot for tool belt upgrade
var is_tool_use_in_progress: bool = false
var tool_use_completed: bool = false
var tool_use_start_time: int = 0
var tool_use_position = null
var tool_use_duration: float = 0.0

# For bone attachment adjustments
var using_bone_attachment: bool = false

# Static dictionary to track which tiles are being used by tools
static var tiles_being_used = {} # Key: "x,z", Value: player node

func _ready():
	# Ensure owner is set if accessed via get_node
	if not owner and get_parent() is CharacterBody3D:
		player = get_parent()
		# Attempt to get animation controller again if player is now known
		if not animation_controller and is_instance_valid(player):
			animation_controller = player.find_child("PlayerAnimationController")

	# Create back tool holder if it doesn't exist but tool belt is active
	if tool_belt_enabled() and not back_tool_holder:
		create_back_tool_holder()

	# Check if we're using a bone attachment
	if tool_holder:
		var parent = tool_holder.get_parent()
		# Use safer check for BoneAttachment3D
		if parent and parent is BoneAttachment3D:
			using_bone_attachment = true
			print("PlayerToolHandler: Using bone attachment for tool holder")


func _process(delta):
	# Update tool use progress if in progress
	if is_tool_use_in_progress and not tool_use_completed:
		update_tool_use_progress(delta)

# Check if tool belt upgrade is enabled
func tool_belt_enabled() -> bool:
	var parameter_manager = get_parameter_manager()
	if parameter_manager:
		# Ensure default value type matches expected return type (float vs int)
		return parameter_manager.get_value("player.tool_belt_capacity", 1) > 1
	return false

# Create back tool holder if it doesn't exist
func create_back_tool_holder():
	if not is_instance_valid(player):
		push_error("Cannot create BackToolHolder, player reference is invalid.")
		return

	if player.has_node("BackToolHolder"):
		back_tool_holder = player.get_node("BackToolHolder")
		return

	var holder = Node3D.new()
	holder.name = "BackToolHolder"
	holder.position = Vector3(0, 0.2, -0.3) # Position on the player's back
	player.add_child(holder)
	back_tool_holder = holder
	print("PlayerToolHandler: Created BackToolHolder")


# Pick up a tool
func pick_up_tool(tool_obj):
	if not is_instance_valid(tool_obj):
		push_error("ERROR: Tool object is not valid!")
		return

	if not is_instance_valid(tool_holder):
		push_error("ERROR: ToolHolder node is not valid or not found!")
		return

	print("Attempting to pick up tool: " + tool_obj.name)

	# If we have a tool belt and already have a tool, store the current tool
	if current_tool and tool_belt_enabled() and not stored_tool:
		print("Storing current tool (%s) in belt" % current_tool.name)
		store_current_tool()
	# If no belt or belt full, drop current tool first
	elif current_tool:
		print("Dropping current tool (%s) before picking up new one" % current_tool.name)
		drop_tool()

	# Store original parent if it exists and is valid
	var original_parent = tool_obj.get_parent()
	if is_instance_valid(original_parent):
		tool_obj.set_meta("original_parent_path", original_parent.get_path())
		#print("Stored original parent path: " + original_parent.get_path())
	else:
		tool_obj.set_meta("original_parent_path", null) # Ensure meta exists but is null
		print("Tool had no valid original parent.")


	# Disable physics/collision on the tool
	if tool_obj is RigidBody3D:
		print("Tool is RigidBody3D, disabling physics & collision.")
		# Store original properties using meta for safety
		tool_obj.set_meta("original_freeze", tool_obj.freeze)
		tool_obj.set_meta("original_collision_layer", tool_obj.collision_layer)
		tool_obj.set_meta("original_collision_mask", tool_obj.collision_mask)
		tool_obj.freeze = true
		tool_obj.collision_layer = 0
		tool_obj.collision_mask = 0
	elif tool_obj is CollisionObject3D: # Handle StaticBody3D, Area3D etc.
		print("Tool is CollisionObject3D, disabling collision.")
		tool_obj.set_meta("original_collision_layer", tool_obj.collision_layer)
		tool_obj.set_meta("original_collision_mask", tool_obj.collision_mask)
		tool_obj.collision_layer = 0
		tool_obj.collision_mask = 0
		# Optionally disable monitoring/monitorable if needed
		if tool_obj.has_method("set_monitoring"): tool_obj.set_monitoring(false)
		if tool_obj.has_method("set_monitorable"): tool_obj.set_monitorable(false)


	# Reparent the tool to the tool holder
	if is_instance_valid(original_parent):
		original_parent.remove_child(tool_obj)
	tool_holder.add_child(tool_obj)

	# Set current tool reference
	current_tool = tool_obj
	print("Tool (%s) added to tool holder." % current_tool.name)

	# Apply tool-specific adjustments (position/rotation in hand)
	apply_tool_specific_adjustments(tool_obj)

	# Ensure visibility (sometimes gets lost during reparenting)
	tool_obj.visible = true


# Apply the right transform for each tool type relative to the tool_holder
func apply_tool_specific_adjustments(tool_obj):
	if not is_instance_valid(tool_obj): return

	var tool_name = tool_obj.name # Use name as a fallback identifier

	# Reset first for consistency
	tool_obj.position = Vector3.ZERO
	tool_obj.rotation = Vector3.ZERO

	# Apply adjustments based on tool name (adjust values as needed)
	# Using rotation_degrees might be more intuitive
	match tool_name:
		"Hoe":
			tool_obj.position = Vector3(0, 0.1, -0.05)
			tool_obj.rotation_degrees = Vector3(rad_to_deg(-0.736), rad_to_deg(-1.265), rad_to_deg(0.204)) # Convert radians if needed
		"WateringCan":
			tool_obj.position = Vector3(0, 0.05, 0) # Adjusted Y slightly
			tool_obj.rotation_degrees = Vector3(0, -90, -90) # Example: Point forward
		"Basket":
			tool_obj.position = Vector3(-0.05, 0, -0.1) # Adjusted X slightly
			tool_obj.rotation_degrees = Vector3(0, 0, -90)
		"SeedBag": # Assuming name is "SeedBag"
			tool_obj.position = Vector3(0, 0, 0.05)
			tool_obj.rotation_degrees = Vector3(0, 0, -90)
		_:
			# Default: Ensure it's reset if name doesn't match known tools
			tool_obj.position = Vector3.ZERO
			tool_obj.rotation = Vector3.ZERO
			print("Applied default adjustments for tool: " + tool_name)

	print("Applied adjustments for tool: " + tool_name)


# Store the current tool on the player's back
func store_current_tool():
	if not current_tool or not tool_belt_enabled(): return false
	if not is_instance_valid(back_tool_holder):
		push_warning("Cannot store tool, BackToolHolder is invalid.")
		return false

	var tool_to_store = current_tool
	print("Storing tool (%s) on back." % tool_to_store.name)

	# Clear current tool reference
	current_tool = null

	# Reparent from hand to back
	if tool_to_store.get_parent() == tool_holder:
		tool_holder.remove_child(tool_to_store)
	back_tool_holder.add_child(tool_to_store)

	# Position and rotate appropriately for back storage
	tool_to_store.position = Vector3.ZERO # Adjust as needed for back position
	tool_to_store.rotation_degrees = Vector3(90, 0, 0) # Rotate to lay flat on back (example)

	# Update stored tool reference
	stored_tool = tool_to_store
	return true


# Swap between current and stored tools
func swap_tools():
	if not tool_belt_enabled() or not stored_tool: return false
	if not is_instance_valid(tool_holder) or not is_instance_valid(back_tool_holder):
		push_error("Cannot swap tools, holder nodes are invalid.")
		return false

	print("Swapping tools...")

	# Save references
	var tool_from_hand = current_tool
	var tool_from_back = stored_tool

	# Clear references temporarily
	current_tool = null
	stored_tool = null

	# Move tool from back to hand
	if is_instance_valid(tool_from_back):
		if tool_from_back.get_parent() == back_tool_holder:
			back_tool_holder.remove_child(tool_from_back)
		tool_holder.add_child(tool_from_back)
		current_tool = tool_from_back
		apply_tool_specific_adjustments(current_tool) # Apply hand position/rotation
		print("Moved %s from back to hand." % current_tool.name)

	# Move tool from hand to back
	if is_instance_valid(tool_from_hand):
		if tool_from_hand.get_parent() == tool_holder:
			tool_holder.remove_child(tool_from_hand)
		back_tool_holder.add_child(tool_from_hand)
		# Apply back position/rotation
		tool_from_hand.position = Vector3.ZERO
		tool_from_hand.rotation_degrees = Vector3(90, 0, 0) # Example back rotation
		stored_tool = tool_from_hand
		print("Moved %s from hand to back." % stored_tool.name)

	return true


# Drop the currently held tool
func drop_tool():
	if not current_tool: return false

	var tool_to_drop = current_tool
	print("Dropping tool: %s" % tool_to_drop.name)

	# Unhighlight if applicable
	if tool_to_drop.has_method("set_highlighted"):
		tool_to_drop.set_highlighted(false)

	# Clear the reference FIRST
	current_tool = null

	# Ensure tool instance is still valid after clearing reference
	if not is_instance_valid(tool_to_drop):
		print("Tool instance became invalid after clearing reference.")
		return false

	# Remove from tool holder
	if tool_to_drop.get_parent() == tool_holder:
		tool_holder.remove_child(tool_to_drop)
	else:
		print("Warning: Tool to drop was not parented to tool_holder.")


	# Determine parent to drop into (try original parent, fallback to player's parent)
	var target_parent = player.get_parent() # Fallback
	var original_parent_path = tool_to_drop.get_meta("original_parent_path", null)
	if original_parent_path:
		var original_parent_node = get_node_or_null(original_parent_path)
		if is_instance_valid(original_parent_node):
			target_parent = original_parent_node
			print("Found original parent: %s" % target_parent.name)
		else:
			print("Original parent path found but node is invalid, using player's parent.")
	elif is_instance_valid(player.get_parent()):
		target_parent = player.get_parent()
		print("No original parent stored, using player's parent: %s" % target_parent.name)
	else:
		push_error("Cannot drop tool: No valid parent found (original or player's).")
		# Re-add to holder temporarily to prevent losing the node? Or queue_free?
		# For now, just return to avoid errors. Consider adding it back to holder.
		# tool_holder.add_child(tool_to_drop) # Re-attach to avoid losing it
		# current_tool = tool_to_drop # Restore reference
		return false


	# Add to the target parent
	target_parent.add_child(tool_to_drop)

	# Position in front of player
	var drop_offset = player.global_transform.basis.z * 0.5 + Vector3.UP * 0.2 # Closer and slightly up
	tool_to_drop.global_position = player.global_position + drop_offset
	tool_to_drop.rotation = Vector3.ZERO # Reset rotation on drop

	# Re-enable physics/collision
	if tool_to_drop is RigidBody3D:
		# Restore original properties from meta
		tool_to_drop.freeze = tool_to_drop.get_meta("original_freeze", false)
		tool_to_drop.collision_layer = tool_to_drop.get_meta("original_collision_layer", 1) # Default layer 1 if meta missing
		tool_to_drop.collision_mask = tool_to_drop.get_meta("original_collision_mask", 1) # Default mask 1 if meta missing
		print("Re-enabled RigidBody3D physics/collision.")
		# Add a small upward impulse
		tool_to_drop.apply_central_impulse(Vector3.UP * 1.0) # Small pop-up
	elif tool_to_drop is CollisionObject3D:
		tool_to_drop.collision_layer = tool_to_drop.get_meta("original_collision_layer", 1)
		tool_to_drop.collision_mask = tool_to_drop.get_meta("original_collision_mask", 1)
		# Restore monitoring/monitorable if needed
		if tool_to_drop.has_method("set_monitoring"): tool_to_drop.set_monitoring(true) # Assuming default is true
		if tool_to_drop.has_method("set_monitorable"): tool_to_drop.set_monitorable(true) # Assuming default is true
		print("Re-enabled CollisionObject3D collision.")

	# Clean up meta info
	tool_to_drop.remove_meta("original_parent_path")
	tool_to_drop.remove_meta("original_freeze")
	tool_to_drop.remove_meta("original_collision_layer")
	tool_to_drop.remove_meta("original_collision_mask")


	# Force update interaction system (if applicable)
	var interaction = player.get_node_or_null("PlayerInteraction")
	if interaction and interaction.has_method("update_potential_interactables"):
		interaction.update_potential_interactables() # Assuming such a method exists

	return true


# Drop all tools (current and stored)
func drop_all_tools():
	print("Dropping all tools...")
	# Drop current tool
	if current_tool:
		drop_tool() # This handles clearing current_tool reference

	# Drop stored tool
	if stored_tool:
		var tool_to_drop = stored_tool
		stored_tool = null # Clear reference

		if not is_instance_valid(tool_to_drop):
			print("Stored tool instance became invalid.")
			return

		print("Dropping stored tool: %s" % tool_to_drop.name)

		# Remove from back holder
		if tool_to_drop.get_parent() == back_tool_holder:
			back_tool_holder.remove_child(tool_to_drop)

		# Determine parent (similar logic to drop_tool)
		var target_parent = player.get_parent()
		var original_parent_path = tool_to_drop.get_meta("original_parent_path", null)
		if original_parent_path:
			var original_parent_node = get_node_or_null(original_parent_path)
			if is_instance_valid(original_parent_node): target_parent = original_parent_node
		if not is_instance_valid(target_parent):
			push_error("Cannot drop stored tool: No valid parent.")
			return

		target_parent.add_child(tool_to_drop)

		# Position behind player (example)
		var drop_offset = -player.global_transform.basis.z * 0.5 + Vector3.UP * 0.2
		tool_to_drop.global_position = player.global_position + drop_offset
		tool_to_drop.rotation = Vector3.ZERO

		# Re-enable physics/collision (same logic as drop_tool)
		if tool_to_drop is RigidBody3D:
			tool_to_drop.freeze = tool_to_drop.get_meta("original_freeze", false)
			tool_to_drop.collision_layer = tool_to_drop.get_meta("original_collision_layer", 1)
			tool_to_drop.collision_mask = tool_to_drop.get_meta("original_collision_mask", 1)
			tool_to_drop.apply_central_impulse(Vector3.UP * 1.0)
		elif tool_to_drop is CollisionObject3D:
			tool_to_drop.collision_layer = tool_to_drop.get_meta("original_collision_layer", 1)
			tool_to_drop.collision_mask = tool_to_drop.get_meta("original_collision_mask", 1)
			if tool_to_drop.has_method("set_monitoring"): tool_to_drop.set_monitoring(true)
			if tool_to_drop.has_method("set_monitorable"): tool_to_drop.set_monitorable(true)

		# Clean up meta
		tool_to_drop.remove_meta("original_parent_path")
		tool_to_drop.remove_meta("original_freeze")
		tool_to_drop.remove_meta("original_collision_layer")
		tool_to_drop.remove_meta("original_collision_mask")


# Start using the current tool
func start_tool_use():
	if not current_tool or is_tool_use_in_progress:
		return

	# Ensure player reference is valid
	if not is_instance_valid(player):
		push_error("Cannot use tool, player reference invalid.")
		return

	var grid_tracker = player.get_node_or_null("PlayerGridTracker")
	if not grid_tracker:
		push_error("PlayerGridTracker not found.")
		return

	var target_pos = grid_tracker.front_grid_position # Assumes this returns a valid Vector3i or similar

	# Check if the tile is already being used by another player
	var pos_key = "%d,%d" % [target_pos.x, target_pos.z] # Use string formatting for key
	if tiles_being_used.has(pos_key) and tiles_being_used[pos_key] != player:
		print("Tool use conflict: Tile %s already in use by another player." % pos_key)
		# Optionally provide feedback to the player (e.g., sound effect, UI message)
		return

	# Check if the tool can be used on the target position
	# The tool's 'use' method should return true if usage can begin
	if not current_tool.has_method("use") or not current_tool.use(target_pos):
		print("Tool (%s) cannot be used on target position %s." % [current_tool.name, target_pos])
		# Optionally provide feedback
		return

	# Mark this tile as being used by this player
	tiles_being_used[pos_key] = player
	print("Player %d started using tool %s on tile %s" % [player.player_index, current_tool.name, pos_key])

	# Determine if the tool use is progress-based or instant
	var interaction_type = 0 # Default to instant
	if current_tool.has_method("get_usage_interaction_type"):
		interaction_type = current_tool.get_usage_interaction_type() # Should return 0 (Instant) or 1 (Progress)

	if interaction_type == 1: # Progress-Based
		var duration = 1.0 # Default duration
		if current_tool.has_method("get_usage_duration"):
			duration = current_tool.get_usage_duration()

		# Setup progress tracking state
		is_tool_use_in_progress = true
		tool_use_completed = false
		tool_use_start_time = Time.get_ticks_msec()
		tool_use_position = target_pos
		tool_use_duration = duration

		# Disable movement during progress-based tool use
		var movement = player.get_node_or_null("PlayerMovement")
		if movement:
			movement.set_movement_disabled(true) # Assuming a setter method

		# Show initial progress feedback (e.g., progress bar)
		var interaction_feedback = player.get_node_or_null("InteractionFeedback")
		if interaction_feedback and interaction_feedback.has_method("show_progress"):
			interaction_feedback.show_progress(0.0)

		# --- Trigger Animation ---
		# Determine animation name based on tool
		var tool_anim_name = get_tool_animation_name(current_tool)
		if animation_controller and tool_anim_name != "":
			print("Requesting action animation: " + tool_anim_name)
			animation_controller.play_action_animation(tool_anim_name)
		# -------------------------

	else: # Instant Tool Use
		# Complete the use immediately
		if current_tool.has_method("complete_use"):
			current_tool.complete_use(target_pos)
		else:
			push_warning("Instant tool %s has no complete_use method." % current_tool.name)

		# --- Trigger Animation (Optional for Instant) ---
		# You might still want a short animation for instant actions
		var tool_anim_name = get_tool_animation_name(current_tool)
		if animation_controller and tool_anim_name != "":
			print("Requesting action animation (instant): " + tool_anim_name)
			animation_controller.play_action_animation(tool_anim_name)
			# Note: For instant actions, the animation might finish *after* the effect.
			# The animation controller's _on_action_animation_finished handles returning to idle/run.
		# -------------------------

		# Clear the tile usage immediately for instant tools
		if tiles_being_used.has(pos_key) and tiles_being_used[pos_key] == player:
			tiles_being_used.erase(pos_key)
			print("Cleared tile usage for instant action on %s" % pos_key)


# Helper to get the animation name for a tool
func get_tool_animation_name(tool_node) -> String:
	if not is_instance_valid(tool_node): return ""

	# Option 1: Get from tool property (Recommended)
	if tool_node.has_method("get_use_animation_name"):
		return tool_node.get_use_animation_name() # e.g., return "UseHoe"

	# Option 2: Map based on tool name (Fallback)
	# IMPORTANT: Ensure these names match your AnimationPlayer/AnimationTree states/animations
	match tool_node.name:
		"Hoe": return "Hoe" # Or "UseHoe", "ActionHoe" etc.
		"WateringCan": return "Watering" # Or "UseWateringCan"
		"SeedingBag": return "Planting" # Or "UseSeeds"
		"Basket": return "Harvesting" # Or "UseBasket"
		_:
			print("No specific animation name defined for tool: " + tool_node.name)
			return "" # Return empty string if no animation defined


# Update the tool use progress
func update_tool_use_progress(_delta): # Delta might not be needed if using ticks
	if not is_tool_use_in_progress or tool_use_completed or tool_use_duration <= 0:
		return

	var elapsed_ms = Time.get_ticks_msec() - tool_use_start_time
	var progress = clamp(float(elapsed_ms) / (tool_use_duration * 1000.0), 0.0, 1.0)

	# Update progress bar feedback
	var interaction_feedback = player.get_node_or_null("InteractionFeedback")
	if interaction_feedback and interaction_feedback.has_method("update_progress"):
		interaction_feedback.update_progress(progress)

	# Check if complete
	if progress >= 1.0:
		# Ensure completion logic runs only once
		tool_use_completed = true
		_on_tool_use_completed(tool_use_position)


# Handle completion of progress-based tool use
func _on_tool_use_completed(position):
	print("Tool use completed at position: %s" % str(position))

	# Hide progress bar
	var interaction_feedback = player.get_node_or_null("InteractionFeedback")
	if interaction_feedback and interaction_feedback.has_method("hide_progress"):
		interaction_feedback.hide_progress()

	# Call the tool's completion logic
	if current_tool and current_tool.has_method("complete_use"):
		print("Calling complete_use on tool %s" % current_tool.name)
		current_tool.complete_use(position)
	else:
		push_warning("Progress-based tool %s has no complete_use method or current_tool is invalid." % (current_tool.name if current_tool else "None"))
	
	# --- ADD THIS BLOCK ---
	# Stop the animation immediately
	if is_instance_valid(animation_controller):
		animation_controller.stop_action_animation()
	# --- END ADD BLOCK ---

	# Reset the tool use state variables AFTER completion logic
	is_tool_use_in_progress = false
	# Keep tool_use_completed = true until next action starts? Or reset here? Resetting seems safer.
	# tool_use_completed = false # Reset for next use
	tool_use_position = null

	# Clear the tile usage lock
	var pos_key = "%d,%d" % [position.x, position.z]
	if tiles_being_used.has(pos_key) and tiles_being_used[pos_key] == player:
		tiles_being_used.erase(pos_key)
		print("Cleared tile usage lock for %s" % pos_key)

	# Re-enable movement
	# IMPORTANT: Do this AFTER clearing state, otherwise _input might immediately trigger another action
	var movement = player.get_node_or_null("PlayerMovement")
	if movement:
		movement.set_movement_disabled(false)

	# Note: The animation controller handles returning to Idle/Run via its
	# _on_action_animation_finished signal handler. No need to call update_animation_state here.


# Cancel the current progress-based tool use
func cancel_tool_use():
	if not is_tool_use_in_progress or tool_use_completed:
		return # Can only cancel if in progress and not yet completed

	print("Cancelling tool use.")

	# Hide progress bar
	var interaction_feedback = player.get_node_or_null("InteractionFeedback")
	if interaction_feedback and interaction_feedback.has_method("hide_progress"):
		interaction_feedback.hide_progress()

	# Call cancellation logic on the tool if it exists
	if current_tool and current_tool.has_method("cancel_use"):
		current_tool.cancel_use(tool_use_position)

	# Clear the tile usage lock
	if tool_use_position:
		var pos_key = "%d,%d" % [tool_use_position.x, tool_use_position.z]
		if tiles_being_used.has(pos_key) and tiles_being_used[pos_key] == player:
			tiles_being_used.erase(pos_key)
			print("Cleared tile usage lock for cancelled action on %s" % pos_key)

	# Reset state variables
	is_tool_use_in_progress = false
	tool_use_completed = false # Reset completion flag as well
	tool_use_position = null

	# Re-enable movement
	var movement = player.get_node_or_null("PlayerMovement")
	if movement:
		movement.set_movement_disabled(false)
		
	# --- ADD THIS BLOCK ---
	# Stop the current animation and return to Idle/Run
	if is_instance_valid(animation_controller):
		animation_controller.stop_action_animation()
	# --- END ADD BLOCK ---

	# Stop the current animation and return to Idle/Run
	# We need to tell the animation controller to stop the action
	if animation_controller:
		# Option A: If AnimationTree handles transitions well, just force update
		# animation_controller.force_update_state()
		# Option B: Explicitly stop and update (safer if tree transitions are complex)
		if animation_controller.animation_player:
			animation_controller.animation_player.stop() # Stop current animation
		animation_controller.is_playing_action_anim = false # Manually reset flag
		animation_controller.force_update_state() # Trigger Idle/Run check


# Clear references to a tool (called when a tool is destroyed externally)
func clear_tool_reference(tool_obj):
	var cleared = false
	if not is_instance_valid(tool_obj):
		print("Attempted to clear reference to an invalid tool object.")
		# Check if our references point to this now-invalid object ID
		if current_tool and current_tool.get_instance_id() == tool_obj.get_instance_id():
			print("Clearing invalid current_tool reference.")
			current_tool = null
			cleared = true
		if stored_tool and stored_tool.get_instance_id() == tool_obj.get_instance_id():
			print("Clearing invalid stored_tool reference.")
			stored_tool = null
			cleared = true
		return cleared

	# If tool_obj is valid, compare directly
	if current_tool == tool_obj:
		print("Clearing reference to current tool: " + tool_obj.name)
		current_tool = null
		cleared = true
	if stored_tool == tool_obj:
		print("Clearing reference to stored tool: " + tool_obj.name)
		stored_tool = null
		cleared = true

	if cleared:
		print("Tool reference cleared.")
	return cleared


# Get parameter manager reference (using Service Locator pattern)
func get_parameter_manager():
	# Use has_node check for safety
	if get_tree().root.has_node("ServiceLocator"):
		var service_locator = get_node("/root/ServiceLocator")
		if service_locator and service_locator.has_method("get_service"):
			return service_locator.get_service("parameter_manager")
	print("Parameter Manager service not found via ServiceLocator.")
	return null
