# scripts/tools/ToolCapabilities.gd
class_name ToolCapabilities

# Define all possible tool capabilities
enum Capability {
	NONE = 0,
	TILL_SOIL = 1,
	PLANT_SEEDS = 2,
	WATER_PLANTS = 4,
	HARVEST_CROPS = 8,
	DELIVER_ORDERS = 16
	# Add more as needed
}

# Static helper functions
static func has_capability(capabilities: int, capability: int) -> bool:
	return (capabilities & capability) != 0
