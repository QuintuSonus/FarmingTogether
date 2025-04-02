# scripts/debug/ToolAdjustmentHelper.gd
# Attach this script to a child node of your Player scene.
# Allows in-game adjustment of the held tool's position and rotation for easier setup.
# Press G: Toggle between adjusting Position and Rotation. (Or map debug_toggle_adjust_mode)
# Arrow Keys / Page Up/Down: Adjust the selected property.
# Press S: Print the current position and rotation values to the console.
extends Node

# Configuration
@export var enabled: bool = true
@export var adjustment_speed: float = 0.01 # Speed for position changes
@export var rotation_speed: float = 1.0 # Speed for rotation changes (degrees)

# References - Set automatically if this is a child of the Player node
@onready var player = get_parent() if get_parent() is CharacterBody3D else null
@onready var tool_handler = player.get_node("PlayerToolHandler") if is_instance_valid(player) and player.has_node("PlayerToolHandler") else null
# We need the tool_holder reference to know the pivot point's transform space
@onready var tool_holder = tool_handler.tool_holder if is_instance_valid(tool_handler) and is_instance_valid(tool_handler.tool_holder) else null

# State
var current_tool_node = null # Stores the actual tool node being adjusted
var adjusting_position: bool = true  # If false, adjusting rotation

func _ready():
	if not enabled:
		set_process(false)
		set_process_input(false)
		return

	if not is_instance_valid(player) or not is_instance_valid(tool_handler):
		push_error("ToolAdjustmentHelper: Player or PlayerToolHandler not found/invalid. Disabling.")
		set_process(false)
		set_process_input(false)
		return
	if not is_instance_valid(tool_holder):
		push_error("ToolAdjustmentHelper: ToolHolder reference is invalid. Rotation adjustment might be incorrect. Disabling.")
		set_process(false)
		set_process_input(false)
		return

	print("--- Tool Adjustment Helper Active ---")
	print(" - Hold a tool.")
	print(" - Press [G] or mapped key (e.g., F1) to toggle Position/Rotation adjustment.")
	print(" - Use Arrow Keys & PageUp/PageDown to adjust.")
	print(" - Press [S] to print current values to console.")
	print("------------------------------------")
	# Define the input action if it doesn't exist
	if not InputMap.has_action("debug_toggle_adjust_mode"):
		InputMap.add_action("debug_toggle_adjust_mode")
		var event = InputEventKey.new()
		event.keycode = KEY_G # Default to G key
		InputMap.action_add_event("debug_toggle_adjust_mode", event)
		print("ToolAdjustmentHelper: Created input action 'debug_toggle_adjust_mode' mapped to G key.")


func _process(_delta):
	if not enabled or not is_instance_valid(tool_handler):
		return

	# Track the currently held tool node
	var tool_from_handler = tool_handler.current_tool # Assumes current_tool is the Node
	if tool_from_handler != current_tool_node:
		current_tool_node = tool_from_handler
		if is_instance_valid(current_tool_node):
			print("Adjusting tool: " + str(current_tool_node.name))
			_print_current_values() # Print values when tool changes
		else:
			print("No tool held.")

func _input(event):
	if not enabled or not is_instance_valid(current_tool_node): # Check if we have a valid tool node
		return

	# Toggle adjustment mode
	if event.is_action_pressed("debug_toggle_adjust_mode"): # Use the defined action
		adjusting_position = !adjusting_position
		print("Now adjusting: " + ("Position" if adjusting_position else "Rotation"))
		_print_current_values() # Print values when mode changes
		get_viewport().set_input_as_handled()

	# Save/Print current values
	if event is InputEventKey and event.keycode == KEY_S and event.pressed:
		save_current_values()
		get_viewport().set_input_as_handled()

	# --- Adjustments ---
	var adjusted = false
	if adjusting_position:
		# Position adjustments (still adjusts the tool's local position relative to holder)
		if Input.is_action_pressed("ui_right"):
			current_tool_node.position.x += adjustment_speed; adjusted = true
		elif Input.is_action_pressed("ui_left"):
			current_tool_node.position.x -= adjustment_speed; adjusted = true
		elif Input.is_action_pressed("ui_up"): # Forward/Backward relative to tool holder
			current_tool_node.position.z -= adjustment_speed; adjusted = true
		elif Input.is_action_pressed("ui_down"): # Forward/Backward relative to tool holder
			current_tool_node.position.z += adjustment_speed; adjusted = true
		elif Input.is_key_pressed(KEY_PAGEUP): # Vertical adjustment
			current_tool_node.position.y += adjustment_speed; adjusted = true
		elif Input.is_key_pressed(KEY_PAGEDOWN): # Vertical adjustment
			current_tool_node.position.y -= adjustment_speed; adjusted = true
		# Use elif to only process one adjustment per frame if multiple keys are pressed

	else:
		# --- MODIFIED: Rotation adjustments around the ToolHolder origin ---
		var axis = Vector3.ZERO
		var angle = 0.0
		var angle_step = rotation_speed # Speed is already in degrees

		# Determine axis and angle based on input (relative to ToolHolder's perspective)
		if Input.is_action_pressed("ui_right"):   # Yaw
			axis = Vector3.UP; angle = -angle_step; adjusted = true
		elif Input.is_action_pressed("ui_left"):  # Yaw
			axis = Vector3.UP; angle = angle_step; adjusted = true
		elif Input.is_action_pressed("ui_up"):    # Pitch
			axis = Vector3.RIGHT; angle = angle_step; adjusted = true
		elif Input.is_action_pressed("ui_down"):  # Pitch
			axis = Vector3.RIGHT; angle = -angle_step; adjusted = true
		elif Input.is_key_pressed(KEY_PAGEUP):    # Roll
			axis = Vector3.BACK; angle = angle_step; adjusted = true # Use BACK for positive Z roll
		elif Input.is_key_pressed(KEY_PAGEDOWN):  # Roll
			axis = Vector3.BACK; angle = -angle_step; adjusted = true
		# Use elif to prevent multiple rotations per frame

		if adjusted:
			# Get the current local transform of the tool relative to the ToolHolder
			var current_local_transform : Transform3D = current_tool_node.transform

			# Create a new transform by rotating the current one AROUND THE PARENT'S ORIGIN (0,0,0)
			var new_local_transform = current_local_transform.rotated(axis, deg_to_rad(angle))

			# Apply the new local transform back to the tool node
			current_tool_node.transform = new_local_transform

	# Print values if adjusted
	if adjusted:
		_print_current_values()
		# Optional: Mark input as handled if adjustments were made
		# get_viewport().set_input_as_handled()


# Prints current values to the console
func _print_current_values():
	if not is_instance_valid(current_tool_node): return
	if adjusting_position:
		# Print position relative to the ToolHolder (which is the offset needed)
		print("Position Offset: " + str(current_tool_node.position))
	else:
		# --- FIX: Use global rad_to_deg() on each component ---
		var euler_rad = current_tool_node.transform.basis.get_euler()
		var euler_deg = Vector3(
			rad_to_deg(euler_rad.x),
			rad_to_deg(euler_rad.y),
			rad_to_deg(euler_rad.z)
		)
		print("Rotation Degrees: " + str(euler_deg))


# Save/Print current values formatted for easy copying
func save_current_values():
	if not is_instance_valid(current_tool_node):
		print("No tool held to save values for.")
		return

	print("\n--- TOOL ADJUSTMENT VALUES ---")
	var tool_class = current_tool_node.get_class()
	var tool_name_slice = current_tool_node.name.get_slice(":", 0) # Get base name if instanced

	print("Tool Class: " + tool_class)
	print("Tool Name: " + current_tool_node.name)

	# --- Position Offset ---
	var pos_str = "Vector3(%.3f, %.3f, %.3f)" % [current_tool_node.position.x, current_tool_node.position.y, current_tool_node.position.z]
	print("Position Offset (relative to ToolHolder): " + pos_str)

	# --- Rotation ---
	# --- FIX: Use global rad_to_deg() on each component ---
	var euler_rad = current_tool_node.transform.basis.get_euler()
	var rotation_degrees_from_basis = Vector3(
		rad_to_deg(euler_rad.x),
		rad_to_deg(euler_rad.y),
		rad_to_deg(euler_rad.z)
	)
	var rot_deg_str = "Vector3(%.1f, %.1f, %.1f)" % [rotation_degrees_from_basis.x, rotation_degrees_from_basis.y, rotation_degrees_from_basis.z]
	print("Rotation Degrees: " + rot_deg_str)

	# --- Code Snippet ---
	print("\n# Code snippet for PlayerToolHandler.gd -> apply_tool_rotation_adjustments():")
	print('match tool_obj.name.get_slice(":", 0):') # Match base name
	print('\t"%s":' % tool_name_slice)
	# Position is handled by AttachmentPoint, but offset value is useful reference
	# print("\t\t# Calculated Position Offset: %s" % pos_str)
	print("\t\ttool_obj.rotation_degrees = %s" % rot_deg_str) # Provide rotation degrees line
	print("\t_:")
	print("\t\ttool_obj.rotation = Vector3.ZERO")


	print("--- END VALUES ---")
