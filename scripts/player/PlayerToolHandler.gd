# res://scripts/player/PlayerToolHandler.gd
# Manages the player's currently held tool, tool belt (if upgraded),
# and handles the logic for starting, progressing, completing, or cancelling tool interactions
# based on the data-driven InteractionDefinition system.
class_name PlayerToolHandler
extends Node

# --- Constants ---
const ATTACHMENT_POINT_NAME = "AttachmentPoint" # Consistent name for the handle node

# --- References ---
@onready var player = get_parent()
@export var tool_holder: Node3D = null
@onready var back_tool_holder = $"../BackToolHolder" if $"..".has_node("BackToolHolder") else null
@onready var animation_controller: PlayerAnimationController = owner.find_child("PlayerAnimationController") if owner else null

# --- Tool State ---
var current_tool: Tool = null
var stored_tool: Tool = null

# --- Refactored Tool Use State ---
var is_tool_use_in_progress: bool = false
var current_interaction: InteractionDefinition = null
var tool_use_start_time: int = 0
var tool_use_position: Vector3i
var current_interaction_final_duration: float = 0.0

# --- Static State ---
static var tiles_being_used = {}

# --- Initialization ---
func _ready():
	if not is_instance_valid(player):
		push_error("PlayerToolHandler: Player reference invalid in _ready!")
	if not animation_controller and is_instance_valid(player):
		animation_controller = player.find_child("PlayerAnimationController")
	if tool_belt_enabled() and not back_tool_holder:
		create_back_tool_holder()
	if not tool_holder and is_instance_valid(player):
		tool_holder = player.get_node_or_null("ToolHolder")
		if not tool_holder:
			push_warning("PlayerToolHandler: tool_holder not assigned in Inspector and not found automatically.")

# --- Tool Belt and Holder Management ---
func tool_belt_enabled() -> bool:
	var parameter_manager = get_parameter_manager()
	if parameter_manager:
		return parameter_manager.get_value("player.tool_belt_capacity", 1.0) > 1.0
	return false

func create_back_tool_holder():
	if not is_instance_valid(player):
		push_error("Cannot create BackToolHolder, player reference is invalid.")
		return
	if player.has_node("BackToolHolder"):
		back_tool_holder = player.get_node("BackToolHolder")
		return
	var holder = Node3D.new()
	holder.name = "BackToolHolder"
	holder.position = Vector3(0, 0.8, -0.2)
	holder.rotation_degrees = Vector3(0, 180, 0)
	player.add_child(holder)
	back_tool_holder = holder
	print("PlayerToolHandler: Created BackToolHolder")

# --- Tool Pickup / Drop / Swap Logic ---

# MODIFIED: Handles picking up a tool instance using the AttachmentPoint
func pick_up_tool(tool_obj: Tool):
	if not is_instance_valid(tool_obj):
		push_error("ERROR: Tool object to pick up is not valid!")
		return
	if not is_instance_valid(tool_holder):
		push_error("ERROR: ToolHolder node is not valid or not found!")
		return

	print("Attempting to pick up tool: " + tool_obj.name)

	# Handle existing tool (store or drop)
	if current_tool and tool_belt_enabled() and not stored_tool:
		print("Storing current tool (%s) in belt" % current_tool.name)
		store_current_tool()
	elif current_tool:
		print("Dropping current tool (%s) before picking up new one" % current_tool.name)
		drop_tool()

	# --- Prepare Tool for Holding ---
	# Store original parent path
	var original_parent = tool_obj.get_parent()
	if is_instance_valid(original_parent):
		tool_obj.set_meta("original_parent_path", original_parent.get_path())
	else:
		tool_obj.set_meta("original_parent_path", null)

	# Disable physics/collision
	_disable_tool_physics(tool_obj)

	# --- Calculate Attachment Offset ---
	var attachment_offset = Vector3.ZERO
	var attachment_node = tool_obj.find_child(ATTACHMENT_POINT_NAME, false) # Find the specific node
	if attachment_node:
		# Get the LOCAL position of the attachment point relative to the tool's origin
		attachment_offset = attachment_node.position
		print("Found '%s' at local position: %s" % [ATTACHMENT_POINT_NAME, str(attachment_offset)])
	else:
		push_warning("Tool '%s' is missing the '%s' node. Attaching at origin." % [tool_obj.name, ATTACHMENT_POINT_NAME])
		# Fallback: attach at origin (or apply old adjustments)

	# Reparent the tool to the tool holder
	if is_instance_valid(original_parent):
		original_parent.remove_child(tool_obj)
	tool_holder.add_child(tool_obj)

	# Set current tool reference
	current_tool = tool_obj
	print("Tool (%s) added to tool holder." % current_tool.name)

	# --- Apply Attachment ---
	# Set the tool's LOCAL position to the NEGATIVE of the offset.
	# This aligns the tool's AttachmentPoint with the tool_holder's origin.
	tool_obj.position = -attachment_offset

	# Apply rotation adjustments (can be kept or simplified)
	apply_tool_rotation_adjustments(tool_obj)

	tool_obj.visible = true # Ensure visibility


# Helper to disable physics/collision
func _disable_tool_physics(tool_obj: Node):
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

# Helper to re-enable physics/collision
func _enable_tool_physics(tool_obj: Node):
	if tool_obj is RigidBody3D:
		tool_obj.freeze = tool_obj.get_meta("original_freeze", false)
		tool_obj.collision_layer = tool_obj.get_meta("original_collision_layer", 1)
		tool_obj.collision_mask = tool_obj.get_meta("original_collision_mask", 1)
		tool_obj.apply_central_impulse(Vector3.UP * 0.5) # Small pop-up
	elif tool_obj is CollisionObject3D:
		tool_obj.collision_layer = tool_obj.get_meta("original_collision_layer", 1)
		tool_obj.collision_mask = tool_obj.get_meta("original_collision_mask", 1)
		if tool_obj.has_method("set_monitoring"): tool_obj.set_monitoring(true)
		if tool_obj.has_method("set_monitorable"): tool_obj.set_monitorable(true)

	# Clean up meta info
	tool_obj.remove_meta("original_parent_path")
	tool_obj.remove_meta("original_freeze")
	tool_obj.remove_meta("original_collision_layer")
	tool_obj.remove_meta("original_collision_mask")

# RENAMED: Applies specific local ROTATION adjustments to the tool when held.
# Position is now handled by the AttachmentPoint.
func apply_tool_rotation_adjustments(tool_obj: Tool):
	if not is_instance_valid(tool_obj): return

	# Reset rotation first
	tool_obj.rotation = Vector3.ZERO

	# Apply rotation adjustments based on tool name
	match tool_obj.name.get_slice(":", 0): # Use name or a more reliable identifier
		"Hoe":
			tool_obj.rotation_degrees = Vector3(-62, -23, -27)
		"WateringCan":
			tool_obj.rotation_degrees = Vector3(53, -56, -144)
		"Basket":
			tool_obj.rotation_degrees = Vector3(-28, 36, -129)
		"SeedBag", "SeedingBag":
			tool_obj.rotation_degrees = Vector3(-32, 95, -156)
		_:
			tool_obj.rotation = Vector3.ZERO # Default rotation

	# print("Applied rotation adjustments for tool: " + tool_obj.name) # Optional Debug

# Stores the currently held tool onto the back holder.
func store_current_tool():
	if not current_tool or not tool_belt_enabled(): return false
	if not is_instance_valid(back_tool_holder):
		push_warning("Cannot store tool, BackToolHolder is invalid.")
		return false

	var tool_to_store = current_tool
	print("Storing tool (%s) on back." % tool_to_store.name)
	current_tool = null

	if tool_to_store.get_parent() == tool_holder:
		tool_holder.remove_child(tool_to_store)
	back_tool_holder.add_child(tool_to_store)

	# Apply back storage transform
	tool_to_store.position = Vector3(0, 0, 0.1)
	tool_to_store.rotation_degrees = Vector3(90, 0, 0)

	stored_tool = tool_to_store
	return true

# Swaps the tools between the hand and the back holder.
func swap_tools():
	if not tool_belt_enabled() or not (current_tool or stored_tool): return false
	if not is_instance_valid(tool_holder) or not is_instance_valid(back_tool_holder):
		push_error("Cannot swap tools, holder nodes are invalid.")
		return false

	print("Swapping tools...")
	var tool_from_hand = current_tool
	var tool_from_back = stored_tool
	current_tool = null
	stored_tool = null

	# Move tool from back to hand
	if is_instance_valid(tool_from_back):
		if tool_from_back.get_parent() == back_tool_holder:
			back_tool_holder.remove_child(tool_from_back)
		tool_holder.add_child(tool_from_back)
		current_tool = tool_from_back

		# --- Apply Attachment Offset for Hand ---
		var attachment_offset = Vector3.ZERO
		var attachment_node = current_tool.find_child(ATTACHMENT_POINT_NAME, false)
		if attachment_node:
			attachment_offset = attachment_node.position
		current_tool.position = -attachment_offset
		apply_tool_rotation_adjustments(current_tool) # Apply hand rotation
		print("Moved %s from back to hand." % current_tool.name)

	# Move tool from hand to back
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
	if tool_to_drop.has_method("set_highlighted"):
		tool_to_drop.set_highlighted(false)
	current_tool = null
	if not is_instance_valid(tool_to_drop): return false

	if tool_to_drop.get_parent() == tool_holder:
		tool_holder.remove_child(tool_to_drop)

	var target_parent = player.get_parent()
	var original_parent_path = tool_to_drop.get_meta("original_parent_path", null)
	if original_parent_path:
		var original_parent_node = get_node_or_null(original_parent_path)
		if is_instance_valid(original_parent_node): target_parent = original_parent_node
	if not is_instance_valid(target_parent):
		push_error("Cannot drop tool: No valid parent found.")
		return false

	target_parent.add_child(tool_to_drop)
	var drop_offset = player.global_transform.basis.z * 0.6 + Vector3.UP * 0.1
	tool_to_drop.global_position = player.global_position + drop_offset
	tool_to_drop.rotation = Vector3.ZERO

	_enable_tool_physics(tool_to_drop) # Use helper
	return true

# Drops both currently held and stored tools.
func drop_all_tools():
	print("Dropping all tools...")
	var dropped_current = false
	var dropped_stored = false
	if current_tool:
		dropped_current = drop_tool()

	if stored_tool:
		var tool_to_drop = stored_tool
		stored_tool = null
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
		var drop_offset = -player.global_transform.basis.z * 0.6 + Vector3.UP * 0.1
		tool_to_drop.global_position = player.global_position + drop_offset
		tool_to_drop.rotation = Vector3.ZERO

		_enable_tool_physics(tool_to_drop) # Use helper
		dropped_stored = true

	return dropped_current or dropped_stored

# --- REFACTORED Tool Usage ---
# Checks if the current tool can be used on the tile in front of the player
func can_use_tool(tile_position):
	var grid_tracker = player.get_node_or_null("PlayerGridTracker")
	if not grid_tracker:
		push_error("PlayerToolHandler: PlayerGridTracker not found!")
		return false # Cannot determine target

	# Ensure a tool is held
	if not is_instance_valid(current_tool):
		return false

	var target_pos = grid_tracker.get_front_grid_position()

	# Ask the current tool for a valid interaction based on the target.
	var interaction_def: InteractionDefinition = current_tool.get_valid_interaction(target_pos)
	return interaction_def != null # Return true if a valid interaction exists

# Called when the player presses the 'use tool' action.
func start_tool_use():
	if not is_instance_valid(current_tool) or is_tool_use_in_progress: return
	if not is_instance_valid(player): return

	var grid_tracker = player.get_node_or_null("PlayerGridTracker")
	if not grid_tracker:
		push_error("PlayerToolHandler: PlayerGridTracker not found!")
		return

	var target_pos = grid_tracker.get_front_grid_position()
	var interaction_def: InteractionDefinition = current_tool.get_valid_interaction(target_pos)

	if not is_instance_valid(interaction_def):
		print("Tool %s has no valid interaction for target %s" % [current_tool.name, str(target_pos)])
		# TODO: Play 'cannot use' sound
		return

	var pos_key = "%d,%d" % [target_pos.x, target_pos.z]
	if tiles_being_used.has(pos_key) and tiles_being_used[pos_key] != player:
		print("Tool use conflict: Tile %s already in use." % pos_key)
		# TODO: Play conflict sound
		return

	tiles_being_used[pos_key] = player
	print("Player %d starting interaction '%s' with tool %s on tile %s" % [player.player_index if is_instance_valid(player) else -1, interaction_def.interaction_id, current_tool.name, pos_key])

	current_interaction = interaction_def
	tool_use_position = target_pos

	if current_interaction.interaction_type == InteractionDefinition.InteractionType.PROGRESS:
		is_tool_use_in_progress = true
		tool_use_start_time = Time.get_ticks_msec()

		var base_duration = current_interaction.duration
		var final_duration = base_duration
		var parameter_manager = get_parameter_manager()
		if current_interaction.duration_parameter_id != "" and parameter_manager:
			final_duration = parameter_manager.get_value(current_interaction.duration_parameter_id, base_duration)

		if is_instance_valid(current_tool): # Check tool validity before calling method
			final_duration /= current_tool.get_global_tool_speed_multiplier()
		current_interaction_final_duration = max(0.1, final_duration)

		var movement = player.get_node_or_null("PlayerMovement")
		if movement: movement.set_movement_disabled(true)

		var interaction_feedback = player.get_node_or_null("InteractionFeedback")
		if interaction_feedback: interaction_feedback.show_progress(0.0)

		var tool_anim_name = get_tool_animation_name(current_tool)
		if animation_controller and tool_anim_name != "":
			animation_controller.play_action_animation(tool_anim_name)

	elif current_interaction.interaction_type == InteractionDefinition.InteractionType.INSTANT:
		if is_instance_valid(current_tool): # Check tool validity
			current_tool.complete_interaction_effect(target_pos, current_interaction.interaction_id)

		var tool_anim_name = get_tool_animation_name(current_tool)
		if animation_controller and tool_anim_name != "":
			animation_controller.play_action_animation(tool_anim_name)

		if tiles_being_used.has(pos_key) and tiles_being_used[pos_key] == player:
			tiles_being_used.erase(pos_key)

		current_interaction = null

# Called every frame to update progress for active interactions.
func _process(delta):
	if is_tool_use_in_progress:
		update_tool_use_progress(delta)

# Updates the progress of the current interaction.
func update_tool_use_progress(_delta):
	if not is_tool_use_in_progress or not is_instance_valid(current_interaction) or \
	   current_interaction.interaction_type != InteractionDefinition.InteractionType.PROGRESS:
		return

	var duration = current_interaction_final_duration
	if duration <= 0:
		_on_tool_use_completed(tool_use_position)
		return

	var elapsed_ms = Time.get_ticks_msec() - tool_use_start_time
	var progress = clamp(float(elapsed_ms) / (duration * 1000.0), 0.0, 1.0)

	var interaction_feedback = player.get_node_or_null("InteractionFeedback")
	if interaction_feedback: interaction_feedback.update_progress(progress)

	if progress >= 1.0:
		_on_tool_use_completed(tool_use_position)

# Called internally when a progress-based interaction reaches 100%.
func _on_tool_use_completed(position: Vector3i):
	if not is_tool_use_in_progress or not is_instance_valid(current_interaction):
		is_tool_use_in_progress = false
		current_interaction = null
		var movement = player.get_node_or_null("PlayerMovement")
		if movement: movement.set_movement_disabled(false)
		return

	print("Tool interaction '%s' completed at position: %s" % [current_interaction.interaction_id, str(position)])

	var interaction_feedback = player.get_node_or_null("InteractionFeedback")
	if interaction_feedback: interaction_feedback.hide_progress()

	if is_instance_valid(current_tool):
		current_tool.complete_interaction_effect(position, current_interaction.interaction_id)

	if is_instance_valid(animation_controller):
		animation_controller.stop_action_animation()

	var pos_key = "%d,%d" % [position.x, position.z]
	if tiles_being_used.has(pos_key) and tiles_being_used[pos_key] == player:
		tiles_being_used.erase(pos_key)

	is_tool_use_in_progress = false
	current_interaction = null

	var movement = player.get_node_or_null("PlayerMovement")
	if movement: movement.set_movement_disabled(false)

# Called when the player releases the 'use tool' action during a progress interaction.
func cancel_tool_use():
	if not is_tool_use_in_progress or not is_instance_valid(current_interaction): return

	print("Cancelling tool interaction '%s'." % current_interaction.interaction_id)

	var interaction_feedback = player.get_node_or_null("InteractionFeedback")
	if interaction_feedback: interaction_feedback.hide_progress()

	# Optional: Cancel effect on tool
	# if is_instance_valid(current_tool) and current_tool.has_method("cancel_interaction_effect"):
	#     current_tool.cancel_interaction_effect(tool_use_position, current_interaction.interaction_id)

	var pos_key = "%d,%d" % [tool_use_position.x, tool_use_position.z]
	if tiles_being_used.has(pos_key) and tiles_being_used[pos_key] == player:
		tiles_being_used.erase(pos_key)

	is_tool_use_in_progress = false
	current_interaction = null

	var movement = player.get_node_or_null("PlayerMovement")
	if movement: movement.set_movement_disabled(false)

	if is_instance_valid(animation_controller):
		animation_controller.stop_action_animation()

# --- Helper Functions ---
func get_tool_animation_name(tool_node: Tool) -> String:
	if not is_instance_valid(tool_node): return ""
	match tool_node.name.get_slice(":", 0):
		"Hoe": return "Hoe"
		"WateringCan": return "Watering"
		"SeedBag", "SeedingBag": return "Planting"
		"Basket": return "Harvesting"
		_: return ""

func clear_tool_reference(tool_obj):
	var cleared = false
	var check_id = tool_obj.get_instance_id() if is_instance_valid(tool_obj) else 0
	if current_tool and (not is_instance_valid(current_tool) or current_tool.get_instance_id() == check_id):
		current_tool = null
		cleared = true
	if stored_tool and (not is_instance_valid(stored_tool) or stored_tool.get_instance_id() == check_id):
		stored_tool = null
		cleared = true
	return cleared

func get_parameter_manager():
	var service_locator = get_node_or_null("/root/ServiceLocator")
	if service_locator and service_locator.has_method("get_service"):
		if service_locator.has_service("parameter_manager"):
			return service_locator.get_service("parameter_manager")
	return null # Return null if not found
