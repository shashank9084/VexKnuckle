@icon("res://addons/nodes_plus/icons/node/icon_gear.png")
class_name ObjectPool
extends Node
## An object pool component.
##
## Manages a reusable pool of scene instances to avoid constant creation/destruction.
## Works synergistically with [Spawner] for efficient spawning of projectiles, enemies, and effects.
## Supports pre-warming, max capacity, and automatic growth.

#region ─── Signals ───────────────────────────────
## Emitted when an instance is acquired from the pool.
signal instance_acquired(instance: Node)
## Emitted when an instance is returned to the pool.
signal instance_released(instance: Node)
## Emitted when the pool is empty and a new instance is created.
signal pool_depleted
#endregion


#region ─── Exports ───────────────────────────────
## The scene to pool instances of.
@export var scene: PackedScene

## Maximum number of instances the pool can hold (0 = unlimited).
@export var max_size: int = 0

## Number of instances to pre-create on _ready().
@export var prewarm_count: int = 0

## If true, the pool can create new instances when empty.
@export var allow_growth: bool = true

## If true, returns instances to the pool instead of queue_free().
@export var auto_return: bool = true

@export_category("Debug")
## Enable or disable debug output.
@export var debug_mode: bool = false
#endregion


#region ─── Internal Vars ───────────────────────────────
var _pool: Array[Node] = []
var _active: Array[Node] = []
#endregion


#region ─── Lifecycle ───────────────────────────────
func _ready() -> void:
	if not scene:
		push_warning("[ObjectPool] No scene assigned.")
		return

	for i in prewarm_count:
		var instance := _create_instance()
		_recycle(instance)

	if debug_mode:
		print("[ObjectPool] Prewarmed with ", prewarm_count, " instances.")
#endregion


#region ─── Public API ───────────────────────────────
## Acquires an instance from the pool (or creates one if allowed).
func acquire() -> Node:
	if not scene:
		return null

	# Try to find a free instance
	for instance in _pool:
		if is_instance_valid(instance) and not instance.is_inside_tree():
			_active.append(instance)
			instance_acquired.emit(instance)
			return instance

	# Growth is allowed
	if allow_growth:
		if max_size > 0 and _active.size() + _pool.size() >= max_size:
			pool_depleted.emit()
			if debug_mode:
				print("[ObjectPool] Pool depleted, cannot acquire.")
			return null

		var instance := _create_instance()
		_active.append(instance)
		instance_acquired.emit(instance)
		return instance

	pool_depleted.emit()
	if debug_mode:
		print("[ObjectPool] Pool empty and growth disabled.")
	return null


## Returns an instance to the pool.
func release(instance: Node) -> void:
	if not is_instance_valid(instance):
		return

	_active.erase(instance)

	if instance.is_inside_tree():
		instance.get_parent().remove_child(instance)

	_recycle(instance)
	instance_released.emit(instance)


## Returns an instance to the pool (alias for use with queue_free replacement).
func return_to_pool(instance: Node) -> void:
	release(instance)


## Pre-creates a given number of instances.
func prewarm(count: int) -> void:
	for i in count:
		var instance := _create_instance()
		_recycle(instance)


## Returns the number of available (free) instances.
func get_available_count() -> int:
	var count := 0
	for instance in _pool:
		if is_instance_valid(instance):
			count += 1
	return count


## Returns the number of active (in-use) instances.
func get_active_count() -> int:
	return _active.size()


## Returns the total number of instances managed by this pool.
func get_total_count() -> int:
	return _pool.size() + _active.size()


## Clears all instances from the pool.
func clear() -> void:
	for instance in _pool:
		if is_instance_valid(instance):
			instance.queue_free()
	_pool.clear()

	for instance in _active:
		if is_instance_valid(instance):
			instance.queue_free()
	_active.clear()
#endregion


#region ─── Internal ───────────────────────────────
func _create_instance() -> Node:
	var instance := scene.instantiate()
	instance.tree_exited.connect(_on_instance_exited.bind(instance))
	add_child(instance)
	instance.visible = false
	return instance


func _recycle(instance: Node) -> void:
	instance.visible = false
	instance.set_process(false)
	instance.set_physics_process(false)

	# Disable hitboxes/areas
	if instance.has_method("set_active"):
		instance.set_active(false)

	# Reset position
	if instance is Node2D:
		instance.position = Vector2.ZERO
	elif instance is Node3D:
		instance.position = Vector3.ZERO

	_pool.append(instance)
	if instance in _active:
		_active.erase(instance)


func _on_instance_exited(instance: Node) -> void:
	_pool.erase(instance)
	_active.erase(instance)
#endregion
