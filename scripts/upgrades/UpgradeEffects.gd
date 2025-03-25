# scripts/upgrades/UpgradeEffects.gd
class_name UpgradeEffects
extends Node

# Dependencies
var parameter_manager: ParameterManager

func _ready():
	# Get parameter manager from service locator
	var service_locator = get_node_or_null("/root/ServiceLocator")
	if service_locator:
		print("UpdateEffects : service_locator found")
		parameter_manager = service_locator.get_service("parameter_manager")
		print(parameter_manager)

# Apply all effects for an upgrade at a specific level
func apply_upgrade_effects(upgrade_data: UpgradeData, level: int):
	print("UpgradeEffects: Starting to apply effects for " + upgrade_data.name + " (Level " + str(level) + ")")
	
	if not parameter_manager:
		print("UpgradeEffects: Cannot apply effects - parameter_manager is NULL!")
		return
	
	print("UpgradeEffects: parameter_manager is valid, proceeding with effect application")
	
	# Apply effects based on upgrade type
	match upgrade_data.type:
		UpgradeData.UpgradeType.TILE:
			apply_tile_upgrade_effects(upgrade_data, level)
		UpgradeData.UpgradeType.TOOL:
			apply_tool_upgrade_effects(upgrade_data, level)
		UpgradeData.UpgradeType.PLAYER:
			apply_player_upgrade_effects(upgrade_data, level)
	
	print("UpgradeEffects: Finished applying effects for " + upgrade_data.name)

# Apply tile upgrade effects
func apply_tile_upgrade_effects(upgrade_data: UpgradeData, level: int):
	# Tile upgrades are applied when the player applies them to specific tiles
	# No global effects to apply
	
	# For upgrades that affect all tiles of a specific type, we could apply them here
	match upgrade_data.id:
		"fertile_soil":
			# This will be applied per-tile when plants grow on tiles with this upgrade
			print("UpgradeEffects: Fertile Soil effect registered")
		
		"preservation_mulch":
			# This will be applied per-tile when plants check spoil time
			print("UpgradeEffects: Preservation Mulch effect registered")
		
		"sprinkler_system":
			# This would require creating a sprinkler component for these tiles
			print("UpgradeEffects: Sprinkler System effect registered")
		
		"express_delivery_zone":
			# This will be checked when orders are delivered
			print("UpgradeEffects: Express Delivery Zone effect registered")

# Apply tool upgrade effects
func apply_tool_upgrade_effects(upgrade_data: UpgradeData, level: int):
	match upgrade_data.id:
		"well_worn_hoe":
			# Log BEFORE value
			var before_value = parameter_manager.get_value("tool.hoe.usage_time")
			print("UpgradeEffects: Hoe usage time BEFORE: " + str(before_value) + "s")
			
			# Apply the modifier
			var reduction_factor = pow(0.75, level)
			parameter_manager.add_modifier(
				"tool.hoe.usage_time",
				"upgrade.well_worn_hoe",
				reduction_factor,
				GameParameter.ModifierType.MULTIPLY
			)
			
			# Log AFTER value
			var after_value = parameter_manager.get_value("tool.hoe.usage_time")
			print("UpgradeEffects: Hoe usage time AFTER: " + str(after_value) + "s")
			
		"large_watering_can":
			# Increase watering can capacity
			parameter_manager.add_modifier(
				"tool.watering_can.capacity",
				"upgrade.large_watering_can",
				2.0 * level, # +2 per level
				GameParameter.ModifierType.ADDITIVE
			)
			 # Update existing watering cans in the scene
			update_existing_watering_cans()
			
		"extended_basket":
			# Increase basket capacity
			parameter_manager.add_modifier(
				"tool.basket.capacity",
				"upgrade.extended_basket",
				2.0 * level, # +2 per level
				GameParameter.ModifierType.ADDITIVE
			)
			
		"rapid_seeder":
			# Reduce seed planting time
			parameter_manager.add_modifier(
				"tool.seeding.usage_time",
				"upgrade.rapid_seeder",
				0.7, # 30% reduction
				GameParameter.ModifierType.MULTIPLY
			)
			
		"hose_attachment":
			# This would require modifying the watering can's use behavior
			# We'll set a parameter to indicate this upgrade is active
			parameter_manager.add_modifier(
				"tool.watering_can.area_effect",
				"upgrade.hose_attachment",
				1.0, # Flag to indicate active
				GameParameter.ModifierType.SET
			)
			print("UpgradeEffects: Hose Attachment upgrade applied - watering can now waters adjacent tiles")
			# Update existing watering cans in the scene
			update_existing_watering_cans()

# Apply player upgrade effects
func apply_player_upgrade_effects(upgrade_data: UpgradeData, level: int):
	match upgrade_data.id:
		"running_shoes":
			# Increase movement speed

			parameter_manager.add_modifier(
				"player.movement_speed",
				"upgrade.running_shoes",
				1.15**level, # 15% increase per level
				GameParameter.ModifierType.MULTIPLY
			)
			
			# Also apply to mud speed
			parameter_manager.add_modifier(
				"player.mud_speed",
				"upgrade.running_shoes",
				1.15, # 15% increase
				GameParameter.ModifierType.MULTIPLY
			)
			
		"tool_belt":
			# This would require modifying the player's tool handler
			# We'll set a parameter to indicate this upgrade is active
			parameter_manager.add_modifier(
				"player.tool_belt_capacity",
				"upgrade.tool_belt",
				2.0, # Allow carrying 2 tools
				GameParameter.ModifierType.SET
			)
			
		"energy_drink":
			# Reduce all tool usage times
			parameter_manager.add_modifier(
				"tool.global.usage_time_multiplier",
				"upgrade.energy_drink",
				0.9**level, # 10% faster
				GameParameter.ModifierType.MULTIPLY
			)
			
		"order_insight":
			# Increase order timers
			parameter_manager.add_modifier(
				"order.time_multiplier",
				"upgrade.order_insight",
				1.2**level, # 20% more time per level
				GameParameter.ModifierType.MULTIPLY
			)
			
		"experience_badge":
			# Increase currency earned
			parameter_manager.add_modifier(
				"currency.earning_multiplier",
				"upgrade.experience_badge",
				1.1, # 10% more currency
				GameParameter.ModifierType.MULTIPLY
			)

func update_existing_watering_cans():
	# Find all watering cans in the scene
	var watering_cans = get_tree().get_nodes_in_group("watering_can_tools")
	
	for can in watering_cans:
		if can.has_method("update_water_capacity_from_parameters"):
			can.update_water_capacity_from_parameters()
			print("UpgradeEffects: Updated existing watering can")
