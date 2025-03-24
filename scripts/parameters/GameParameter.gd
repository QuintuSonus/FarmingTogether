# scripts/parameters/GameParameter.gd
class_name GameParameter
extends Resource

# Base parameter properties
@export var id: String
@export var base_value: float
@export var description: String = ""

# List of modifiers applied to this parameter
var modifiers = []  # Array of dictionaries with {id, value, type}

# Modifier types
enum ModifierType {
	ADDITIVE,    # Adds to the base value
	MULTIPLY,    # Multiplies the result (applied after additive)
	SET,         # Sets an absolute value (overrides everything)
	MINIMUM,     # Sets a minimum value
	MAXIMUM      # Sets a maximum value
}

# Get the final calculated value
func get_value() -> float:
	# Start with base value
	var result = base_value
	
	# Apply additive modifiers first
	for mod in modifiers:
		if mod.type == ModifierType.ADDITIVE:
			result += mod.value
	
	# Apply multiplicative modifiers
	for mod in modifiers:
		if mod.type == ModifierType.MULTIPLY:
			result *= mod.value
	
	# Apply minimum and maximum constraints
	var min_value = -INF
	var max_value = INF
	
	for mod in modifiers:
		if mod.type == ModifierType.MINIMUM and mod.value > min_value:
			min_value = mod.value
		elif mod.type == ModifierType.MAXIMUM and mod.value < max_value:
			max_value = mod.value
	
	result = clamp(result, min_value, max_value)
	
	# Apply SET modifiers last (they override everything)
	for mod in modifiers:
		if mod.type == ModifierType.SET:
			result = mod.value
			break  # Only apply the last SET modifier
	
	return result

# Add a new modifier
func add_modifier(id: String, value: float, type: int = ModifierType.MULTIPLY) -> void:
	# Remove existing modifier with same ID if it exists
	remove_modifier(id)
	
	# Add the new modifier
	modifiers.append({
		"id": id,
		"value": value,
		"type": type
	})

# Remove a modifier by ID
func remove_modifier(id: String) -> bool:
	for i in range(modifiers.size() - 1, -1, -1):
		if modifiers[i].id == id:
			modifiers.remove_at(i)
			return true
	return false

# Reset all modifiers
func reset_modifiers() -> void:
	modifiers.clear()
