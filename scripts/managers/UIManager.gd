# scripts/managers/UIManager.gd (MODIFIED)
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
	game_ui_elements.clear()
	game_ui_visibility_states.clear()
	if ui_layer:
		for child in ui_layer.get_children():
			# Skip debug buttons or editor UI
			if "Debug" not in child.name and child.name != "EditorUI":
				game_ui_elements.append(child)

	# Explicitly add specific UI roots if needed (e.g., OrderUI, LevelDisplay)
	var order_ui = ui_layer.get_node_or_null("OrderUI")
	if order_ui and not game_ui_elements.has(order_ui): game_ui_elements.append(order_ui)
	var level_display = ui_layer.get_node_or_null("LevelDisplay")
	if level_display and not game_ui_elements.has(level_display): game_ui_elements.append(level_display)

	print("UIManager: Found " + str(game_ui_elements.size()) + " game UI elements")


# Show all gameplay UI elements
func show_gameplay_ui():
	if game_ui_elements.size() == 0: find_game_ui_elements()
	if ui_layer:
		for ui_element in game_ui_elements:
			if is_instance_valid(ui_element): # Check if node is still valid
				 # Basic check to avoid showing editor/debug elements if they ended up here
				if "editor" in ui_element.name.to_lower() or "debug" in ui_element.name.to_lower():
					continue
				ui_element.visible = true
		print("UIManager: Showed gameplay UI")


# Hide all gameplay UI elements
func hide_gameplay_ui():
	if game_ui_elements.size() == 0: find_game_ui_elements()
	game_ui_visibility_states.clear()
	for ui_element in game_ui_elements:
		if is_instance_valid(ui_element):
			 # Basic check to avoid hiding debug/editor elements if needed
			 # if "debug" in ui_element.name.to_lower() or "editor" in ui_element.name.to_lower():
			 #    continue
			game_ui_visibility_states[ui_element] = ui_element.visible
			ui_element.visible = false
	print("UIManager: Hid " + str(game_ui_visibility_states.size()) + " game UI elements")


# Restore visibility of game UI elements
func restore_game_ui():
	for ui_element in game_ui_visibility_states:
		if is_instance_valid(ui_element):
			ui_element.visible = game_ui_visibility_states[ui_element]
	game_ui_visibility_states.clear()
	print("UIManager: Restored game UI elements")

# --- REMOVED update_level_display function ---
# func update_level_display(...): ...
