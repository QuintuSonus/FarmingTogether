# scripts/player/PlayerToolHandler.gd
class_name PlayerToolHandler
extends Node

# References
var player: CharacterBody3D = null
@onready var tool_holder = $"../ToolHolder"
@onready var back_tool_holder = $"../BackToolHolder" if $"..".has_node("BackToolHolder") else null

# Tool state
var current_tool = null
var stored_tool = null  # Second tool slot for tool belt upgrade
var is_tool_use_in_progress: bool = false
var tool_use_completed: bool = false
var tool_use_start_time: int = 0
var tool_use_position = null
var tool_use_duration: float = 0.0

# Static dictionary to track which tiles are being used by tools
static var tiles_being_used = {}

func _ready():
	# Create back tool holder if it doesn't exist but tool belt is active
	if tool_belt_enabled() and not back_tool_holder:
		create_back_tool_holder()

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

# Pick up a tool
func pick_up_tool(tool_obj):
	if not is_instance_valid(tool_obj):
		return
		
	# If we have a tool belt and already have a tool, store the current tool
	if current_tool and tool_belt_enabled() and not stored_tool:
		store_current_tool()
	elif current_tool:
		# First drop the current tool
		drop_tool()
	
	# Get the original parent to restore when dropping
	tool_obj.original_parent = tool_obj.get_parent()
	
	# Disable physics on the tool
	if tool_obj is RigidBody3D:
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
	if tool_obj.get_parent():
		tool_obj.get_parent().remove_child(tool_obj)
		
	if tool_holder:
		tool_holder.add_child(tool_obj)
		
		# Reset transform relative to holder
		tool_obj.position = Vector3.ZERO
		tool_obj.rotation = Vector3.ZERO
		
		# Store reference to current tool
		current_tool = tool_obj
	else:
		push_error("Player: ToolHolder node not found!")

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
		back_tool.position = Vector3.ZERO
		back_tool.rotation = Vector3.ZERO
		current_tool = back_tool
	
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
