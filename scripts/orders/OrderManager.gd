# scripts/orders/OrderManager.gd
class_name OrderManager
extends Node

# Configuration
@export var max_active_orders: int = 3
@export var initial_order_delay: float = 5.0
@export var new_order_min_delay: float = 10.0
@export var new_order_max_delay: float = 20.0
@export var level_time_limit: float = 300.0  # 5 minutes for the level

# Progression-based configuration
@export var required_orders: int = 3  # How many orders must be completed to win
@export var current_level: int = 1    # Player's current progression level

# State
var active_orders: Array = []
var completed_orders: Array = []
var failed_orders: Array = []
var available_crop_types: Array = ["carrot"]  # Will be updated based on unlocked dispensers
var current_score: int = 0
var level_timer: float = 0.0
var new_order_timer: float = 0.0
var orders_completed_this_run: int = 0

# Order ID counter
var next_order_id: int = 1

# Signals
signal order_created(order)
signal order_completed(order, score)
signal order_failed(order)
signal score_changed(new_score)
signal level_time_updated(time_remaining)
signal level_completed(score, currency_earned)
signal level_failed()

func _ready():
	print("OrderManager initialized")
	
	# Get available crops from farm data
	update_available_crops()
	
	# Set required orders based on level
	set_level_parameters()
	
	
	print("OrderManager level " + str(current_level) + " started")
	print("Required orders: " + str(required_orders))
	print("Available crops: " + str(available_crop_types))

func _process(delta):
	# Update level timer
	level_timer += delta
	emit_signal("level_time_updated", level_time_limit - level_timer)
	
	# Check if the level is over
	if level_timer >= level_time_limit:
		check_level_completion()
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
			# Set new timer for next order - shorter for higher levels
			var min_delay = max(new_order_min_delay - (current_level * 0.5), 5.0)
			var max_delay = max(new_order_max_delay - (current_level * 1.0), 10.0)
			new_order_timer = randf_range(min_delay, max_delay)

# Update available crops based on farm data
func update_available_crops():
	var farm_data = FarmData.load_data()
	
	# Reset and populate list based on unlocked seed dispensers
	available_crop_types = []
	
	# Always have carrots available (starter crop)
	available_crop_types.append("carrot")
	
	# Add tomatoes if unlocked
	if farm_data.is_seed_unlocked("tomato"):
		available_crop_types.append("tomato")
	
	# Future crops can be added here
	
	print("Available crops updated: " + str(available_crop_types))

# Set level parameters based on current level
func set_level_parameters():
	# Adjust required orders based on level
	required_orders = 3 + (current_level - 1)  # Level 1: 3, Level 2: 4, etc.
	
	# Cap at 10 orders
	required_orders = min(required_orders, 10)
	
	# Adjust time limit (more time for higher levels with more orders)
	level_time_limit = 180.0 + (current_level * 30.0)  # Level 1: 3:30, Level 2: 4:00, etc.
	
	# Cap at 8 minutes
	level_time_limit = min(level_time_limit, 480.0)
	
	# Adjust max active orders based on level
	max_active_orders = min(3 + floor(current_level / 2), 5)  # Level 1-2: 3, Level 3-4: 4, Level 5+: 5

# Create a new order based on current difficulty
func create_new_order():
	# Calculate a difficulty factor (0 to 1) based on:
	# - How far into the level we are
	# - Current player level
	var time_factor = level_timer / level_time_limit
	var level_factor = min((current_level - 1) / 5.0, 1.0)  # Caps at level 6
	
	# Combined difficulty rises through the level and with player level
	var difficulty_factor = (time_factor * 0.3) + (level_factor * 0.7)
	
	# Determine order parameters based on difficulty
	var order_crops = {}
	var crop_count = 1
	var crop_types = 1
	
	# Scale complexity with difficulty
	if difficulty_factor > 0.3 or current_level >= 2:
		crop_count += 1  # Base: 1, After threshold: 2
		
	if difficulty_factor > 0.6 or current_level >= 3:
		crop_count += 1  # Base: 2, After threshold: 3
		
	if difficulty_factor > 0.4 or current_level >= 3:
		crop_types = min(2, available_crop_types.size())  # Introduce mixed orders
	
	if difficulty_factor > 0.7 or current_level >= 5:
		crop_count += 1  # Base: 3, After threshold: 4
	
	# Force single-crop simple orders at level 1
	if current_level == 1:
		crop_count = 1 + floor(time_factor * 2)  # Level 1: 1-2 crops max
		crop_types = 1  # Always single type in level 1
	
	# Cap crop count based on available types
	crop_count = min(crop_count, crop_types * 3)  # Maximum 3 of each type
	
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
	
	# Base time per crop, decreasing with level
	var time_per_crop = max(20.0 - (current_level * 1.5), 10.0)
	
	# Time limit scales with order size and decreases with level
	var time_base = max(60.0 - (current_level * 5.0), 30.0)
	var time_limit = time_base + (time_per_crop * total_crop_count)
	
	# Create the order
	var order = Order.new(next_order_id, order_crops, time_limit)
	
	# Set difficulty directly for UI purposes
	order.order_difficulty = 1 + floor(difficulty_factor * 2)  # 1-3
	
	# Scale up score value with order complexity
	order.score_value = 100 * order.order_difficulty * total_crop_count
	
	next_order_id += 1
	
	# Add to active orders
	active_orders.append(order)
	
	# Emit signal
	emit_signal("order_created", order)
	
	print("New order created: ", order.display_name, " (", order.order_id, ")")
	print("Required crops: ", order.required_crops)
	print("Time limit: ", order.time_limit, " seconds")
	print("Difficulty: ", order.order_difficulty, " (Score value: ", order.score_value, ")")

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
	
	# Track completion
	orders_completed_this_run += 1
	
	# Move to completed orders
	completed_orders.append(matched_order)
	active_orders.remove_at(order_index)
	
	# Emit signals
	emit_signal("order_completed", matched_order, score)
	emit_signal("score_changed", current_score)
	
	# Check if level is complete
	if orders_completed_this_run >= required_orders:
		check_level_completion()
	
	print("Order completed: ", matched_order.display_name, " (", matched_order.order_id, ")")
	print("Score: ", score, " | Total score: ", current_score)
	print("Orders completed: ", orders_completed_this_run, "/", required_orders)
	
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

# Check if level is completed
func check_level_completion():
	# If we have enough completed orders, level is successful
	if orders_completed_this_run >= required_orders:
		print("Level " + str(current_level) + " completed!")
		
		# Calculate rewards - base amount plus bonus based on score
		var base_reward = 100 + (current_level * 50)  # 150, 200, 250, etc.
		var score_bonus = floor(current_score / 100) * 10  # Every 100 points = 10 currency
		var total_reward = base_reward + score_bonus
		
		# Emit level completed signal with score and reward
		emit_signal("level_completed", current_score, total_reward)
		
		# Update farm data stats
		var farm_data = FarmData.load_data()
		farm_data.add_stat("orders_completed", orders_completed_this_run)
		farm_data.add_stat("levels_completed", 1)
		farm_data.add_run_score(current_score)
		farm_data.save()
		
		# Pause processing
		set_process(false)
	else:
		# Level failed - not enough orders completed
		print("Level failed! Completed " + str(orders_completed_this_run) + "/" + str(required_orders) + " required orders")
		emit_signal("level_failed")
		
		# Pause processing
		set_process(false)

# Reset orders for a new level
func reset_orders():
	# Clear any existing orders
	for order in active_orders:
		if get_signal_connection_list("order_failed").size() > 0:
			emit_signal("order_failed", order)
	
	# Reset order lists
	active_orders.clear()
	completed_orders.clear()
	failed_orders.clear()
	
	# Reset counters
	orders_completed_this_run = 0
	current_score = 0
	emit_signal("score_changed", current_score)
	
	# Reset level timer
	level_timer = 0.0
	emit_signal("level_time_updated", level_time_limit)
	
	# Reset order ID counter
	next_order_id = 1
	
	# Update available crops
	update_available_crops()
	
	# Set parameters for current level
	set_level_parameters()
	
	# Set initial order timer
	new_order_timer = initial_order_delay
	
	# Resume processing
	set_process(true)
	
	print("OrderManager: Orders reset for level " + str(current_level))
	print("Required orders: " + str(required_orders))
	print("Available crops: " + str(available_crop_types))
