# scripts/interaction/InteractionManager.gd
class_name InteractionManager
extends Node3D

# Configuration
@export var detection_frequency: float = 0.1  # How often to update detected interactables
@export var max_detection_distance: float = 2.0
@export var detection_angle_degrees: float = 120.0
@export var interaction_layer: int = 2  # Physics layer for interactable objects

# State
var current_interactable = null
var potential_interactable = null
var current_interaction_progress: float = 0.0
var is_interaction_in_progress: bool = false
var actor = null
var current_action_name = ""

# Signals
signal interaction_started(actor, interactable)
signal interaction_completed(actor, interactable)
signal interaction_canceled(actor, interactable)
signal potential_interactable_changed(interactable)

# Called when the node enters the scene tree for the first time
func _ready():
	# Create a timer for periodic detection updates
	var timer = Timer.new()
	timer.name = "DetectionTimer"
	timer.wait_time = detection_frequency
	timer.autostart = true
	timer.timeout.connect(_on_detection_timer_timeout)
	add_child(timer)
	
	# Get reference to parent (assumed to be the player)
	actor = get_parent()

func _on_detection_timer_timeout():
	# Only update potential interactable if not in the middle of an interaction
	if not is_interaction_in_progress:
		var new_potential = get_best_interactable()
		
		if new_potential != potential_interactable:
			# Unhighlight old potential
			if potential_interactable != null and potential_interactable.has_method("set_highlighted"):
				potential_interactable.set_highlighted(false)
				
			# Highlight new potential
			if new_potential != null and new_potential.has_method("set_highlighted"):
				new_potential.set_highlighted(true)
				
			potential_interactable = new_potential
			emit_signal("potential_interactable_changed", potential_interactable)

func get_best_interactable():
	var interactables = []
	var forward_dir = actor.global_transform.basis.z  # Player's forward direction
	var interaction_angle_rad = deg_to_rad(detection_angle_degrees / 2)
	
	# Find all nodes in the "interactables" group
	for obj in get_tree().get_nodes_in_group("interactables"):
		# Skip if it's not in our interaction layer
		if not obj is CollisionObject3D or not obj.get_collision_layer_value(interaction_layer):
			continue
			
		var dir_to_obj = (obj.global_position - actor.global_position).normalized()
		var dot_product = forward_dir.dot(dir_to_obj)
		
		# Skip if it's behind the player (dot product < 0)
		if dot_product <= 0:
			continue
			
		var angle = acos(dot_product)
		var distance = actor.global_position.distance_to(obj.global_position)
		
		# Check if within range and angle
		if distance <= max_detection_distance and angle <= interaction_angle_rad:
			# Check if the object can be interacted with
			if obj.has_method("can_interact") and obj.can_interact(actor):
				var priority = obj.get_priority() if obj.has_method("get_priority") else 1.0
				
				# Distance factor: closer objects get higher priority
				priority *= (max_detection_distance - distance) / max_detection_distance
				
				# Angle factor: more directly in front gets higher priority
				priority *= (interaction_angle_rad - angle) / interaction_angle_rad
				
				interactables.append({
					"object": obj,
					"priority": priority
				})
	
	# Sort by priority (highest first)
	if interactables.size() > 0:
		interactables.sort_custom(func(a, b): return a.priority > b.priority)
		return interactables[0].object
	
	return null

func start_interaction(action_name: String = "interact"):
	print("InteractionManager: start_interaction called with action: ", action_name)
	
	# Store the action name for later use
	current_action_name = action_name
	
	if is_interaction_in_progress:
		print("InteractionManager: Interaction already in progress, ignoring")
		return
		
	var interactable = potential_interactable
	
	# Special case for "interact" action: if no interactable and player has tool, drop it
	if action_name == "interact" and (not interactable) and actor and actor.has_method("drop_tool") and actor.current_tool:
		print("InteractionManager: No interactable but player has tool, dropping tool")
		actor.drop_tool()
		return
	
	# Exit if no interactable found
	if not interactable:
		print("InteractionManager: No potential interactable found")
		return
	
	print("InteractionManager: Interacting with: ", interactable.name, " for action: ", action_name)
	
	# Don't use the interaction manager for "use_tool" actions
	# This is handled directly by the Player script
	if action_name == "use_tool":
		print("InteractionManager: Tool use action, letting Player script handle it")
		return
		
	# For interact actions (picking up tools, etc.)
	if action_name == "interact":
		var interaction_type = interactable.get_interaction_type()
		print("InteractionManager: Interaction type: ", interaction_type)
		
		if interaction_type == Interactable.InteractionType.INSTANTANEOUS:
			# Handle instantaneous interaction
			print("InteractionManager: Performing instantaneous interaction")
			if interactable.interact(actor):
				emit_signal("interaction_completed", actor, interactable)
		else:
			# Start progress-based interaction
			print("InteractionManager: Starting progress-based interaction")
			current_interactable = interactable
			current_interaction_progress = 0.0
			is_interaction_in_progress = true
			emit_signal("interaction_started", actor, interactable)
		
func update_interaction(delta: float):
	if not is_interaction_in_progress or not current_interactable:
		return
		
	if not current_interactable.can_interact(actor):
		print("InteractionManager: Can no longer interact, canceling")
		cancel_interaction()
		return
	
	var duration = 1.0
	if current_interactable.has_method("get_interaction_duration"):
		duration = current_interactable.get_interaction_duration()
	
	print("InteractionManager: Updating interaction progress: ", current_interaction_progress)
	current_interaction_progress += delta / duration
	
	# Update progress bar or other UI
	if actor and actor.has_method("update_interaction_progress"):
		actor.update_interaction_progress(current_interaction_progress)
	
	if current_interaction_progress >= 1.0:
		print("InteractionManager: Interaction complete")
		complete_interaction()
		
func cancel_interaction():
	if current_interactable:
		emit_signal("interaction_canceled", actor, current_interactable)
	
	is_interaction_in_progress = false
	current_interactable = null
	current_action_name = ""
	
func complete_interaction():
	if current_interactable:
		print("InteractionManager: Completing interaction with ", current_interactable.name, " for action: ", current_action_name)
		
		if current_action_name == "interact":
			# Handle normal interact action
			current_interactable.interact(actor, 1.0)
		
		emit_signal("interaction_completed", actor, current_interactable)
	else:
		print("InteractionManager: No current interactable to complete")
	
	is_interaction_in_progress = false
	current_interactable = null
	current_action_name = ""
