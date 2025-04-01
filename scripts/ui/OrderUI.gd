# scripts/ui/OrderUI.gd
extends Control

# References to UI elements
# References to UI elements - will be assigned in _ready()
var timer_label
var score_label
var order_container

# Preload order slot scene
@export var order_slot_scene: PackedScene
var default_order_slot_scene = preload("res://scenes/ui/OrderSlot.tscn")

# Dictionary to track UI slots for each order
var order_slots = {}

# Reference to the order manager
var order_manager: OrderManager

func _ready():
	print("OrderUI: _ready() called")

	# Get references to UI elements
	timer_label = find_child("TimeLabel", true)
	score_label = find_child("ScoreLabel", true)
	order_container = find_child("OrderContainer", true)
	
	# Print node tree to debug
	print_node_tree(self)
	
	# Check if UI elements were found
	if not timer_label:
		push_error("OrderUI: TimeLabel node not found!")
	else:
		print("OrderUI: TimeLabel found")
		
	if not score_label:
		push_error("OrderUI: ScoreLabel node not found!")
	else:
		print("OrderUI: ScoreLabel found")
		
	if not order_container:
		push_error("OrderUI: OrderContainer node not found!")
	else:
		print("OrderUI: OrderContainer found")
	
	# Verify the order slot scene is available
	if order_slot_scene == null and default_order_slot_scene == null:
		push_error("OrderUI: Order slot scene not available! Check that scenes/ui/OrderSlot.tscn exists and is loaded.")
	
	# Find the order manager
	order_manager = get_node_or_null("/root/Main/OrderManager")
	
	if not order_manager:
		push_error("OrderUI: OrderManager not found!")
		return
	else:
		print("OrderUI: OrderManager found")
	
	# Connect to order manager signals
	order_manager.connect("order_created", _on_order_created)
	order_manager.connect("order_completed", _on_order_completed)
	order_manager.connect("order_failed", _on_order_failed)
	order_manager.connect("score_changed", _on_score_changed)
	order_manager.connect("level_time_updated", _on_level_time_updated)
	
	# Initialize UI
	update_score_display(0)
	update_timer_display(order_manager.level_time_limit)
	
	# Make sure all size flags are set correctly for the container
	if order_container:
		order_container.size_flags_horizontal = Control.SIZE_FILL
		order_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		print("OrderUI: Container size set")

# For debugging - print the node tree
func print_node_tree(node, indent = ""):
	print(indent + node.name + " [" + node.get_class() + "]")
	for child in node.get_children():
		print_node_tree(child, indent + "  ")

func _on_order_created(order):
	# Safety check - make sure we have an order container
	if not order_container:
		push_error("OrderUI: Cannot add order slot - order_container is null!")
		# Try to find it again
		order_container = get_node_or_null("OrderContainer")
		if not order_container:
			push_error("OrderUI: Still cannot find OrderContainer!")
			return
	
	# Check if order_slot_scene is set, if not use the default
	var slot_scene = order_slot_scene if order_slot_scene != null else default_order_slot_scene
	
	# Make sure we have a valid scene
	if slot_scene == null:
		push_error("OrderUI: No order slot scene available! Check that OrderSlot.tscn exists.")
		return
	
	# Instantiate a new order slot
	var new_slot = slot_scene.instantiate()
	if not new_slot:
		push_error("OrderUI: Failed to instantiate OrderSlot scene!")
		return
		
	# Add the slot to the container
	order_container.add_child(new_slot)
	
	# Initialize the slot with order data
	if new_slot.has_method("initialize"):
		new_slot.initialize(order)
	else:
		push_error("OrderUI: OrderSlot doesn't have initialize method!")
	
	# Store reference to the slot
	order_slots[order.order_id] = new_slot
	
	# Update the container
	arrange_order_slots()

func _on_order_completed(order, score):
	# Get the slot
	var slot = order_slots.get(order.order_id)
	if slot:
		# Play completion animation
		slot.play_completion_animation()
		
		# Wait for animation to finish then remove
		await get_tree().create_timer(1.0).timeout
		
		# Remove slot
		slot.queue_free()
		order_slots.erase(order.order_id)
		
		# Rearrange remaining slots
		arrange_order_slots()

func _on_order_failed(order):
	# Get the slot
	var slot = order_slots.get(order.order_id)
	if slot:
		# Play fail animation
		slot.play_fail_animation()
		
		# Wait for animation to finish then remove
		await get_tree().create_timer(1.0).timeout
		
		# Remove slot
		slot.queue_free()
		order_slots.erase(order.order_id)
		
		# Rearrange remaining slots
		arrange_order_slots()

func _on_score_changed(new_score):
	update_score_display(new_score)

func _on_level_time_updated(time_remaining):
	update_timer_display(time_remaining)

func update_score_display(score):
	if score_label:
		score_label.text = str(score)
	else:
		push_error("OrderUI: score_label is null")

func update_timer_display(time_seconds):
	if timer_label:
		var minutes = int(time_seconds) / 60
		var seconds = int(time_seconds) % 60
		timer_label.text = "%d:%02d" % [minutes, seconds]
		
		# Visual warning when time is running low
		if time_seconds < 30:
			timer_label.add_theme_color_override("font_color", Color(1, 0, 0))
		else:
			timer_label.remove_theme_color_override("font_color")
	else:
		push_error("OrderUI: timer_label is null")

func arrange_order_slots():
	# Safety check for order_container
	if not order_container:
		push_error("OrderUI: Cannot arrange slots - order_container is null!")
		return
		
	# Get all slots
	var slots = order_slots.values()
	
	# If no slots, nothing to do
	if slots.size() == 0:
		return
	
	# Calculate spacing
	var slot_width = 200  # Assuming each slot is 200 pixels wide
	var total_width = slots.size() * slot_width
	var spacing = 10  # Gap between slots
	
	if slots.size() > 1:
		total_width += (slots.size() - 1) * spacing
	
	var start_x = (order_container.size.x - total_width) / 2
	
	# Position each slot
	for i in range(slots.size()):
		var slot = slots[i]
		if not is_instance_valid(slot):
			continue  # Skip invalid slots
			
		var target_position = Vector2(start_x + (slot_width + spacing) * i, 0)
		
		# If using animations, tween to new position
		if slot.has_method("set_target_position"):
			slot.set_target_position(target_position)
		else:
			slot.position = target_position

# Handle window resize to reposition slots
func _notification(what):
	if what == NOTIFICATION_RESIZED:
		arrange_order_slots()
