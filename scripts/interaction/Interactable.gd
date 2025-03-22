# scripts/interaction/Interactable.gd
class_name Interactable
extends Node

# Constants for interaction types
enum InteractionType {
	INSTANTANEOUS,  # Completes immediately (picking up items, harvesting)
	PROGRESS_BASED  # Requires holding input (using hoe, planting)
}

# Virtual methods to be implemented by interactable objects
func can_interact(actor) -> bool:
	return true  # Default implementation

func get_interaction_type() -> int:
	return InteractionType.INSTANTANEOUS  # Default type

func get_interaction_duration() -> float:
	return 0.0  # Only relevant for PROGRESS_BASED

func get_interaction_prompt() -> String:
	return "Interact"  # UI prompt text

func get_priority() -> float:
	return 1.0  # Higher value = higher priority when multiple interactables are available

func interact(actor, progress: float = 1.0) -> bool:
	return false  # Return true if successful, override in subclasses
