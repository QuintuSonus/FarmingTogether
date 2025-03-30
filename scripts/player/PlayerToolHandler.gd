# scripts/player/PlayerToolHandler.gd
class_name PlayerToolHandler
extends Node

# References
var player: CharacterBody3D = null
@export var tool_holder: Node3D = null

@onready var back_tool_holder = $"../BackToolHolder" if $"..".has_node("BackToolHolder") else null
@onready var animation_controller = $"../PlayerAnimationController" if $"..".has_node("PlayerAnimationController") else null

# Tool state
var current_tool = null
var stored_tool = null  # Second tool slot for tool belt upgrade
var is_tool_use_in_progress: bool = false
var tool_use_completed: bool = false
var tool_use_start_time: int = 0
var tool_use_position = null
var tool_use_duration: float = 0.0

# For bone attachment adjustments
var using_bone_attachment: bool = false

# Static dictionary to track which tiles are being used by tools
static var tiles_being_used = {}

func _ready():
	# Create back tool holder if it doesn't exist but tool belt is active
	if tool_belt_enabled() and not back_tool_holder:
		create_back_tool_holder()
		
	# Check if we're using a bone attachment
	if tool_holder:
		var parent = tool_holder.get_parent()
		if parent and "BoneAttachment" in parent.get_class():
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
		return parameter_manager.get_value("player.tool_belt_capacity", 1.0) > 1.0
	return false

# Create back tool holder if it doesn't exist
func create_back_tool_holder():
	if player.has_node("BackToolHolder"):
		back_tool_holder = player.get_node("BackToolHolder")
		return
		
	var holder = Node3D.new()
	holder.name = "BackToolHolder"
	holder.position = Vector3(0, 0.2, -0.3)  # Position on the player's back
	player.add_child(holder)
	back_tool_holder = holder
	print("PlayerToolHandler: Created BackToolHolder")

# Pick up a tool - FIXED FOR BONE ATTACHMENT
# Pick up a tool - FIXED FOR BONE ATTACHMENT WITH DEBUG
func pick_up_tool(tool_obj):
	if not is_instance_valid(tool_obj):
		print("ERROR: Tool object is not valid!")
		return
	
	print("========== TOOL PICKUP START ==========")
	print("Picking up tool: " + tool_obj.name)
	print("Tool class: " + tool_obj.get_class())
	
	# Debug the tool holder
	print("Tool holder exists: " + str(is_instance_valid(tool_holder)))
	if tool_holder:
		print("Tool holder path: " + str(tool_holder.get_path()))
		print("Tool holder parent: " + tool_holder.get_parent().name)
		if "BoneAttachment" in tool_holder.get_parent().get_class():
			print("Tool holder is attached to a bone!")
			using_bone_attachment = true
	
	# Debug initial tool state
	print("Initial tool state:")
	print(tool_obj.transform)
	print("Tool visibility: " + str(tool_obj.visible))
	
	# If we have a tool belt and already have a tool, store the current tool
	if current_tool and tool_belt_enabled() and not stored_tool:
		print("Storing current tool in belt")
		store_current_tool()
	elif current_tool:
		# First drop the current tool
		print("Dropping current tool")
		drop_tool()
	
	# Get the original parent to restore when dropping
	tool_obj.original_parent = tool_obj.get_parent()
	print("Original parent: " + (tool_obj.original_parent.name if tool_obj.original_parent else "null"))
	
	# Disable physics on the tool
	if tool_obj is RigidBody3D:
		print("Tool is a RigidBody3D, disabling physics")
		# Store original physics properties
		tool_obj.original_freeze = tool_obj.freeze
		tool_obj.freeze = true
		
		# Store original collision settings
		tool_obj.original_collision_layer = tool_obj.collision_layer
		tool_obj.original_collision_mask = tool_obj.collision_mask
		
		# Disable collision
		tool_obj.collision_layer = 0
		tool_obj.collision_mask = 0
	
	# Attach the tool to the tool holder
	print("Removing tool from original parent")
	if tool_obj.get_parent():
		tool_obj.get_parent().remove_child(tool_obj)
	else:
		print("WARNING: Tool had no parent")
		
	if tool_holder:
		print("Adding tool to tool holder")
		
		# Store the tool's visibility before adding
		var was_visible = tool_obj.visible
		print("Tool visibility before adding: " + str(was_visible))
		
		# Add the tool to the tool holder
		tool_holder.add_child(tool_obj)
		
		# Check visibility after adding
		print("Tool visibility after adding: " + str(tool_obj.visible))
		
		# Force visibility if needed
		if !tool_obj.visible and was_visible:
			print("Tool disappeared! Forcing visibility back on")
			tool_obj.visible = true
		
		# Store reference to current tool
		current_tool = tool_obj
		
		# Debug tool state after adding to holder
		print("Tool state after adding to holder:")
		print(tool_obj.transform)
		
		print("Applying tool-specific adjustments")
		print(tool_obj.get_class())
		# Apply tool-specific adjustments
		apply_tool_specific_adjustments(tool_obj)
		
		# Debug tool state after adjustments
		print("Tool state after adjustments:")
		print(tool_obj.transform)
		print("Final visibility: " + str(tool_obj.visible))
	else:
		print("ERROR: ToolHolder node not found!")
		push_error("Player: ToolHolder node not found!")
		
	print("========== TOOL PICKUP END ==========")

# Apply the right transform for each tool type
func apply_tool_specific_adjustments(tool_obj):
	if not tool_obj:
		return
	
	# Get the tool class and tool type (if available)
	var tool_name = tool_obj.name
	var tool_type = ""
	
	if tool_obj.has_method("get_tool_type"):
		tool_type = tool_obj.get_tool_type()
	
	# Apply different adjustments based on the tool type
	if tool_name == "Hoe":
		tool_obj.position = Vector3(0, 0.1, -0.05)
		tool_obj.rotation = Vector3(-0.736529, -1.26588, 0.204204)
		
	elif tool_name == "WateringCan":
		tool_obj.position = Vector3(0, 0.5, 0)
		tool_obj.rotation_degrees = Vector3(45, 0, -150)
		
	elif tool_name == "Basket":
		tool_obj.position = Vector3(0, 0, -0.1)
		tool_obj.rotation_degrees = Vector3(0, 0, -90)
		
	elif tool_name == "SeedBag":
		tool_obj.position = Vector3(0, 0, 0.05)
		tool_obj.rotation_degrees = Vector3(0, 0, -90)
		
	else:
		# Default position and rotation
		tool_obj.position = Vector3.ZERO
		tool_obj.rotation = Vector3.ZERO
	
	print("Applied adjustments for tool: " + tool_name)

# Store the current tool on the player's back
func store_current_tool():
	if not current_tool or not tool_belt_enabled():
		return false
	
	# Ensure we have a back tool holder
	if not back_tool_holder:
		create_back_tool_holder()
	
	# Get reference to the tool
	var tool_obj = current_tool
	
	# Clear the current tool reference
	current_tool = null
	
	# Remove from current holder
	if tool_obj.get_parent():
		tool_obj.get_parent().remove_child(tool_obj)
	
	# Add to back holder
	back_tool_holder.add_child(tool_obj)
	
	# Position and rotate appropriately for back storage
	tool_obj.position = Vector3.ZERO
	tool_obj.rotation = Vector3(PI/2, 0, 0)  # Rotate to lay flat on back
	
	# Update reference
	stored_tool = tool_obj
	
	print("PlayerToolHandler: Stored tool on back")
	return true

# Swap between current and stored tools
func swap_tools():
	if not tool_belt_enabled() or not stored_tool:
		return false
	
	print("PlayerToolHandler: Swapping tools")
	
	# Save references to both tools
	var hand_tool = current_tool
	var back_tool = stored_tool
	
	# Clear references first
	current_tool = null
	stored_tool = null
	
	# Remove tools from their holders
	if hand_tool and hand_tool.get_parent():
		hand_tool.get_parent().remove_child(hand_tool)
	
	if back_tool and back_tool.get_parent():
		back_tool.get_parent().remove_child(back_tool)
	
	# Move back tool to hand
	if tool_holder and back_tool:
		tool_holder.add_child(back_tool)
		current_tool = back_tool
		# Apply tool-specific adjustments for the tool now in hand
		apply_tool_specific_adjustments(back_tool)
	
	# Move hand tool to back
	if back_tool_holder and hand_tool:
		back_tool_holder.add_child(hand_tool)
		hand_tool.position = Vector3.ZERO
		hand_tool.rotation = Vector3(PI/2, 0, 0)  # Rotate to lay flat on back
		stored_tool = hand_tool
	
	return true

# Drop the currently held tool
func drop_tool():
	# Simplified drop logic with error checking
	if not current_tool:
		return false
	
	# Store reference to the tool
	var tool_obj = current_tool
	
	# First, unhighlight the tool if it's currently highlighted
	if tool_obj.has_method("set_highlighted"):
		tool_obj.set_highlighted(false)
	
	# Clear the tool reference FIRST
	current_tool = null
	
	# Make sure the tool still exists 
	if not is_instance_valid(tool_obj):
		return false
	
	# Remove from tool holder if it's there
	if tool_holder and tool_obj.get_parent() == tool_holder:
		tool_holder.remove_child(tool_obj)
	
	# Get a parent to add it to
	var target_parent = player.get_parent()
	
	# Try to use the original parent if available
	if tool_obj.get("original_parent") != null:
		var original = tool_obj.get("original_parent")
		if is_instance_valid(original):
			target_parent = original
	
	# Add to parent if not already in scene
	if not tool_obj.is_inside_tree():
		target_parent.add_child(tool_obj)
	
	# Position in front of player
	var drop_pos = player.global_position + player.global_transform.basis.z * 1.0
	drop_pos.y = 1.0  # Slightly above ground
	tool_obj.global_position = drop_pos
	
	# Re-enable physics
	if tool_obj is RigidBody3D:
		# Reset collision
		tool_obj.collision_layer = 1 << 1  # Layer 2
		tool_obj.collision_mask = 1  # Layer 1
		
		# Set not frozen
		tool_obj.freeze = false
		
		# Add impulse
		tool_obj.apply_central_impulse(Vector3(0, 0.5, 0))
	
	# Force update interaction system
	var interaction = player.get_node_or_null("PlayerInteraction")
	if interaction and interaction.interaction_manager:
		if interaction.interaction_manager.potential_interactable == tool_obj:
			interaction.interaction_manager.potential_interactable = null
			interaction.interaction_manager.emit_signal("potential_interactable_changed", null)
	
	return true

# Drop all tools (used when exiting game or changing levels)
func drop_all_tools():
	# First drop the current tool
	drop_tool()
	
	# Then drop the stored tool if we have one
	if stored_tool:
		var tool_obj = stored_tool
		stored_tool = null
		
		# Make sure the tool still exists
		if not is_instance_valid(tool_obj):
			return
		
		# Remove from back tool holder
		if back_tool_holder and tool_obj.get_parent() == back_tool_holder:
			back_tool_holder.remove_child(tool_obj)
		
		# Get a parent to add it to
		var target_parent = player.get_parent()
		
		# Add to parent if not already in scene
		if not tool_obj.is_inside_tree():
			target_parent.add_child(tool_obj)
		
		# Position behind player
		var drop_pos = player.global_position - player.global_transform.basis.z * 1.0
		drop_pos.y = 1.0  # Slightly above ground
		tool_obj.global_position = drop_pos
		
		# Re-enable physics
		if tool_obj is RigidBody3D:
			# Reset collision
			tool_obj.collision_layer = 1 << 1  # Layer 2
			tool_obj.collision_mask = 1  # Layer 1
			tool_obj.freeze = false
			tool_obj.apply_central_impulse(Vector3(0, 0.5, 0))

# Start using the current tool
func start_tool_use():
	if not current_tool or is_tool_use_in_progress:
		return
	
	var grid_tracker = player.get_node_or_null("PlayerGridTracker")
	if not grid_tracker:
		return
		
	var target_pos = grid_tracker.front_grid_position
	
	# Check if another player is already using a tool on this tile
	var pos_key = str(target_pos.x) + "," + str(target_pos.z)
	if tiles_being_used.has(pos_key) and tiles_being_used[pos_key] != player:
		print("Tool use conflict: Another player is already using a tool on this tile")
		return
	
	var can_use = current_tool.use(target_pos)
	
	if can_use:
		# Mark this tile as being used by this player
		tiles_being_used[pos_key] = player
		
		# Use the tool's usage-specific methods
		if current_tool.has_method("get_usage_interaction_type") and current_tool.get_usage_interaction_type() == 1: # 1 = Progress_Based
			# Get duration
			var duration = 1.0
			if current_tool.has_method("get_usage_duration"):
				duration = current_tool.get_usage_duration()
			
			# Setup progress tracking
			is_tool_use_in_progress = true
			tool_use_completed = false
			tool_use_start_time = Time.get_ticks_msec()
			tool_use_position = target_pos
			tool_use_duration = duration
			
			# Disable movement during progress-based tool use
			var movement = player.get_node_or_null("PlayerMovement")
			if movement:
				movement.movement_disabled = true
			
			# Show initial progress
			var interaction_feedback = player.get_node_or_null("InteractionFeedback")
			if interaction_feedback:
				interaction_feedback.show_progress(0.0)
				
			# Play appropriate animation if we have animation controller
			if animation_controller:
				var tool_action = "hoe"
				
				# Determine appropriate animation based on tool type
				if current_tool.get_class() == "Hoe":
					tool_action = "hoe"
				elif current_tool.get_class() == "WateringCan":
					tool_action = "water"
				elif current_tool.get_class() == "SeedBag" or "Seed" in current_tool.get_class():
					tool_action = "plant"
				elif current_tool.get_class() == "Basket":
					tool_action = "harvest"
					
				animation_controller.play_action_animation(tool_action)
		else:
			# Instant tool use

			current_tool.complete_use(target_pos)
			
			# Clear the tile usage immediately for instant tools
			if tiles_being_used.has(pos_key) and tiles_being_used[pos_key] == player:
				tiles_being_used.erase(pos_key)

# Update the tool use progress
func update_tool_use_progress(delta):
	if is_tool_use_in_progress and not tool_use_completed and tool_use_duration > 0:
		var elapsed = (Time.get_ticks_msec() - tool_use_start_time) / 1000.0
		var progress = clamp(elapsed / tool_use_duration, 0.0, 1.0)
		
		# Update progress bar
		var interaction_feedback = player.get_node_or_null("InteractionFeedback")
		if interaction_feedback:
			interaction_feedback.update_progress(progress)
		
		# Check if complete
		if progress >= 1.0 and not tool_use_completed:
			tool_use_completed = true
			_on_tool_use_completed(tool_use_position)

# Handle completion of tool use
func _on_tool_use_completed(position):
	# Hide progress bar
	var interaction_feedback = player.get_node_or_null("InteractionFeedback")
	if interaction_feedback:
		interaction_feedback.hide_progress()
	
	# Complete the tool use
	if current_tool and current_tool.has_method("complete_use"):
		print("calling complete use from player tool handler")
		current_tool.complete_use(position)
	
	# Reset the tool use state
	is_tool_use_in_progress = false
	tool_use_position = null
	
	# Clear the tile usage
	var pos_key = str(position.x) + "," + str(position.z)
	if tiles_being_used.has(pos_key) and tiles_being_used[pos_key] == player:
		tiles_being_used.erase(pos_key)
	
	# Re-enable movement
	var movement = player.get_node_or_null("PlayerMovement")
	if movement:
		movement.movement_disabled = false

# Cancel the current tool use
func cancel_tool_use():
	if is_tool_use_in_progress and not tool_use_completed:
		var interaction_feedback = player.get_node_or_null("InteractionFeedback")
		if interaction_feedback:
			interaction_feedback.hide_progress()
			
		# Re-enable movement
		var movement = player.get_node_or_null("PlayerMovement")
		if movement:
			movement.movement_disabled = false
		
		# Clear the tile usage
		if tool_use_position:
			var pos_key = str(tool_use_position.x) + "," + str(tool_use_position.z)
			if tiles_being_used.has(pos_key) and tiles_being_used[pos_key] == player:
				tiles_being_used.erase(pos_key)
	
	is_tool_use_in_progress = false
	tool_use_completed = false
	tool_use_position = null

# Clear references to a tool (called when a tool is destroyed)
func clear_tool_reference(tool_obj):
	var cleared = false
	
	if current_tool == tool_obj:
		print("Clearing reference to tool: " + str(tool_obj.name if is_instance_valid(tool_obj) else "unknown"))
		current_tool = null
		cleared = true
	
	if stored_tool == tool_obj:
		print("Clearing reference to stored tool: " + str(tool_obj.name if is_instance_valid(tool_obj) else "unknown"))
		stored_tool = null
		cleared = true
		
	return cleared

# Get parameter manager reference
func get_parameter_manager():
	var service_locator = get_node_or_null("/root/ServiceLocator")
	if service_locator and service_locator.has_method("get_service"):
		return service_locator.get_service("parameter_manager")
	return null
