@icon("res://addons/nodes_plus/icons/node/Regenerate.svg")
class_name Regeneration
extends Node
## A health regeneration component.
## 
## Gradually heals linked [Health] and [Shield] components over time.

#region ─── Exports ───────────────────────────────
## [Health] node to apply healing to.
@export var health_node: Health

## [Shield] node to apply healing to.
@export var shield_node: Shield

## Amount of health to regenerate per second.
@export var regen_rate: float = 2.0

## If true, regeneration is active.
@export var active: bool = false

@export_category("Debug")
## Enable or disable debug output.
@export var debug_mode: bool = false
#endregion

#region ─── Lifecycle ───────────────────────────────
func _process(delta: float) -> void:
	if not active:
		return

	if health_node and not health_node.is_full_health():
		if shield_node and not shield_node.is_full_health() and not shield_node.is_broken():
			shield_node.recharge(regen_rate * delta)
		else:
			health_node.heal(regen_rate * delta)
	elif shield_node and not shield_node.is_broken():
		shield_node.recharge(regen_rate * delta)
#endregion
