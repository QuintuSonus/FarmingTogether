# scripts/player/PlayerInteraction.gd
class_name PlayerInteraction
extends Node

# References
var player: CharacterBody3D = null 
var level_manager = null
@onready var interaction_manager = $"../InteractionManager"
@onready var interaction_feedback = $"../InteractionFeedback"

# Interaction state
var is_interacting: bool = false

func _ready():
	# Connect to interaction manager signals if available
	if interaction_manager:
		interaction_manager.connect("interaction_started", _on_interaction_started)
		interaction_manager.connect("interaction_completed", _on_interaction_completed)
		interaction_manager.connect("interaction_canceled", _on_interaction_canceled)
		interaction_manager.connect("potential_interactable_changed", _on_potential_interactable_changed)
	else:
		push_error("PlayerInteraction: InteractionManager not found!")

func set_level_manager(manager):
	level_manager = manager

# Called when the player starts interacting with something
func _on_interaction_started(actor, interactable):
	if actor != player or !is_instance_valid(interactable):
		return
		
	is_interacting = true
	
	if interactable.has_method("get_interaction_duration") and interaction_feedback:
		interaction_feedback.show_progress(0.0)
		
		# Disable movement during progress-based interactions
		if interactable.get_interaction_type() == 1: # 1 = PROGRESS_BASED
			var movement = player.get_node_or_null("PlayerMovement")
			if movement:
				movement.movement_disabled = true

# Called when an interaction is completed
func _on_interaction_completed(actor, interactable):
	if actor != player:
		return
		
	is_interacting = false
	
	if interaction_feedback:
		interaction_feedback.hide_progress()
	
	# Re-enable movement
	var movement = player.get_node_or_null("PlayerMovement")
	if movement:
		movement.movement_disabled = false

# Called when an interaction is canceled
func _on_interaction_canceled(actor, interactable):
	if actor != player:
		return
		
	is_interacting = false
	
	if interaction_feedback:
		interaction_feedback.hide_progress()
		
	# Re-enable movement
	var movement = player.get_node_or_null("PlayerMovement")
	if movement:
		movement.movement_disabled = false

# Called when the potential interactable changes
func _on_potential_interactable_changed(interactable):
	if !interaction_feedback:
		return
		
	if interactable and interactable.has_method("get_interaction_prompt"):
		interaction_feedback.show_prompt(interactable.get_interaction_prompt())
	else:
		interaction_feedback.hide_prompt()

# Update interaction progress
func update_interaction_progress(progress):
	if interaction_feedback:
		interaction_feedback.update_progress(progress)

# Start an interaction
func start_interaction():
	if interaction_manager and !is_interacting:
		interaction_manager.start_interaction()

# Cancel the current interaction
func cancel_interaction():
	if interaction_manager and is_interacting:
		interaction_manager.cancel_interaction()

# Check if the player can interact with something
func can_interact_with(object) -> bool:
	if !interaction_manager:
		return false
		
	if !object or !is_instance_valid(object):
		return false
		
	if !object.has_method("can_interact"):
		return false
		
	return object.can_interact(player)
