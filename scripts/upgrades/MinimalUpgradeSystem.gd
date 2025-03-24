# scripts/managers/MinimalUpgradeSystem.gd
# This is a minimal implementation for testing the upgrade UI
# It doesn't require all the refactoring and can work with the existing FarmData

class_name MinimalUpgradeSystem
extends Node

# Components
var upgrade_registry: UpgradeRegistry

# Farm data reference
var farm_data = null

func _ready():
	print("MinimalUpgradeSystem initializing...")
	
	# Create and initialize the upgrade registry
	upgrade_registry = UpgradeRegistry.new()
	add_child(upgrade_registry)
	upgrade_registry.initialize()
	
	# Try to find farm data
	var farm_layout_manager = get_node_or_null("/root/Main/FarmLayoutManager") 
	if farm_layout_manager:
		farm_data = farm_layout_manager.farm_data
		print("MinimalUpgradeSystem: Got farm_data from FarmLayoutManager")
	
	if not farm_data:
		# Try direct loading
		farm_data = FarmData.load_data()
		print("MinimalUpgradeSystem: Loaded farm_data directly")
	
	# Initialize purchased_upgrades in farm_data if it doesn't exist
	if farm_data and not "purchased_upgrades" in farm_data:
		farm_data.purchased_upgrades = {}
		print("MinimalUpgradeSystem: Created purchased_upgrades in farm_data")
	
	# Initialize tile_upgrades in farm_data if it doesn't exist
	if farm_data and not "tile_upgrades" in farm_data:
		farm_data.tile_upgrades = {}
		print("MinimalUpgradeSystem: Created tile_upgrades in farm_data")
	
	print("MinimalUpgradeSystem initialization complete")

# Apply all purchased upgrades
func apply_all_upgrades():
	if not farm_data or not "purchased_upgrades" in farm_data:
		push_error("MinimalUpgradeSystem: Cannot apply upgrades - farm_data not available")
		return
	
	print("MinimalUpgradeSystem: Applying all purchased upgrades")
	
	# In this minimal version, we just print the upgrades
	# A full implementation would apply the effects
	for upgrade_id in farm_data.purchased_upgrades:
		var level = farm_data.purchased_upgrades[upgrade_id]
		if level > 0:
			var upgrade = upgrade_registry.get_upgrade(upgrade_id)
			if upgrade:
				print("MinimalUpgradeSystem: Applied upgrade " + upgrade.name + " (Level " + str(level) + ")")

# Apply an upgrade to a specific tile
func apply_upgrade_to_tile(tile_pos: Vector3i, upgrade_id: String) -> bool:
	if not farm_data or not "tile_upgrades" in farm_data:
		push_error("MinimalUpgradeSystem: Cannot apply tile upgrade - farm_data not available")
		return false
	
	var upgrade = upgrade_registry.get_upgrade(upgrade_id)
	if not upgrade or upgrade.type != UpgradeData.UpgradeType.TILE:
		return false
	
	# Check if player has purchased this upgrade
	var level = get_upgrade_level(upgrade_id)
	if level <= 0:
		return false
	
	# Record that this tile has this upgrade
	var pos_key = str(tile_pos.x) + "," + str(tile_pos.z)
	
	if not farm_data.tile_upgrades.has(pos_key):
		farm_data.tile_upgrades[pos_key] = {}
	
	farm_data.tile_upgrades[pos_key][upgrade_id] = level
	farm_data.save()
	
	print("MinimalUpgradeSystem: Applied " + upgrade.name + " to tile at " + pos_key)
	return true

# Purchase an upgrade
func purchase_upgrade(upgrade_id: String) -> bool:
	if not farm_data:
		push_error("MinimalUpgradeSystem: Cannot purchase upgrade - farm_data not available")
		return false
	
	var upgrade = upgrade_registry.get_upgrade(upgrade_id)
	if not upgrade:
		push_error("MinimalUpgradeSystem: Unknown upgrade ID: " + upgrade_id)
		return false
	
	# Check if player has enough currency
	if farm_data.currency < upgrade.cost:
		print("MinimalUpgradeSystem: Not enough currency to purchase " + upgrade.name)
		return false
	
	# Check if upgrade is already at max level
	var current_level = get_upgrade_level(upgrade_id)
	if current_level >= upgrade.max_level:
		print("MinimalUpgradeSystem: " + upgrade.name + " already at max level")
		return false
	
	# Purchase the upgrade
	farm_data.currency -= upgrade.cost
	
	# Ensure purchased_upgrades exists
	if not "purchased_upgrades" in farm_data:
		farm_data.purchased_upgrades = {}
		
	farm_data.purchased_upgrades[upgrade_id] = current_level + 1
	farm_data.save()
	
	print("MinimalUpgradeSystem: Purchased " + upgrade.name + " (Level " + str(current_level + 1) + ")")
	
	# Apply the upgrade
	apply_all_upgrades()
	
	return true

# Get the current level of an upgrade
func get_upgrade_level(upgrade_id: String) -> int:
	if not farm_data or not "purchased_upgrades" in farm_data:
		return 0
	
	return farm_data.purchased_upgrades.get(upgrade_id, 0)
