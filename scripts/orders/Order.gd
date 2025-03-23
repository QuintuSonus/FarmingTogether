# scripts/orders/Order.gd
class_name Order
extends Resource

# Order states
enum OrderState {
	ACTIVE,
	COMPLETED,
	FAILED
}

# Order properties
var order_id: int
var required_crops: Dictionary = {}  # Dictionary of crop_type: quantity
var time_limit: float
var time_remaining: float
var state: int = OrderState.ACTIVE
var score_value: int = 100
var time_bonus_multiplier: float = 0.5  # Bonus multiplier based on time remaining

# Optional properties for visual display
var display_name: String = ""
var order_difficulty: int = 1  # 1-3, affects visual display

# Initialize a new order
func _init(p_id: int = 0, p_crops: Dictionary = {}, p_time_limit: float = 60.0):
	order_id = p_id
	required_crops = p_crops
	time_limit = p_time_limit
	time_remaining = time_limit
	# Generate a display name based on crop types
	generate_display_name()
	# Set difficulty based on crop quantity and variety
	calculate_difficulty()

# Generate a descriptive name for the order
func generate_display_name() -> void:
	var crop_names = []
	for crop_type in required_crops.keys():
		var quantity = required_crops[crop_type]
		crop_names.append(str(quantity) + " " + crop_type.capitalize() + "(s)")
	
	if crop_names.size() == 1:
		display_name = crop_names[0] + " Order"
	else:
		display_name = "Mixed Harvest Order"

# Calculate order difficulty based on requirements
func calculate_difficulty() -> void:
	var total_items = 0
	var unique_types = required_crops.keys().size()
	
	for quantity in required_crops.values():
		total_items += quantity
	
	if total_items <= 2 and unique_types == 1:
		order_difficulty = 1
	elif total_items <= 4 and unique_types <= 2:
		order_difficulty = 2
	else:
		order_difficulty = 3
	
	# Adjust score based on difficulty
	score_value = 100 * order_difficulty

# Update the time remaining
func update(delta: float) -> void:
	if state == OrderState.ACTIVE:
		time_remaining -= delta
		
		# Check if time expired
		if time_remaining <= 0:
			time_remaining = 0
			state = OrderState.FAILED

# Check if a basket contains the required crops
func can_fulfill_with_basket(basket) -> bool:
	if basket == null or not basket.has_method("get_crop_count"):
		return false
	
	# Check if basket has all required crops
	for crop_type in required_crops:
		var required = required_crops[crop_type]
		var available = basket.get_crop_count(crop_type)
		
		if available < required:
			return false
	
	return true

# Complete the order
func complete() -> int:
	if state == OrderState.ACTIVE:
		state = OrderState.COMPLETED
		
		# Calculate score with time bonus
		var time_ratio = time_remaining / time_limit
		var bonus = int(score_value * time_ratio * time_bonus_multiplier)
		
		return score_value + bonus
	
	return 0
