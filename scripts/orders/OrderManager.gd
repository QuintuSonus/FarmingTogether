# scripts/orders/OrderManager.gd
class_name OrderManager
extends Node

# Configuration
@export var max_active_orders: int = 3
@export var initial_order_delay: float = 5.0
@export var new_order_min_delay: float = 10.0
@export var new_order_max_delay: float = 20.0

# Progression-based configuration
@export var required_orders: int = 3  # How many orders must be completed to win
@export var current_level: int = 1    # Player's current progression level

# State
var active_orders: Array = []
var completed_orders: Array = []
var failed_orders: Array = []
var available_crop_types: Array = ["carrot"]  # Will be updated based on unlocked dispensers
var current_score: int = 0
var new_order_timer: float = 0.0
var orders_completed_this_run: int = 0

# Order ID counter
var next_order_id: int = 1

# References to new architecture
var game_data: GameData = null
var game_data_manager: GameDataManager = null

# Signals
signal order_created(order)
signal order_completed(order, score)
signal order_failed(order)
signal score_changed(new_score)


func _ready():
	print("OrderManager initialized")
	
	# Get references to GameData and GameDataManager
	get_game_data_references()
	
	# Get available crops from game data
	update_available_crops()
	
	print("OrderManager level " + str(current_level) + " started")
	print("Required orders: " + str(required_orders))
	print("Available crops: " + str(available_crop_types))

# Get references to GameData and GameDataManager
func get_game_data_references():
	# Try to get from ServiceLocator first
	var service_locator = get_node_or_null("/root/ServiceLocator")
	if service_locator:
		game_data = service_locator.get_service("game_data")
		game_data_manager = service_locator.get_service("game_data_manager")
	
	# If not found through ServiceLocator, try direct node reference
	if not game_data_manager:
		game_data_manager = get_node_or_null("/root/Main/GameDataManager")
		if game_data_manager:
			game_data = game_data_manager.game_data
	
	# Final fallback - try to find it in the scene tree
	if not game_data_manager:
		var possible_manager = get_tree().get_root().find_child("GameDataManager", true, false)
		if possible_manager:
			game_data_manager = possible_manager
			game_data = game_data_manager.game_data
			
	if not game_data and not game_data_manager:
		print("OrderManager: WARNING - Could not find GameData or GameDataManager references!")

func _process(delta):
	# Update level timer
	#level_timer += delta
	#emit_signal("level_time_updated", level_time_limit - level_timer)
	#
	## Check if the level is over
	#if level_timer >= level_time_limit:
		#check_level_completion()
		#return
	
	# Update active orders
	for order in active_orders:
		order.update(delta)
		
		# Check for failed orders
		if order.state == Order.OrderState.FAILED:
			handle_failed_order(order)
	
	## Process new order timer
	#if active_orders.size() < max_active_orders:
		#new_order_timer -= delta
		#
		#if new_order_timer <= 0:
			#create_new_order()
			## Set new timer for next order - shorter for higher levels
			#var min_delay = max(new_order_min_delay - (current_level * 0.5), 5.0)
			#var max_delay = max(new_order_max_delay - (current_level * 1.0), 10.0)
			#new_order_timer = randf_range(min_delay, max_delay)

# Update available crops based on game data
func update_available_crops():
	# Reset and populate list based on unlocked seed dispensers
	available_crop_types = []
	
	# Always have carrots available (starter crop)
	available_crop_types.append("carrot")
	
	# Add tomatoes if unlocked using the new architecture
	if game_data and game_data.progression_data and game_data.progression_data.unlocked_seeds.has("tomato"):
		available_crop_types.append("tomato")
	# Fallback to game_data_manager if game_data is not available
	elif game_data_manager and game_data_manager.is_seed_unlocked("tomato"):
		available_crop_types.append("tomato")
	
	# Future crops can be added here
	
	print("Available crops updated: " + str(available_crop_types))



# Create a new order based on current difficulty
#func create_new_order():
	## Calculate a difficulty factor (0 to 1) based on:
	## - How far into the level we are
	## - Current player level
#
	#
	#var level_factor = min((current_level - 1) / 5.0, 1.0)  # Caps at level 6
	#
	## Combined difficulty rises through the level and with player level
	#var difficulty_factor = (time_factor * 0.3) + (level_factor * 0.7)
	#
	## Determine order parameters based on difficulty
	#var order_crops = {}
	#var crop_count = 1
	#var crop_types = 1
	#
	## Scale complexity with difficulty
	#if difficulty_factor > 0.3 or current_level >= 2:
		#crop_count += 1  # Base: 1, After threshold: 2
		#
	#if difficulty_factor > 0.6 or current_level >= 3:
		#crop_count += 1  # Base: 2, After threshold: 3
		#
	#if difficulty_factor > 0.4 or current_level >= 3:
		#crop_types = min(2, available_crop_types.size())  # Introduce mixed orders
	#
	#if difficulty_factor > 0.7 or current_level >= 5:
		#crop_count += 1  # Base: 3, After threshold: 4
	#
	## Force single-crop simple orders at level 1
	#if current_level == 1:
		#crop_count = 1 + floor(time_factor * 2)  # Level 1: 1-2 crops max
		#crop_types = 1  # Always single type in level 1
	#
	## Cap crop count based on available types
	#crop_count = min(crop_count, crop_types * 3)  # Maximum 3 of each type
	#
	## Generate required crops
	#var types_to_use = []
	#available_crop_types.shuffle()
	#
	#for i in range(min(crop_types, available_crop_types.size())):
		#types_to_use.append(available_crop_types[i])
	#
	## Distribute crop count among crop types
	#while crop_count > 0:
		#var crop_type = types_to_use[randi() % types_to_use.size()]
		#
		#if not order_crops.has(crop_type):
			#order_crops[crop_type] = 0
		#
		#order_crops[crop_type] += 1
		#crop_count -= 1
	#
	## Determine time limit based on difficulty and order size
	#update_timer_multiplier_from_parameters()
	#var total_crop_count = 0
	#for count in order_crops.values():
		#total_crop_count += count
	#
	## Base time per crop, decreasing with level
	#var time_per_crop = max(20.0 - (current_level * 1.5), 10.0)
	#
	## Time limit scales with order size and decreases with level
	#var time_base = max(60.0 - (current_level * 5.0), 30.0)
	#var time_limit = (time_base + (time_per_crop * total_crop_count))*time_multiplier
	#
	## Create the order
	#var order = Order.new(next_order_id, order_crops, time_limit)
	#
	## Set difficulty directly for UI purposes
	#order.order_difficulty = 1 + floor(difficulty_factor * 2)  # 1-3
	#
	## Scale up score value with order complexity
	#order.score_value = 100 * order.order_difficulty * total_crop_count
	#
	#next_order_id += 1
	#
	## Add to active orders
	#active_orders.append(order)
	#
	## Emit signal
	#emit_signal("order_created", order)
	#
	#print("New order created: ", order.display_name, " (", order.order_id, ")")
	#print("Required crops: ", order.required_crops)
	#print("Time limit: ", order.time_limit, " seconds")
	#print("Difficulty: ", order.order_difficulty, " (Score value: ", order.score_value, ")")

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
func try_complete_any_order(basket, is_express_delivery: bool = false) -> bool:
	var matching_order = check_basket_for_exact_order_match(basket)
	
	if matching_order:
		return complete_order(matching_order.order_id, basket, is_express_delivery)
	
	# If we get here, no exact match was found
	return false

# Complete an order
func complete_order(order_id: int, basket, is_express_delivery: bool = false) -> bool:
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
	
	# Apply express delivery bonus if applicable
	if is_express_delivery:
		score = int(score * 1.15)  # 15% bonus
		print("Express delivery bonus applied! Score increased to " + str(score))
	
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
		
	# Reset order ID counter
	next_order_id = 1
	
	# Update available crops
	update_available_crops()
	
	# Set initial order timer
	new_order_timer = initial_order_delay
	
	# Resume processing
	set_process(true)
	
	print("OrderManager: Orders reset for level " + str(current_level))
	print("Required orders: " + str(required_orders))
	print("Available crops: " + str(available_crop_types))


func get_parameter_manager():
	var service_locator = get_node_or_null("/root/ServiceLocator")
	if service_locator and service_locator.has_method("get_service"):
		return service_locator.get_service("parameter_manager")
		print("parameters found")
	return null
