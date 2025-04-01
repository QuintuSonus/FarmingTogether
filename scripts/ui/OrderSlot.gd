# scripts/ui/OrderSlot.gd (MODIFIED)
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

# --- REMOVED Animation properties related to position ---
# var target_position = Vector2.ZERO
# var animation_speed = 10.0

# Colors for timer progress
var normal_color = Color(0.2, 0.8, 0.2)  # Green
var warning_color = Color(0.9, 0.6, 0.1)  # Orange
var critical_color = Color(0.9, 0.1, 0.1)  # Red


# --- MODIFIED: Removed position animation ---
func _process(delta):
	# Update timer if we have an order
	if order and order.state == Order.OrderState.ACTIVE:
		var progress = 0.0
		# Prevent division by zero if time_limit is somehow 0
		if order.time_limit > 0:
			progress = clamp(order.time_remaining / order.time_limit, 0.0, 1.0)

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
	if timer_progress: # Null check
		timer_progress.value = 100
		timer_progress.modulate = normal_color

	# Set panel style based on order difficulty
	var difficulty = 1 # Default
	if order and "order_difficulty" in order:
		difficulty = order.order_difficulty
	if panel: # Null check
		panel.add_theme_stylebox_override("panel", create_panel_style(difficulty))

	# --- MODIFIED: Removed initial position offset and position tween ---
	# Initial animation - just fade in
	modulate.a = 0
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1, 0.3)
	# tween.tween_property(self, "position:y", 0, 0.3).set_ease(Tween.EASE_OUT) # REMOVED


# Create panel style based on difficulty (Keep as is)
func create_panel_style(difficulty):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	match difficulty:
		1: style.border_color = Color(0.2, 0.8, 0.2)  # Green
		2: style.border_color = Color(0.9, 0.6, 0.1)  # Orange
		3: style.border_color = Color(0.9, 0.1, 0.1)  # Red
		_: style.border_color = Color(1, 1, 1)        # White default
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.border_width_left = 4
	style.border_width_right = 4
	return style

# Setup the crop requirements display (Keep as is)
func setup_crop_display():
	if not crop_container or not crop_item_scene: return # Safety checks
	for child in crop_container.get_children():
		child.queue_free()
	if not order or not "required_crops" in order: return # Check order validity

	for crop_type in order.required_crops:
		var quantity = order.required_crops[crop_type]
		for i in range(quantity):
			var crop_item = crop_item_scene.instantiate()
			crop_container.add_child(crop_item)
			var icon = get_crop_icon(crop_type)
			var texture_rect = crop_item.find_child("TextureRect") # More robust find
			if icon and texture_rect and texture_rect is TextureRect:
				texture_rect.texture = icon

# Get icon for crop type (Keep as is)
func get_crop_icon(crop_type):
	match crop_type.to_lower():
		"carrot": return carrot_icon
		"tomato": return tomato_icon
		_:
			push_error("OrderSlot: Unknown crop type: " + crop_type)
			return null

# --- REMOVED set_target_position function ---
# func set_target_position(pos): ...

# Play completion animation (Keep as is)
func play_completion_animation():
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0, 0.5)
	tween.parallel().tween_property(self, "scale", Vector2(1.2, 1.2), 0.5)
	if panel: panel.modulate = Color(0.2, 1.0, 0.2)

# Play fail animation (Keep as is)
func play_fail_animation():
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0, 0.5)
	tween.parallel().tween_property(self, "scale", Vector2(0.8, 0.8), 0.5)
	if panel: panel.modulate = Color(1.0, 0.2, 0.2)
