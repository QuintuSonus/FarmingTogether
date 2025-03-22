# scripts/plants/CarrotPlant.gd
extends Plant

@onready var seed_mesh = $SeedMesh
@onready var growing_mesh = $GrowingMesh
@onready var leaves = $Leaves

# Override the _ready function to set carrot-specific properties
func _ready():
	super._ready()
	
	# Set carrot specific properties
	crop_type = "carrot"
	growth_time = 20.0  # Seconds to grow
	spoil_time = 15.0   # Seconds until spoiled
	
	# Make interactable
	collision_layer = 2  # Set to interaction layer
	
	# Start with seed appearance
	update_appearance()

# Override the update_appearance method to update the visual appearance
func update_appearance():
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
			growing_mesh.scale = Vector3(scale_factor, scale_factor, scale_factor)
			leaves.scale = Vector3(scale_factor, scale_factor, scale_factor)
		
		GrowthStage.HARVESTABLE:
			seed_mesh.visible = false
			growing_mesh.visible = true
			leaves.visible = true
			
			# Full size
			growing_mesh.scale = Vector3.ONE
			leaves.scale = Vector3.ONE
		
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

# We also need to implement the set_highlighted method for the interaction system
func set_highlighted(is_highlighted: bool):
	if is_highlighted:
		# You could add a glow effect or change the material
		# For now, we'll just scale slightly to indicate highlighting
		scale = Vector3(1.1, 1.1, 1.1)
	else:
		scale = Vector3.ONE
