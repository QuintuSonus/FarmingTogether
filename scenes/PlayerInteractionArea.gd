# PlayerInteractionArea.gd
# Attached to the Area3D node on the Player.
# Detects nearby interactable objects (specifically tools for pickup)
# and finds the closest valid one, managing highlighting.
class_name PlayerInteractionArea
extends Area3D

# Store a reference to the player (the parent node)
@onready var player = get_parent()

# List to keep track of interactable physics bodies currently inside the area
var overlapping_interactables = []

# <<< NEW >>> Variable to track the currently highlighted tool
var currently_highlighted_tool: Tool = null

func _ready():
	# Ensure player reference is valid
	if not is_instance_valid(player):
		push_error("PlayerInteractionArea: Parent node is not a valid player!")
		set_process(false)
		return

	# Connect signals to track bodies entering/exiting the area
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))

	print("PlayerInteractionArea ready.")

# <<< NEW >>> Process function to handle highlighting updates
func _process(_delta):
	# Find the closest tool we can pick up right now
	var closest_tool = get_closest_pickupable_tool()

	# Check if the highlighted tool needs to change
	if closest_tool != currently_highlighted_tool:
		# Unhighlight the previous tool (if any and still valid)
		if is_instance_valid(currently_highlighted_tool):
			if currently_highlighted_tool.has_method("set_highlighted"):
				currently_highlighted_tool.set_highlighted(false)
			# print("Unhighlighted: ", currently_highlighted_tool.name) # Optional Debug

		# Highlight the new closest tool (if any)
		if is_instance_valid(closest_tool):
			if closest_tool.has_method("set_highlighted"):
				closest_tool.set_highlighted(true)
			# print("Highlighted: ", closest_tool.name) # Optional Debug

		# Update the tracked highlighted tool
		currently_highlighted_tool = closest_tool


func _on_body_entered(body: Node3D):
	if body.is_in_group("interactables"):
		if not overlapping_interactables.has(body):
			overlapping_interactables.append(body)

func _on_body_exited(body: Node3D):
	if overlapping_interactables.has(body):
		overlapping_interactables.erase(body)
		# <<< NEW >>> If the exited body was the highlighted one, clear highlight
		if body == currently_highlighted_tool:
			if is_instance_valid(currently_highlighted_tool):
				if currently_highlighted_tool.has_method("set_highlighted"):
					currently_highlighted_tool.set_highlighted(false)
			currently_highlighted_tool = null


# Finds the closest tool within the area that the player can currently pick up.
func get_closest_pickupable_tool() -> Tool:
	var closest_tool: Tool = null
	var min_dist_sq = INF

	for body in overlapping_interactables:
		if not is_instance_valid(body):
			call_deferred("remove_invalid_body", body)
			continue

		if body is Tool:
			var tool = body as Tool
			# Check if pickup is possible
			if tool.can_interact(player):
				var dist_sq = player.global_position.distance_squared_to(tool.global_position)
				# Optional: Facing check could go here
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest_tool = tool

	return closest_tool

# Helper to remove invalid bodies from the list during iteration
func remove_invalid_body(body):
	if overlapping_interactables.has(body):
		overlapping_interactables.erase(body)
