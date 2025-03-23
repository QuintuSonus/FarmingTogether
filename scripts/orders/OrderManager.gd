# scripts/orders/OrderManager.gd
class_name OrderManager
extends Node

# Configuration
@export var max_active_orders: int = 3
@export var initial_order_delay: float = 5.0
@export var new_order_min_delay: float = 10.0
@export var new_order_max_delay: float = 20.0
@export var level_time_limit: float = 300.0  # 5 minutes for the level

# Difficulty progression
@export var start_with_single_crop_orders: bool = true
@export var start_difficulty_ramp_time: float = 60.0  # When to start increasing difficulty
@export var max_difficulty_time: float = 240.0  # When to reach max difficulty

# State
var active_orders: Array = []
var completed_orders: Array = []
var failed_orders: Array = []
var available_crop_types: Array = ["carrot", "tomato"]
var current_score: int = 0
var level_timer: float = 0.0
var new_order_timer: float = 0.0

# Order ID counter
var next_order_id: int = 1

# Signals
signal order_created(order)
signal order_completed(order, score)
signal order_failed(order)
signal score_changed(new_score)
signal level_time_updated(time_remaining)

func _ready():
	print("OrderManager initialized")
	
	# Start with a shorter initial order delay for testing
	new_order_timer = 3.0
	
	# Force immediate order creation for testing
	call_deferred("create_test_order")
	
	# Debug signal connections
	await get_tree().process_frame
	print("OrderManager signals:")
	print("- order_created has ", get_signal_connection_list("order_created").size(), " connections")
	print("- order_completed has ", get_signal_connection_list("order_completed").size(), " connections")
	print("- order_failed has ", get_signal_connection_list("order_failed").size(), " connections")

func _process(delta):
	# Update level timer
	level_timer += delta
	emit_signal("level_time_updated", level_time_limit - level_timer)
	
	# Check if the level is over
	if level_timer >= level_time_limit:
		# Implement level end logic here
		return
	
	# Update active orders
	for order in active_orders:
		order.update(delta)
		
		# Check for failed orders
		if order.state == Order.OrderState.FAILED:
			handle_failed_order(order)
	
	# Process new order timer
	if active_orders.size() < max_active_orders:
		new_order_timer -= delta
		
		if new_order_timer <= 0:
			create_new_order()
			# Set new timer for next order
			new_order_timer = randf_range(new_order_min_delay, new_order_max_delay)

# Create a test order for debugging
func create_test_order():
	print("Creating test order after 1 second...")
	await get_tree().create_timer(1.0).timeout
	
	# Create a simple test order
	var test_crops = {"carrot": 2}
	var order = Order.new(next_order_id, test_crops, 60.0)
	next_order_id += 1
	
	# Add to active orders
	active_orders.append(order)
	
	# Emit signal
	emit_signal("order_created", order)
	
	print("Test order created: ", order.display_name, " (", order.order_id, ")")

# Create a new order based on current difficulty
func create_new_order():
	# Calculate current difficulty factor (0 to 1)
	var difficulty_factor = clamp(
		(level_timer - start_difficulty_ramp_time) / (max_difficulty_time - start_difficulty_ramp_time),
		0.0, 1.0
	)
	
	# Determine order parameters based on difficulty
	var order_crops = {}
	var crop_count = 1
	var crop_types = 1
	
	# Increase complexity with difficulty
	if difficulty_factor > 0.3:
		crop_count = 2
	if difficulty_factor > 0.6:
		crop_count = 3
	if difficulty_factor > 0.4:
		crop_types = 2
	
	# Force simple orders at the start if configured
	if start_with_single_crop_orders and level_timer < start_difficulty_ramp_time:
		crop_count = 1
		crop_types = 1
	
	# Generate required crops
	var types_to_use = []
	available_crop_types.shuffle()
	
	for i in range(min(crop_types, available_crop_types.size())):
		types_to_use.append(available_crop_types[i])
	
	# Distribute crop count among crop types
	while crop_count > 0:
		var crop_type = types_to_use[randi() % types_to_use.size()]
		
		if not order_crops.has(crop_type):
			order_crops[crop_type] = 0
		
		order_crops[crop_type] += 1
		crop_count -= 1
	
	# Determine time limit based on difficulty and order size
	var total_crop_count = 0
	for count in order_crops.values():
		total_crop_count += count
	
	var time_base = 60.0  # Base time in seconds
	var time_per_crop = 20.0  # Additional seconds per crop
	var time_limit = time_base + (time_per_crop * total_crop_count)
	
	# Create the order
	var order = Order.new(next_order_id, order_crops, time_limit)
	next_order_id += 1
	
	# Add to active orders
	active_orders.append(order)
	
	# Emit signal
	emit_signal("order_created", order)
	
	print("New order created: ", order.display_name, " (", order.order_id, ")")
	print("Required crops: ", order.required_crops)
	print("Time limit: ", order.time_limit, " seconds")

# Check if a basket EXACTLY matches any current order
func check_basket_for_exact_order_match(basket) -> Order:
	if not basket or not basket.has_method("get_crop_count"):
		return null
	
	# Check each active order
	for order in active_orders:
		var is_exact_match = true
		
		# First check if all required crops are in the basket in exact quantities
		for crop_type in order.required_crops:
			var required = order.required_crops[crop_type]
			var available = basket.get_crop_count(crop_type)
			
			if available != required:  # Must be exactly the required amount
				is_exact_match = false
				break
		
		# Then check if the basket has ANY crops not in the order
		if is_exact_match:
			for crop_type in basket.contained_crops.keys():
				if not order.required_crops.has(crop_type):
					is_exact_match = false
					break
		
		if is_exact_match:
			return order
	
	return null

# Try to complete any order with exact basket match
func try_complete_any_order(basket) -> bool:
	var matching_order = check_basket_for_exact_order_match(basket)
	
	if matching_order:
		return complete_order(matching_order.order_id, basket)
	
	# If we get here, no exact match was found
	return false

# Complete an order
# Complete an order
func complete_order(order_id: int, basket) -> bool:
	var order_index = -1
	var matched_order = null
	
	# Find the order
	for i in range(active_orders.size()):
		if active_orders[i].order_id == order_id:
			order_index = i
			matched_order = active_orders[i]
			break
	
	if matched_order == null:
		return false
	
	# Calculate score
	var score = matched_order.complete()
	current_score += score
	
	# Clear the basket after successful order completion
	if basket and basket.has_method("clear_crops"):
		print("OrderManager: Clearing basket after successful order completion")
		basket.clear_crops()
	
	# Move to completed orders
	completed_orders.append(matched_order)
	active_orders.remove_at(order_index)
	
	# Emit signals
	emit_signal("order_completed", matched_order, score)
	emit_signal("score_changed", current_score)
	
	print("Order completed: ", matched_order.display_name, " (", matched_order.order_id, ")")
	print("Score: ", score, " | Total score: ", current_score)
	
	return true

# Handle a failed order
func handle_failed_order(order):
	# Move to failed orders
	var index = active_orders.find(order)
	if index >= 0:
		active_orders.remove_at(index)
		failed_orders.append(order)
		
		# Emit signal
		emit_signal("order_failed", order)
		
		print("Order failed: ", order.display_name, " (", order.order_id, ")")
		
func reset_orders():
	# Clear any existing orders
	for order in active_orders:
		if get_signal_connection_list("order_failed").size() > 0:
			emit_signal("order_failed", order)
	
	# Reset order lists
	active_orders.clear()
	completed_orders.clear()
	failed_orders.clear()
	
	# Reset score
	current_score = 0
	emit_signal("score_changed", current_score)
	
	# Reset level timer
	level_timer = 0.0
	emit_signal("level_time_updated", level_time_limit)
	
	# Reset order ID counter
	next_order_id = 1
	
	# Set initial order timer
	new_order_timer = initial_order_delay
	
	print("OrderManager: Orders reset")
