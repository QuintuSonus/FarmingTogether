# scripts/upgrades/UpgradeSystem.gd
class_name UpgradeSystem
extends Node

# Components
var upgrade_registry: UpgradeRegistry
var upgrade_effects: UpgradeEffects

# Service dependencies
var game_data: GameData
var parameter_manager: ParameterManager
var event_bus: EventBus

# Autoload singleton approach
static var instance = null

func _init():
	if instance == null:
		instance = self
	else:
		push_error("UpgradeSystem instance already exists!")

func _ready():
	# Create components
	upgrade_registry = UpgradeRegistry.new()
	upgrade_effects = UpgradeEffects.new()
	add_child(upgrade_registry)
	add_child(upgrade_effects)
	
	# Get service dependencies
	var service_locator = get_node_or_null("/root/ServiceLocator")
	if service_locator:
		game_data = service_locator.get_service("game_data")
		parameter_manager = service_locator.get_service("parameter_manager")
		event_bus = service_locator.get_service("event_bus")
		print(service_locator.get_service("parameter_manager"))
	if parameter_manager:
		print("UpgradeSystem: ParameterManager reference is valid")
	else:
		print("UpgradeSystem: ParameterManager reference is NULL!")
	# Register ourselves with the service locator
	if service_locator:
		service_locator.register_service("upgrade_system", self)
	
	# Initialize registry
	upgrade_registry.initialize()
	
	# Register event listeners
	if event_bus:
		event_bus.register_listener(EventBus.Events.LEVEL_COMPLETED, self, "_on_level_completed")
	
	print("UpgradeSystem initialized")

# Apply all purchased upgrades
func apply_all_upgrades():
	if not game_data or not game_data.upgrades_data:
		push_error("UpgradeSystem: Cannot apply upgrades - game_data not available")
		return
	
	print("UpgradeSystem: Applying all purchased upgrades")
	
	var upgrades = game_data.upgrades_data.purchased_upgrades
	for upgrade_id in upgrades:
		var level = upgrades[upgrade_id]
		if level > 0:
			apply_upgrade(upgrade_id, level)

# Apply a specific upgrade
func apply_upgrade(upgrade_id: String, level: int):
	var upgrade_data = upgrade_registry.get_upgrade(upgrade_id)
	if not upgrade_data:
		push_error("UpgradeSystem: Unknown upgrade ID: " + upgrade_id)
		return
	
	print("UpgradeSystem: Applying upgrade " + upgrade_data.name + " (Level " + str(level) + ")")
	
	# Apply effects based on upgrade type
	upgrade_effects.apply_upgrade_effects(upgrade_data, level)
	
	# Emit event
	if event_bus:
		event_bus.emit_event(EventBus.Events.UPGRADE_APPLIED, {
			"upgrade_id": upgrade_id,
			"level": level,
			"upgrade_data": upgrade_data
		})

# Purchase an upgrade
func purchase_upgrade(upgrade_id: String) -> bool:
	if not game_data or not game_data.upgrades_data or not game_data.progression_data:
		push_error("UpgradeSystem: Cannot purchase upgrade - game_data not available")
		return false
	
	var upgrade_data = upgrade_registry.get_upgrade(upgrade_id)
	if not upgrade_data:
		push_error("UpgradeSystem: Unknown upgrade ID: " + upgrade_id)
		return false
	
	# Check if player has enough currency
	if game_data.progression_data.currency < upgrade_data.cost:
		print("UpgradeSystem: Not enough currency to purchase " + upgrade_data.name)
		return false
	
	# Check if upgrade is already at max level
	var current_level = game_data.upgrades_data.purchased_upgrades.get(upgrade_id, 0)
	if current_level >= upgrade_data.max_level:
		print("UpgradeSystem: " + upgrade_data.name + " already at max level")
		return false
	
	# Purchase the upgrade
	game_data.progression_data.currency -= upgrade_data.cost
	game_data.upgrades_data.purchased_upgrades[upgrade_id] = current_level + 1
	
	# Save the game data
	game_data.save()
	
	print("UpgradeSystem: Purchased " + upgrade_data.name + " (Level " + str(current_level + 1) + ")")
	
	# Apply the upgrade
	apply_upgrade(upgrade_id, current_level + 1)
	
	# Emit event
	if event_bus:
		event_bus.emit_event(EventBus.Events.UPGRADE_PURCHASED, {
			"upgrade_id": upgrade_id,
			"level": current_level + 1,
			"upgrade_data": upgrade_data
		})
	
	return true

# Apply an upgrade to a specific tile
func apply_upgrade_to_tile(tile_pos: Vector3i, upgrade_id: String) -> bool:
	if not game_data or not game_data.upgrades_data:
		push_error("UpgradeSystem: Cannot apply tile upgrade - game_data not available")
		return false
	
	var upgrade_data = upgrade_registry.get_upgrade(upgrade_id)
	if not upgrade_data or upgrade_data.type != UpgradeData.UpgradeType.TILE:
		return false
	
	# Check if player has purchased this upgrade
	var level = get_upgrade_level(upgrade_id)
	if level <= 0:
		return false
	
	# Record that this tile has this upgrade
	var pos_key = str(tile_pos.x) + "," + str(tile_pos.z)
	
	if not game_data.upgrades_data.tile_upgrades.has(pos_key):
		game_data.upgrades_data.tile_upgrades[pos_key] = {}
	
	game_data.upgrades_data.tile_upgrades[pos_key][upgrade_id] = level
	
	if upgrade_id == "sprinkler_system":
	# Get reference to the sprinkler manager
		var sprinkler_manager = get_sprinkler_manager()
		if sprinkler_manager:
			# Create a sprinkler at this position
			sprinkler_manager.create_sprinkler(tile_pos)
		else:
			print("LevelEditor: Could not find SprinklerManager")
		
	game_data.save()
	
	print("UpgradeSystem: Applied " + upgrade_data.name + " to tile at " + pos_key)
	
	# Emit event
	if event_bus:
		event_bus.emit_event(EventBus.Events.TILE_MODIFIED, {
			"position": tile_pos,
			"upgrade_id": upgrade_id,
			"level": level
		})
	
	return true

# Check if a tile has a specific upgrade
func tile_has_upgrade(tile_pos: Vector3i, upgrade_id: String) -> bool:
	if not game_data or not game_data.upgrades_data:
		return false
	
	var pos_key = str(tile_pos.x) + "," + str(tile_pos.z)
	
	if not game_data.upgrades_data.tile_upgrades.has(pos_key):
		return false
	
	return game_data.upgrades_data.tile_upgrades[pos_key].has(upgrade_id)

# Get the current level of an upgrade
func get_upgrade_level(upgrade_id: String) -> int:
	if not game_data or not game_data.upgrades_data:
		return 0
	
	return game_data.upgrades_data.purchased_upgrades.get(upgrade_id, 0)

# Event handlers
func _on_level_completed(args):
	# This is called after completing a level to show the upgrade screen
	print("UpgradeSystem: Level completed - preparing upgrade screen")
	
	# Logic to show upgrade screen will be implemented here
	
# Static accessor
static func get_instance() -> UpgradeSystem:
	return instance

func get_sprinkler_manager():
	# Try through service locator first
	var service_locator = get_node_or_null("/root/ServiceLocator")
	if service_locator and service_locator.has_method("get_service"):
		var manager = service_locator.get_service("sprinkler_manager")
		if manager:
			return manager
	
	# Try direct reference next
	var main = get_node_or_null("/root/Main")
	if main:
		var manager = main.get_node_or_null("SprinklerManager")
		if manager:
			return manager
	
	return null
