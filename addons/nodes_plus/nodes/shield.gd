@icon("res://addons/nodes_plus/icons/node/icon_shield.png")
class_name Shield
extends Node
## A Shield component.
##
## Provides a secondary layer of protection for an entity with [Health].
## Absorbs incoming damage before it affects health, and can be recharged.
## Emits signals when the shield value changes or breaks completely.

#region ─── Signals ───────────────────────────────
## Emitted when the shield is fully depleted.
signal shield_broken
## Emitted when the shield value changes.
signal shield_changed(current: float, max: float)
#endregion

#region ─── Exports ───────────────────────────────
## The maximum shield capacity.
@export var max_shield: float = 50.0

## The current shield value.
@export var current_shield: float = 50.0

## The linked [Health] node that takes damage once the shield is depleted.
@export var linked_health: Health

@export_category("Debug")
## Enable or disable debug output.
@export var debug_mode: bool = false
#endregion

#region ─── Public API ───────────────────────────────
## Applies [param amount] of damage to the shield.
## Any leftover damage after the shield breaks will be passed to the linked [Health] node.
func apply_damage(amount: float) -> void:
	var leftover = amount - current_shield
	current_shield = max(0.0, current_shield - amount)
	shield_changed.emit(current_shield, max_shield)

	if current_shield <= 0.0:
		shield_broken.emit()
		if leftover > 0.0 and linked_health:
			linked_health.apply_damage(leftover)

## Recharges the shield by [param amount].
## Clamped so it never exceeds [member max_shield].
func recharge(amount: float) -> void:
	current_shield = clamp(current_shield + amount, 0.0, max_shield)
	shield_changed.emit(current_shield, max_shield)

## Returns true if the shield is at full capacity.
func is_full_health() -> bool:
	return current_shield >= max_shield

## Returns true if the shield is depleted.
func is_broken() -> bool:
	return current_shield <= 0.0
#endregion
