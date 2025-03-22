# scripts/ui/InteractionFeedback.gd
extends Control

@onready var progress_bar = $ProgressBar
@onready var prompt_label = $PromptLabel

func _ready():
	progress_bar.visible = false
	prompt_label.visible = false

func show_prompt(text: String):
	prompt_label.text = text
	prompt_label.visible = true
	
func hide_prompt():
	prompt_label.visible = false
	
func show_progress(value: float):
	progress_bar.value = value * 100  # Assuming 0-100 range
	progress_bar.visible = true
	
func hide_progress():
	progress_bar.visible = false
	
func update_progress(value: float):
	if progress_bar.visible:
		progress_bar.value = value * 100
