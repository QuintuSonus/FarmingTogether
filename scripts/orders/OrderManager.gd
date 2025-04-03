# scripts/orders/OrderManager.gd
class_name OrderManager
extends Node

# Configuration
@export var max_active_orders: int = 3
@export var initial_order_delay: float = 20.0
@export var new_order_min_delay: float = 20.0
@export var new_order_max_delay: float = 30.0
@export var time_multiplier: float = 1.0 # Multiplier for individual order timers

# State
var active_orders: Array[Order] = []
var completed_orders: Array[Order] = []
var failed_orders: Array[Order] = []
var available_crop_types: Array = ["carrot"]
var new_order_timer: float = 0.0
var orders_completed_this_run: int = 0

# Reference for current level difficulty scaling
var current_level: int = 1

# Order ID counter
var next_order_id: int = 1

# References (obtained in _ready)
var game_data: GameData = null
var game_data_manager: GameDataManager = null

# Signals
signal order_created(order)
signal order_failed(order)
signal order_completed_bonus(order, bonus_score)

func _ready():
	print("OrderManager initialized")
	get_game_data_references()
	update_available_crops()
	set_level_parameters()
	print("OrderManager ready for level " + str(current_level))
	print("Max active orders: " + str(max_active_orders))
	print("Available crops: " + str(available_crop_types))
	new_order_timer = initial_order_delay

func get_game_data_references():
	var service_locator = ServiceLocator.get_instance() # Correct way
	if service_locator:
		if service_locator.has_service("game_data"):
			game_data = service_locator.get_service("game_data")
		if service_locator.has_service("game_data_manager"):
			game_data_manager = service_locator.get_service("game_data_manager")

	if not game_data_manager: game_data_manager = get_node_or_null("/root/Main/GameDataManager")
	if game_data_manager and not game_data: game_data = game_data_manager.game_data
	if not game_data or not game_data_manager:
		push_warning("OrderManager: Could not find GameData or GameDataManager references!")

func _process(delta):
	for i in range(active_orders.size() - 1, -1, -1):
		var order = active_orders[i]
		if not is_instance_valid(order):
			active_orders.remove_at(i)
			continue
		order.update(delta)
		if order.state == Order.OrderState.FAILED:
			handle_failed_order(order)

	if active_orders.size() < max_active_orders:
		new_order_timer -= delta
		if new_order_timer <= 0:
			create_new_order()
			var min_delay = max(new_order_min_delay - (current_level * 0.5), 5.0)
			var max_delay = max(new_order_max_delay - (current_level * 1.0), 10.0)
			new_order_timer = randf_range(min_delay, max_delay)

func update_available_crops():
	available_crop_types = []
	available_crop_types.append("carrot")
	if game_data and game_data.progression_data and game_data.progression_data.unlocked_seeds.has("tomato"):
		available_crop_types.append("tomato")
	elif game_data_manager and game_data_manager.has_method("is_seed_unlocked") and game_data_manager.is_seed_unlocked("tomato"):
		available_crop_types.append("tomato")
	print("OrderManager: Available crops updated: " + str(available_crop_types))

func set_level_parameters():
	max_active_orders = min(3 + floori(current_level / 2.0), 5)

func create_new_order():
	if available_crop_types.is_empty():
		push_warning("OrderManager: Cannot create order, no available crop types!")
		return

	var level_factor = min(float(current_level - 1) / 5.0, 1.0)
	var difficulty_factor = level_factor

	var order_crops = {}
	var crop_count = 1
	var crop_types_to_use_count = 1

	if difficulty_factor > 0.3 or current_level >= 2: crop_count += 1
	if difficulty_factor > 0.6 or current_level >= 3: crop_count += 1
	if difficulty_factor > 0.4 or current_level >= 3: crop_types_to_use_count = min(2, available_crop_types.size())
	if difficulty_factor > 0.7 or current_level >= 5: crop_count += 1
	if current_level == 1:
		crop_count = 1
		crop_types_to_use_count = 1

	var types_to_use = []
	var shuffled_types = available_crop_types.duplicate()
	shuffled_types.shuffle()
	for i in range(min(crop_types_to_use_count, shuffled_types.size())):
		types_to_use.append(shuffled_types[i])

	var remaining_crops = crop_count
	while remaining_crops > 0 and not types_to_use.is_empty():
		var crop_type = types_to_use[randi() % types_to_use.size()]
		order_crops[crop_type] = order_crops.get(crop_type, 0) + 1
		remaining_crops -= 1

	if order_crops.is_empty():
		print("OrderManager: Failed to generate crops for order, using default.")
		order_crops["carrot"] = 1

	update_timer_multiplier_from_parameters()
	var total_crop_count = 0
	for count in order_crops.values(): total_crop_count += count
	var time_per_crop = max(20.0 - (current_level * 1.5), 10.0)
	var time_base = max(60.0 - (current_level * 5.0), 30.0)
	var order_time_limit = (time_base + (time_per_crop * total_crop_count)) * time_multiplier

	var order = Order.new(next_order_id, order_crops, order_time_limit)
	next_order_id += 1

	active_orders.append(order)
	emit_signal("order_created", order)
	print("OrderManager: New order %d created: %s, Time: %.1fs" % [order.order_id, order.display_name, order.time_limit])

func check_basket_for_exact_order_match(basket: Basket) -> Order:
	if not basket or not basket is Basket: return null
	for order in active_orders:
		if not is_instance_valid(order): continue
		var is_exact_match = true
		var required = order.required_crops
		var available_in_basket = basket.contained_crops
		if required.size() != available_in_basket.size():
			is_exact_match = false
		else:
			for crop_type in required:
				if not available_in_basket.has(crop_type) or available_in_basket[crop_type] != required[crop_type]:
					is_exact_match = false
					break
		if is_exact_match:
			return order
	return null

# --- NEW: Calculate and register bonus score ---
func register_order_bonus(order: Order, basket: Basket, is_express_delivery: bool = false):
	if not order or order.state != Order.OrderState.ACTIVE:
		push_warning("OrderManager: Cannot register bonus for invalid or non-active order %s" % order)
		return

	# --- CORRECTED GameManager Retrieval ---
	var game_manager = null
	var service_locator = ServiceLocator.get_instance()
	if service_locator and service_locator.has_service("game_manager"):
		game_manager = service_locator.get_service("game_manager")
	else:
		game_manager = get_node_or_null("/root/Main") # Fallback
	# --- End Correction ---

	if not game_manager or not game_manager.has_method("add_score") or not game_manager.game_data:
		push_error("OrderManager: Cannot calculate bonus score - GameManager invalid or missing methods/data.")
		return

	var order_base_value = 0
	var crop_scores = {}
	# Access GameData via GameManager using the corrected property check logic
	if game_manager.game_data and \
	   game_manager.game_data.get("crop_base_scores") != null and \
	   typeof(game_manager.game_data.crop_base_scores) == TYPE_DICTIONARY:
		crop_scores = game_manager.game_data.crop_base_scores
	# If using @export var crop_base_scores: Dictionary = ...
	# elif game_manager.game_data and game_manager.game_data.crop_base_scores != null and \
	#	 typeof(game_manager.game_data.crop_base_scores) == TYPE_DICTIONARY:
	#	 crop_scores = game_manager.game_data.crop_base_scores
	else:
		push_warning("OrderManager: Cannot find 'crop_base_scores' Dictionary in GameData! Using fallback.")
		crop_scores = {"carrot": 10, "tomato": 15} # Fallback


	for crop_type in order.required_crops:
		var quantity = order.required_crops[crop_type]
		var score_per_crop = crop_scores.get(crop_type, 0)
		order_base_value += quantity * score_per_crop

	if order_base_value == 0:
		print("OrderManager: Order base value is 0, no bonus score added.")

	var time_ratio = clamp(order.time_remaining / order.time_limit, 0.0, 1.0) if order.time_limit > 0 else 1.0
	var bonus_percentage = lerp(0.20, 0.40, time_ratio)
	var bonus_score = int(order_base_value * bonus_percentage)

	if is_express_delivery:
		bonus_score = int(bonus_score * 1.15)
		print("OrderManager: Express delivery bonus applied to order bonus!")

	if bonus_score > 0:
		game_manager.add_score(bonus_score) # Call on instance
		print("OrderManager: Added %d BONUS score for completing order %d." % [bonus_score, order.order_id])

	# --- Mark Order as Completed Internally ---
	var order_index = active_orders.find(order)
	if order_index != -1:
		order.state = Order.OrderState.COMPLETED
		completed_orders.append(order)
		active_orders.remove_at(order_index)
		emit_signal("order_completed_bonus", order, bonus_score)
		orders_completed_this_run += 1
		print("OrderManager: Marked Order %d as completed." % order.order_id)
	else:
		push_warning("OrderManager: Could not find order %d in active_orders to mark as complete." % order.order_id)


func handle_failed_order(order):
	var index = active_orders.find(order)
	if index >= 0:
		active_orders.remove_at(index)
		failed_orders.append(order)
		emit_signal("order_failed", order)
		print("OrderManager: Order %d failed (timer expired)." % order.order_id)

func reset_orders():
	for order in active_orders:
		if is_instance_valid(order):
			emit_signal("order_failed", order)
	active_orders.clear()
	completed_orders.clear()
	failed_orders.clear()
	orders_completed_this_run = 0
	next_order_id = 1
	update_available_crops()
	set_level_parameters()
	new_order_timer = initial_order_delay
	set_process(true)
	print("OrderManager: Orders reset for level " + str(current_level))

func update_timer_multiplier_from_parameters():
	var parameter_manager = get_parameter_manager()
	if parameter_manager:
		time_multiplier = parameter_manager.get_value("order.time_multiplier", time_multiplier)

func get_parameter_manager():
	# Use correct ServiceLocator pattern
	var service_locator = ServiceLocator.get_instance()
	if service_locator and service_locator.has_service("parameter_manager"):
		return service_locator.get_service("parameter_manager")
	# Fallback
	var pm = get_node_or_null("/root/ParameterManager")
	# if not pm: print("OrderManager: ParameterManager service/node not found.") # Optional debug
	return pm
