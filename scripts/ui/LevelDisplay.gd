# scripts/ui/LevelDisplay.gd (NEW SCRIPT)
extends Control

# References to child labels - Adjust paths if needed within LevelDisplay node
@onready var level_label: Label = $LevelLabel
@onready var required_score_label: Label = $RequiredScoreLabel # Ensure node is named this
@onready var time_label: Label = $TimeLabel

var game_manager: GameManager = null

func _ready():
	# Get GameManager reference
	var service_locator = ServiceLocator.get_instance()
	if service_locator and service_locator.has_service("game_manager"):
		game_manager = service_locator.get_service("game_manager")
	else:
		game_manager = get_node_or_null("/root/Main") # Fallback

	if not game_manager:
		push_error("LevelDisplay: GameManager not found!")
		# Set default text if manager is missing
		if level_label: level_label.text = "Level ?"
		if required_score_label: required_score_label.text = "Score: 0 / ?"
		if time_label: time_label.text = "0:00"
		return

	# Connect to GameManager signals
	if not game_manager.is_connected("score_changed", update_score_requirement_display):
		game_manager.connect("score_changed", update_score_requirement_display)
	if not game_manager.is_connected("level_time_updated", update_timer_display):
		game_manager.connect("level_time_updated", update_timer_display)
	# NOTE: Assumes GameManager has a 'current_level' property.
	# If level changes trigger a signal, connect here. Otherwise, update_level might need to be called externally.
	# Example: if game_manager.has_signal("level_changed"): game_manager.connect("level_changed", update_level_label)

	# Initial UI update
	update_level_label(game_manager.current_level)
	update_score_requirement_display(game_manager.current_level_score)
	update_timer_display(game_manager.level_time_limit)


# Updates the Level Number display
func update_level_label(level_num : int):
	if level_label:
		level_label.text = "Level " + str(level_num)

# Updates the "Score: X / Y" display (connected to GameManager.score_changed)
func update_score_requirement_display(current_score):
	if not required_score_label: return
	if not game_manager: return

	var required_score = game_manager.get_required_score()
	required_score_label.text = "Score: %d / %d" % [current_score, required_score]


# Updates the level timer display (connected to GameManager.level_time_updated)
func update_timer_display(time_remaining):
	if time_label:
		var time_seconds = max(0.0, time_remaining)
		var minutes = floori(time_seconds / 60.0)
		var seconds = floori(fmod(time_seconds, 60.0))
		time_label.text = "%d:%02d" % [minutes, seconds]

		# Visual warning when time is running low
		if time_seconds < 30:
			time_label.add_theme_color_override("font_color", Color.RED)
		elif time_label.has_theme_color_override("font_color"):
			time_label.remove_theme_color_override("font_color")
