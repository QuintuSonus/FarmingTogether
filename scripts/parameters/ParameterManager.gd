# scripts/parameters/ParameterManager.gd
class_name ParameterManager
extends Node

# Dictionary of all parameters
var parameters = {}

func _ready():
	register_default_parameters()

# Register a new parameter
func register_parameter(id: String, base_value: float, description: String = "") -> GameParameter:
	var param = GameParameter.new()
	param.id = id
	param.base_value = base_value
	param.description = description
	
	parameters[id] = param
	return param

# Get a parameter (creates it if it doesn't exist)
func get_parameter(id: String, default_value: float = 1.0) -> GameParameter:
	if not parameters.has(id):
		return register_parameter(id, default_value)
	return parameters[id]

# Get a parameter value
func get_value(id: String, default_value: float = 1.0) -> float:
	var param = get_parameter(id, default_value)
	return param.get_value()

# Add a modifier to a parameter
func add_modifier(param_id: String, modifier_id: String, value: float, type: int = GameParameter.ModifierType.MULTIPLY) -> void:
	var param = get_parameter(param_id)
	param.add_modifier(modifier_id, value, type)

# Remove a modifier from a parameter
func remove_modifier(param_id: String, modifier_id: String) -> bool:
	if not parameters.has(param_id):
		return false
	return parameters[param_id].remove_modifier(modifier_id)

# Register all default game parameters
func register_default_parameters() -> void:
	# Player parameters
	register_parameter("player.movement_speed", 4.0, "Player's base movement speed")
	register_parameter("player.mud_speed", 2.0, "Player's movement speed on mud")
	
	# Tool parameters
	register_parameter("tool.hoe.usage_time", 3.0, "Time to use the hoe")
	register_parameter("tool.seeding.usage_time", 2.0, "Time to plant seeds")
	register_parameter("tool.watering_can.capacity", 5.0, "Watering can water capacity")
	register_parameter("tool.basket.capacity", 6.0, "Basket crop capacity")
	
	# Plant parameters
	register_parameter("plant.carrot.growth_time", 20.0, "Time for carrots to grow")
	register_parameter("plant.carrot.spoil_time", 15.0, "Time before carrots spoil")
	register_parameter("plant.tomato.growth_time", 30.0, "Time for tomatoes to grow")
	register_parameter("plant.tomato.spoil_time", 15.0, "Time before tomatoes spoil")
	
	# Order parameters
	register_parameter("order.time_multiplier", 1.0, "Multiplier for order timers")
	register_parameter("order.point_multiplier", 1.0, "Multiplier for order points")
	
	print("ParameterManager: Registered default parameters")
