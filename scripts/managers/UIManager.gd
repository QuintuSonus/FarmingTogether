# scripts/managers/UIManager.gd
class_name UIManager
extends Node

var ui_layer: CanvasLayer = null
var game_ui_elements = []
var game_ui_visibility_states = {}

func _ready():
	# Get reference to UI layer
	ui_layer = get_parent().get_node_or_null("UILayer")
	if not ui_layer:
		# Create it if it doesn't exist
		ui_layer = CanvasLayer.new()
		ui_layer.name = "UILayer"
		get_parent().add_child(ui_layer)
		print("UIManager: Created new UILayer")

# Get the UI layer
func get_ui_layer() -> CanvasLayer:
	return ui_layer

# Find and store references to game UI elements
func find_game_ui_elements():
	# Clear previous references
	game_ui_elements.clear()
	game_ui_visibility_states.clear()
	
	if ui_layer:
		# Add all direct UI children except debug buttons
		for child in ui_layer.get_children():
			# Skip any debug buttons or editor UI
			if "Debug" not in child.name and child.name != "EditorUI":
				game_ui_elements.append(child)
	
	# Specifically look for OrderUI which is a common gameplay UI element
	var order_ui = ui_layer.get_node_or_null("OrderUI")
	if order_ui and not game_ui_elements.has(order_ui):
		game_ui_elements.append(order_ui)
	
	print("UIManager: Found " + str(game_ui_elements.size()) + " game UI elements")

# Show all gameplay UI elements
func show_gameplay_ui():
	# Find UI elements if we haven't yet
	if game_ui_elements.size() == 0:
		find_game_ui_elements()
	
	if ui_layer:
		# Show all gameplay UI elements
		for ui_element in game_ui_elements:
			# Skip debug buttons in release builds
			if not OS.is_debug_build() and ("debug" in ui_element.name.to_lower() or "editor" in ui_element.name.to_lower()):
				continue
				
			# Skip the level editor UI if it somehow got added to UILayer
			if "editorui" in ui_element.name.to_lower():
				continue
				
			# Show all other UI elements
			ui_element.visible = true
		
		print("UIManager: Showed gameplay UI")

# Hide all gameplay UI elements
func hide_gameplay_ui():
	# Find UI elements if we haven't yet
	if game_ui_elements.size() == 0:
		find_game_ui_elements()
	
	# Store current visibility states and hide UI
	game_ui_visibility_states.clear()
	
	for ui_element in game_ui_elements:
		if is_instance_valid(ui_element):
			# Skip debug buttons
			if "debug" in ui_element.name.to_lower() or "editor" in ui_element.name.to_lower():
				continue
				
			game_ui_visibility_states[ui_element] = ui_element.visible
			ui_element.visible = false
	
	print("UIManager: Hid " + str(game_ui_visibility_states.size()) + " game UI elements")

# Restore visibility of game UI elements
func restore_game_ui():
	# Restore previous visibility states
	for ui_element in game_ui_visibility_states:
		if is_instance_valid(ui_element):
			ui_element.visible = game_ui_visibility_states[ui_element]
	
	# Clear the dictionary
	game_ui_visibility_states.clear()
	
	print("UIManager: Restored game UI elements")
	
func update_level_display(current_level: int, orders_completed: int = 0, required_orders: int = 0):
	print("UIManager: Updating level display with level: " + str(current_level))
	
	# Find the level display elements
	var level_label = ui_layer.get_node_or_null("/root/Main/UILayer/LevelDisplay/LevelLabel")
	if level_label:
		level_label.text = "Level " + str(current_level)
		print("Successfully updated level label to: Level " + str(current_level))
	else:
		print("ERROR: Could not find LevelLabel node")
	
	# Update required orders label if available
	var orders_label = ui_layer.get_node_or_null("/root/Main/UILayer/LevelDisplay/RequiredOrdersLabel")
	if orders_label:
		orders_label.text = "Complete " + str(orders_completed) + "/" + str(required_orders)
		print("Successfully updated orders label to: " + str(orders_completed) + "/" + str(required_orders))
	else:
		print("ERROR: Could not find RequiredOrdersLabel node")
