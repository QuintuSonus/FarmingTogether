# scripts/editor/EditorUI.gd
extends Control

# Reference to parent editor
var level_editor = null

func _ready():
	# Get reference to parent editor
	level_editor = get_parent()
	
	# Set up default visibility
	visible = true  # Will be controlled by LevelEditor visibility
	
	# Connect reset button if it exists
	var reset_button = find_child("ResetProgressionButton")
	if reset_button:
		reset_button.connect("pressed", Callable(self, "_on_reset_progression_pressed"))

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
