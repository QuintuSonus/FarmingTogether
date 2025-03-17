# Tool.gd - Base class for all tools
extends Node3D

class_name Tool

# Tool properties
@export var tool_name: String = "Generic Tool"
@export var tool_description: String = "A generic tool"
@export var tool_icon: Texture
@export var interaction_time: float = 0.0  # Time in seconds to complete interaction (0 = instantaneous)

# For progress-based interactions
var interaction_progress: float = 0.0
var is_in_use: bool = false
var using_player = null

# Tool state
var is_on_ground: bool = true
var is_held: bool = false

# Visual components
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var interaction_area: Area3D = $InteractionArea

# Called when the node enters the scene tree for the first time
func _ready():
	# Make sure we're in the interactable group
	add_to_group("interactable")
	
	# Connect interaction area signals
	if interaction_area:
		# Make sure the Area3D has signals connected
		if not interaction_area.is_connected("body_entered", _on_interaction_area_body_entered):
			interaction_area.connect("body_entered", _on_interaction_area_body_entered)
		
		# Set collision properties
		interaction_area.collision_layer = 2  # Layer 2 (Interactable)
		interaction_area.collision_mask = 1   # Layer 1 (Player)
	else:
		# Try to find the interaction area if it wasn't set
		interaction_area = find_child("InteractionArea")
		if interaction_area:
			print("Found interaction area:", interaction_area.name)
			if not interaction_area.is_connected("body_entered", _on_interaction_area_body_entered):
				interaction_area.connect("body_entered", _on_interaction_area_body_entered)
			
			# Set collision properties
			interaction_area.collision_layer = 2  # Layer 2 (Interactable)
			interaction_area.collision_mask = 1   # Layer 1 (Player)
		else:
			push_error("Tool is missing InteractionArea! Create an Area3D child named 'InteractionArea'")
	
	# Try to find mesh instance if it wasn't set
	if not mesh_instance:
		mesh_instance = find_child("MeshInstance3D")
		if not mesh_instance:
			push_error("Tool is missing MeshInstance3D! Create a MeshInstance3D child")
	
	# Set initial state
	set_on_ground(true)
	
	print("Tool initialized: ", tool_name)

# Called every frame
func _process(delta):
	# Handle progress-based interactions
	if is_in_use and interaction_time > 0:
		# Update progress
		interaction_progress += delta / interaction_time
		
		# Check if interaction is complete
		if interaction_progress >= 1.0:
			# Complete the interaction
			complete_use()
			
		# Update visual feedback (progress bar, etc.)
		update_interaction_visual()

# Can this tool be interacted with
func can_interact() -> bool:
	return is_on_ground or is_held

# Handle interaction with the tool (picking up/dropping)
func interact(player):
	if is_on_ground:
		# Tool is on the ground, pick it up
		pick_up(player)
	else:
		# Tool is held, drop it
		drop()

# Pick up the tool
func pick_up(player):
	# Remove from original parent
	var original_parent = get_parent()
	if original_parent:
		original_parent.remove_child(self)
	
	# Add to player
	player.add_child(self)
	
	# Update player's reference to current tool
	player.current_tool = self
	
	# Update tool state
	is_on_ground = false
	is_held = true
	
	# Position on player (can be overridden by specific tools)
	position = Vector3(0, 0.5, 0)
	rotation = Vector3(0, 0, 0)
	
	# Disable collision while held
	if interaction_area:
		interaction_area.monitoring = false
		interaction_area.monitorable = false
	
	# Notify
	print("Picked up: ", tool_name)

# Drop the tool
func drop():
	if is_held and get_parent() is CharacterBody3D:
		var player = get_parent()
		
		# Remove from player
		player.remove_child(self)
		
		# Add to the level
		var level = player.get_parent()
		if level:
			level.add_child(self)
			
			# Place in front of player
			global_position = player.global_position - player.global_transform.basis.z * 1.0
			global_position.y = 0.1  # Slightly above ground
			
			# Reset rotation (face up)
			rotation = Vector3(0, 0, 0)
		
		# Update player's reference to current tool
		player.current_tool = null
		
		# Update tool state
		is_on_ground = true
		is_held = false
		
		# Enable collision for pickup
		if interaction_area:
			interaction_area.monitoring = true
			interaction_area.monitorable = true
		
		# Notify
		print("Dropped: ", tool_name)

# Set tool on the ground state
func set_on_ground(on_ground: bool):
	is_on_ground = on_ground
	is_held = not on_ground
	
	# Adjust visual appearance when on ground vs held
	if on_ground:
		# Typical on-ground appearance (can be overridden)
		if mesh_instance:
			mesh_instance.rotation = Vector3(0, 0, 0)
	else:
		# Typical held appearance (can be overridden)
		if mesh_instance:
			mesh_instance.rotation = Vector3(0, 0, 0)
	
	# Enable/disable collision based on state
	if interaction_area:
		interaction_area.monitoring = on_ground
		interaction_area.monitorable = on_ground

# Begin using the tool
func begin_use(player, target_position):
	# Only allow usage if the tool is held
	if not is_held or not player:
		return false
	
	# Store using player for later reference
	using_player = player
	
	# If this is a progress-based interaction
	if interaction_time > 0:
		is_in_use = true
		interaction_progress = 0.0
		
		# Disable player movement during interaction
		if player.has_method("set_input_enabled"):
			player.set_input_enabled(false)
		
		return true
	else:
		# Instantaneous interaction, complete immediately
		return perform_action(player, target_position)

# Cancel the current tool usage
func cancel_use():
	if is_in_use:
		is_in_use = false
		interaction_progress = 0.0
		
		# Re-enable player movement
		if using_player and using_player.has_method("set_input_enabled"):
			using_player.set_input_enabled(true)
		
		using_player = null
		
		# Reset visual feedback
		update_interaction_visual()

# Complete the current tool usage
func complete_use():
	if is_in_use and using_player:
		is_in_use = false
		interaction_progress = 0.0
		
		# Perform the actual action
		perform_action(using_player, using_player.current_grid_position)
		
		# Re-enable player movement
		if using_player.has_method("set_input_enabled"):
			using_player.set_input_enabled(true)
		
		using_player = null
		
		# Reset visual feedback
		update_interaction_visual()

# Perform the tool's action (to be overridden by specific tools)
func perform_action(player, target_position):
	# Base implementation does nothing
	print("Using tool: ", tool_name)
	return true

# Update visual feedback for interaction progress
func update_interaction_visual():
	# This would be implemented in specific tool classes
	# or could show a generic progress bar above the player
	pass

# Called when a body enters the interaction area
func _on_interaction_area_body_entered(body):
	if body is CharacterBody3D:  # Assuming player is a CharacterBody3D
		print(tool_name, " detected player in interaction area")

# Use the tool on a specific grid position
func use(player, grid_position):
	begin_use(player, grid_position)
