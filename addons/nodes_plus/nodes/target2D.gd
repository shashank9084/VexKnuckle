@icon("res://addons/nodes_plus/icons/node_2D/icon_target.png")
class_name Target2D
extends Area2D
## A 2D target/lock-on component.
##
## Scans for potential targets within its area and manages a current target.
## Works with [Follow2D] and [Projectile2D] to provide homing or tracking behavior.
## Supports filtering by group and manual target switching.

#region ─── Signals ───────────────────────────────
## Emitted when the current target changes.
signal target_changed(new_target: Node2D)
## Emitted when the current target is lost (out of range or destroyed).
signal target_lost
## Emitted when a new potential target enters the scan area.
signal target_entered(target: Node2D)
## Emitted when a potential target leaves the scan area.
signal target_exited(target: Node2D)
#endregion


#region ─── Exports ───────────────────────────────
## If true, automatically acquires the nearest target on scan.
@export var auto_acquire: bool = true

## Maximum number of targets to track in the list (0 = unlimited).
@export var max_targets: int = 0

## If true, auto-switches to a new target when the current one is lost.
@export var auto_switch: bool = true

@export_category("Filtering")
## Only targets in these groups are valid (empty = accept all).
@export var valid_groups: Array[String] = []

@export_category("Debug")
## Enable or disable debug output.
@export var debug_mode: bool = false
#endregion


#region ─── Internal Vars ───────────────────────────────
var _targets: Array[Node2D] = []
var _current_target: Node2D
#endregion


#region ─── Lifecycle ───────────────────────────────
func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
#endregion


#region ─── Core Logic ───────────────────────────────
func _on_area_entered(area: Area2D) -> void:
	var potential := area.get_parent() as Node2D
	if not potential:
		return
	if not _is_valid_target(potential):
		return
	if potential in _targets:
		return

	if max_targets > 0 and _targets.size() >= max_targets:
		return

	_targets.append(potential)
	target_entered.emit(potential)

	if debug_mode:
		print("[Target2D] Target entered: ", potential.name)

	if auto_acquire and not is_instance_valid(_current_target):
		_select_target(potential)


func _on_area_exited(area: Area2D) -> void:
	var potential := area.get_parent() as Node2D
	if not potential:
		return
	if potential not in _targets:
		return

	_targets.erase(potential)
	target_exited.emit(potential)

	if debug_mode:
		print("[Target2D] Target exited: ", potential.name)

	if potential == _current_target:
		if auto_switch:
			_acquire_nearest()
		else:
			_clear_target()
#endregion


#region ─── Public API ───────────────────────────────
## Returns the current target, or null if none.
func get_target() -> Node2D:
	if is_instance_valid(_current_target):
		return _current_target
	return null


## Returns the list of all tracked targets.
func get_all_targets() -> Array[Node2D]:
	return _targets.filter(func(t): return is_instance_valid(t))


## Manually sets the current target.
func set_target(target: Node2D) -> void:
	if target and target in _targets:
		_select_target(target)


## Acquires the nearest valid target.
func acquire_nearest() -> void:
	_acquire_nearest()


## Clears the current target.
func clear_target() -> void:
	_clear_target()


## Checks if a specific node is a valid target.
func is_valid_target(node: Node) -> bool:
	return _is_valid_target(node)
#endregion


#region ─── Internal ───────────────────────────────
func _select_target(target: Node2D) -> void:
	if not is_instance_valid(target):
		_clear_target()
		return

	_current_target = target
	target_changed.emit(target)
	if debug_mode:
		print("[Target2D] Selected target: ", target.name)


func _clear_target() -> void:
	_current_target = null
	target_lost.emit()
	if debug_mode:
		print("[Target2D] Target cleared.")


func _acquire_nearest() -> void:
	var nearest: Node2D
	var nearest_dist := INF
	var origin := global_position

	for t in _targets:
		if not is_instance_valid(t):
			continue
		var dist := origin.distance_squared_to(t.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = t

	if nearest:
		_select_target(nearest)
	else:
		_clear_target()


func _is_valid_target(node: Node) -> bool:
	if valid_groups.is_empty():
		return true
	for group in valid_groups:
		if node.is_in_group(group):
			return true
	return false
#endregion
