# scripts/upgrades/UpgradeRegistry.gd
class_name UpgradeRegistry
extends Node

# Dictionary of all possible upgrades
var all_upgrades = {}

func _ready():
	print("UpgradeRegistry ready")

# Initialize with all upgrades
func initialize():
	# Clear existing upgrades
	all_upgrades.clear()
	
	# Register all upgrades
	UpgradeDefinitions.register_all_upgrades(self)
	
	print("UpgradeRegistry: Initialized with " + str(all_upgrades.size()) + " upgrades")

# Register an upgrade
func register_upgrade(upgrade: UpgradeData):
	if all_upgrades.has(upgrade.id):
		push_warning("UpgradeRegistry: Overwriting existing upgrade: " + upgrade.id)
	
	all_upgrades[upgrade.id] = upgrade
	print("UpgradeRegistry: Registered upgrade: " + upgrade.name + " (" + upgrade.id + ")")

# Get an upgrade by ID
func get_upgrade(id: String) -> UpgradeData:
	if not all_upgrades.has(id):
		push_error("UpgradeRegistry: Upgrade not found: " + id)
		return null
	
	return all_upgrades[id]

# Get all upgrades
func get_all_upgrades() -> Dictionary:
	return all_upgrades

# Get upgrades by type
func get_upgrades_by_type(type: int) -> Array:
	var result = []
	for upgrade in all_upgrades.values():
		if upgrade.type == type:
			result.append(upgrade)
	return result

# Get available upgrades (not at max level)
func get_available_upgrades(current_levels: Dictionary) -> Array:
	var result = []
	for upgrade in all_upgrades.values():
		var current_level = current_levels.get(upgrade.id, 0)
		if current_level < upgrade.max_level:
			result.append(upgrade)
	return result
