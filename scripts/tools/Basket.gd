# scripts/tools/Basket.gd
class_name Basket
extends Tool

var contained_crops = {}  # Dictionary of crop_type: count

# Visual feedback variables
var slots_container: Node3D
var max_slots = 6  # Maximum number of slots to display

# References to crop icons (textures)
var crop_icons = {
	"carrot": preload("res://assets/textures/crops/carrot_icon.png"),
	"tomato": preload("res://assets/textures/crops/tomato_icon.png")
}

# Fallback colors for crops without icons
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
	
# Remove specific crop types (for order fulfillment)
func remove_crops(crop_type: String, amount: int) -> int:
	if not contained_crops.has(crop_type) or contained_crops[crop_type] < amount:
		return 0
		
	contained_crops[crop_type] -= amount
	
	# Remove entry if zero
	if contained_crops[crop_type] <= 0:
		contained_crops.erase(crop_type)
	
	# Update visual appearance
	update_appearance()
	
	return amount
	
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

# Create a billboard sprite for a crop
func create_crop_sprite(crop_type: String) -> MeshInstance3D:
	# Create a quad mesh for the sprite
	var quad = QuadMesh.new()
	quad.size = Vector2(0.15, 0.15)  # Size of the icon
	
	# Create mesh instance
	var sprite = MeshInstance3D.new()
	sprite.mesh = quad
	
	# Create material with the crop icon
	var material = StandardMaterial3D.new()
	
	# Check if we have an icon for this crop type
	if crop_icons.has(crop_type) and crop_icons[crop_type] != null:
		# Use the icon texture
		material.albedo_texture = crop_icons[crop_type]
		material.albedo_color = Color(1, 1, 1, 1)  # White to show texture as is
	else:
		# Fallback to color if no icon available
		material.albedo_color = get_crop_color(crop_type)
	
	# Make it double-sided and unshaded for consistent visibility
	material.cull_mode = StandardMaterial3D.CULL_DISABLED
	material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	
	# Make it transparent (in case the texture has transparency)
	material.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	
	# Enable billboard mode on the MATERIAL (not the mesh)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	
	# Apply material
	sprite.material_override = material
	
	return sprite

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
	var slot_size = 0.15  # Size of each crop icon
	var spacing = 0.05    # Gap between icons
	var total_width = slot_count * (slot_size + spacing) - spacing
	var start_x = -total_width / 2 + slot_size / 2
	
	# Create a background panel for the slots
	if slot_count > 0:
		var panel = MeshInstance3D.new()
		panel.name = "SlotsPanel"
		
		# Create a slightly larger box for the background
		var panel_mesh = BoxMesh.new()
		var panel_width = total_width + 0.1
		panel_mesh.size = Vector3(panel_width, 0.2, 0.02)
		panel.mesh = panel_mesh
		
		# Create dark semi-transparent material
		var panel_material = StandardMaterial3D.new()
		panel_material.albedo_color = Color(0.1, 0.1, 0.1, 0.7)
		panel_material.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
		panel.material_override = panel_material
		
		slots_container.add_child(panel)
	
	# Add each crop icon
	for i in range(slot_count):
		var crop_type = displayed_crops[i]
		var x_pos = start_x + i * (slot_size + spacing)
		
		# Create crop sprite
		var crop_sprite = create_crop_sprite(crop_type)
		crop_sprite.name = "Crop" + str(i)
		
		# Position slightly in front of the panel
		crop_sprite.position = Vector3(x_pos, 0, 0.03)
		
		slots_container.add_child(crop_sprite)
	
	# If we have more crops than slots, add an indicator
	if all_crops.size() > max_slots:
		var more_indicator = Node3D.new()
		more_indicator.name = "MoreIndicator"
		more_indicator.position = Vector3(total_width/2 + slot_size + spacing, 0, 0)
		
		# Create three dots for "..." indicator
		for j in range(3):
			var dot = MeshInstance3D.new()
			var sphere = SphereMesh.new()
			sphere.radius = 0.025
			sphere.height = 0.05
			dot.mesh = sphere
			
			# Position dots horizontally
			dot.position = Vector3(j * 0.05, 0, 0.03)
			
			# White material
			var dot_material = StandardMaterial3D.new()
			dot_material.albedo_color = Color(1, 1, 1)
			dot.material_override = dot_material
			
			more_indicator.add_child(dot)
		
		slots_container.add_child(more_indicator)

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

# Helper function to get a text summary of current crops
func get_crops_summary() -> String:
	var summary = ""
	var crop_types = contained_crops.keys()
	
	for i in range(crop_types.size()):
		var crop_type = crop_types[i]
		var count = contained_crops[crop_type]
		
		summary += str(count) + " " + crop_type
		
		# Add comma or "and" for readability
		if i < crop_types.size() - 2:
			summary += ", "
		elif i == crop_types.size() - 2:
			summary += " and "
	
	return summary

func use(target_position):
	
	var level_manager = get_node("/root/Main/LevelManager")
	
	# First check for harvestable plants at this position
	var found_harvestable_plant = false
	
	# Check both groups to be safe
	for group in ["plants", "interactables"]:
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
					
					found_harvestable_plant = true
					return true
	
	if found_harvestable_plant:
		return true
		
	# Check if we're at a delivery tile with crops (original logic)
	if get_total_crops() > 0:
		if level_manager.is_tile_type(target_position, level_manager.TileType.DELIVERY):
			
			return true
	
	
	return false

func _effect_harvest_crop(target_position):
	
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

func _effect_deliver_crop(target_position: Vector3i) -> bool:
	var level_manager = get_node_or_null("/root/Main/LevelManager")
	if not level_manager: return false

	if level_manager.is_tile_type(target_position, level_manager.TileType.DELIVERY) or \
	   level_manager.is_tile_type(target_position, level_manager.TileType.DELIVERY_EXPRESS):

		var total_items = get_total_crops()
		if total_items == 0:
			print("Basket: Nothing to deliver.")
			return false

		# --- UPDATED SCORING LOGIC ---
		var score = 0
		# Get GameDataManager for adding stats
		var gdm = get_node_or_null("/root/Main/GameDataManager") # Or use ServiceLocator

		# Calculate base score using CropRegistry
		for crop_type in self.contained_crops:
			var quantity = self.contained_crops[crop_type]
			# Use the NEW static function from CropRegistry Autoload
			var value = CropRegistry.get_crop_score(crop_type)
			score += quantity * value

		# Optional: Apply quantity bonus
		if total_items > 1:
			var quantity_bonus_multiplier = 1.0 + (0.1 * (total_items - 1))
			score = int(score * quantity_bonus_multiplier)

		# Optional: Apply Express Delivery bonus
		var is_express = level_manager.is_tile_type(target_position, level_manager.TileType.DELIVERY_EXPRESS)
		if is_express:
			score = int(score * 1.15)
			print("Basket: Express delivery bonus applied!")

		# Add score to stats via GameDataManager
		if gdm:
			gdm.add_stat("total_score", score)
			print("Basket: Delivered crops for a score of: " + str(score))
		else:
			push_error("Basket: GameDataManager not found for adding score stat!")
		# --- END UPDATED SCORING LOGIC ---

		clear_crops()
		return true
	else:
		print("Basket: Not a delivery tile.")
		return false

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
