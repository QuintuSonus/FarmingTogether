# scripts/tools/Tool.gd
class_name Tool
extends RigidBody3D

# Properties to store original state when picked up
# Properties to store original state when picked up
var original_parent = null
var original_freeze = false
var original_collision_layer = 0
var original_collision_mask = 0

# Make sure tools are interactable
func _ready():
	add_to_group("interactables")
	# Set to interaction layer (2)
	set_collision_layer_value(2, true)
	
		# Set default physics properties
	freeze = false

func can_interact(actor):
	# Tools can always be picked up
	return true

func get_interaction_type():
	return Interactable.InteractionType.INSTANTANEOUS

func get_interaction_prompt():
	return "Pick Up"
	
func get_priority():
	return 2.0  # Higher priority than other objects

func interact(actor, _progress = 1.0):
	if actor.has_method("pick_up_tool"):
		actor.pick_up_tool(self)
		return true
	return false
	
# Optional method for visual feedback
func set_highlighted(is_highlighted: bool):
	# Implement highlighting logic (e.g., change material)
	pass
