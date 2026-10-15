@icon("res://addons/nodes_plus/icons/node_2D/icon_hitbox.png")
class_name Hurtbox2D
extends Area2D
## A 2D Hurtbox component.
##
## Detects collisions with [Hitbox2D] nodes and applies [Damage] automatically.
## If a [Shield] node is linked, damage will be absorbed by the shield first.
## Handles invincibility and damage filtering by group or node name.


#region ─── Signals ───────────────────────────────
## Emitted when the hurtbox takes damage.
signal damaged(source: Node, amount: float)
## Emitted when invincibility starts.
signal invincibility_started
## Emitted when invincibility ends.
signal invincibility_ended
#endregion


#region ─── Exports ───────────────────────────────
## The [Health] node to apply damage to.
@export var health: Health

## (Optional) A [Shield] node to absorb damage before health is reduced.
@export var shield: Shield

## (Optional) Group or node name filter (only accepts damage from these [Hitbox2D] nodes).
@export var valid_hitbox_group: Array[String] = []

## If true, this hurtbox will ignore further hits while invincible.
@export var invincible: bool = false

## Time (in seconds) of invulnerability after being hit.
@export var invincibility_time: float = 0.2

## Enable or disable debug mode (prints hit info).
@export var debug_mode: bool = false
#endregion


#region ─── Internal Vars ───────────────────────────────
var _invincible_timer: Timer
#endregion


#region ─── Built-in ───────────────────────────────
func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	_invincible_timer = Timer.new()
	_invincible_timer.one_shot = true
	add_child(_invincible_timer)
	_invincible_timer.timeout.connect(_on_invincibility_timeout)
#endregion


#region ─── Core Logic ───────────────────────────────
func _on_area_entered(area: Area2D) -> void:
	if (not health and not shield) or invincible:
		return
	var amount := _resolve_damage_from_area(area)
	if amount <= 0.0:
		return
	if not _is_valid_target(area):
		return
	_apply_hit(area, amount)


func _on_body_entered(body: Node2D) -> void:
	if (not health and not shield) or invincible:
		return
	var amount := _resolve_damage_from_body(body)
	if amount <= 0.0:
		return
	if not _is_valid_target(body):
		return
	_apply_hit(body, amount)


func _resolve_damage_from_area(area: Area2D) -> float:
	if area.has_method("get_damage_amount"):
		return area.get_damage_amount()
	elif "damage_amount" in area:
		return area.damage_amount
	if debug_mode:
		print("[Hurtbox2D] Area entered but no damage data:", area.name)
	return 0.0


func _resolve_damage_from_body(body: Node2D) -> float:
	for child in body.get_children():
		if child is Hitbox2D and child.has_method("get_damage_amount"):
			return child.get_damage_amount()
	if "damage_amount" in body:
		return body.damage_amount
	if debug_mode:
		print("[Hurtbox2D] Body entered but no damage data:", body.name)
	return 0.0


func _is_valid_target(node: Node) -> bool:
	if valid_hitbox_group.size() == 0:
		return true
	for group in valid_hitbox_group:
		if node.is_in_group(group) or node.name == group:
			return true
	if debug_mode:
		print("[Hurtbox2D] Target not in valid group:", node.name)
	return false


func _apply_hit(source: Node, amount: float) -> void:
	if shield and shield.current_shield > 0.0:
		shield.apply_damage(amount)
	else:
		if health:
			health.apply_damage(amount)

	damaged.emit(source, amount)

	if debug_mode:
		print_rich("[Hurtbox2D] Hit by [color=green]", source.name, "[/color] for [color=red]", amount, " damage")

	if invincibility_time > 0.0:
		_set_invincible(true)
		_invincible_timer.start(invincibility_time)
#endregion


#region ─── Invincibility Logic ───────────────────────────────
func _set_invincible(value: bool) -> void:
	invincible = value
	if value:
		invincibility_started.emit()
	else:
		invincibility_ended.emit()

func _on_invincibility_timeout() -> void:
	_set_invincible(false)
#endregion
