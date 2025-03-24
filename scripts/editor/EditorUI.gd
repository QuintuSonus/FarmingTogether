# scripts/editor/EditorUI.gd
extends Control

# Reference to parent editor
var level_editor = null

func _ready():
	# Get reference to parent editor
	level_editor = get_parent()
	
	# Set up default visibility
	visible = true  # Will be controlled by LevelEditor visibility
	
	# Connect tool buttons
	connect_tool_buttons()
	
	# Connect reset button if it exists
	var reset_button = find_child("ResetProgressionButton")
	if reset_button:
		reset_button.connect("pressed", Callable(self, "_on_reset_progression_pressed"))
		
	# Connect remove tool button
	var remove_tool_button = find_node_in_tabs("RemoveToolButton")
	if remove_tool_button:
		remove_tool_button.connect("pressed", Callable(self, "_on_remove_tool_pressed"))
		
	var start_button = find_child("StartButton")
	if start_button:
		start_button.text = "Start Next Level"
		start_button.connect("pressed", Callable(level_editor, "start_next_level"))

# Connect all tool buttons
func connect_tool_buttons():
	# Tool buttons
	var tool_buttons = {
		"HoeButton": "hoe",
		"WateringCanButton": "watering_can",
		"BasketButton": "basket",
		"CarrotSeedButton": "carrot_seeds",
		"TomatoSeedButton": "tomato_seeds",
	}
	
	for button_name in tool_buttons:
		var button = find_node_in_tabs(button_name)
		if button:
			button.connect("pressed", Callable(self, "_on_tool_button_pressed").bind(tool_buttons[button_name]))
			
# Helper to find nodes within tab containers
func find_node_in_tabs(node_name: String) -> Node:
	# Check in the TabContainer
	var tab_container = find_child("TabContainer")
	if tab_container:
		for tab in tab_container.get_children():
			var found_node = tab.find_child(node_name)
			if found_node:
				return found_node
	
	# If not found in tabs, try direct search
	return find_child(node_name)

# Update the selected tile label
func update_selected_tile(tile_type: String):
	var label = find_node_in_tabs("SelectedTileLabel")
	if label:
		label.text = "Selected: " + tile_type.capitalize()

# Update the selected tool label
func update_selected_tool(tool_type: String):
	var label = find_node_in_tabs("SelectedToolLabel")
	if label:
		label.text = "Selected: " + tool_type.capitalize().replace("_", " ")

# Update currency display
func update_currency(amount: int):
	var label = $TopPanel/CurrencyLabel
	if label:
		label.text = "Currency: " + str(amount)

# Disable buttons that can't be afforded
func update_button_states(currency: int):
	var tile_buttons = {
		"DirtButton": "dirt",
		"SoilButton": "soil", 
		"WaterButton": "water",
		"MudButton": "mud",
		"DeliveryButton": "delivery"
	}
	
	var tool_buttons = {
		"HoeButton": "hoe",
		"WateringCanButton": "watering_can",
		"BasketButton": "basket",
		"CarrotSeedButton": "carrot_seeds",
		"TomatoSeedButton": "tomato_seeds",
	}
	
	# Update tile buttons
	for button_name in tile_buttons:
		var button = find_node_in_tabs(button_name)
		if button and level_editor and level_editor.farm_data:
			var cost = level_editor.farm_data.get_tile_cost(tile_buttons[button_name])
			button.disabled = cost > currency
	
	# Update tool buttons
	for button_name in tool_buttons:
		var button = find_node_in_tabs(button_name)
		if button and level_editor and level_editor.farm_data:
			var cost = level_editor.farm_data.get_tool_cost(tool_buttons[button_name])
			button.disabled = cost > currency

# Handle tool button presses
func _on_tool_button_pressed(tool_type: String):
	if level_editor:
		level_editor.select_tool_type(tool_type)
		update_selected_tool(tool_type)

# Handle remove tool button
func _on_remove_tool_pressed():
	if level_editor:
		level_editor.select_tool_type("remove_tool")
		update_selected_tool("Remove Tool")

func _on_reset_progression_pressed():
	# Show confirmation dialog
	var dialog = ConfirmationDialog.new()
	dialog.title = "Reset Progression"
	dialog.dialog_text = "Are you sure you want to reset all progression?\nThis will delete your farm layout and reset your currency.\nThis cannot be undone!"
	dialog.dialog_hide_on_ok = true
	dialog.size = Vector2(400, 150)
	
	# Connect dialog signals
	dialog.confirmed.connect(self._confirm_reset_progression)
	dialog.canceled.connect(self._cancel_reset_progression)
	
	# Add dialog to scene and show it
	add_child(dialog)
	dialog.popup_centered()

# Add this method to handle confirmation
func _confirm_reset_progression():
	# Actually do the reset
	if level_editor and level_editor.farm_data:
		level_editor.reset_farm_progression()

# Add this method to handle cancellation
func _cancel_reset_progression():
	print("Farm reset canceled by user")
