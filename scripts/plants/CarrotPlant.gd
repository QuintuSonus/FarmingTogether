# scripts/plants/CarrotPlant.gd
extends Plant

@onready var seed_mesh = $SeedMesh
@onready var growing_mesh = $GrowingMesh
@onready var leaves = $Leaves
# Fix: Check if WaterParticles node exists to avoid errors
@onready var water_particles = $WaterParticles if has_node("WaterParticles") else null

# Override the _ready function to set carrot-specific properties
func _ready():
	# Set carrot specific properties
	crop_type = "carrot"
	growth_time = 20.0  # Seconds to grow
	spoil_time = 15.0   # Seconds until spoiled
	
	# IMPORTANT: Call super._ready() after setting properties
	# This ensures our plant is properly registered in groups
	super._ready()
	
	# Make sure we're in both groups
	add_to_group("plants")
	add_to_group("interactables")
	
	# Make interactable
	collision_layer = 2  # Set to interaction layer
	
	# Start with seed appearance
	update_appearance()
	
	print("CarrotPlant initialized! Position: ", global_position, 
		" Grid pos: ", get_node("/root/Main/LevelManager").world_to_grid(global_position))
		
	# Verify our node references
	if not seed_mesh:
		push_error("CarrotPlant: SeedMesh node not found!")
	if not growing_mesh:
		push_error("CarrotPlant: GrowingMesh node not found!")
	if not leaves:
		push_error("CarrotPlant: Leaves node not found!")

# Override the update_appearance method to update the visual appearance
func update_appearance():
	print("CarrotPlant.update_appearance() - Stage:", current_stage, ", Growth:", growth_progress)
	
	if not seed_mesh or not growing_mesh or not leaves:
		push_error("CarrotPlant.update_appearance: Missing node references!")
		return
		
	match current_stage:
		GrowthStage.SEED:
			seed_mesh.visible = true
			growing_mesh.visible = false
			leaves.visible = false
		
		GrowthStage.GROWING:
			seed_mesh.visible = false
			growing_mesh.visible = true
			leaves.visible = true
			
			# Adjust size based on growth progress
			var scale_factor = 0.3 + (growth_progress * 0.7)
			print("CarrotPlant: Growing - scale factor = ", scale_factor)
			growing_mesh.scale = Vector3(scale_factor, scale_factor, scale_factor)
			leaves.scale = Vector3(scale_factor, scale_factor, scale_factor)
		
		GrowthStage.HARVESTABLE:
			seed_mesh.visible = false
			growing_mesh.visible = true
			leaves.visible = true
			
			# Full size
			growing_mesh.scale = Vector3.ONE
			leaves.scale = Vector3.ONE
			
			print("CarrotPlant: Fully grown and harvestable!")
		
		GrowthStage.SPOILED:
			seed_mesh.visible = false
			growing_mesh.visible = true
			leaves.visible = true
			
			# Change color to indicate spoilage
			var spoiled_material = StandardMaterial3D.new()
			spoiled_material.albedo_color = Color(0.4, 0.3, 0.1) # Brownish color
			growing_mesh.set_surface_override_material(0, spoiled_material)
			
			for leaf in leaves.get_children():
				if leaf is CSGBox3D:
					var leaf_material = StandardMaterial3D.new()
					leaf_material.albedo_color = Color(0.3, 0.3, 0.1) # Yellowish-brown
					leaf.material = leaf_material
					
			print("CarrotPlant: Spoiled!")

# Override the water method to add visual effects
func water():
	print("CarrotPlant.water() called - Beginning watering process")
	var result = super.water()  # Call the parent method
	print("  Parent water() result: " + str(result))
	
	if result:
		print("  Plant was successfully watered!")
		# Fixed: Check for water_particles before using
		if water_particles:
			water_particles.emitting = true
			print("  Watering particles emitted!")
		else:
			print("  Note: WaterParticles node not found - skipping particle effect")
	else:
		print("  Plant could not be watered (already watered or wrong stage)")
	
	return result

# We also need to implement the set_highlighted method for the interaction system
func set_highlighted(is_highlighted: bool):
	if is_highlighted:
		# You could add a glow effect or change the material
		# For now, we'll just scale slightly to indicate highlighting
		scale = Vector3(1.1, 1.1, 1.1)
	else:
		scale = Vector3.ONE
