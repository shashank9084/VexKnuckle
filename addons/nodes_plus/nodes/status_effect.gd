@icon("res://addons/nodes_plus/icons/node/icon_brain.png")
class_name StatusEffect
extends Node
## A status effect component.
##
## Two independent systems you can use together or separately:
##   Modifiers — Temporarily changes a property on the target, then restores the original value
##               when the effect ends. Example: stun (can_take_damage = false), slow (speed = 0).
##   Ticks — Applies damage or healing at regular intervals to assigned Health/Shield nodes.
##           Example: poison (-5 HP every second), regeneration (+10 HP every 0.5s).

#region ─── Signals ───────────────────────────────
## Emitted when the effect is applied to a target.
signal applied(target: Node)
## Emitted when the effect expires or is removed.
signal expired(target: Node)
## Emitted each tick with the amount of damage (negative) or healing (positive).
signal ticked(amount: float)
## Emitted when the effect stacks (same effect applied again).
signal stacked(stacks: int)
#endregion


#region ─── Exports ───────────────────────────────
## Duration of the effect in seconds (0 = permanent).
@export var duration: float = 3.0

## If true, the effect starts automatically on _ready().
@export var auto_start: bool = true

## Maximum number of stacks (0 = unlimited).
@export var max_stacks: int = 0

## If true, applying again refreshes the duration.
@export var refresh_on_stack: bool = true

@export_category("Modifiers")
## The node whose property will be temporarily changed.
## The original value is restored when the effect ends. If empty, uses the parent node.
@export var target_node: Node:
	set(value):
		if _target_node_backing == value:
			return
		_target_node_backing = value
		notify_property_list_changed()
	get:
		return _target_node_backing

## Property name to temporarily override (e.g. "can_take_damage", "speed", "modulate").
@export var property_name: String = "":
	set(value):
		if _property_name_backing == value:
			return
		_property_name_backing = value
		notify_property_list_changed()
	get:
		return _property_name_backing

## Value to assign while the effect is active.
@export var property_value: Variant

## If true, adds [property_value] to the current value instead of replacing it.
@export var additive: bool = false

@export_category("Ticks")
## [Health] node that receives tick damage or healing.
@export var tick_health: Health

## [Shield] node that receives tick damage.
@export var tick_shield: Shield

## Damage or healing applied per tick. Negative = damage, positive = heal.
@export var tick_amount: float = 0.0

## Seconds between each tick.
@export var tick_interval: float = 1.0

@export_category("Visuals")
## Optional name for UI display.
@export var effect_name: String = "Status Effect"

## Optional color tint for UI elements.
@export var effect_color: Color = Color.WHITE

@export_category("Debug")
## Enable or disable debug output.
@export var debug_mode: bool = false
#endregion


#region ─── Internal Vars ───────────────────────────────
var _target_node_backing: Node
var _property_name_backing: String = ""
var _modifier_target: Node
var _original_value: Variant
var _stacks: int = 1
var _elapsed: float = 0.0
var _tick_elapsed: float = 0.0
var _active: bool = false
var _has_property: bool = false
#endregion


#region ─── Lifecycle ───────────────────────────────
func _ready() -> void:
	if auto_start:
		apply()


func _process(delta: float) -> void:
	if not _active:
		return

	_elapsed += delta

	# Duration expiry
	if duration > 0.0 and _elapsed >= duration:
		_expire()
		return

	# Tick logic
	if tick_amount != 0.0 and tick_interval > 0.0:
		_tick_elapsed += delta
		if _tick_elapsed >= tick_interval:
			_tick_elapsed = 0.0
			_perform_tick()
#endregion


#region ─── Public API ───────────────────────────────
## Applies the effect to an optional target (defaults to exported [member target_node], then parent).
func apply(target: Node = null) -> void:
	var t := target if target else (target_node if target_node else get_parent())
	if not is_instance_valid(t):
		push_warning("[StatusEffect] No valid target to apply to.")
		return

	_modifier_target = t
	_active = true
	_elapsed = 0.0
	_tick_elapsed = 0.0

	_apply_modifier()
	applied.emit(_modifier_target)

	if debug_mode:
		print("[StatusEffect] Applied '", effect_name, "' to: ", _modifier_target.name)


## Stacks this effect on the target.
func stack(amount: int = 1) -> void:
	if max_stacks > 0 and _stacks >= max_stacks:
		return

	_stacks += amount
	if max_stacks > 0:
		_stacks = min(_stacks, max_stacks)

	if refresh_on_stack:
		_elapsed = 0.0

	stacked.emit(_stacks)

	if debug_mode:
		print("[StatusEffect] Stacked '", effect_name, "' to ", _stacks, " stacks.")


## Removes the effect and reverses modifications.
func remove() -> void:
	_expire()


## Returns the current number of stacks.
func get_stacks() -> int:
	return _stacks


## Returns the remaining time in seconds (0 for permanent effects).
func get_remaining_time() -> float:
	if duration <= 0.0:
		return INF
	return max(duration - _elapsed, 0.0)


## Returns the progress ratio (0.0–1.0).
func get_progress_ratio() -> float:
	if duration <= 0.0:
		return 0.0
	return clamp(_elapsed / duration, 0.0, 1.0)
#endregion


func _validate_property(property: Dictionary) -> void:
	if property.name != "property_value" or not target_node or property_name.is_empty():
		return
	if property_name not in target_node:
		return

	var value := target_node.get(property_name)
	property.type = typeof(value)


#region ─── Internal ───────────────────────────────
func _apply_modifier() -> void:
	if property_name.is_empty() or not _modifier_target:
		return

	var target := _modifier_target
	if property_name in target:
		_has_property = true
		_original_value = target[property_name]

		if additive and typeof(property_value) == TYPE_FLOAT:
			target[property_name] = _original_value + property_value
		else:
			target[property_name] = property_value

		if debug_mode:
			print("[StatusEffect] Set ", _modifier_target.name, ".", property_name, " from ", _original_value, " to ", target[property_name])
	else:
		if debug_mode:
			print("[StatusEffect] Property '", property_name, "' not found on ", _modifier_target.name)


func _reverse_modifier() -> void:
	if not _has_property or not is_instance_valid(_modifier_target):
		return

	if property_name in _modifier_target:
		_modifier_target[property_name] = _original_value


func _perform_tick() -> void:
	var final_amount := tick_amount * _stacks
	ticked.emit(final_amount)

	if final_amount < 0.0:
		if tick_shield:
			tick_shield.apply_damage(abs(final_amount))
		elif tick_health:
			tick_health.apply_damage(abs(final_amount))
	elif final_amount > 0.0 and tick_health:
		tick_health.heal(final_amount)


func _expire() -> void:
	if not _active:
		return

	_active = false
	_reverse_modifier()
	expired.emit(_modifier_target)

	if debug_mode:
		print("[StatusEffect] '", effect_name, "' expired on: ", _modifier_target.name if _modifier_target else "null")
#endregion
