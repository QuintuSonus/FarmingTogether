# scripts/player/PlayerGridTracker.gd
class_name PlayerGridTracker
extends Node

# References
var player: CharacterBody3D = null
var level_manager = null
@onready var tile_highlighter = $"../TileHighlighter"
@onready var tile_targeting_point = $"../TileTargetingPoint"

# Grid position tracking
var current_grid_position: Vector3i = Vector3i(0, 0, 0)
var front_grid_position: Vector3i = Vector3i(0, 0, 0)
var current_tile_type = null

func set_level_manager(manager):
	level_manager = manager

func _process(_delta):
	update_grid_positions()
	update_tile_highlight()

# Update current and front grid positions
func update_grid_positions():
	if !level_manager:
		return
	
	# Update current grid position
	current_grid_position = level_manager.world_to_grid(player.global_position)
	current_tile_type = level_manager.get_tile_type(current_grid_position)
	
	# Update front grid position using targeting point
	if tile_targeting_point:
		var forward_point = tile_targeting_point.global_position
		front_grid_position = level_manager.world_to_grid(forward_point)
	else:
		# Fallback if targeting point doesn't exist
		var forward_offset = player.global_transform.basis.z * 1.0
		var forward_pos = player.global_position + forward_offset
		front_grid_position = level_manager.world_to_grid(forward_pos)

# Update the tile highlight based on player position and current tool
func update_tile_highlight():
	if !level_manager or !tile_targeting_point or !tile_highlighter:
		return
	
	# Check if the targeted tile is within bounds
	if level_manager.is_within_bounds(front_grid_position):
		# Get world position of this grid cell for highlighting
		var highlight_pos = level_manager.grid_to_world(front_grid_position)
		
		# Center the highlight on the tile exactly
		highlight_pos.x = float(front_grid_position.x) + 0.5
		highlight_pos.z = float(front_grid_position.z) + 0.5
		
		# Check if current tool can interact with this tile
		var can_interact = false
		var tool_handler = player.get_node_or_null("PlayerToolHandler")
		if tool_handler and tool_handler.current_tool and tool_handler.has_method("can_use_tool"):

			can_interact = tool_handler.can_use_tool(front_grid_position)
			
			# Update highlighter with interaction status
			tile_highlighter.highlight_tile(highlight_pos, can_interact)
		else:
			# No tool, use neutral highlight
			tile_highlighter.highlight_neutral(highlight_pos)
	else:
		# Hide highlighter if no valid tile in front
		tile_highlighter.hide_highlight()

# Get the current grid position
func get_grid_position() -> Vector3i:
	return current_grid_position

# Get the grid position in front of the player
func get_front_grid_position() -> Vector3i:
	return front_grid_position

# Get the type of tile at the player's position
func get_current_tile_type():
	return current_tile_type

# Get the type of tile in front of the player
func get_front_tile_type():
	if level_manager:
		return level_manager.get_tile_type(front_grid_position)
	return null
