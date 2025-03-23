# scripts/ui/OrderSlot.gd
extends MarginContainer

# Order reference
var order = null

# UI elements
@onready var panel = $Panel
@onready var timer_progress = $Panel/VBoxContainer/TimerProgress
@onready var order_icon = $Panel/VBoxContainer/OrderDisplay/OrderIcon
@onready var crop_container = $Panel/VBoxContainer/OrderDisplay/CropsContainer

# Preloaded resources
@export var carrot_icon: Texture2D
@export var tomato_icon: Texture2D
@export var crop_item_scene: PackedScene

# Animation properties
var target_position = Vector2.ZERO
var animation_speed = 10.0

# Colors for timer progress
var normal_color = Color(0.2, 0.8, 0.2)  # Green
var warning_color = Color(0.9, 0.6, 0.1)  # Orange
var critical_color = Color(0.9, 0.1, 0.1)  # Red

# Process for animations
func _process(delta):
	# Smooth position movement
	if position != target_position:
		position = position.move_toward(target_position, delta * animation_speed * 200)
	
	# Update timer if we have an order
	if order and order.state == Order.OrderState.ACTIVE:
		var progress = order.time_remaining / order.time_limit
		timer_progress.value = progress * 100
		
		# Update timer color based on remaining time
		if progress < 0.25:
			timer_progress.modulate = critical_color
		elif progress < 0.5:
			timer_progress.modulate = warning_color
		else:
			timer_progress.modulate = normal_color

# Initialize with an order
func initialize(p_order):
	order = p_order
	
	# Setup UI based on order data
	setup_crop_display()
	
	# Set initial timer value
	timer_progress.value = 100
	timer_progress.modulate = normal_color
	
	# Set panel style based on order difficulty
	var difficulty = order.order_difficulty
	panel.add_theme_stylebox_override("panel", create_panel_style(difficulty))
	
	# Initial animation - slide in from top
	position.y = -100
	modulate.a = 0
	
	var tween = create_tween()
	tween.tween_property(self, "position:y", 0, 0.3).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 1, 0.3)

# Create panel style based on difficulty
func create_panel_style(difficulty):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	
	# Add colored border based on difficulty
	match difficulty:
		1:  # Easy
			style.border_color = Color(0.2, 0.8, 0.2)  # Green
		2:  # Medium
			style.border_color = Color(0.9, 0.6, 0.1)  # Orange
		3:  # Hard
			style.border_color = Color(0.9, 0.1, 0.1)  # Red
		_:
			style.border_color = Color(1, 1, 1)  # White default
	
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.border_width_left = 4
	style.border_width_right = 4
	
	return style

# Setup the crop requirements display
func setup_crop_display():
	# Clear existing items
	for child in crop_container.get_children():
		child.queue_free()
	
	# Add crop icons based on required crops
	for crop_type in order.required_crops:
		var quantity = order.required_crops[crop_type]
		
		for i in range(quantity):
			var crop_item = crop_item_scene.instantiate()
			crop_container.add_child(crop_item)
			
			# Set the icon based on crop type
			var icon = get_crop_icon(crop_type)
			if icon and crop_item.has_node("TextureRect"):
				crop_item.get_node("TextureRect").texture = icon

# Get icon for crop type
func get_crop_icon(crop_type):
	match crop_type.to_lower():
		"carrot":
			return carrot_icon
		"tomato":
			return tomato_icon
		_:
			push_error("OrderSlot: Unknown crop type: " + crop_type)
			return null

# Set target position (called from OrderUI)
func set_target_position(pos):
	target_position = pos

# Play completion animation
func play_completion_animation():
	# Fade out and scale up
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0, 0.5)
	tween.parallel().tween_property(self, "scale", Vector2(1.2, 1.2), 0.5)
	
	# Flash green
	panel.modulate = Color(0.2, 1.0, 0.2)  # Bright green
	
	# Play sound effect (to be implemented)
	# SoundManager.play_sound("order_complete")

# Play fail animation
func play_fail_animation():
	# Fade out and shrink
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0, 0.5)
	tween.parallel().tween_property(self, "scale", Vector2(0.8, 0.8), 0.5)
	
	# Flash red
	panel.modulate = Color(1.0, 0.2, 0.2)  # Bright red
	
	# Play sound effect (to be implemented)
	# SoundManager.play_sound("order_failed")
