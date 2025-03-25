# scripts/upgrades/Sprinkler.gd
class_name Sprinkler
extends Node3D

# Configuration
@export var watering_interval: float = 30.0  # Seconds between watering
@export var water_range: int = 1  # How many tiles away to water (1 = adjacent tiles)

# References
@onready var water_particles = $WaterParticles
@onready var watering_timer = $WateringTimer

# State
var grid_position: Vector3i
var level_manager = null

func _ready():
	# Find level manager
	level_manager = get_node("/root/Main/LevelManager")
	if not level_manager:
		level_manager = get_tree().get_root().find_child("LevelManager", true, false)
		
	if not level_manager:
		push_error("Sprinkler: Could not find LevelManager!")
		
	# Configure timer
	watering_timer.wait_time = watering_interval
	watering_timer.start()
	
	# Get our grid position from world position
	if level_manager:
		grid_position = level_manager.world_to_grid(global_position)
		print("Sprinkler initialized at grid position: ", grid_position)

# Water all adjacent tiles
func water_adjacent_tiles():
	if not level_manager:
		push_error("Sprinkler: Cannot water - level manager not found")
		return
		
	print("Sprinkler at ", grid_position, " watering adjacent tiles")
	
	# Play particle effect
	if water_particles:
		water_particles.emitting = true
	
	# Get adjacent positions
	var positions_to_water = get_adjacent_positions(grid_position)
	
	# Find plants at these positions that need watering
	var plants_watered = 0
	
	for pos in positions_to_water:
		# Only water soil tiles - check the tile type first
		if level_manager.is_tile_type(pos, level_manager.TileType.SOIL):
			# Look for plants on this tile
			for plant in get_tree().get_nodes_in_group("plants"):
				if not is_instance_valid(plant) or not plant is Plant:
					continue
					
				# Check if plant is at this position and needs water
				var plant_grid_pos = level_manager.world_to_grid(plant.global_position)
				if plant_grid_pos == pos and plant.current_stage == Plant.GrowthStage.SEED and not plant.is_watered:
					# Water the plant
					if plant.water():
						plants_watered += 1
						print("Sprinkler watered plant at ", pos)
	
	print("Sprinkler at ", grid_position, " watered ", plants_watered, " plants")
	
	# Play sound if we watered any plants
	if plants_watered > 0:
		# In a full implementation, add sound effect: SoundManager.play_sound("sprinkler")
		pass

# Get adjacent tile positions
func get_adjacent_positions(center: Vector3i) -> Array:
	var positions = []
	
	# Add the four adjacent directions (up, right, down, left)
	positions.append(center + Vector3i(0, 0, -1))  # North
	positions.append(center + Vector3i(1, 0, 0))   # East
	positions.append(center + Vector3i(0, 0, 1))   # South
	positions.append(center + Vector3i(-1, 0, 0))  # West
	
	# Add diagonal tiles for better coverage
	positions.append(center + Vector3i(1, 0, -1))   # Northeast
	positions.append(center + Vector3i(1, 0, 1))    # Southeast
	positions.append(center + Vector3i(-1, 0, 1))   # Southwest
	positions.append(center + Vector3i(-1, 0, -1))  # Northwest
	
	return positions

# Timer signal handler
func _on_watering_timer_timeout():
	water_adjacent_tiles()
