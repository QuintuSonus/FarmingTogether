# scripts/tools/SeedBagDispenser.gd
extends StaticBody3D

# Configuration
@export var seed_type: String = "carrot"
@export var cooldown_time: float = 3.0
@export var seed_bag_scene: PackedScene = null

# NEW: Mesh resources to assign to seed bags
@export var carrot_seed_mesh: PackedScene = null
@export var tomato_seed_mesh: PackedScene = null

# State
var can_dispense: bool = true
var cooldown_timer: float = 0.0

# References
@onready var label_3d = $Label3D

func _ready():
	# Add to group
	add_to_group("interactables")
	
	# Set default label text
	if label_3d:
		label_3d.text = seed_type.capitalize() + " Seeds"
	
	# Set default seed bag scene if not specified
	if not seed_bag_scene:
		seed_bag_scene = load("res://scenes/tools/SeedingBag.tscn")

func _process(delta):
	# Update cooldown timer
	if not can_dispense:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			can_dispense = true
			if label_3d:
				label_3d.text = seed_type.capitalize() + " Seeds"

# INTERACTION METHODS
func get_interaction_prompt() -> String:
	if can_dispense:
		return "Get " + seed_type.capitalize() + " Seeds"
	else:
		return "Wait..."

func get_interaction_type() -> int:
	return 0  # INSTANTANEOUS

func can_interact(actor) -> bool:
	# Check if actor already has a tool
	if actor.has_method("get_current_tool"):
		var current_tool = actor.get_current_tool()
		if current_tool != null:
			return false
	
	return can_dispense

func get_priority() -> float:
	return 1.0

func interact(actor) -> bool:
	if !can_dispense:
		return false
		
	# Create seed bag
	if seed_bag_scene:
		var bag = seed_bag_scene.instantiate()
		get_tree().current_scene.add_child(bag)
		
		# Set seed type
		bag.seed_type = seed_type
		
		# NEW: Assign the appropriate mesh resource
		if seed_type == "carrot" and carrot_seed_mesh != null:
			bag.carrot_seed_mesh = carrot_seed_mesh
		elif seed_type == "tomato" and tomato_seed_mesh != null:
			bag.tomato_seed_mesh = tomato_seed_mesh
			
		# Apply the mesh - ensure the method exists first
		if bag.has_method("apply_seed_mesh"):
			bag.apply_seed_mesh()
		
		# Position in front of dispenser
		var spawn_pos = global_position
		spawn_pos.y += 1.0  # Above the dispenser
		bag.global_position = spawn_pos
		
		# Have player pick it up
		if actor.has_method("pick_up_tool"):
			actor.pick_up_tool(bag)
		
		# Start cooldown
		can_dispense = false
		cooldown_timer = cooldown_time
		
		# Update label
		if label_3d:
			label_3d.text = "Reloading..."
		
		return true
	
	return false

# Set highlighted state
func set_highlighted(is_highlighted: bool):
	# Show/hide 3D label
	if label_3d:
		label_3d.visible = is_highlighted
