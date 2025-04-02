# scripts/debug/ToolAdjustmentHelper.gd
extends Node

# References
@onready var player = get_parent()

# Configuration
@export var enabled: bool = true
@export var adjustment_speed: float = 0.01
@export var rotation_speed: float = 0.01

# Currently selected tool for adjustment
var current_tool = null
var adjusting_position: bool = true  # If false, adjusting rotation

func _ready():
	if not enabled:
		set_process(false)
		set_process_input(false)
		return
	
	print("Tool Adjustment Helper active - Press G to toggle adjustment mode")
	print("Use Arrow keys to adjust position/rotation")
	print("Press S to save current values")

func _process(_delta):
	# Make sure we have a reference to the player and tool
	if not player or not player.has_method("get_current_tool"):
		return
	
	# Get the current tool
	var tool = player.get_current_tool()
	if tool != current_tool:
		current_tool = tool
		if current_tool:
			print("Now adjusting tool: " + str(current_tool.name))
			print("Position: " + str(current_tool.position))
			print("Rotation: " + str(current_tool.rotation))
		else:
			print("No tool selected")

func _input(event):
	if not current_tool:
		return
	
	# Toggle between position and rotation adjustment
	if event.is_action_pressed("ui_focus_next") or (event is InputEventKey and event.keycode == KEY_G and event.pressed):
		adjusting_position = !adjusting_position
		print("Now adjusting: " + ("Position" if adjusting_position else "Rotation"))
	
	# Save current values
	if event is InputEventKey and event.keycode == KEY_S and event.pressed:
		save_current_values()
	
	# Position adjustments
	if adjusting_position:
		if event.is_action_pressed("ui_right"):
			current_tool.position.x += adjustment_speed
			print("Position: " + str(current_tool.position))
		
		if event.is_action_pressed("ui_left"):
			current_tool.position.x -= adjustment_speed
			print("Position: " + str(current_tool.position))
		
		if event.is_action_pressed("ui_up"):
			current_tool.position.y += adjustment_speed
			print("Position: " + str(current_tool.position))
		
		if event.is_action_pressed("ui_down"):
			current_tool.position.y -= adjustment_speed
			print("Position: " + str(current_tool.position))
			
		# Z-axis adjustments with Page Up/Down
		if event is InputEventKey and event.keycode == KEY_PAGEUP and event.pressed:
			current_tool.position.z += adjustment_speed
			print("Position: " + str(current_tool.position))
			
		if event is InputEventKey and event.keycode == KEY_PAGEDOWN and event.pressed:
			current_tool.position.z -= adjustment_speed
			print("Position: " + str(current_tool.position))
	
	# Rotation adjustments
	else:
		if event.is_action_pressed("ui_right"):
			current_tool.rotation.y += rotation_speed
			print("Rotation: " + str(current_tool.rotation))
		
		if event.is_action_pressed("ui_left"):
			current_tool.rotation.y -= rotation_speed
			print("Rotation: " + str(current_tool.rotation))
		
		if event.is_action_pressed("ui_up"):
			current_tool.rotation.x += rotation_speed
			print("Rotation: " + str(current_tool.rotation))
		
		if event.is_action_pressed("ui_down"):
			current_tool.rotation.x -= rotation_speed
			print("Rotation: " + str(current_tool.rotation))
			
		# Z-axis rotation with Page Up/Down
		if event is InputEventKey and event.keycode == KEY_PAGEUP and event.pressed:
			current_tool.rotation.z += rotation_speed
			print("Rotation: " + str(current_tool.rotation))
			
		if event is InputEventKey and event.keycode == KEY_PAGEDOWN and event.pressed:
			current_tool.rotation.z -= rotation_speed
			print("Rotation: " + str(current_tool.rotation))

# Save current values to console for copying into code
func save_current_values():
	if not current_tool:
		return
	
	print("\n--- SAVED TOOL ADJUSTMENT VALUES ---")
	
	var tool_class = current_tool.get_class()
	var tool_type = ""
	
	if current_tool.has_method("get_tool_type"):
		tool_type = current_tool.get_tool_type()
	
	print("Tool Class: " + tool_class)
	if tool_type:
		print("Tool Type: " + tool_type)
	
	print("\nPosition: " + str(current_tool.position))
	print("Rotation: " + str(current_tool.rotation))
	print("Rotation (degrees): " + str(current_tool.rotation_degrees))
	
	print("\n# Code snippet for PlayerToolHandler.gd:")
	print('if tool_obj.get_class() == "' + tool_class + '":')
	print("\ttool_obj.position = Vector3" + str(current_tool.position))
	print("\ttool_obj.rotation = Vector3" + str(current_tool.rotation))
	
	print("\n--- END SAVED VALUES ---\n")
