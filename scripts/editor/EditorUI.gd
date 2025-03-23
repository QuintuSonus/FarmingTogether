# scripts/editor/EditorUI.gd
extends Control

# Reference to parent editor
var level_editor = null

func _ready():
	# Get reference to parent editor
	level_editor = get_parent()
	
	# Set up default visibility
	visible = true  # Will be controlled by LevelEditor visibility

# Update the selected tile label
func update_selected_tile(tile_type: String):
	var label = $LeftPanel/VBoxContainer/SelectedTileLabel
	if label:
		label.text = "Selected: " + tile_type.capitalize()

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
	
	for button_name in tile_buttons:
		var button = find_child(button_name)
		if button and level_editor and level_editor.farm_data:
			var cost = level_editor.farm_data.get_tile_cost(tile_buttons[button_name])
			button.disabled = cost > currency
