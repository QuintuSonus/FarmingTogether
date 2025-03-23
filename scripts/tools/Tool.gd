# scripts/tools/Tool.gd
class_name Tool
extends RigidBody3D

# Properties
var original_parent = null
var original_freeze = false
var original_collision_layer = 0
var original_collision_mask = 0

# Tool capabilities (override in subclasses)
func get_capabilities() -> int:
	return ToolCapabilities.Capability.NONE

# Make sure tools are interactable
func _ready():
	add_to_group("interactables")
	set_collision_layer_value(2, true)
	freeze = false

# Interactable implementation for pickup
func can_interact(actor):
	# For pickup, we only check if the actor isn't already holding this tool
	if actor.has_method("get_current_tool"):
		return actor.get_current_tool() != self
	return true

func get_interaction_type():
	return Interactable.InteractionType.INSTANTANEOUS
	
# NEW METHOD: For tool usage - can be overridden in subclasses
func get_usage_interaction_type() -> int:
	return Interactable.InteractionType.INSTANTANEOUS
	
# NEW METHOD: For tool usage duration
func get_usage_duration() -> float:
	return 0.0

func get_interaction_prompt():
	return "Pick Up"
	
func get_priority():
	return 2.0  # Higher priority than other objects

func interact(actor, _progress = 1.0):
	if actor.has_method("pick_up_tool"):
		actor.pick_up_tool(self)
		return true
	return false

# NEW: Method to check if this tool can be used on a specific interactable
func can_use_on(interactable) -> bool:
	# If the interactable requires a specific capability
	if interactable.has_method("get_required_tool_capability"):
		var required_capability = interactable.get_required_tool_capability()
		if required_capability >= 0:
			return ToolCapabilities.has_capability(get_capabilities(), required_capability)
	return true

# NEW: Unified use method with target position
func use(target_position: Vector3i) -> bool:
	# Basic implementation, override in subclasses
	return false

# NEW: Complete the tool use action
func complete_use(target_position: Vector3i) -> bool:
	# Basic implementation, override in subclasses
	return false

# Optional visual feedback
func set_highlighted(is_highlighted: bool):
	# Implement highlighting logic (e.g., change material)
	pass
