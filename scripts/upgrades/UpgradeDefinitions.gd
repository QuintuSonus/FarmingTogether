# scripts/upgrades/UpgradeDefinitions.gd
class_name UpgradeDefinitions
extends Node

# Register all upgrades with the upgrade registry
static func register_all_upgrades(registry: UpgradeRegistry):
	print("UpgradeDefinitions: Registering all upgrades...")
	
	# Register all tile upgrades
	registry.register_upgrade(create_fertile_soil())
	registry.register_upgrade(create_preservation_mulch())
	registry.register_upgrade(create_sprinkler_system())
	registry.register_upgrade(create_express_delivery())
	registry.register_upgrade(create_crop_rotation())
	registry.register_upgrade(create_quality_control())
	registry.register_upgrade(create_greenhouse())
	
	# Register all tool upgrades
	registry.register_upgrade(create_well_worn_hoe())
	registry.register_upgrade(create_large_watering_can())
	registry.register_upgrade(create_extended_basket())
	registry.register_upgrade(create_rapid_seeder())
	registry.register_upgrade(create_hose_attachment())
	registry.register_upgrade(create_crop_scanner())
	registry.register_upgrade(create_garden_gloves())
	
	# Register all player upgrades
	registry.register_upgrade(create_running_shoes())
	registry.register_upgrade(create_tool_belt())
	registry.register_upgrade(create_energy_drink())
	registry.register_upgrade(create_order_insight())
	registry.register_upgrade(create_farm_layout_memory())
	registry.register_upgrade(create_experience_badge())
	
	print("UpgradeDefinitions: Registered " + str(registry.get_all_upgrades().size()) + " upgrades")

# ---- TILE UPGRADES ----

static func create_fertile_soil() -> UpgradeData:
	var upgrade = UpgradeData.new()
	upgrade.id = "fertile_soil"
	upgrade.name = "Fertile Soil"
	upgrade.description = "Crops planted on enhanced soil grow 20% faster."
	upgrade.cost = 300
	upgrade.type = UpgradeData.UpgradeType.TILE
	upgrade.max_level = 1
	upgrade.effects = {"growth_speed_multiplier": 1.2}
	upgrade.icon_path = "res://assets/textures/upgrades/fertile_soil_icon.png"
	return upgrade

static func create_preservation_mulch() -> UpgradeData:
	var upgrade = UpgradeData.new()
	upgrade.id = "preservation_mulch"
	upgrade.name = "Preservation Mulch"
	upgrade.description = "Increases time before crops spoil by 25%."
	upgrade.cost = 250
	upgrade.type = UpgradeData.UpgradeType.TILE
	upgrade.max_level = 1
	upgrade.effects = {"spoil_time_multiplier": 1.25}
	upgrade.icon_path = "res://assets/textures/upgrades/preservation_mulch_icon.png"
	return upgrade

static func create_sprinkler_system() -> UpgradeData:
	var upgrade = UpgradeData.new()
	upgrade.id = "sprinkler_system"
	upgrade.name = "Sprinkler System"
	upgrade.description = "Automatically waters adjacent soil tiles every 30 seconds."
	upgrade.cost = 500
	upgrade.type = UpgradeData.UpgradeType.TILE
	upgrade.max_level = 1
	upgrade.effects = {"auto_water": true}
	upgrade.icon_path = "res://assets/textures/upgrades/sprinkler_system_icon.png"
	return upgrade

static func create_express_delivery() -> UpgradeData:
	var upgrade = UpgradeData.new()
	upgrade.id = "express_delivery"
	upgrade.name = "Express Delivery Zone"
	upgrade.description = "Orders completed at upgraded delivery tiles earn 15% more points."
	upgrade.cost = 400
	upgrade.type = UpgradeData.UpgradeType.TILE
	upgrade.max_level = 1
	upgrade.effects = {"order_score_multiplier": 1.15}
	upgrade.icon_path = "res://assets/textures/upgrades/express_delivery_icon.png"
	return upgrade

static func create_crop_rotation() -> UpgradeData:
	var upgrade = UpgradeData.new()
	upgrade.id = "crop_rotation"
	upgrade.name = "Crop Rotation Plot"
	upgrade.description = "Soil that can be replanted immediately after harvesting without requiring hoe use."
	upgrade.cost = 350
	upgrade.type = UpgradeData.UpgradeType.TILE
	upgrade.max_level = 1
	upgrade.effects = {"skip_tilling": true}
	upgrade.icon_path = "res://assets/textures/upgrades/crop_rotation_icon.png"
	return upgrade

static func create_quality_control() -> UpgradeData:
	var upgrade = UpgradeData.new()
	upgrade.id = "quality_control"
	upgrade.name = "Quality Control Station"
	upgrade.description = "Crops delivered from this tile have a 10% chance of counting as double for order fulfillment."
	upgrade.cost = 450
	upgrade.type = UpgradeData.UpgradeType.TILE
	upgrade.max_level = 1
	upgrade.effects = {"double_crop_chance": 0.1}
	upgrade.icon_path = "res://assets/textures/upgrades/quality_control_icon.png"
	return upgrade

static func create_greenhouse() -> UpgradeData:
	var upgrade = UpgradeData.new()
	upgrade.id = "greenhouse"
	upgrade.name = "Greenhouse Tile"
	upgrade.description = "Protected growing environment with 30% faster growth and 50% longer spoil times."
	upgrade.cost = 700
	upgrade.type = UpgradeData.UpgradeType.TILE
	upgrade.max_level = 1
	upgrade.effects = {
		"growth_speed_multiplier": 1.3,
		"spoil_time_multiplier": 1.5
	}
	upgrade.icon_path = "res://assets/textures/upgrades/greenhouse_icon.png"
	return upgrade

# ---- TOOL UPGRADES ----

static func create_well_worn_hoe() -> UpgradeData:
	var upgrade = UpgradeData.new()
	upgrade.id = "well_worn_hoe"
	upgrade.name = "Well-Worn Hoe"
	upgrade.description = "Reduces soil tilling time by 25%."
	upgrade.cost = 200
	upgrade.type = UpgradeData.UpgradeType.TOOL
	upgrade.max_level = 4
	upgrade.effects = {"tilling_time_multiplier": 0.75}
	upgrade.icon_path = "res://assets/textures/upgrades/well_worn_hoe_icon.png"
	return upgrade

static func create_large_watering_can() -> UpgradeData:
	var upgrade = UpgradeData.new()
	upgrade.id = "large_watering_can"
	upgrade.name = "Large Watering Can"
	upgrade.description = "Increases water capacity by 2 uses before refilling."
	upgrade.cost = 250
	upgrade.type = UpgradeData.UpgradeType.TOOL
	upgrade.max_level = 5
	upgrade.effects = {"additional_capacity": 2.0}
	upgrade.icon_path = "res://assets/textures/upgrades/large_watering_can_icon.png"
	return upgrade

static func create_extended_basket() -> UpgradeData:
	var upgrade = UpgradeData.new()
	upgrade.id = "extended_basket"
	upgrade.name = "Extended Basket"
	upgrade.description = "Increases basket capacity by 2 slots."
	upgrade.cost = 300
	upgrade.type = UpgradeData.UpgradeType.TOOL
	upgrade.max_level = 2
	upgrade.effects = {"additional_capacity": 2.0}
	upgrade.icon_path = "res://assets/textures/upgrades/extended_basket_icon.png"
	return upgrade

static func create_rapid_seeder() -> UpgradeData:
	var upgrade = UpgradeData.new()
	upgrade.id = "rapid_seeder"
	upgrade.name = "Rapid Seeder"
	upgrade.description = "Reduces seed planting time by 30%."
	upgrade.cost = 200
	upgrade.type = UpgradeData.UpgradeType.TOOL
	upgrade.max_level = 2
	upgrade.effects = {"planting_time_multiplier": 0.7}
	upgrade.icon_path = "res://assets/textures/upgrades/rapid_seeder_icon.png"
	return upgrade

static func create_hose_attachment() -> UpgradeData:
	var upgrade = UpgradeData.new()
	upgrade.id = "hose_attachment"
	upgrade.name = "Hose Attachment"
	upgrade.description = "Watering can now waters in a small area (the target tile plus adjacent tiles)."
	upgrade.cost = 400
	upgrade.type = UpgradeData.UpgradeType.TOOL
	upgrade.max_level = 1
	upgrade.effects = {"area_watering": true}
	upgrade.icon_path = "res://assets/textures/upgrades/hose_attachment_icon.png"
	return upgrade

static func create_crop_scanner() -> UpgradeData:
	var upgrade = UpgradeData.new()
	upgrade.id = "crop_scanner"
	upgrade.name = "Crop Scanner"
	upgrade.description = "Shows exact growth percentage and time remaining when hovering over plants."
	upgrade.cost = 150
	upgrade.type = UpgradeData.UpgradeType.TOOL
	upgrade.max_level = 1
	upgrade.effects = {"show_growth_info": true}
	upgrade.icon_path = "res://assets/textures/upgrades/crop_scanner_icon.png"
	return upgrade

static func create_garden_gloves() -> UpgradeData:
	var upgrade = UpgradeData.new()
	upgrade.id = "garden_gloves"
	upgrade.name = "Garden Gloves"
	upgrade.description = "Harvest crops 25% faster."
	upgrade.cost = 250
	upgrade.type = UpgradeData.UpgradeType.TOOL
	upgrade.max_level = 1
	upgrade.effects = {"harvest_time_multiplier": 0.75}
	upgrade.icon_path = "res://assets/textures/upgrades/garden_gloves_icon.png"
	return upgrade

# ---- PLAYER UPGRADES ----

static func create_running_shoes() -> UpgradeData:
	var upgrade = UpgradeData.new()
	upgrade.id = "running_shoes"
	upgrade.name = "Running Shoes"
	upgrade.description = "Increases movement speed by 15%."
	upgrade.cost = 300
	upgrade.type = UpgradeData.UpgradeType.PLAYER
	upgrade.max_level = 2
	upgrade.effects = {"speed_multiplier": 1.15}
	upgrade.icon_path = "res://assets/textures/upgrades/running_shoes_icon.png"
	return upgrade

static func create_tool_belt() -> UpgradeData:
	var upgrade = UpgradeData.new()
	upgrade.id = "tool_belt"
	upgrade.name = "Tool Belt"
	upgrade.description = "Allows carrying two tools at once (quick swap with Tab key)."
	upgrade.cost = 500
	upgrade.type = UpgradeData.UpgradeType.PLAYER
	upgrade.max_level = 1
	upgrade.effects = {"tool_slots": 2}
	upgrade.icon_path = "res://assets/textures/upgrades/tool_belt_icon.png"
	return upgrade

static func create_energy_drink() -> UpgradeData:
	var upgrade = UpgradeData.new()
	upgrade.id = "energy_drink"
	upgrade.name = "Energy Drink"
	upgrade.description = "All tool usage is 10% faster."
	upgrade.cost = 350
	upgrade.type = UpgradeData.UpgradeType.PLAYER
	upgrade.max_level = 2
	upgrade.effects = {"tool_speed_multiplier": 1.1}
	upgrade.icon_path = "res://assets/textures/upgrades/energy_drink_icon.png"
	return upgrade

static func create_order_insight() -> UpgradeData:
	var upgrade = UpgradeData.new()
	upgrade.id = "order_insight"
	upgrade.name = "Order Insight"
	upgrade.description = "Orders remain visible 20% longer before expiring."
	upgrade.cost = 250
	upgrade.type = UpgradeData.UpgradeType.PLAYER
	upgrade.max_level = 1
	upgrade.effects = {"order_time_multiplier": 1.2}
	upgrade.icon_path = "res://assets/textures/upgrades/order_insight_icon.png"
	return upgrade

static func create_farm_layout_memory() -> UpgradeData:
	var upgrade = UpgradeData.new()
	upgrade.id = "farm_layout_memory"
	upgrade.name = "Farm Layout Memory"
	upgrade.description = "After level completion, up to 3 soil tiles remain tilled for the next run."
	upgrade.cost = 200
	upgrade.type = UpgradeData.UpgradeType.PLAYER
	upgrade.max_level = 3
	upgrade.effects = {"persistent_soil_tiles": 1}
	upgrade.icon_path = "res://assets/textures/upgrades/farm_layout_memory_icon.png"
	return upgrade

static func create_experience_badge() -> UpgradeData:
	var upgrade = UpgradeData.new()
	upgrade.id = "experience_badge"
	upgrade.name = "Experience Badge"
	upgrade.description = "Earn 10% more currency from completed levels."
	upgrade.cost = 400
	upgrade.type = UpgradeData.UpgradeType.PLAYER
	upgrade.max_level = 2
	upgrade.effects = {"currency_multiplier": 1.1}
	upgrade.icon_path = "res://assets/textures/upgrades/experience_badge_icon.png"
	return upgrade
