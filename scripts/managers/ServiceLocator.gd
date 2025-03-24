# scripts/managers/ServiceLocator.gd
class_name ServiceLocator
extends Node

# Dictionary of registered services
var services = {}

# Singleton instance
static var instance = null

func _init():
	if instance == null:
		instance = self
	else:
		push_error("ServiceLocator instance already exists!")

func _ready():
	# Register self to make it accessible
	register_service("service_locator", self)

# Register a service
func register_service(service_name: String, service_instance) -> void:
	if services.has(service_name):
		push_warning("ServiceLocator: Overwriting existing service: " + service_name)
	
	services[service_name] = service_instance
	print("ServiceLocator: Registered service: " + service_name)

# Get a service
func get_service(service_name: String):
	if not services.has(service_name):
		push_error("ServiceLocator: Service not found: " + service_name)
		return null
	
	return services[service_name]

# Check if a service exists
func has_service(service_name: String) -> bool:
	return services.has(service_name)

# Remove a service
func remove_service(service_name: String) -> bool:
	if not services.has(service_name):
		return false
	
	services.erase(service_name)
	return true

# Static method to get the instance
static func get_instance() -> ServiceLocator:
	return instance

# Convenience methods to get common services
static func get_game_data() -> GameData:
	if instance == null:
		return null
	return instance.get_service("game_data")

static func get_parameter_manager() -> ParameterManager:
	if instance == null:
		return null
	return instance.get_service("parameter_manager")

static func get_level_manager():
	if instance == null:
		return null
	return instance.get_service("level_manager")

static func get_upgrade_manager():
	if instance == null:
		return null
	return instance.get_service("upgrade_manager")
