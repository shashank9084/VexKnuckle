@icon("res://addons/nodes_plus/icons/node_2D/icon_follow.png")
class_name Follow2D
extends Node
## A 2D follow component.
##
## Smoothly follows a target [Node2D] using interpolation (lerp).
## Works with [Target2D] for dynamic lock-on, or assign any node directly.
## Supports offset, dead zone, and velocity-based or position-based following.

#region ─── Signals ───────────────────────────────
## Emitted when the target changes.
signal target_changed(new_target: Node2D)
## Emitted when the target is lost (node becomes invalid).
signal target_lost
#endregion


#region ─── Exports ───────────────────────────────
## The node to follow. If empty, follows the parent node.
@export var target: Node2D

## How fast the follower catches up (1.0 = instant, 0.0 = never moves).
@export var follow_speed: float = 5.0

## Offset from the target's position.
@export var offset: Vector2 = Vector2.ZERO

## If set, the follower snaps instantly when within this distance.
@export var dead_zone: float = 1.0

## If true, updates in _process instead of _physics_process.
@export var use_process: bool = false

## Enable or disable debug output.
@export var debug_mode: bool = false
#endregion


#region ─── Internal Vars ───────────────────────────────
var _parent_2d: Node2D
#endregion


#region ─── Lifecycle ───────────────────────────────
func _ready() -> void:
	_parent_2d = get_parent() as Node2D
	if not _parent_2d:
		push_warning("[Follow2D] Parent must be a Node2D.")

func _process(delta: float) -> void:
	if use_process:
		_follow(delta)

func _physics_process(delta: float) -> void:
	if not use_process:
		_follow(delta)
#endregion


#region ─── Public API ───────────────────────────────
## Sets a new target to follow.
func set_target(new_target: Node2D) -> void:
	if target == new_target:
		return
	target = new_target
	if is_instance_valid(target):
		target_changed.emit(target)
		if debug_mode:
			print("[Follow2D] Target set to: ", target.name)
	else:
		_handle_target_lost()


## Removes the current target.
func clear_target() -> void:
	target = null
	target_lost.emit()
#endregion


#region ─── Core Logic ───────────────────────────────
func _follow(delta: float) -> void:
	if not _parent_2d:
		return

	var t: Node2D = target if is_instance_valid(target) else null
	if not t:
		return

	var target_pos := t.global_position + offset
	var current_pos := _parent_2d.global_position
	var distance := current_pos.distance_to(target_pos)

	if dead_zone > 0.0 and distance <= dead_zone:
		return

	if follow_speed >= 100.0:
		_parent_2d.global_position = target_pos
	else:
		_parent_2d.global_position = current_pos.lerp(target_pos, follow_speed * delta)


func _handle_target_lost() -> void:
	target = null
	target_lost.emit()
	if debug_mode:
		print("[Follow2D] Target lost.")
#endregion
