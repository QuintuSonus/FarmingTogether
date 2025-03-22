# scripts/ui/InteractionFeedback.gd
extends Control

@onready var progress_bar = $ProgressBar
@onready var prompt_label = $PromptLabel

# Positioning parameters
@export var vertical_offset: float = 2.0  # Distance above player
@export var bar_width: float = 200.0

# Camera reference
var camera: Camera3D

func _ready():
	# Hide elements initially
	progress_bar.visible = false
	prompt_label.visible = false
	
	# Set progress bar width
	progress_bar.custom_minimum_size.x = bar_width
	
	# Get camera reference
	camera = get_viewport().get_camera_3d()
	
	# Set size flags to ensure proper centering
	progress_bar.size_flags_horizontal = SIZE_SHRINK_CENTER
	prompt_label.size_flags_horizontal = SIZE_SHRINK_CENTER
	
	# Make the control full screen to allow positioning anywhere
	size = get_viewport_rect().size
	
	print("InteractionFeedback initialized")

func _process(_delta):
	# Keep updating the position while visible
	if progress_bar.visible or prompt_label.visible:
		update_position()

func update_position():
	if not camera or not get_parent():
		return
	
	# Get position above the player
	var parent_pos = get_parent().global_position
	var pos_above = parent_pos + Vector3(0, vertical_offset, 0)
	
	# Convert world position to screen position
	var screen_pos = camera.unproject_position(pos_above)
	
	# Position UI elements
	progress_bar.position = screen_pos - Vector2(progress_bar.size.x / 2, progress_bar.size.y + 10)
	prompt_label.position = screen_pos - Vector2(prompt_label.size.x / 2, prompt_label.size.y + 40)

func show_prompt(text: String):
	prompt_label.text = text
	prompt_label.visible = true
	update_position()
	
func hide_prompt():
	prompt_label.visible = false
	
func show_progress(value: float):
	progress_bar.value = value * 100  # Assuming 0-100 range
	progress_bar.visible = true
	update_position()
	print("Progress bar shown with value: ", value * 100)
	
func hide_progress():
	progress_bar.visible = false
	
func update_progress(value: float):
	if progress_bar.visible:
		progress_bar.value = value * 100
		print("Progress updated to: ", value * 100)
