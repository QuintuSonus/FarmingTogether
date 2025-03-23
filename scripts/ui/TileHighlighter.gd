# scripts/ui/TileHighlighter.gd
extends Node3D

@export var highlight_height: float = 0.26  # Slightly above tile surface
@export var can_interact_color: Color = Color(0, 1, 0, 0.4)  # Translucent green
@export var cannot_interact_color: Color = Color(1, 0, 0, 0.4)  # Translucent red
@export var neutral_color: Color = Color(1, 1, 1, 0.3)  # Translucent white

@onready var mesh_instance = $MeshInstance3D

var current_material: StandardMaterial3D

func _ready():
	# Create material if not already set
	current_material = StandardMaterial3D.new()
	current_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	current_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # No lighting effects
	current_material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Visible from both sides
	
	mesh_instance.set_surface_override_material(0, current_material)
	
	# Initially hidden
	visible = false

func highlight_tile(position: Vector3, can_interact: bool = false):
	# Position the highlighter
	global_position = position
	global_position.y = highlight_height  # Set to fixed height above ground
	# Reset rotation to align with grid (important fix)
	global_rotation = Vector3.ZERO
	# Set the color based on interaction possibility
	if can_interact:
		current_material.albedo_color = can_interact_color
	else:
		current_material.albedo_color = cannot_interact_color
	
	# Make visible
	visible = true

func highlight_neutral(position: Vector3):
	global_position = position
	global_position.y = highlight_height
	
	global_rotation = Vector3.ZERO
	
	current_material.albedo_color = neutral_color
	
	visible = true

func hide_highlight():
	visible = false
