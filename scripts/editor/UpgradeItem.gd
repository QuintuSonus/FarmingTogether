# scripts/editor/UpgradeItem.gd
class_name UpgradeItem
extends MarginContainer

# References to UI elements
@onready var panel = $Panel
@onready var icon_rect = $HBoxContainer/IconContainer/IconRect
@onready var name_label = $HBoxContainer/VBoxContainer/HBoxContainer/NameLabel
@onready var level_label = $HBoxContainer/VBoxContainer/HBoxContainer/LevelLabel
@onready var description_label = $HBoxContainer/VBoxContainer/DescriptionLabel
@onready var cost_label = $HBoxContainer/CostLabel

# Upgrade data
var upgrade_id: String
var upgrade_data: UpgradeData
var current_level: int = 0
var max_level: int = 1
var cost: int = 0
var affordable: bool = true

# Styling
var default_style: StyleBoxFlat
var hover_style: StyleBoxFlat
var selected_style: StyleBoxFlat
var unaffordable_style: StyleBoxFlat

# State
var is_selected: bool = false

# Signals
signal upgrade_selected(upgrade_id, upgrade_data)

func _ready():
	# Connect signals
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Set up styles
	setup_styles()

func setup_styles():
	# Clone the default style for hover and selected states
	default_style = panel.get_theme_stylebox("panel").duplicate()
	
	# Hover style - slightly lighter
	hover_style = default_style.duplicate()
	hover_style.bg_color = Color(0.25, 0.25, 0.25, 1.0)
	
	# Selected style - highlighted
	selected_style = default_style.duplicate()
	selected_style.bg_color = Color(0.2, 0.3, 0.4, 1.0)
	selected_style.border_width_top = 2
	selected_style.border_width_bottom = 2
	selected_style.border_width_left = 2
	selected_style.border_width_right = 2
	selected_style.border_color = Color(0.3, 0.6, 1.0, 1.0)
	
	# Unaffordable style - grayed out
	unaffordable_style = default_style.duplicate()
	unaffordable_style.bg_color = Color(0.15, 0.15, 0.15, 0.5)

func initialize(upgrade: UpgradeData, level: int, player_currency: int):
	upgrade_id = upgrade.id
	upgrade_data = upgrade
	current_level = level
	max_level = upgrade.max_level
	cost = upgrade.cost
	
	# Update UI
	name_label.text = upgrade.name
	level_label.text = "Level: " + str(level) + "/" + str(max_level)
	description_label.text = upgrade.description
	cost_label.text = str(cost)
	
	# Check if affordable
	affordable = player_currency >= cost && level < max_level
	
	# Update visual state
	update_visual_state()
	
	# Load icon if available
	if upgrade.icon_path and ResourceLoader.exists(upgrade.icon_path):
		icon_rect.texture = load(upgrade.icon_path)
	else:
		# Use a default icon or hide it
		icon_rect.visible = false

func update_visual_state():
	# Apply appropriate style based on state
	if !affordable or current_level >= max_level:
		panel.add_theme_stylebox_override("panel", unaffordable_style)
		modulate.a = 0.7
	elif is_selected:
		panel.add_theme_stylebox_override("panel", selected_style)
		modulate.a = 1.0
	else:
		panel.add_theme_stylebox_override("panel", default_style)
		modulate.a = 1.0
	
	# Update level text color based on max level
	if current_level >= max_level:
		level_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		level_label.text = "MAXED"
	else:
		level_label.remove_theme_color_override("font_color")
		level_label.text = "Level: " + str(current_level) + "/" + str(max_level)
	
	# Update cost
	if current_level >= max_level:
		cost_label.text = "—"
	else:
		cost_label.text = str(cost)

func set_selected(selected: bool):
	is_selected = selected
	update_visual_state()

func _on_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Only allow selection if not maxed out
		if current_level < max_level:
			emit_signal("upgrade_selected", upgrade_id, upgrade_data)
			set_selected(true)

func _on_mouse_entered():
	if affordable and current_level < max_level and !is_selected:
		panel.add_theme_stylebox_override("panel", hover_style)

func _on_mouse_exited():
	if !is_selected:
		panel.add_theme_stylebox_override("panel", default_style)
