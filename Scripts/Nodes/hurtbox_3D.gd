@icon("res://addons/nodes_plus/icons/node_3D/icon_hitbox.png")
class_name Hurtbox3D
extends Area3D
## Receives physical impacts from Hitbox3D nodes. Holds no health or damage
## data: it reports each accepted impact and lets the game decide what it means.
##
## The hitbox drives detection, so this area's own monitoring is turned off.
## It stays monitorable so hitboxes can find it.

#region ─── Signals ───────────────────────────────
## Emitted when an accepted impact arrives.
signal impacted(impact: Hitbox3D.Impact)
## Emitted when the post-impact cooldown starts.
signal cooldown_started
## Emitted when the post-impact cooldown ends.
signal cooldown_ended
#endregion


#region ─── Exports ───────────────────────────────
## Effective mass of this body or part (kg). Used for reduced-mass energy.
@export var mass: float = 70.0

## Only accept impacts from these groups or node names. Empty accepts all.
@export var valid_hitbox_groups: Array[String] = []

## Seconds after an accepted impact during which further impacts are ignored.
@export var hit_cooldown: float = 0.0

@export var debug_mode: bool = false
#endregion


#region ─── Internal Vars ───────────────────────────────
## Measured world velocity of this hurtbox (m/s).
var velocity: Vector3 = Vector3.ZERO

var _last_position: Vector3 = Vector3.ZERO
var _cooldown_remaining: float = 0.0
#endregion


#region ─── Built-in ───────────────────────────────
func _ready() -> void:
	monitoring = false
	monitorable = true
	_last_position = global_position


func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return

	var current_position := global_position
	velocity = (current_position - _last_position) / delta
	_last_position = current_position

	if _cooldown_remaining > 0.0:
		_cooldown_remaining -= delta
		if _cooldown_remaining <= 0.0:
			_cooldown_remaining = 0.0
			cooldown_ended.emit()
#endregion


#region ─── Public API ───────────────────────────────
## Called by a Hitbox3D. Returns true if the impact was accepted.
func receive_impact(impact: Hitbox3D.Impact) -> bool:
	if is_on_cooldown():
		return false
	if not _is_valid_source(impact.source):
		return false

	impacted.emit(impact)

	if hit_cooldown > 0.0:
		_cooldown_remaining = hit_cooldown
		cooldown_started.emit()

	if debug_mode:
		print("[Hurtbox3D] Impact from ", impact.source.name,
			" | Energy: ", snappedf(impact.energy, 0.01), " J")

	return true


func is_on_cooldown() -> bool:
	return _cooldown_remaining > 0.0


func get_cooldown_remaining() -> float:
	return _cooldown_remaining
#endregion


#region ─── Internal ───────────────────────────────
func _is_valid_source(source: Node) -> bool:
	if valid_hitbox_groups.is_empty():
		return true
	for group in valid_hitbox_groups:
		if source.is_in_group(group) or source.name == group:
			return true
	return false
#endregion
