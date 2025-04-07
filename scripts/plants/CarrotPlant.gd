# scripts/plants/CarrotPlant.gd
extends Plant

@onready var seed_mesh = $SeedMesh
@onready var growing_mesh = $GrowingMesh
@onready var leaves = $Leaves
@onready var water_particles = $WaterParticles if has_node("WaterParticles") else null

# Override the _ready function to set carrot-specific properties
func _ready():
	# Set carrot specific properties
	crop_type = "carrot"
	growth_time = 15.0  # Seconds to grow
	spoil_time = 15.0   # Seconds until spoiled
	
	# Call super._ready() after setting properties
	super._ready()
	
	# Make sure node references are valid
	if not seed_mesh:
		push_error("CarrotPlant: SeedMesh node not found!")
	if not growing_mesh:
		push_error("CarrotPlant: GrowingMesh node not found!")
	if not leaves:
		push_error("CarrotPlant: Leaves node not found!")


func _enter_tree():
	# Make sure only the appropriate meshes are visible on creation
	# We'll double-check in case the scene file has incorrect defaults
	if has_node("SeedMesh") and has_node("GrowingMesh") and has_node("Leaves"):
		$SeedMesh.visible = true
		$GrowingMesh.visible = false
		$Leaves.visible = false
		
# Override the update_appearance method to update the visual appearance
func update_appearance():
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

# Override the water method to add visual effects
func water():
	var result = super.water()  # Call the parent method
	
	if result and water_particles:
		water_particles.emitting = true
	
	return result
