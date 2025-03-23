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
	print("Plant.water() base method called - Stage: " + str(current_stage) + ", Is watered: " + str(is_watered))
	
	if current_stage == GrowthStage.SEED:
		print("  Plant is a seed and can be watered")
		is_watered = true
		current_stage = GrowthStage.GROWING
		print("  Updated state - Stage: " + str(current_stage) + ", Is watered: " + str(is_watered))
		update_appearance()
		return true
	else:
		print("  Cannot water - plant is not in SEED stage (current stage: " + str(current_stage) + ")")
	return false

func _on_spoil_timer_timeout():
	if current_stage == GrowthStage.HARVESTABLE:
		current_stage = GrowthStage.SPOILED
		update_appearance()

func update_appearance():
	# Update the mesh/material based on growth stage
	# This should be implemented in subclasses
	print("Plant.update_appearance() base method called - this should be overridden in subclasses")

# Helper function to check if a tool is a basket
func is_basket(tool_obj):
	# Multiple ways to identify a basket:
	# 1. Check if it's in the basket_tools group
	if tool_obj.is_in_group("basket_tools"):
		return true
	
	# 2. Check if it has the get_tool_type method and it returns "Basket"
	if tool_obj.has_method("get_tool_type") and tool_obj.get_tool_type() == "Basket":
		return true
	
	# 3. Check if it's an instance of the Basket class
	if tool_obj is Basket:
		return true
		
	return false

# Helper function to check if a tool is a watering can
func is_watering_can(tool_obj):
	# Similar checks for watering can
	if tool_obj.is_in_group("watering_can_tools"):
		return true
	
	if tool_obj.has_method("get_tool_type") and tool_obj.get_tool_type() == "WateringCan":
		return true
	
	if tool_obj is WateringCan:
		return true
		
	return false

# Interactable implementation
func can_interact(actor):
	# Debug info 
	var tool_info = "no tool"
	if actor.current_tool:
		tool_info = actor.current_tool.name
	
	print("Plant.can_interact() - Stage: " + str(current_stage) + ", Tool: " + tool_info)
	
	# Can only harvest if plant is harvestable and actor has basket
	if current_stage == GrowthStage.HARVESTABLE:
		var has_basket = actor.current_tool != null and is_basket(actor.current_tool)
		print("  Plant is HARVESTABLE. Has basket? " + str(has_basket))
		return has_basket
	
	# Can water if plant is a seed and actor has watering can
	elif current_stage == GrowthStage.SEED and not is_watered:
		var has_watering_can = actor.current_tool != null and is_watering_can(actor.current_tool)
		print("  Plant is unwatered SEED. Has watering can? " + str(has_watering_can))
		return has_watering_can
	
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
	print("Plant.interact() called with actor: " + str(actor.name))
	print("  Plant stage: " + str(current_stage) + ", Tool: " + str(actor.current_tool.name if actor.current_tool else "none"))
	
	if current_stage == GrowthStage.HARVESTABLE and actor.current_tool and is_basket(actor.current_tool):
		print("  Plant is harvestable and actor has basket")
		# Harvest the plant
		actor.current_tool.add_crop(crop_type)
		# Reset the tile
		var level_manager = actor.get_node("../LevelManager")
		level_manager.reset_soil_to_dirt(level_manager.world_to_grid(global_position))
		# Remove plant
		queue_free()
		return true
	elif current_stage == GrowthStage.SEED and not is_watered and actor.current_tool and is_watering_can(actor.current_tool):
		# Water the plant
		print("  Calling water() method from interact()")
		return water()
	return false

func set_highlighted(is_highlighted: bool):
	# Implement highlighting logic
	if is_highlighted:
		scale = Vector3(1.1, 1.1, 1.1)
	else:
		scale = Vector3.ONE
