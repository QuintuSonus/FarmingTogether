# scripts/upgrades/UpgradeData.gd
class_name UpgradeData
extends Resource

enum UpgradeType {
	TILE,
	TOOL,
	PLAYER
}

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var cost: int = 100
@export var type: UpgradeType = UpgradeType.TILE
@export var max_level: int = 1
@export var icon_path: String = ""
@export var effects: Dictionary = {}  # Parameters that this upgrade modifies

func _init():
	# Default initialization
	pass

func get_effect(key: String, default_value = 0):
	if effects.has(key):
		return effects[key]
	return default_value

func get_scaled_effect(key: String, level: int, default_value = 0):
	var base_value = get_effect(key, default_value)
	
	# If the key indicates a multiplier, apply it multiple times for each level
	if key.ends_with("_multiplier"):
		return pow(base_value, level)
	
	# For additive effects, simply multiply by level
	if key.ends_with("_additional") or is_additive_effect(key):
		return base_value * level
	
	# Boolean effects (on/off flags) are true if level > 0
	if typeof(base_value) == TYPE_BOOL:
		return level > 0
	
	# Default: just return the base value
	return base_value

func is_additive_effect(key: String) -> bool:
	# List of keys that should be treated as additive
	var additive_keys = [
		"additional_capacity",
		"tool_slots",
		"persistent_soil_tiles"
	]
	
	return additive_keys.has(key)
