@icon("res://addons/nodes_plus/icons/node_3D/icon_area_damage.png")
class_name Hitbox3D
extends Area3D
## A 3D Hitbox component.
##
## Detects overlaps with [Hurtbox3D] nodes and provides damage information.
## Works with a linked [Damage] node that defines how much damage is applied.
## Can trigger once per activation, or repeatedly, depending on configuration.

#region ─── Signals ───────────────────────────────
## Emitted when this hitbox successfully damages a target.
signal hit_detected(target: Node, amount: float)
## Emitted when the hitbox becomes active.
signal hitbox_activated
## Emitted when the hitbox becomes inactive.
signal hitbox_deactivated
#endregion


#region ─── Exports ───────────────────────────────
## Reference to a [Damage] node that defines the damage value.
@export var damage_node: Damage

## Whether this hitbox can currently deal damage.
@export var active: bool = true:
	get:
		return _active
	set(value):
		_active = value
		set_monitoring(value)
		if value:
			hitbox_activated.emit()
		else:
			hitbox_deactivated.emit()

## If true, this hitbox will only damage each target once per activation.
@export var one_shot: bool = false

## Enable or disable debug output.
@export var debug_mode: bool = false
#endregion


#region ─── Private ───────────────────────────────
var _active: bool = true
var _damaged_targets: Array[Node] = []
#endregion


#region ─── Lifecycle ───────────────────────────────
func _ready() -> void:
	connect("area_entered", _on_area_entered)
	set_monitoring(active)
#endregion


#region ─── Core Logic ───────────────────────────────
func _on_area_entered(area: Area3D) -> void:
	if not _active:
		return
	if not damage_node:
		if debug_mode:
			print("[Hitbox3D] Missing Damage node, ignoring hit.")
		return
	if not area is Hurtbox3D:
		if debug_mode:
			print("[Hitbox3D] Area entered is not a Hurtbox3D: ", area.name)
		return

	var hurt: Hurtbox3D = area as Hurtbox3D

	# One-shot check
	if one_shot and hurt in _damaged_targets:
		return

	# Compute final damage value
	var amount := get_damage_amount()

	# Manually emit for consistency
	hit_detected.emit(hurt, amount)

	if debug_mode:
		print_rich("[Hitbox3D] Hit [color=green]", hurt.get_parent().name,"'s ", hurt.name, "[/color] for [color=red]", amount, " damage")

	if one_shot:
		_damaged_targets.append(hurt)
#endregion


#region ─── Public API ───────────────────────────────
## Returns the damage amount this hitbox should deal.
##
## If the linked [Damage] node has a `get_final_damage()` method, it will be used;
## otherwise it falls back to `damage_amount`.
func get_damage_amount() -> float:
	if not damage_node:
		return 0.0
	return float(damage_node.get_final_damage())


## Resets the list of damaged targets (for one-shot hitboxes).
func reset_hitbox() -> void:
	_damaged_targets.clear()


## Enables or disables the hitbox manually.
func set_active(value: bool) -> void:
	active = value
#endregion
