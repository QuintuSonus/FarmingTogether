# scripts/plants/Plant.gd
class_name Plant
extends StaticBody3D

enum GrowthStage {
	SEED,
	GROWING,
	HARVESTABLE,
	SPOILED
}

# Configuration
@export var crop_type: String = "carrot"
@export var growth_time: float = 20.0  # Seconds to grow
@export var spoil_time: float = 15.0  # Seconds until spoiled

# State
var current_stage = GrowthStage.SEED
var growth_progress: float = 0.0
var is_watered: bool = false

# Called when the node enters the scene tree for the first time
func _ready():
	add_to_group("interactables")
	add_to_group("plants")
	# Set to interaction layer (2)
	set_collision_layer_value(2, true)
	
	# Debug output
	print("Plant initialized: " + crop_type)

func _process(delta):
	# Only grow if watered
	if is_watered and current_stage == GrowthStage.GROWING:
		growth_progress += delta / growth_time
		
		# Log growing state periodically
		if Engine.get_frames_drawn() % 30 == 0:  # Log every 30 frames
			print("Plant at ", global_position, " - growing: ", 
				int(growth_progress * 100), "%, time left: ", 
				int((1.0 - growth_progress) * growth_time), "s")
		
		# Update appearance more frequently during growth
		if Engine.get_frames_drawn() % 5 == 0:  # Only update every 5 frames for performance
			update_appearance()
		
		if growth_progress >= 1.0:
			# Plant is fully grown
			current_stage = GrowthStage.HARVESTABLE
			print("Plant at ", global_position, " is now HARVESTABLE!")
			
			# Start spoil timer
			var timer = Timer.new()
			timer.wait_time = spoil_time
			timer.one_shot = true
			timer.timeout.connect(_on_spoil_timer_timeout)
			add_child(timer)
			timer.start()
			
			# Update appearance
			update_appearance()

func water():
	if current_stage == GrowthStage.SEED:
		is_watered = true
		current_stage = GrowthStage.GROWING
		update_appearance()
		return true
	return false

func _on_spoil_timer_timeout():
	if current_stage == GrowthStage.HARVESTABLE:
		current_stage = GrowthStage.SPOILED
		update_appearance()

func update_appearance():
	# Update the mesh/material based on growth stage
	# This should be implemented in subclasses
	push_warning("Plant.update_appearance() called on base class. This should be overridden in subclasses.")

# Interactable implementation
func can_interact(actor):
	# Can only harvest if plant is harvestable and actor has basket
	if current_stage == GrowthStage.HARVESTABLE:
		return actor.current_tool != null and actor.current_tool.get_class() == "Basket"
	# Can water if plant is a seed and actor has watering can
	elif current_stage == GrowthStage.SEED and not is_watered:
		return actor.current_tool != null and actor.current_tool.get_class() == "WateringCan"
	return false

func get_interaction_type():
	return Interactable.InteractionType.INSTANTANEOUS

func get_interaction_prompt():
	match current_stage:
		GrowthStage.SEED:
			return "Water" if not is_watered else "Already Watered"
		GrowthStage.GROWING:
			return "Growing..."
		GrowthStage.HARVESTABLE:
			return "Harvest"
		GrowthStage.SPOILED:
			return "Spoiled"
	return "Interact"

func interact(actor, _progress = 1.0):
	if current_stage == GrowthStage.HARVESTABLE and actor.current_tool and actor.current_tool.get_class() == "Basket":
		# Harvest the plant
		actor.current_tool.add_crop(crop_type)
		# Reset the tile
		var level_manager = actor.get_node("../LevelManager")
		level_manager.reset_soil_to_dirt(level_manager.world_to_grid(global_position))
		# Remove plant
		queue_free()
		return true
	elif current_stage == GrowthStage.SEED and not is_watered and actor.current_tool and actor.current_tool.get_class() == "WateringCan":
		# Water the plant
		return water()
	return false

func set_highlighted(is_highlighted: bool):
	# Implement highlighting logic
	pass
