# scripts/debug/GridDebugger.gd
extends Node3D

@export var enabled: bool = true
@export var update_interval: float = 0.5  # How often to update labels

# --- REVISED: Use correct type hint ---
var level_manager: LevelManager = null
var labels = {} # Dictionary to store Label3D nodes, keyed by Vector3i position
var update_timer = 0

# Colors for different tile types (Ensure these match LevelManager's TileType enum)
var type_colors = {
	0: Color(0.7, 0.7, 0.7),  # REGULAR_GROUND - Gray
	1: Color(0.6, 0.4, 0.2),  # DIRT_GROUND - Brown
	2: Color(0.5, 0.3, 0.1),  # DIRT_FERTILE - Darker Brown
	3: Color(0.7, 0.5, 0.3),  # DIRT_PRESERVED - Lighter Brown
	4: Color(0.4, 0.25, 0.05), # DIRT_PERSISTENT - Very Dark Brown
	5: Color(0.4, 0.3, 0.1),  # SOIL - Dark Brown (Same as Fertile?)
	6: Color(0.2, 0.5, 1.0),  # WATER - Blue
	7: Color(0.4, 0.3, 0.3),  # MUD - Dark Gray
	8: Color(1.0, 0.8, 0.0),  # DELIVERY - Yellow/Gold
	10: Color(1.0, 0.9, 0.4), # DELIVERY_EXPRESS - Lighter Gold
	11: Color(0.5, 0.7, 1.0)  # SPRINKLER - Light Blue
}

func _ready():
	if not enabled:
		set_process(false) # Disable process if not enabled
		return

	# Find the level manager
	var lm_node = get_node_or_null("/root/Main/LevelManager")
	if lm_node is LevelManager:
		level_manager = lm_node
	else:
		lm_node = get_tree().get_root().find_child("LevelManager", true, false)
		if lm_node is LevelManager:
			level_manager = lm_node

	if not level_manager:
		push_error("GridDebugger: Could not find LevelManager node or it's not the expected type!")
		set_process(false) # Disable if LevelManager not found
		return

	# --- REVISED: Print actual bounds instead of width/height ---
	var actual_bounds = level_manager.get_actual_bounds()
	print("GridDebugger: Level Bounds: ", actual_bounds)

	# Print all tile states (optional, but good for comparison)
	if level_manager.has_method("print_all_tile_states"):
		level_manager.print_all_tile_states()

	# Create debug labels for all tiles within actual bounds
	create_debug_labels()

func create_debug_labels():
	if not level_manager: return # Should not happen if _ready check passed

	# Remove any existing labels
	for label in labels.values():
		if is_instance_valid(label): # Check if label still exists
			label.queue_free()
	labels.clear()

	# --- REVISED: Use actual bounds from LevelManager ---
	var actual_bounds = level_manager.get_actual_bounds()
	if actual_bounds.size.x == 0 or actual_bounds.size.y == 0:
		print("GridDebugger: No valid level bounds found, cannot create labels.")
		return

	print("GridDebugger: Creating labels within bounds: ", actual_bounds)

	# Iterate over the actual bounds
	for x in range(actual_bounds.position.x, actual_bounds.end.x):
		for z in range(actual_bounds.position.y, actual_bounds.end.y):
			var grid_pos = Vector3i(x, 0, z)

			# --- Check if LevelManager actually tracks this tile ---
			# Optional: Only create labels for tiles explicitly in tile_states
			# if not level_manager.tile_states.has(grid_pos):
			#	 continue

			var world_pos = level_manager.grid_to_world(grid_pos) # Use centered position

			var label3d = Label3D.new()
			# Text will be updated in update_label_colors
			label3d.position = world_pos + Vector3(0, 1.5, 0) # Position above the tile center
			label3d.pixel_size = 0.015 # Slightly larger for readability
			label3d.font_size = 18    # Smaller font size
			label3d.outline_modulate = Color.BLACK # Add black outline
			label3d.outline_size = 4
			label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED # Face camera

			add_child(label3d)
			labels[grid_pos] = label3d # Store using Vector3i key

	print("GridDebugger: Created ", labels.size(), " labels.")

	# Update label colors and text immediately
	update_label_colors()

func update_label_colors():
	if not level_manager: return

	for grid_pos in labels.keys():
		var label = labels[grid_pos]
		if not is_instance_valid(label): continue # Skip if label was somehow freed

		# --- REVISED: Use get_tile_type consistently ---
		# Get type, handling potential -1 for tiles outside tracked state
		var tile_type = level_manager.get_tile_type(grid_pos)

		# Default to white/empty text if type is invalid (-1)
		var type_text = "EMPTY"
		label.modulate = Color.GRAY

		if tile_type != -1:
			# Set color based on tile type using the dictionary
			label.modulate = type_colors.get(tile_type, Color.WHITE) # Default to white if type unknown

			# Get type name from enum for display
			if tile_type >= 0 and tile_type < level_manager.TileType.keys().size():
				type_text = level_manager.TileType.keys()[tile_type]
			else:
				type_text = "UNKNOWN("+str(tile_type)+")"

		# Update label text to show coordinates and type name
		label.text = "({x},{z})\n{type}".format({"x": grid_pos.x, "z": grid_pos.z, "type": type_text})


func _process(delta):
	if not enabled or not level_manager:
		return

	# Update periodically
	update_timer += delta
	if update_timer >= update_interval:
		update_timer = 0.0
		# Only update colors/text, no need to recreate labels
		update_label_colors()
