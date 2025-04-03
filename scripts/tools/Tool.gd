# res://scripts/tools/Tool.gd
# Base class for all tools in the game. Handles pickup interaction
# and provides the framework for the data-driven interaction system.
class_name Tool
extends RigidBody3D

# --- NEW: List of possible interactions this tool can perform ---
# Assign InteractionDefinition resources (.tres files) to this array in the Inspector.
# These define what the tool can do, to what target, how long it takes, and what effect it has.
@export var possible_interactions: Array[InteractionDefinition]
@onready var mesh_instance = $MeshInstance3D

# --- Properties for restoring state when dropped ---
var original_parent = null
var original_freeze = false
var original_collision_layer = 0
var original_collision_mask = 0

func _ready():
	# Add to the 'interactables' group so the player's InteractionManager can detect it for pickup.
	add_to_group("interactables")
	# Set collision layer/mask for physics and interaction detection.
	# Layer 2: Interactables (so player raycast can hit it)
	# Mask 1: World (so it collides with the ground)
	set_collision_layer_value(2, true)
	set_collision_mask_value(1, true)
	# Tools start non-frozen (can be pushed around) until picked up.
	freeze = false
	# Ensure the 'possible_interactions' array is initialized, even if not set in the editor.
	if possible_interactions == null:
		possible_interactions = []

# --- Tool Capabilities ---
# Returns a bitmask representing the fundamental abilities of this tool.
# This is overridden by specific tool types (Hoe, WateringCan, etc.).
func get_capabilities() -> int:
	# Base tool has no specific capabilities.
	return ToolCapabilities.Capability.NONE

# --- Interactable Implementation (for Tool Pickup) ---

# Determines if an actor (player) can interact with this tool (for picking it up).
func can_interact(actor):
	# Check if the actor is already holding this specific tool instance.
	if actor.has_method("get_current_tool"):
		return actor.get_current_tool() != self
	# If the actor isn't holding this tool, they can interact to pick it up.
	return true

# Returns the interaction type for picking up the tool.
func get_interaction_type():
	# Picking up a tool is always an instantaneous action.
	return Interactable.InteractionType.INSTANTANEOUS

# Returns the text prompt displayed when the player looks at the tool on the ground.
func get_interaction_prompt():
	return "Pick Up" # Simple prompt for pickup.

# Returns the priority for this interaction (pickup).
func get_priority():
	# Tools on the ground should have a higher priority than other interactables like plants.
	return 2.0

# Executes the pickup interaction.
func interact(actor, _progress = 1.0):
	# Called by InteractionManager when the player interacts with the tool on the ground.
	# Delegates the actual pickup logic to the actor (player).
	if actor.has_method("pick_up_tool"):
		actor.pick_up_tool(self)
		return true # Indicate interaction was successful.
	return false # Actor couldn't pick up the tool.

# --- REFACTORED: Tool Usage Logic (Data-Driven) ---

# Determines the type of target at the given grid position.
# This function needs access to game state (LevelManager, plants) to identify the target.
# Returns a String identifier (e.g., "DirtTile", "PlantSeed", "WaterTile").
func _get_target_type(target_position: Vector3i) -> String:
	# Attempt to get the LevelManager (assuming it's accessible, e.g., via Autoload or /root).
	var level_manager = get_node_or_null("/root/Main/LevelManager")
	if not level_manager:
		push_warning("Tool._get_target_type: LevelManager not found!")
		return "Unknown"

	# --- Priority 1: Check for specific interactable nodes (like Plants) at the position ---
	# This part requires a robust way to find nodes at a specific grid position.
	# A spatial query or iterating through relevant groups (like "plants") is needed.
	# Example implementation (assuming plants are in the "plants" group):
	for obj in get_tree().get_nodes_in_group("plants"):
		# Ensure object is valid and is a Plant before accessing properties
		if not is_instance_valid(obj) or not obj is Plant:
			continue

		# Get the grid position of the plant
		var plant_grid_pos = level_manager.world_to_grid(obj.global_position)

		# If the plant is at the target position, determine its state
		if plant_grid_pos == target_position:
			match obj.current_stage:
				Plant.GrowthStage.SEED:
					# Distinguish between watered and unwatered seeds if necessary
					# For now, just identifying it as a seed might be enough for watering.
					return "PlantSeed" # Target is a seed that might need watering.
				Plant.GrowthStage.HARVESTABLE:
					return "PlantHarvestable" # Target is ready to be harvested.
				Plant.GrowthStage.SPOILED:
					return "PlantSpoiled" # Target is a spoiled plant (for Hoe cleanup).
				_:
					return "PlantOther" # Growing or other state.

	# --- Priority 2: If no specific interactable found, check the tile type ---
	var tile_type_enum = level_manager.get_tile_type(target_position)

	# Match the tile enum value to return a string identifier.
	match tile_type_enum:
		level_manager.TileType.DIRT_GROUND, \
		level_manager.TileType.DIRT_FERTILE, \
		level_manager.TileType.DIRT_PRESERVED, \
		level_manager.TileType.DIRT_PERSISTENT:
			return "DirtTile" # Any type of dirt that can be tilled.
		level_manager.TileType.SOIL:
			# Note: The check for spoiled plants was moved to Priority 1.
			# If we reach here, it's soil without a spoiled plant.
			return "SoilTile" # Soil ready for planting.
		level_manager.TileType.WATER:
			return "WaterTile" # Water source for refilling.
		level_manager.TileType.DELIVERY, \
		level_manager.TileType.DELIVERY_EXPRESS:
			return "DeliveryTile" # For delivering orders with the basket.
		# Add cases for other tile types (Mud, RegularGround, etc.) if needed.
		_:
			return "OtherTile" # Default for unrecognized or non-interactive tiles.


# Checks the tool's 'possible_interactions' list to find a valid action
# for the determined target type at the given position.
# Returns the InteractionDefinition resource if a valid interaction is found, otherwise null.
func get_valid_interaction(target_position: Vector3i) -> InteractionDefinition:
	# Determine what kind of target we are looking at.
	var target_type: String = _get_target_type(target_position)
	# Get the capabilities of this specific tool instance.
	var tool_caps: int = get_capabilities()

	# Iterate through all interactions defined for this tool.
	for interaction_def in possible_interactions:
		# Skip if the resource assigned in the editor is invalid or null.
		if not is_instance_valid(interaction_def):
			push_warning("Tool %s has an invalid InteractionDefinition resource in its list." % name)
			continue

		# Check 1: Does the interaction's required target type match the actual target?
		# "Any" acts as a wildcard, matching any target type.
		var target_match: bool = (interaction_def.required_target_type == "Any" or \
								  interaction_def.required_target_type == target_type)

		# Check 2: Does the tool have the capability required by this interaction?
		# Capability.NONE acts as a wildcard, meaning no specific capability is needed.
		var capability_match: bool = (interaction_def.required_tool_capability == ToolCapabilities.Capability.NONE or \
									  ToolCapabilities.has_capability(tool_caps, interaction_def.required_tool_capability))

		# If both target and capability requirements are met...
		if target_match and capability_match:
			# ...then this is a valid interaction for the current context. Return its definition.
			# print("Tool %s found valid interaction '%s' for target '%s'" % [name, interaction_def.interaction_id, target_type]) # Optional Debug
			return interaction_def

	# If the loop finishes without finding a match, no valid interaction exists.
	# print("Tool %s found NO valid interaction for target '%s'" % [name, target_type]) # Optional Debug
	return null


# Called by PlayerToolHandler after an interaction (instant or progress-based) completes.
# Finds the correct InteractionDefinition based on the ID and calls the associated effect function.
func complete_interaction_effect(target_position: Vector3i, interaction_id: String):
	var interaction_def: InteractionDefinition = null
	# Find the InteractionDefinition resource that matches the ID of the interaction that was started.
	for definition in possible_interactions:
		if is_instance_valid(definition) and definition.interaction_id == interaction_id:
			interaction_def = definition
			break # Found the matching definition.

	# If no matching definition was found (shouldn't normally happen if start_tool_use worked).
	if not interaction_def:
		push_error("Tool %s cannot complete unknown interaction_id: %s" % [name, interaction_id])
		return

	# Get the name of the function to call from the definition.
	var effect_func_name: String = interaction_def.effect_function_name

	# Check if this tool's script actually has the specified effect function.
	if has_method(effect_func_name):
		# Call the effect function, passing the target position.
		# This executes the actual game logic (tilling, watering, filling, etc.).
		print("Tool %s executing effect '%s' for interaction '%s' at %s" % [name, effect_func_name, interaction_id, str(target_position)])
		call(effect_func_name, target_position)
	else:
		# Log a warning if the function is missing - indicates a setup error.
		push_warning("Tool %s has interaction '%s' but is missing effect function: %s" % [name, interaction_id, effect_func_name])


# --- Default Effect Function ---
# A fallback function called if an InteractionDefinition specifies this name
# and the specific tool doesn't override it or implement the specified function.
func _default_effect(target_position: Vector3i):
	print("Tool %s used default effect at %s (InteractionDefinition might need specific effect_function_name)" % [name, str(target_position)])


# --- Other Helper Functions ---

# Optional visual feedback when the player looks at the tool.
func set_highlighted(is_highlighted: bool):
	#if not mesh_instance:
		#return
		#
	#if is_highlighted:
		#mesh_instance.scale = Vector3(1.1, 1.1, 1.1)
	#else:
		#mesh_instance.scale = Vector3.ONE
	pass

# Gets the global tool speed multiplier (e.g., from "Energy Drink" upgrade).
func get_global_tool_speed_multiplier() -> float:
	var parameter_manager = get_parameter_manager()
	if parameter_manager:
		# Parameter ID should match what UpgradeEffects uses.
		# Returns 1.0 if parameter doesn't exist or manager not found.
		return parameter_manager.get_value("tool.global.usage_time_multiplier", 1.0)
	return 1.0

# Helper to get the ParameterManager (assuming ServiceLocator or Autoload).
func get_parameter_manager():
	# Assumes ParameterManager is an Autoload singleton.
	if Engine.has_singleton("ParameterManager"):
		return Engine.get_singleton("ParameterManager")
	# Fallback: Try finding via ServiceLocator pattern if still used.
	# var service_locator = get_node_or_null("/root/ServiceLocator")
	# if service_locator and service_locator.has_method("get_service"):
	#     return service_locator.get_service("parameter_manager")
	push_warning("Tool: ParameterManager not found (Autoload or ServiceLocator).")
	return null
