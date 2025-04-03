# res://scripts/interaction/InteractionDefinition.gd
# Defines the properties of a specific tool interaction.
# Create Resource files (.tres) based on this script in the Godot editor
# and assign them to the 'possible_interactions' array on your Tool scripts.
class_name InteractionDefinition
extends Resource

## Enum defining whether the interaction happens instantly or requires holding the action button.
enum InteractionType {
	INSTANT,    # Interaction completes immediately on button press.
	PROGRESS    # Interaction requires holding the button for a duration.
}

## --- Exported Properties (Editable in Godot Editor for each .tres file) ---

## A unique string identifier for this specific interaction.
## Examples: "till_soil", "water_plant", "fill_can", "harvest_carrot"
@export var interaction_id: String = "default_interaction"

## The text prompt displayed to the player when this interaction is available.
## Examples: "Till", "Water", "Refill", "Harvest"
@export var display_name: String = "Interact"

## The type of interaction (Instant or Progress-based).
@export var interaction_type: InteractionType = InteractionType.INSTANT

## The base duration in seconds required to complete the interaction.
## Only used if interaction_type is PROGRESS. This value can be modified by upgrades.
@export var duration: float = 1.0

## The ID of the parameter in ParameterManager that holds the potentially upgraded duration for this interaction.
## If empty, the base 'duration' above will be used (potentially modified only by global speed multipliers).
## Example: "tool.hoe.usage_time", "tool.seeding.usage_time"
@export var duration_parameter_id: String = ""

## Describes the required target for this interaction using a String identifier.
## The Tool script's _get_target_type() function should return one of these strings.
## Examples: "DirtTile", "SoilTile", "WaterTile", "PlantSeed", "PlantHarvestable", "PlantSpoiled", "Any"
@export var required_target_type: String = "Any"

## The specific capability the tool must possess to perform this interaction.
## Uses the ToolCapabilities.Capability enum. NONE means any tool can perform it (if target matches).
@export var required_tool_capability: ToolCapabilities.Capability = ToolCapabilities.Capability.NONE

## The exact name of the function that should be called on the *Tool's script*
## when this interaction successfully completes. This function implements the actual game logic effect.
## Example: "_effect_till_soil", "_effect_water_plant", "_effect_fill_can"
@export var effect_function_name: String = "_default_effect"

@export var animation_name : String = ""
## --- Optional Properties ---

## The name of the animation state to play on the player's AnimationTree during the interaction.
# @export var animation_name: String = ""

## An AudioStream resource to play when the interaction starts or completes.
# @export var sound_effect: AudioStream
