# scripts/orders/Order.gd
class_name Order
extends Resource

# Order states
enum OrderState {
	ACTIVE,
	COMPLETED, # State now set by OrderManager.register_order_bonus
	FAILED     # State set by timer expiry in this script
}

# Order properties
var order_id: int
var required_crops: Dictionary = {}  # Dictionary of crop_type: quantity
var time_limit: float = 60.0         # Time limit for this specific order
var time_remaining: float = 60.0     # How much time is left for this order
var state: int = OrderState.ACTIVE

# Optional properties for visual display
var display_name: String = ""
var order_difficulty: int = 1  # 1-3, affects visual display (e.g., border color)

# Initialize a new order
func _init(p_id: int = 0, p_crops: Dictionary = {}, p_time_limit: float = 60.0):
	order_id = p_id
	required_crops = p_crops
	time_limit = p_time_limit if p_time_limit > 0 else 60.0 # Ensure positive time limit
	time_remaining = time_limit
	state = OrderState.ACTIVE # Ensure state starts as active

	# Generate a display name based on crop types
	generate_display_name()
	# Set difficulty based on crop quantity and variety
	calculate_difficulty() #

# Generate a descriptive name for the order (Keep as is)
func generate_display_name() -> void:
	var crop_names = []
	for crop_type in required_crops.keys():
		var quantity = required_crops[crop_type]
		# Ensure crop_type is capitalized correctly
		var type_name = crop_type.capitalize() if crop_type is String else str(crop_type)
		crop_names.append(str(quantity) + " " + type_name + ("s" if quantity > 1 else "")) # Add (s) for plural

	if crop_names.size() == 0:
		display_name = "Empty Order (?)" # Handle case with no crops
	elif crop_names.size() == 1:
		display_name = crop_names[0] + " Order"
	else:
		display_name = "Mixed Harvest Order" #


# Calculate order difficulty based on requirements (Keep as is, removed score_value assignment)
func calculate_difficulty() -> void:
	var total_items = 0
	var unique_types = required_crops.keys().size()

	for quantity in required_crops.values():
		total_items += quantity

	if total_items == 0: # Handle empty order case
		order_difficulty = 1
	elif total_items <= 2 and unique_types == 1:
		order_difficulty = 1
	elif total_items <= 4 and unique_types <= 2:
		order_difficulty = 2
	else:
		order_difficulty = 3 #

	# --- REMOVED score_value assignment ---
	# score_value = 100 * order_difficulty


# Update the time remaining for this specific order (Keep as is)
func update(delta: float) -> void:
	if state == OrderState.ACTIVE:
		time_remaining -= delta

		# Check if time expired for this order
		if time_remaining <= 0:
			time_remaining = 0
			state = OrderState.FAILED # Set state to failed


# Check if a basket contains the required crops (Keep as is)
# Note: This checks if the basket *contains at least* the required amount.
# OrderManager.check_basket_for_exact_order_match checks for *exact* match.
func can_fulfill_with_basket(basket) -> bool:
	if not basket or not basket is Basket or not basket.has_method("get_crop_count"):
		return false

	# Check if basket has *at least* all required crops
	for crop_type in required_crops:
		var required_amount = required_crops[crop_type]
		var available_amount = basket.get_crop_count(crop_type)

		if available_amount < required_amount:
			return false # Not enough of this crop type

	return true # Basket contains at least the required amounts


# --- REMOVED complete() method ---
# Score calculation and state change to COMPLETED are now handled
# by OrderManager.register_order_bonus() when an exact match is delivered.
