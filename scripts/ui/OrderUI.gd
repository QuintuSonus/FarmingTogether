# scripts/ui/OrderUI.gd (MODIFIED)
extends Control

# References - ONLY for order display
@onready var order_container = $OrderContainer # Example path, adjust if needed

# Preload order slot scene
@export var order_slot_scene: PackedScene # Assign in Inspector
var default_order_slot_scene = preload("res://scenes/ui/OrderSlot.tscn")

# Dictionary to track UI slots for each order
var order_slots = {}

# Reference to OrderManager (obtained in _ready)
var order_manager: OrderManager = null

func _ready():
	print("OrderUI: _ready() called")

	# Ensure scene is loaded
	if order_slot_scene == null:
		order_slot_scene = default_order_slot_scene
	if order_slot_scene == null:
		push_error("OrderUI: Order slot scene not available!")
		return

	# Get references ONLY for order display
	if not order_container: order_container = find_child("OrderContainer", true)
	if not order_container: push_error("OrderUI: OrderContainer node not found!")

	# Find the OrderManager
	var service_locator = ServiceLocator.get_instance()
	if service_locator and service_locator.has_service("order_manager"):
		order_manager = service_locator.get_service("order_manager")
	else:
		order_manager = get_node_or_null("/root/Main/OrderManager") # Fallback

	if not order_manager:
		push_warning("OrderUI: OrderManager not found! Cannot display orders.")
	else:
		print("OrderUI: OrderManager found")
		# Connect only to OrderManager signals needed for order slots
		if not order_manager.is_connected("order_created", _on_order_created):
			order_manager.connect("order_created", _on_order_created)
		if not order_manager.is_connected("order_completed_bonus", _on_order_completed):
			order_manager.connect("order_completed_bonus", _on_order_completed)
		if not order_manager.is_connected("order_failed", _on_order_failed):
			order_manager.connect("order_failed", _on_order_failed)

	# Configure container
	if order_container:
		order_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		order_container.size_flags_vertical = Control.SIZE_FILL
		print("OrderUI: OrderContainer size flags set")

# --- Keep Order Slot Management Functions ---

func _on_order_created(order):
	if not order_container: return
	if not is_instance_valid(order): return
	var new_slot = order_slot_scene.instantiate()
	if not new_slot:
		push_error("OrderUI: Failed to instantiate OrderSlot scene!")
		return
	order_container.add_child(new_slot)
	if new_slot.has_method("initialize"):
		new_slot.initialize(order)
	else:
		push_error("OrderUI: OrderSlot doesn't have initialize method!")
		new_slot.queue_free()
		return
	order_slots[order.order_id] = new_slot


func _on_order_completed(order, bonus_score):
	if not is_instance_valid(order): return
	var order_id = order.order_id
	var slot = order_slots.get(order_id)
	if slot and is_instance_valid(slot):
		print("OrderUI: Playing completion for Order %d" % order_id)
		if slot.has_method("play_completion_animation"):
			slot.play_completion_animation()
		else: slot.queue_free()
		await get_tree().create_timer(0.6).timeout
		if is_instance_valid(slot): slot.queue_free()
		if order_slots.has(order_id): order_slots.erase(order_id)

	else: print("OrderUI: Slot for completed order %d not found." % order_id)

func _on_order_failed(order):
	if not is_instance_valid(order): return
	var order_id = order.order_id
	var slot = order_slots.get(order_id)
	if slot and is_instance_valid(slot):
		print("OrderUI: Playing fail for Order %d" % order_id)
		if slot.has_method("play_fail_animation"):
			slot.play_fail_animation()
		else: slot.queue_free()
		await get_tree().create_timer(0.6).timeout
		if is_instance_valid(slot): slot.queue_free()
		if order_slots.has(order_id): order_slots.erase(order_id)

	else: print("OrderUI: Slot for failed order %d not found." % order_id)

# --- REMOVED score/timer/requirement update functions ---
# func update_score_display(score): ...
# func update_timer_display(time_remaining): ...
# func update_score_requirement_display(current_score): ...


func _notification(what):
	if what == NOTIFICATION_RESIZED:
		# arrange_order_slots() # Only if using manual layout
		pass
