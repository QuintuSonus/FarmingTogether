# scripts/managers/EventBus.gd
class_name EventBus
extends Node

# Define common event names
enum Events {
	UPGRADE_PURCHASED,
	UPGRADE_APPLIED,
	PLANT_GROWN,
	PLANT_HARVESTED,
	ORDER_COMPLETED,
	LEVEL_COMPLETED,
	TOOL_USED,
	TILE_MODIFIED
}

# Dictionary of event listeners
var listeners = {}

# Singleton instance
static var instance = null

func _init():
	if instance == null:
		instance = self
	else:
		push_error("EventBus instance already exists!")

func _ready():
	print("EventBus initialized")

# Register a listener for an event
func register_listener(event_name, target, method_name, binds = []):
	if not listeners.has(event_name):
		listeners[event_name] = []
	
	listeners[event_name].append({
		"target": target,
		"method": method_name,
		"binds": binds
	})
	
	print("EventBus: Registered listener for event: " + str(event_name))

# Unregister a listener
func unregister_listener(event_name, target, method_name = null):
	if not listeners.has(event_name):
		return
	
	for i in range(listeners[event_name].size() - 1, -1, -1):
		var listener = listeners[event_name][i]
		if listener.target == target:
			if method_name == null or listener.method == method_name:
				listeners[event_name].remove_at(i)
	
	# Clean up empty event lists
	if listeners[event_name].size() == 0:
		listeners.erase(event_name)

# Emit an event
func emit_event(event_name, args = {}):
	if not listeners.has(event_name):
		return
	
	print("EventBus: Emitting event: " + str(event_name) + " with args: " + str(args))
	
	# Create a copy of the listeners array to prevent issues if listeners are added/removed during iteration
	var event_listeners = listeners[event_name].duplicate()
	
	for listener in event_listeners:
		var target = listener.target
		
		# Skip if target is no longer valid
		if not is_instance_valid(target):
			continue
		
		var method = listener.method
		var binds = listener.binds
		
		# Call method with arguments
		if binds.size() > 0:
			# Combine args and binds
			var combined_args = [args]
			combined_args.append_array(binds)
			target.callv(method, combined_args)
		else:
			target.call(method, args)

# Static method to get instance
static func get_instance() -> EventBus:
	return instance

# Convenience methods
static func register(event_name, target, method_name, binds = []):
	if instance:
		instance.register_listener(event_name, target, method_name, binds)

static func unregister(event_name, target, method_name = null):
	if instance:
		instance.unregister_listener(event_name, target, method_name)

static func emit(event_name, args = {}):
	if instance:
		instance.emit_event(event_name, args)
