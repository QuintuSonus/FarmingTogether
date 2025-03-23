# scripts/tools/Basket.gd
class_name Basket
extends Tool

var contained_crops = {}  # Dictionary of crop_type: count

# Visual feedback variables
var slots_container: Node3D
var max_slots = 6  # Maximum number of slots to display

# Color mapping for different crop types
var crop_colors = {
	"carrot": Color(1.0, 0.5, 0.0),  # Orange for carrots
	"tomato": Color(0.9, 0.1, 0.1)   # Red for tomatoes
}

func _ready():
	super._ready()
	print("Basket initialized")
	# Add to a special group to identify basket tools
	add_to_group("basket_tools")
	
	# Create visual slots container
	setup_slots_container()
	
	# Initial appearance
	update_appearance()

func setup_slots_container():
	# Create a container for all slots
	slots_container = Node3D.new()
	slots_container.name = "SlotsContainer"
	slots_container.position = Vector3(0, 0.5, 0)
	add_child(slots_container)
	
	# Initialize empty slots
	update_slots()

# Custom method to identify this as a basket
func get_tool_type():
	return "Basket"
	
func get_capabilities() -> int:
	return ToolCapabilities.Capability.HARVEST_CROPS | ToolCapabilities.Capability.DELIVER_ORDERS

func add_crop(crop_type: String):
	print("Basket: Adding crop: " + crop_type)
	if contained_crops.has(crop_type):
		contained_crops[crop_type] += 1
	else:
		contained_crops[crop_type] = 1
	
	# Update visual appearance
	update_appearance()
	print("Basket: Now contains " + str(get_total_crops()) + " crops")
	
func get_crop_count(crop_type: String) -> int:
	return contained_crops.get(crop_type, 0)
	
func get_total_crops() -> int:
	var total = 0
	for crop in contained_crops.values():
		total += crop
	return total
	
func clear_crops():
	contained_crops.clear()
	update_appearance()
	
func update_appearance():
	# Update the visual slots
	update_slots()
	
	# Update the mesh color to provide a subtle feedback
	var mesh = get_node_or_null("MeshInstance3D")
	if mesh:
		var material = StandardMaterial3D.new()
		
		if get_total_crops() == 0:
			# Empty basket - default brown
			material.albedo_color = Color(0.474108, 0.286657, 0.19824, 1)
		else:
			# Filled basket - slightly brighter brown
			material.albedo_color = Color(0.55, 0.35, 0.25, 1)
		
		mesh.material_override = material

# Update the slots to show current crop contents
func update_slots():
	# Clear existing slots
	for child in slots_container.get_children():
		child.queue_free()
	
	# Get a flattened list of all crops
	var all_crops = []
	for crop_type in contained_crops:
		for i in range(contained_crops[crop_type]):
			all_crops.append(crop_type)
	
	# Cap at max_slots
	var displayed_crops = all_crops.slice(0, min(all_crops.size(), max_slots))
	var slot_count = displayed_crops.size()
	
	# Create slots
	var slot_size = 0.12
	var spacing = 0.02
	var total_width = slot_count * (slot_size + spacing) - spacing
	var start_x = -total_width / 2 + slot_size / 2
	
	for i in range(slot_count):
		var crop_type = displayed_crops[i]
		var x_pos = start_x + i * (slot_size + spacing)
		
		# Create slot visual
		var slot = MeshInstance3D.new()
		slot.name = "Slot" + str(i)
		
		# Use a cube mesh for the slot
		var cube_mesh = BoxMesh.new()
		cube_mesh.size = Vector3(slot_size, slot_size, slot_size / 4)
		slot.mesh = cube_mesh
		
		# Position the slot
		slot.position = Vector3(x_pos, 0, 0)
		
		# Create material with crop color
		var material = StandardMaterial3D.new()
		material.albedo_color = get_crop_color(crop_type)
		material.emission_enabled = true
		material.emission = material.albedo_color * 0.5  # Subtle glow
		material.metallic = 0.2
		material.roughness = 0.6
		slot.material_override = material
		
		slots_container.add_child(slot)
	
	# If we have more crops than slots, add an indicator
	if all_crops.size() > max_slots:
		var more_indicator = MeshInstance3D.new()
		more_indicator.name = "MoreIndicator"
		
		# Use three small spheres as "..." indicator
		var parent = Node3D.new()
		parent.position = Vector3(total_width/2 + slot_size/2 + spacing, 0, 0)
		
		for j in range(3):
			var dot = MeshInstance3D.new()
			var sphere = SphereMesh.new()
			sphere.radius = slot_size / 8
			sphere.height = slot_size / 4
			dot.mesh = sphere
			
			# Position dots horizontally
			dot.position = Vector3(j * (slot_size/6), 0, 0)
			
			# White material
			var dot_material = StandardMaterial3D.new()
			dot_material.albedo_color = Color(1, 1, 1)
			dot.material_override = dot_material
			
			parent.add_child(dot)
		
		slots_container.add_child(parent)

# Get a color for a crop type
func get_crop_color(crop_type: String) -> Color:
	if crop_colors.has(crop_type):
		return crop_colors[crop_type]
	
	# Generate a consistent color for unknown crop types
	var hash_val = 0
	for c in crop_type:
		hash_val = ((hash_val << 5) - hash_val) + c.unicode_at(0)
	
	# Create a bright, saturated color
	var hue = abs(hash_val) % 360 / 360.0
	return Color.from_hsv(hue, 0.8, 0.9)

func use(target_position):
	print("Basket.use() called at position: " + str(target_position))
	var level_manager = get_node("/root/Main/LevelManager")
	
	# First check for harvestable plants at this position
	var found_harvestable_plant = false
	
	# Check both groups to be safe
	for group in ["plants", "interactables"]:
		for obj in get_tree().get_nodes_in_group(group):
			if obj is Plant and obj.current_stage == Plant.GrowthStage.HARVESTABLE:
				var plant_grid_pos = level_manager.world_to_grid(obj.global_position)
				print("Basket: Found harvestable plant at " + str(plant_grid_pos) + ", target is " + str(target_position))
				
				# Calculate direct grid position too
				var obj_direct_grid = Vector3i(
					int(floor(obj.global_position.x)),
					0,
					int(floor(obj.global_position.z))
				)
				
				if plant_grid_pos == target_position or obj_direct_grid == target_position:
					print("Basket: Position match - can harvest plant!")
					found_harvestable_plant = true
					return true
	
	if found_harvestable_plant:
		return true
		
	# Check if we're at a delivery tile with crops (original logic)
	if get_total_crops() > 0:
		if level_manager.is_tile_type(target_position, level_manager.TileType.DELIVERY):
			print("Basket: At delivery tile with crops - can deliver")
			return true
	
	print("Basket: Cannot use at this position")
	return false

func complete_use(target_position):
	print("Basket.complete_use() called at position: " + str(target_position))
	var level_manager = get_node("/root/Main/LevelManager")
	
	# First try to harvest any plants at this position
	var harvested = false
	
	for group in ["plants", "interactables"]:
		if harvested:
			break
			
		for obj in get_tree().get_nodes_in_group(group):
			if obj is Plant and obj.current_stage == Plant.GrowthStage.HARVESTABLE:
				var plant_grid_pos = level_manager.world_to_grid(obj.global_position)
				
				# Calculate direct grid position too
				var obj_direct_grid = Vector3i(
					int(floor(obj.global_position.x)),
					0,
					int(floor(obj.global_position.z))
				)
				
				if plant_grid_pos == target_position or obj_direct_grid == target_position:
					print("Basket: Harvesting plant " + obj.name + " of type " + obj.crop_type)
					add_crop(obj.crop_type)
					
					# Reset the tile
					level_manager.reset_soil_to_dirt(plant_grid_pos)
					
					# Remove the plant
					obj.queue_free()
					harvested = true
					return true
	
	# If we didn't harvest anything, try to deliver
	if level_manager.is_tile_type(target_position, level_manager.TileType.DELIVERY):
		print("Basket: At delivery tile")
		
		# Here we would check if the crops match an order
		# For now, just clear the basket if it has crops
		if get_total_crops() > 0:
			print("Basket: Delivering " + str(get_total_crops()) + " crops")
			clear_crops()
			return true
		else:
			print("Basket: Nothing to deliver")
	
	return false

func _process(delta):
	# Check if being held by player to adjust visuals position
	var player = get_node_or_null("/root/Main/Player")
	var is_held = false
	
	if player and player.has_method("get_current_tool"):
		is_held = player.get_current_tool() == self
	
	# Adjust slots position based on whether basket is held or on ground
	if is_held:
		slots_container.position = Vector3(0, 0.6, 0.1)  # Higher up and forward when held
	else:
		slots_container.position = Vector3(0, 0.6, 0)    # Directly above when on ground
