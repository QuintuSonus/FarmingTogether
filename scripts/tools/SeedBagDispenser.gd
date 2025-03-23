# scripts/tools/SeedBagDispenser.gd
class_name SeedBagDispenser
extends StaticBody3D

# Configuration
@export var seed_type: String = "carrot"
@export_file("*.tscn") var seed_bag_scene_path: String = "res://scenes/tools/SeedingBag.tscn"
var seed_bag_scene: PackedScene

# Visual properties
@onready var mesh_instance = $MeshInstance3D

func _ready():
	# Add to interactables group for player interaction
	add_to_group("interactables")
	
	# Load the seed bag scene
	seed_bag_scene = load(seed_bag_scene_path)
	if not seed_bag_scene:
		push_error("SeedBagDispenser: Failed to load seed bag scene from path: " + seed_bag_scene_path)
	
	# Update appearance based on seed type
	update_appearance()
	
	print("SeedBagDispenser initialized for crop type: " + seed_type)

# Update visual appearance based on seed type
func update_appearance():
	if not mesh_instance:
		return
		
	var material = StandardMaterial3D.new()
	
	# Set color based on seed type
	match seed_type.to_lower():
		"carrot":
			material.albedo_color = Color(1.0, 0.5, 0.0)  # Orange
		"tomato":
			material.albedo_color = Color(0.9, 0.1, 0.1)  # Red
		_:
			material.albedo_color = Color(0.8, 0.8, 0.1)  # Yellow default
			
	mesh_instance.material_override = material

# Interactable implementation
func can_interact(actor):
	return true

func get_interaction_type():
	return Interactable.InteractionType.INSTANTANEOUS
	
func get_interaction_prompt():
	return "Take " + seed_type.capitalize() + " Seeds"

func get_priority():
	return 1.0

func interact(actor, _progress = 1.0):
	# Create a new seed bag
	if not seed_bag_scene:
		push_error("SeedBagDispenser: Cannot create seed bag - scene not loaded")
		return false
		
	print("SeedBagDispenser: Creating new " + seed_type + " seed bag")
	
	var new_seed_bag = seed_bag_scene.instantiate()
	if not new_seed_bag:
		push_error("SeedBagDispenser: Failed to instantiate seed bag")
		return false
		
	# Configure the seed bag
	new_seed_bag.seed_type = seed_type
	
	# Set the appropriate plant scene path based on seed type
	match seed_type.to_lower():
		"carrot":
			new_seed_bag.plant_scene_path = "res://scenes/plants/CarrotPlant.tscn"
		"tomato":
			new_seed_bag.plant_scene_path = "res://scenes/plants/TomatoPlant.tscn"
	
	# Add it to the scene
	get_tree().root.add_child(new_seed_bag)
	
	# Position it at the dispenser
	new_seed_bag.global_position = global_position + Vector3(0, 1, 0)
	
	# Give it to the player directly
	if actor.has_method("pick_up_tool"):
		actor.pick_up_tool(new_seed_bag)
		return true
	
	return false

# Highlight when player looks at it
func set_highlighted(is_highlighted: bool):
	if not mesh_instance:
		return
		
	if is_highlighted:
		mesh_instance.scale = Vector3(1.1, 1.1, 1.1)
	else:
		mesh_instance.scale = Vector3.ONE
