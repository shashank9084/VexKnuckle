@icon("res://addons/nodes_plus/icons/node_3D/icon_follow.png")
class_name Follow3D
extends Node
## A 3D follow component.
##
## Smoothly follows a target [Node3D] using interpolation (lerp).
## Works with [Target3D] for dynamic lock-on, or assign any node directly.
## Supports offset, dead zone, and velocity-based or position-based following.

#region ─── Signals ───────────────────────────────
## Emitted when the target changes.
signal target_changed(new_target: Node3D)
## Emitted when the target is lost (node becomes invalid).
signal target_lost
#endregion


#region ─── Exports ───────────────────────────────
## The node to follow. If empty, follows the parent node.
@export var target: Node3D

## How fast the follower catches up (1.0 = instant, 0.0 = never moves).
@export var follow_speed: float = 5.0

## Offset from the target's position.
@export var offset: Vector3 = Vector3.ZERO

## If set, the follower snaps instantly when within this distance.
@export var dead_zone: float = 0.1

## If true, updates in _process instead of _physics_process.
@export var use_process: bool = false

## Enable or disable debug output.
@export var debug_mode: bool = false
#endregion


#region ─── Internal Vars ───────────────────────────────
var _parent_3d: Node3D
#endregion


#region ─── Lifecycle ───────────────────────────────
func _ready() -> void:
	_parent_3d = get_parent() as Node3D
	if not _parent_3d:
		push_warning("[Follow3D] Parent must be a Node3D.")

func _process(delta: float) -> void:
	if use_process:
		_follow(delta)

func _physics_process(delta: float) -> void:
	if not use_process:
		_follow(delta)
#endregion


#region ─── Public API ───────────────────────────────
## Sets a new target to follow.
func set_target(new_target: Node3D) -> void:
	if target == new_target:
		return
	target = new_target
	if is_instance_valid(target):
		target_changed.emit(target)
		if debug_mode:
			print("[Follow3D] Target set to: ", target.name)
	else:
		_handle_target_lost()


## Removes the current target.
func clear_target() -> void:
	target = null
	target_lost.emit()
#endregion


#region ─── Core Logic ───────────────────────────────
func _follow(delta: float) -> void:
	if not _parent_3d:
		return

	var t: Node3D = target if is_instance_valid(target) else null
	if not t:
		return

	var target_pos := t.global_position + offset
	var current_pos := _parent_3d.global_position
	var distance := current_pos.distance_to(target_pos)

	if dead_zone > 0.0 and distance <= dead_zone:
		return

	if follow_speed >= 100.0:
		_parent_3d.global_position = target_pos
	else:
		_parent_3d.global_position = current_pos.lerp(target_pos, follow_speed * delta)


func _handle_target_lost() -> void:
	target = null
	target_lost.emit()
	if debug_mode:
		print("[Follow3D] Target lost.")
#endregion
