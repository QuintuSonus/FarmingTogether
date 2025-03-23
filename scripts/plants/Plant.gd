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
var spoil_progress: float = 0.0
var is_watered: bool = false

# Simple 3D progress bars
var growth_bar: MeshInstance3D
var spoil_bar: MeshInstance3D
var growth_bar_container: Node3D
var spoil_bar_container: Node3D

# Called when the node enters the scene tree for the first time
# Plant.gd - Fix for _ready() function
func _ready():
	add_to_group("interactables")
	add_to_group("plants")
	# Set to interaction layer (2)
	set_collision_layer_value(2, true)
	
	# Set up progress bars
	setup_progress_bars()
	
	# EXPLICIT INITIALIZATION - Set initial stage
	current_stage = GrowthStage.SEED
	is_watered = false
	growth_progress = 0.0
	spoil_progress = 0.0
	
	# Update appearance based on initial stage
	call_deferred("update_appearance")
	
	# Update progress bar visibility
	update_progress_bar_visibility()
	
	# Debug output
	print("Plant initialized: " + crop_type + ", Stage: " + str(current_stage))

func setup_progress_bars():
	# Create containers for our progress bars
	growth_bar_container = Node3D.new()
	growth_bar_container.name = "GrowthBarContainer"
	growth_bar_container.position = Vector3(0, 0.7, 0)
	add_child(growth_bar_container)
	
	spoil_bar_container = Node3D.new()
	spoil_bar_container.name = "SpoilBarContainer"
	spoil_bar_container.position = Vector3(0, 0.8, 0)
	add_child(spoil_bar_container)
	
	# Create growth bar (green)
	growth_bar = create_simple_progress_bar(Color(0.2, 0.8, 0.2)) # Green
	growth_bar_container.add_child(growth_bar)
	
	# Create spoil bar (red)
	spoil_bar = create_simple_progress_bar(Color(0.9, 0.1, 0.1)) # Red
	spoil_bar_container.add_child(spoil_bar)
	
	# Initial visibility
	update_progress_bar_visibility()

# Helper method to create a simple 3D progress bar
func create_simple_progress_bar(color: Color) -> MeshInstance3D:
	# Create a mesh for the progress bar
	var bar_mesh = BoxMesh.new()
	bar_mesh.size = Vector3(1.0, 0.1, 0.05) # Width, height, depth
	
	# Create material with the specified color
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true # Make it glow
	material.emission = color
	material.emission_energy = 2.0
	
	# Create mesh instance
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = bar_mesh
	mesh_instance.material_override = material
	
	# Center the bar (so it grows from the middle)
	mesh_instance.position.x = 0
	
	# Set initial scale to 0 (empty)
	mesh_instance.scale.x = 0.0
	
	return mesh_instance

func _process(delta):
	# Only grow if watered
	if is_watered and current_stage == GrowthStage.GROWING:
		growth_progress += delta / growth_time
		
		# Update growth bar scale to show progress
		if growth_bar:
			growth_bar.scale.x = growth_progress
			
			# Make sure it's visible
			if growth_bar_container and not growth_bar_container.visible:
				growth_bar_container.visible = true
		
		# Update appearance periodically
		if Engine.get_frames_drawn() % 5 == 0:
			update_appearance()
		
		if growth_progress >= 1.0:
			# Plant is fully grown
			current_stage = GrowthStage.HARVESTABLE
			print("Plant at ", global_position, " is now HARVESTABLE!")
			
			# Update progress bar visibility
			update_progress_bar_visibility()
			
			# Update appearance
			update_appearance()
			
			# Start spoil timer and tracking
			start_spoil_timer()
	
	# Track spoiling progress if in harvestable stage
	if current_stage == GrowthStage.HARVESTABLE:
		spoil_progress += delta / spoil_time
		
		# Update spoil bar scale to show progress - starts at 1.0 and shrinks to 0
		if spoil_bar:
			spoil_bar.scale.x = 1.0 - spoil_progress
			
			# Make sure parent is visible
			if spoil_bar_container and not spoil_bar_container.visible:
				print("Forcing spoil bar visibility")
				spoil_bar_container.visible = true
		
		if spoil_progress >= 1.0:
			# Plant is now spoiled
			current_stage = GrowthStage.SPOILED
			print("Plant at ", global_position, " has SPOILED!")
			
			# Update progress bar visibility
			update_progress_bar_visibility()
			
			# Update appearance
			update_appearance()

func update_progress_bar_visibility():
	if growth_bar_container:
		growth_bar_container.visible = (current_stage == GrowthStage.GROWING)
		if current_stage == GrowthStage.GROWING:
			print("Made growth bar visible")
	
	if spoil_bar_container:
		spoil_bar_container.visible = (current_stage == GrowthStage.HARVESTABLE)
		if current_stage == GrowthStage.HARVESTABLE:
			print("Made spoil bar visible")

func start_spoil_timer():
	print("Starting spoil timer")
	spoil_progress = 0.0
	
	if spoil_bar:
		spoil_bar.scale.x = 1.0
	
	if spoil_bar_container:
		spoil_bar_container.visible = true
		print("Set spoil bar to visible")

func water():
	print("Plant.water() base method called - Stage: " + str(current_stage) + ", Is watered: " + str(is_watered))
	
	if current_stage == GrowthStage.SEED:
		print("  Plant is a seed and can be watered")
		is_watered = true
		current_stage = GrowthStage.GROWING
		growth_progress = 0.0
		
		# Update progress bar visibility
		update_progress_bar_visibility()
		
		print("  Updated state - Stage: " + str(current_stage) + ", Is watered: " + str(is_watered))
		update_appearance()
		return true
	else:
		print("  Cannot water - plant is not in SEED stage (current stage: " + str(current_stage) + ")")
	return false

func update_appearance():
	# Update the mesh/material based on growth stage
	# This should be implemented in subclasses
	print("Plant.update_appearance() base method called - this should be overridden in subclasses")

# Get required tool capability based on plant state
func get_required_tool_capability() -> int:
	match current_stage:
		GrowthStage.SEED:
			return ToolCapabilities.Capability.WATER_PLANTS if not is_watered else -1
		GrowthStage.HARVESTABLE:
			return ToolCapabilities.Capability.HARVEST_CROPS
	return -1

# Check if actor has a tool that can interact with this plant
func can_interact(actor):
	# Debug info with safer access to avoid crashes with freed tools 
	var tool_info = "no tool"
	if actor.current_tool and is_instance_valid(actor.current_tool):
		tool_info = actor.current_tool.name
	else:
		# Tool is no longer valid
		tool_info = "freed tool"
	
	print("Plant.can_interact() - Stage: " + str(current_stage) + ", Tool: " + tool_info)
	
	var required_capability = get_required_tool_capability()
	if required_capability < 0:
		return false
		
	if actor.current_tool and is_instance_valid(actor.current_tool) and actor.current_tool.has_method("get_capabilities"):
		var tool_capabilities = actor.current_tool.get_capabilities()
		return ToolCapabilities.has_capability(tool_capabilities, required_capability)
	
	return false

func get_interaction_type() -> int:
	return Interactable.InteractionType.INSTANTANEOUS

func get_interaction_prompt() -> String:
	match current_stage:
		GrowthStage.SEED:
			return "Water" if not is_watered else "Already Watered"
		GrowthStage.GROWING:
			return "Growing... " + str(int(growth_progress * 100)) + "%"
		GrowthStage.HARVESTABLE:
			var remaining = 100 - int(spoil_progress * 100)
			return "Harvest (Spoils in " + str(remaining) + "%)"
		GrowthStage.SPOILED:
			return "Spoiled"
	return "Interact"

func get_priority() -> float:
	return 1.0

func interact(actor, _progress = 1.0) -> bool:
	print("Plant.interact() called with actor: " + str(actor.name))
	
	# Check for valid tool with safer access
	var tool_name = "none"
	if actor.current_tool and is_instance_valid(actor.current_tool):
		tool_name = actor.current_tool.name
	else:
		tool_name = "freed tool"
	
	print("  Plant stage: " + str(current_stage) + ", Tool: " + str(tool_name))
	
	if current_stage == GrowthStage.HARVESTABLE and actor.current_tool and is_instance_valid(actor.current_tool) and actor.current_tool.has_method("get_capabilities") and ToolCapabilities.has_capability(actor.current_tool.get_capabilities(), ToolCapabilities.Capability.HARVEST_CROPS):
		print("  Plant is harvestable and actor has harvest capability")
		# Harvest the plant
		actor.current_tool.add_crop(crop_type)
		# Reset the tile
		var level_manager = actor.get_node("../LevelManager")
		level_manager.reset_soil_to_dirt(level_manager.world_to_grid(global_position))
		# Remove plant
		queue_free()
		return true
	elif current_stage == GrowthStage.SEED and not is_watered and actor.current_tool and is_instance_valid(actor.current_tool) and actor.current_tool.has_method("get_capabilities") and ToolCapabilities.has_capability(actor.current_tool.get_capabilities(), ToolCapabilities.Capability.WATER_PLANTS):
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
