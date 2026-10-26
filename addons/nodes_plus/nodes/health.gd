@icon("res://addons/nodes_plus/icons/node/Health.svg")
class_name Health
extends Node
## A health component.
## 
## Used to manage the health and received [Damage] of entities, it also manages healing.

#region ─── Signals ───────────────────────────────
## Emitted when the health value changes.
signal health_changed(current_health: float, max_health: float)
## Emitted when the health is completely depleted.
signal health_depleted
#endregion

#region ─── Exports ───────────────────────────────
## The max health of the entity.
@export var max_health: float = 100.0:
	get:
		return _max_health
	set(value):
		_max_health = max(value, 1.0)
		_current_health = clamp(_current_health, 0.0, _max_health)

## The current health of the entity.
@export var current_health: float = 100.0:
	get:
		return _current_health
	set(value):
		_current_health = clamp(value, 0.0, max_health)
		health_changed.emit(_current_health, max_health)
		if _current_health <= 0.0:
			health_depleted.emit()
		change_visual_health_bar(_current_health)

## If true, the entity can be damaged.
@export var can_take_damage: bool = true

## If true, the entity can be healed.
@export var can_heal: bool = true

@export_category("Visuals")
## Node to use for the health bar. Needs a "value" or "text" property.
## Normally a [ProgressBar] or [Label].
@export var health_bar: Node
#endregion

#region ─── Internal Vars ───────────────────────────────
var _max_health: float = 100.0
var _current_health: float = 100.0
#endregion


#region ─── Lifecycle ───────────────────────────────
func _ready() -> void:
	while not is_instance_valid(health_bar):
		await get_tree().create_timer(0.1).timeout
	_current_health = clamp(_current_health, 0.0, max_health)
	current_health = _current_health
	change_visual_health_bar(current_health)
#endregion


#region ─── Public API ───────────────────────────────
func change_visual_health_bar(health : float):
	if health_bar.has_method("set_text"):
		health_bar.text = str(health)
	if health_bar.has_method("set_max"):
		health_bar.max_value = float(max_health)
	if health_bar.has_method("set_value"):
		health_bar.value = float(health)
	
func apply_damage(amount: float) -> void:
	if not can_take_damage:
		return
	current_health -= abs(amount)

func heal(amount: float) -> void:
	if not can_heal:
		return
	current_health += abs(amount)

func is_dead() -> bool:
	return _current_health <= 0.0

func is_full_health() -> bool:
	return _current_health >= max_health

func get_health_ratio() -> float:
	return _current_health / max_health
#endregion
