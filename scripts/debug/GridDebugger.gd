# scripts/debug/GridDebugger.gd
extends Node3D

@export var enabled: bool = true
@export var update_interval: float = 0.5  # How often to update labels

var level_manager = null
var labels = {}
var update_timer = 0

# Colors for different tile types
var type_colors = {
	0: Color(0.7, 0.7, 0.7),  # REGULAR_GROUND - Gray
	1: Color(0.6, 0.4, 0.2),  # DIRT_GROUND - Brown
	2: Color(0.4, 0.3, 0.1),  # SOIL - Dark Brown
	3: Color(0.2, 0.5, 1.0),  # WATER - Blue
	4: Color(0.4, 0.3, 0.3),  # MUD - Dark Gray
	5: Color(1.0, 0.8, 0.0)   # DELIVERY - Yellow/Gold
}

func _ready():
	if not enabled:
		return
		
	# Find the level manager
	level_manager = get_node_or_null("/root/Main/LevelManager")
	if not level_manager:
		level_manager = get_tree().get_root().find_child("LevelManager", true, false)
	
	if not level_manager:
		push_error("GridDebugger: Could not find LevelManager")
		return
	
	# Print grid info
	print("Grid dimensions: ", level_manager.level_width, "x", level_manager.level_height)
	
	# Print all tile states
	if level_manager.has_method("print_all_tile_states"):
		level_manager.print_all_tile_states()
	
	# Create debug labels for all tiles
	create_debug_labels()

func create_debug_labels():
	# Remove any existing labels
	for label in labels.values():
		label.queue_free()
	labels.clear()
	
	# Create new labels for all grid cells
	for x in range(level_manager.level_width):
		for z in range(level_manager.level_height):
			var pos = Vector3i(x, 0, z)
			var world_pos = level_manager.grid_to_world(pos)
			
			var label3d = Label3D.new()
			label3d.text = str(pos)
			label3d.position = world_pos + Vector3(0, 1.5, 0)  # Position above the tile
			label3d.pixel_size = 0.01
			label3d.font_size = 24
			label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			
			add_child(label3d)
			labels[pos] = label3d
	
	# Update label colors
	update_label_colors()

func update_label_colors():
	if not level_manager:
		return
		
	for pos in labels.keys():
		var label = labels[pos]
		var tile_type = level_manager.get_tile_type(pos)
		
		# Set color based on tile type
		if type_colors.has(tile_type):
			label.modulate = type_colors[tile_type]
		else:
			label.modulate = Color.WHITE
		
		# Update label text to show coordinates and type
		label.text = str(pos) + "\nType: " + str(tile_type)

func _process(delta):
	if not enabled or not level_manager:
		return
		
	# Update periodically
	update_timer += delta
	if update_timer >= update_interval:
		update_timer = 0
		update_label_colors()
