# scripts/editor/EditorUI.gd
extends Control

# Reference to parent editor
var level_editor = null

# Reference to game data
var game_data = null
var game_data_manager = null

func _ready():
	# Get reference to parent editor
	level_editor = get_parent()
	
	# Get game data references
	if level_editor && level_editor.game_data:
		game_data = level_editor.game_data
	else:
		# Fallback to service locator
		var service_locator = get_node_or_null("/root/ServiceLocator")
		if service_locator:
			game_data = service_locator.get_service("game_data")
			game_data_manager = service_locator.get_service("game_data_manager")
	
	# Set up default visibility
	visible = true  # Will be controlled by LevelEditor visibility
	
	# Connect tool buttons
	connect_tool_buttons()
	connect_tile_buttons()
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
	
	update_currency_display()
	# Set initial button visibility based on available tiles
	if level_editor and level_editor.has_method("get_available_tile_types"):
		var available_tiles = level_editor.get_available_tile_types()
		update_tile_buttons_visibility(available_tiles)
	
	print("EditorUI: Initialized and connected UI elements")

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

func connect_tile_buttons():
	print("EditorUI: Connecting all tile buttons")
	
	# Define mapping of all possible tile buttons
	var tile_buttons = {
		"RegularButton": "regular",
		"DirtButton": "dirt",
		"SoilButton": "soil", 
		"WaterButton": "water",
		"MudButton": "mud",
		"DeliveryButton": "delivery",
		"DirtFertileButton": "dirt_fertile",
		"DirtPreservedButton": "dirt_preserved",
		"DirtPersistentButton": "dirt_persistent", 
		"DeliveryExpressButton": "delivery_express",
		"SprinklerButton": "sprinkler"
	}
	
	# Connect each button
	var connected_count = 0
	for button_name in tile_buttons:
		var button = find_node_in_tabs(button_name)
		if button:
			# Disconnect existing connections to avoid duplicates
			if button.is_connected("pressed", Callable(self, "_on_tile_button_pressed")):
				button.disconnect("pressed", Callable(self, "_on_tile_button_pressed"))
				
			# Connect to our handler with the proper tile type parameter
			button.connect("pressed", Callable(self, "_on_tile_button_pressed").bind(tile_buttons[button_name]))
			connected_count += 1
	
	print("EditorUI: Connected " + str(connected_count) + " tile buttons")
	
# Handle tile button presses
func _on_tile_button_pressed(tile_type: String):
	print("EditorUI: Tile button pressed with tile_type: " + tile_type)
	
	# Call into level_editor to handle the logic
	if level_editor:
		level_editor.select_tile_type(tile_type)
		
		# Update UI elements
		update_selected_tile(tile_type)
	else:
		push_error("EditorUI: level_editor reference is null!")
		
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
		"RegularButton": "regular",
		"DirtButton": "dirt",
		"SoilButton": "soil", 
		"WaterButton": "water",
		"MudButton": "mud",
		"DeliveryButton": "delivery",
		"DirtFertileButton": "dirt_fertile",
		"DirtPreservedButton": "dirt_preserved",
		"DirtPersistentButton": "dirt_persistent", 
		"DeliveryExpressButton": "delivery_express",
		"SprinklerButton": "sprinkler"
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
		if button and level_editor:
			var cost = level_editor.get_tile_cost(tile_buttons[button_name])
			button.disabled = cost > currency
			
			# Update text to include cost
			button.text = tile_buttons[button_name].capitalize() + " Ground (" + str(cost) + ")"
	
	# Update tool buttons
	for button_name in tool_buttons:
		var button = find_node_in_tabs(button_name)
		if button and level_editor:
			var cost = level_editor.get_tool_cost(tool_buttons[button_name])
			button.disabled = cost > currency
			
			# Update text to include cost
			var display_name = tool_buttons[button_name].capitalize().replace("_", " ")
			button.text = display_name + " (" + str(cost) + ")"

# Update currency display and button states
func update_currency_display():
	var currency = 0
	if game_data and game_data.progression_data:
		currency = game_data.progression_data.currency
	
	update_currency(currency)
	update_button_states(currency)

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
	# Reset progression using the appropriate manager
	if game_data_manager and game_data_manager.has_method("reset_progression"):
		game_data_manager.reset_progression()
	elif level_editor and level_editor.has_method("reset_farm_progression"):
		level_editor.reset_farm_progression()
	
	# Update the UI
	update_currency_display()
	
	# Show confirmation message
	var popup = AcceptDialog.new()
	popup.title = "Reset Complete"
	popup.dialog_text = "Farm progression has been reset successfully."
	popup.dialog_hide_on_ok = true
	add_child(popup)
	popup.popup_centered()

# Add this method to handle cancellation
func _cancel_reset_progression():
	print("Farm reset canceled by user")
	
func update_tile_buttons_visibility(available_tiles = null):
	print("EditorUI: Updating tile buttons visibility")
	
	# If no available tiles list provided, get it from level_editor
	if available_tiles == null and level_editor and level_editor.has_method("get_available_tile_types"):
		available_tiles = level_editor.get_available_tile_types()
	
	if available_tiles == null:
		push_error("EditorUI: No available tiles list!")
		return
	
	# Define mapping between button names and tile types
	var button_to_tile_map = {
		"RegularButton": "regular",
		"DirtButton": "dirt",
		"SoilButton": "soil",
		"WaterButton": "water",
		"MudButton": "mud",
		"DeliveryButton": "delivery",
		"DirtFertileButton": "dirt_fertile",
		"DirtPreservedButton": "dirt_preserved",
		"DirtPersistentButton": "dirt_persistent",
		"DeliveryExpressButton": "delivery_express",
		"SprinklerButton": "sprinkler"
	}
	
	# Update buttons visibility and text
	var visible_count = 0
	
	for button_name in button_to_tile_map.keys():
		var button = find_node_in_tabs(button_name)
		if not button:
			print("Button not found: " + button_name)
			continue
			
		var tile_type = button_to_tile_map[button_name]
		
		# Check if this tile is available
		if available_tiles.has(tile_type):
			button.visible = true
			visible_count += 1
			
			# Update text to include cost
			var cost = 0
			if level_editor and level_editor.has_method("get_tile_cost"):
				cost = level_editor.get_tile_cost(tile_type)
				
			# Format display name nicely
			var display_name = tile_type.capitalize().replace("_", " ")
			button.text = display_name + " (" + str(cost) + ")"
		else:
			# Hide unavailable buttons
			button.visible = false
	
	print("EditorUI: Updated with " + str(visible_count) + " visible tile buttons")
