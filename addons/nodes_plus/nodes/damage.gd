@icon("res://addons/nodes_plus/icons/node/icon_sword.png")
class_name Damage
extends Node
## A damage component.
##
## Defines the damage output for attacks or projectiles.
## Handles critical hit logic and emits signals when damage is applied.


#region ─── Signals ───────────────────────────────
## Emitted when damage has been applied to a target.
signal damage_applied(target: Node, amount: float)
#endregion


#region ─── Exports ───────────────────────────────
## The base amount of damage to apply.
@export var damage_amount: float = 10.0

## If true, entity can deal critical hits.
@export var can_crit: bool = false

## Probability (0–1) to land a critical hit.
@export var crit_chance: float = 0.1

## How much a critical hit multiplies the base damage.
@export var crit_multiplier: float = 2.0
#endregion


#region ─── Core Logic ───────────────────────────────
## Calculates and returns the final damage value.
##
## Includes critical hit logic if enabled.
func get_final_damage() -> float:
	var final_damage := damage_amount
	if can_crit and randf() < crit_chance:
		final_damage *= crit_multiplier
	return final_damage


## Applies damage directly to a target with an [apply_damage()] method.
##
## This is optional — your Hitbox2D or Hurtbox2D can also call [get_final_damage()] manually.
func apply_damage(target: Node) -> void:
	if not target or not target.has_method("apply_damage"):
		return

	var final_damage := get_final_damage()
	target.apply_damage(final_damage)
	damage_applied.emit(target, final_damage)
#endregion
