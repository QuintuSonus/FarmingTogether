# scripts/tools/Basket.gd
class_name Basket
extends Tool

var contained_crops = {}  # Dictionary of crop_type: count

# Visual feedback variables
@onready var slots_container = $SlotsContainer # Assuming SlotsContainer node exists as child
var max_slots = 6  # Maximum number of slots to display

# References to crop icons (textures) - Ensure paths are correct
var crop_icons = {
	"carrot": preload("res://assets/textures/crops/carrot_icon.png"),
	"tomato": preload("res://assets/textures/crops/tomato_icon.png")
	# Add other crop icons here
}

# Fallback colors for crops without icons
var crop_colors = {
	"carrot": Color(1.0, 0.5, 0.0),  # Orange for carrots
	"tomato": Color(0.9, 0.1, 0.1)   # Red for tomatoes
	# Add other crop colors here
}

func _ready():
	super._ready()
	print("Basket initialized")
	add_to_group("basket_tools")

	if not slots_container:
		slots_container = Node3D.new()
		slots_container.name = "SlotsContainer"
		slots_container.position = Vector3(0, 0.6, 0) # Initial position
		add_child(slots_container)
		print("Basket: Created SlotsContainer node.")

	update_appearance() # Calls update_slots

func _process(delta):
	var is_held = false
	var parent = get_parent()
	if parent and parent.name == "ToolHolder":
		is_held = true

	if slots_container: # Null check
		if is_held:
			slots_container.position = Vector3(0, 0.6, 0.1)
		else:
			slots_container.position = Vector3(0, 0.6, 0)

func get_tool_type():
	return "Basket"

func get_capabilities() -> int:
	return ToolCapabilities.Capability.HARVEST_CROPS | ToolCapabilities.Capability.DELIVER_ORDERS

func add_crop(crop_type: String):
	print("Basket: Adding crop: " + crop_type)
	var parameter_manager = get_parameter_manager() # Use helper function
	var capacity = 6 # Default
	if parameter_manager:
		capacity = int(parameter_manager.get_value("tool.basket.capacity", 6.0))

	if get_total_crops() >= capacity:
		print("Basket: Full! Cannot add more %s." % crop_type)
		return

	contained_crops[crop_type] = contained_crops.get(crop_type, 0) + 1
	update_appearance()
	print("Basket: Now contains %d / %d crops (%s: %d)" % [get_total_crops(), capacity, crop_type, contained_crops[crop_type]])

func get_crop_count(crop_type: String) -> int:
	return contained_crops.get(crop_type, 0)

func get_total_crops() -> int:
	var total = 0
	for count in contained_crops.values():
		total += count
	return total

func clear_crops():
	contained_crops.clear()
	update_appearance()
	print("Basket: Crops cleared.")

func remove_crops(crop_type: String, amount: int) -> int:
	var available = get_crop_count(crop_type)
	if available == 0: return 0
	var removed_amount = min(amount, available)
	contained_crops[crop_type] -= removed_amount
	if contained_crops[crop_type] <= 0:
		contained_crops.erase(crop_type)
	update_appearance()
	print("Basket: Removed %d %s." % [removed_amount, crop_type])
	return removed_amount

func update_appearance():
	update_slots()
	var mesh = find_child("MeshInstance3D", true, false)
	if mesh and mesh is MeshInstance3D:
		var material = StandardMaterial3D.new()
		if mesh.get_surface_override_material(0) and mesh.get_surface_override_material(0) is StandardMaterial3D:
			material = mesh.get_surface_override_material(0).duplicate()
		elif mesh.mesh and mesh.mesh.surface_get_material(0) and mesh.mesh.surface_get_material(0) is StandardMaterial3D:
			material = mesh.mesh.surface_get_material(0).duplicate()

		if get_total_crops() == 0:
			material.albedo_color = Color(0.474, 0.286, 0.198, 1)
		else:
			material.albedo_color = Color(0.55, 0.35, 0.25, 1)
		mesh.set_surface_override_material(0, material)

func create_crop_sprite(crop_type: String) -> MeshInstance3D:
	var quad = QuadMesh.new()
	quad.size = Vector2(0.15, 0.15)
	var sprite = MeshInstance3D.new()
	sprite.mesh = quad
	var material = StandardMaterial3D.new()
	var icon_texture = crop_icons.get(crop_type)
	if icon_texture != null and icon_texture is Texture2D:
		material.albedo_texture = icon_texture
		material.albedo_color = Color(1, 1, 1, 1)
	else:
		material.albedo_color = get_crop_color(crop_type)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.set_surface_override_material(0, material)
	return sprite

func update_slots():
	if not slots_container: return
	for child in slots_container.get_children():
		child.queue_free()
	var all_crops = []
	for crop_type in contained_crops:
		for i in range(contained_crops[crop_type]):
			all_crops.append(crop_type)
	var displayed_crops = all_crops.slice(0, min(all_crops.size(), max_slots))
	var slot_count = displayed_crops.size()
	if slot_count == 0: return
	var slot_size = 0.15
	var spacing = 0.05
	var total_width = slot_count * (slot_size + spacing) - spacing
	var start_x = -total_width / 2 + slot_size / 2
	var panel = MeshInstance3D.new()
	panel.name = "SlotsPanel"
	var panel_mesh = BoxMesh.new()
	var panel_width = total_width + 0.1
	panel_mesh.size = Vector3(panel_width, 0.2, 0.02)
	panel.mesh = panel_mesh
	var panel_material = StandardMaterial3D.new()
	panel_material.albedo_color = Color(0.1, 0.1, 0.1, 0.7)
	panel_material.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	panel.set_surface_override_material(0, panel_material)
	slots_container.add_child(panel)
	for i in range(slot_count):
		var crop_type = displayed_crops[i]
		var x_pos = start_x + i * (slot_size + spacing)
		var crop_sprite = create_crop_sprite(crop_type)
		crop_sprite.name = "Crop" + str(i)
		crop_sprite.position = Vector3(x_pos, 0, 0.03)
		slots_container.add_child(crop_sprite)
	if all_crops.size() > max_slots:
		var more_indicator = Node3D.new()
		more_indicator.name = "MoreIndicator"
		var indicator_x = start_x + slot_count * (slot_size + spacing)
		more_indicator.position = Vector3(indicator_x, 0, 0)
		for j in range(3):
			var dot = MeshInstance3D.new()
			var sphere = SphereMesh.new()
			sphere.radius = 0.025; sphere.height = 0.05
			dot.mesh = sphere
			dot.position = Vector3(j * 0.05, 0, 0.03)
			var dot_material = StandardMaterial3D.new()
			dot_material.albedo_color = Color(1, 1, 1)
			dot.set_surface_override_material(0, dot_material)
			more_indicator.add_child(dot)
		slots_container.add_child(more_indicator)

func get_crop_color(crop_type: String) -> Color:
	if crop_colors.has(crop_type):
		return crop_colors[crop_type]
	var hash_val = crop_type.hash()
	var hue = fposmod(float(hash_val) * 0.61803398875, 1.0)
	return Color.from_hsv(hue, 0.8, 0.9)

func get_crops_summary() -> String:
	var summary_parts = []
	for crop_type in contained_crops:
		summary_parts.append("%d %s" % [contained_crops[crop_type], crop_type.capitalize()])
	return ", ".join(summary_parts)


# --- CORRECTED MANAGER RETRIEVAL ---
# Helper function to get managers safely using ServiceLocator instance
func _get_managers() -> Dictionary:
	var managers = {"level": null, "game": null, "order": null}
	var service_locator = ServiceLocator.get_instance()
	if service_locator:
		if service_locator.has_service("level_manager"):
			managers.level = service_locator.get_service("level_manager")
		if service_locator.has_service("game_manager"):
			managers.game = service_locator.get_service("game_manager")
		if service_locator.has_service("order_manager"):
			managers.order = service_locator.get_service("order_manager")
	else:
		# Fallback to absolute paths if ServiceLocator not found
		print("Basket: ServiceLocator not found, falling back to absolute paths.")
		managers.level = get_node_or_null("/root/Main/LevelManager")
		managers.game = get_node_or_null("/root/Main") # Assuming GameManager is /root/Main
		managers.order = get_node_or_null("/root/Main/OrderManager")

	if not managers.level: push_error("Basket: LevelManager not found!")
	if not managers.game: push_error("Basket: GameManager not found!")
	if not managers.order: push_error("Basket: OrderManager not found!")

	return managers

# --- REINSTATED Harvest Logic ---
func _effect_harvest_crop(target_position: Vector3i):
	var managers = _get_managers()
	var level_manager = managers.level
	if not level_manager: return false

	var harvested = false
	for obj in get_tree().get_nodes_in_group("plants"):
		if obj is Plant and obj.current_stage == Plant.GrowthStage.HARVESTABLE:
			var plant_grid_pos = level_manager.world_to_grid(obj.global_position)
			if plant_grid_pos == target_position:
				print("Basket: Harvesting plant %s of type %s at %s" % [obj.name, obj.crop_type, str(target_position)])
				add_crop(obj.crop_type)
				level_manager.reset_soil_to_dirt(plant_grid_pos)
				obj.queue_free()
				harvested = true
				break

	if not harvested:
		print("Basket: No harvestable plant found at target position %s" % str(target_position))

	return harvested


# --- Delivery Logic (Using Corrected Manager Retrieval) ---
func _effect_deliver_crop(target_position: Vector3i):
	var managers = _get_managers()
	var level_manager = managers.level
	var game_manager = managers.game
	var order_manager = managers.order

	if not level_manager or not game_manager or not order_manager:
		push_error("Basket: Missing required manager references for delivery!")
		return # Cannot proceed

	var tile_type = level_manager.get_tile_type(target_position)
	var is_delivery_tile = (tile_type == level_manager.TileType.DELIVERY or tile_type == level_manager.TileType.DELIVERY_EXPRESS)

	if not is_delivery_tile:
		print("Basket: Target tile is not a delivery tile.")
		return # Interaction fails

	if get_total_crops() == 0:
		print("Basket: Nothing to deliver.")
		return # Nothing happens

	# --- Process Delivery ---
	var base_score_earned = 0
	var crop_scores = {}
	# Access GameData via GameManager correctly
	if game_manager.game_data and \
		game_manager.game_data.crop_base_scores != null and \
		typeof(game_manager.game_data.crop_base_scores) == TYPE_DICTIONARY:
		crop_scores = game_manager.game_data.crop_base_scores
	# Alternative if it's a direct variable and not meta:
	# elif game_manager.game_data and "crop_base_scores" in game_manager.game_data and \
	#      typeof(game_manager.game_data.crop_base_scores) == TYPE_DICTIONARY:
		#crop_scores = game_manager.game_data.crop_base_scores
	else:
		push_warning("Basket: Cannot find crop_base_scores in GameData!")
		crop_scores = {"carrot": 10, "tomato": 15} # Fallback

	for crop_type in contained_crops:
		var quantity = contained_crops[crop_type]
		var score_per_crop = crop_scores.get(crop_type, 0)
		base_score_earned += quantity * score_per_crop

	if base_score_earned > 0:
		# Call add_score on the GameManager instance
		if game_manager.has_method("add_score"):
			game_manager.add_score(base_score_earned)
			print("Basket: Added %d base score for delivered crops." % base_score_earned)
		else:
			push_warning("Basket: GameManager does not have add_score method!")

	var matching_order = null
	# Call check method on the OrderManager instance
	if order_manager.has_method("check_basket_for_exact_order_match"):
		matching_order = order_manager.check_basket_for_exact_order_match(self)

	if matching_order:
		print("Basket: Delivery matches Order %d." % matching_order.order_id)
		# Call register method on the OrderManager instance
		if order_manager.has_method("register_order_bonus"):
			var is_express = (tile_type == level_manager.TileType.DELIVERY_EXPRESS)
			order_manager.register_order_bonus(matching_order, self, is_express)
		else:
			push_warning("Basket: OrderManager missing register_order_bonus method!")
	else:
		print("Basket: Delivery did not match any specific order.")

	clear_crops()
	# Indicate the interaction effect was successful (delivery attempt happened)


# Helper to get ParameterManager (can use _get_managers or direct call)
func get_parameter_manager():
	var service_locator = ServiceLocator.get_instance()
	if service_locator and service_locator.has_service("parameter_manager"):
		return service_locator.get_service("parameter_manager")
	# Fallback
	var pm = get_node_or_null("/root/ParameterManager") # Assuming ParameterManager might be an autoload
	if not pm: push_warning("Basket: ParameterManager service/node not found.")
	return pm
