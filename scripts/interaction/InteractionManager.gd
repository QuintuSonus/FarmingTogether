# scripts/interaction/InteractionManager.gd
class_name InteractionManager
extends Node3D

# Configuration
@export var detection_frequency: float = 0.1
@export var max_detection_distance: float = 2.0
@export var detection_angle_degrees: float = 120.0

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

func _ready():
	# Setup detection timer
	var timer = Timer.new()
	timer.name = "DetectionTimer"
	timer.wait_time = detection_frequency
	timer.autostart = true
	timer.timeout.connect(_on_detection_timer_timeout)
	add_child(timer)
	
	# Get reference to parent (assumed to be the player)
	actor = get_parent()

func _on_detection_timer_timeout():
	# Only update potential interactable if not in interaction
	if not is_interaction_in_progress:
		var new_potential = get_best_interactable()
		if new_potential != potential_interactable:
			# Update highlighting
			if potential_interactable and potential_interactable.has_method("set_highlighted"):
				potential_interactable.set_highlighted(false)
				
			if new_potential and new_potential.has_method("set_highlighted"):
				new_potential.set_highlighted(true)
				
			potential_interactable = new_potential
			emit_signal("potential_interactable_changed", potential_interactable)

# Find the best interactable object in range
func get_best_interactable():
	var interactables = []
	var forward_dir = actor.global_transform.basis.z
	var interaction_angle_rad = deg_to_rad(detection_angle_degrees / 2)
	
	# Find all interactable objects
	for obj in get_tree().get_nodes_in_group("interactables"):
		if not obj is CollisionObject3D:
			continue
			
		var dir_to_obj = (obj.global_position - actor.global_position).normalized()
		var dot_product = forward_dir.dot(dir_to_obj)
		var distance = actor.global_position.distance_to(obj.global_position)
		
		# Check if within range and angle
		if distance <= max_detection_distance and dot_product > 0:
			var angle = acos(clamp(dot_product, -1.0, 1.0))
			if angle <= interaction_angle_rad:
				# Check if the object can be interacted with
				if obj.has_method("can_interact") and obj.can_interact(actor):
					# Calculate priority score
					var priority = obj.get_priority() if obj.has_method("get_priority") else 1.0
					priority *= (max_detection_distance - distance) / max_detection_distance
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

# Start an interaction with the current potential interactable
func start_interaction():
	if is_interaction_in_progress:
		return
		
	var interactable = potential_interactable
	if not interactable:
		return
	
	# Get interaction type
	var interaction_type = interactable.get_interaction_type() if interactable.has_method("get_interaction_type") else Interactable.InteractionType.INSTANTANEOUS
	
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

# Update interaction progress
func update_interaction(delta: float):
	if not is_interaction_in_progress or not current_interactable:
		return
		
	if not current_interactable.can_interact(actor):
		cancel_interaction()
		return
	
	var duration = 1.0
	if current_interactable.has_method("get_interaction_duration"):
		duration = current_interactable.get_interaction_duration()
	
	current_interaction_progress += delta / duration
	
	# Update UI
	if actor and actor.has_method("update_interaction_progress"):
		actor.update_interaction_progress(current_interaction_progress)
	
	if current_interaction_progress >= 1.0:
		complete_interaction()
		
# Cancel the current interaction
func cancel_interaction():
	if current_interactable:
		emit_signal("interaction_canceled", actor, current_interactable)
	
	is_interaction_in_progress = false
	current_interactable = null
	
# Complete the current interaction
func complete_interaction():
	if current_interactable:
		current_interactable.interact(actor, 1.0)
		emit_signal("interaction_completed", actor, current_interactable)
	
	is_interaction_in_progress = false
	current_interactable = null
