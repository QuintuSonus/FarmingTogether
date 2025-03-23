# scripts/interaction/Interactable.gd
class_name Interactable
extends Node

# Interaction types
enum InteractionType {
	INSTANTANEOUS,  # Completes immediately
	PROGRESS_BASED  # Requires holding input
}

# Interaction requirements
enum InteractionRequirement {
	NONE,           # No special requirement
	REQUIRES_TOOL,  # Requires any tool
	REQUIRES_SPECIFIC_TOOL  # Requires specific tool capability
}

# Virtual methods to be implemented by interactable objects
func can_interact(actor) -> bool:
	return true  # Default implementation

func get_interaction_type() -> int:
	return InteractionType.INSTANTANEOUS

func get_interaction_duration() -> float:
	return 0.0  # Only relevant for PROGRESS_BASED

func get_interaction_prompt() -> String:
	return "Interact"

func get_required_tool_capability() -> int:
	return -1  # -1 means no specific capability required

func get_priority() -> float:
	return 1.0  # Higher value = higher priority

# The main interaction method - returns true if successful
func interact(actor, progress: float = 1.0) -> bool:
	return false  # Override in subclasses

# Optional visual feedback
func set_highlighted(is_highlighted: bool):
	pass  # Override in subclasses
