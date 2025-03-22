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
	if is_interaction_in_progress:
		return
		
	var interactable = potential_interactable
	if not interactable:
		# If no interactable is found and we're holding a tool, drop it
		if actor and actor.has_method("drop_tool") and actor.current_tool:
			actor.drop_tool()
			return
			
	# Continue with normal interaction if there's an interactable
	if interactable:
		var interaction_type = interactable.get_interaction_type()
		
		if interaction_type == Interactable.InteractionType.INSTANTANEOUS:
			# Handle instantaneous interaction
			if interactable.interact(actor):
				emit_signal("interaction_completed", actor, interactable)
		else:
			# Start progress-based interaction
			current_interactable = interactable
			current_interaction_progress = 0.0
			is_interaction_in_progress = true
			emit_signal("interaction_started", actor, interactable)
		
func update_interaction(delta: float):
	if not is_interaction_in_progress or not current_interactable:
		return
		
	if not current_interactable.can_interact(actor):
		cancel_interaction()
		return
		
	var duration = current_interactable.get_interaction_duration()
	current_interaction_progress += delta / duration
	
	if current_interaction_progress >= 1.0:
		complete_interaction()
		
func cancel_interaction():
	if current_interactable:
		emit_signal("interaction_canceled", actor, current_interactable)
	
	is_interaction_in_progress = false
	current_interactable = null
	
func complete_interaction():
	if current_interactable:
		current_interactable.interact(actor, 1.0)
		emit_signal("interaction_completed", actor, current_interactable)
	
	is_interaction_in_progress = false
	current_interactable = null
