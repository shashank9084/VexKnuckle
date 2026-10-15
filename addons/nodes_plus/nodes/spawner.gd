@icon("res://addons/nodes_plus/icons/node/icon_gear.png")
class_name Spawner
extends Node
## A spawner component.
##
## Spawns instances of a [PackedScene] on a timer or on demand.
## Supports spawn limits, rate control, and custom position and parent targeting.

#region ─── Signals ───────────────────────────────
## Emitted each time a new instance is spawned.
signal spawned(instance: Node)
## Emitted when [member max_spawns] is reached (if set to a positive value).
signal spawn_limit_reached
## Emitted when the spawner starts its timer.
signal spawning_started
## Emitted when the spawner stops its timer.
signal spawning_stopped
#endregion

#region ─── Exports ───────────────────────────────
## The scene to instantiate on each spawn.
@export var scene: PackedScene

## Time in seconds between automatic spawns.
@export var spawn_interval: float = 1.0

## If true, starts spawning automatically in _ready().
@export var auto_start: bool = false

## Maximum number of instances to spawn (0 = unlimited).
@export var max_spawns: int = 0

## If true, only spawns once per trigger.
@export var one_shot: bool = false

@export_category("Targeting")
## The node whose transform is used for spawned instances (defaults to the Spawner itself).
@export var spawn_position_node: NodePath

## The parent node for spawned instances (defaults to the Spawner's parent).
@export var spawn_parent_node: NodePath

## Enable or disable debug output.
@export var debug_mode: bool = false
#endregion

#region ─── Internal Vars ───────────────────────────────
var _spawn_count: int = 0
var _active: bool = false
var _elapsed: float = 0.0
#endregion


func _ready() -> void:
	if auto_start:
		start_spawning()


func _process(delta: float) -> void:
	if not _active:
		return

	_elapsed += delta
	if _elapsed >= spawn_interval:
		_elapsed = 0.0
		_spawn()


## Returns the total number of instances spawned so far.
func get_spawn_count() -> int:
	return _spawn_count


## Starts the automatic spawn timer.
func start_spawning() -> void:
	if _active:
		return
	_active = true
	_elapsed = 0.0
	spawning_started.emit()
	if debug_mode:
		print("[Spawner] Started spawning.")


## Stops the automatic spawn timer.
func stop_spawning() -> void:
	if not _active:
		return
	_active = false
	spawning_stopped.emit()
	if debug_mode:
		print("[Spawner] Stopped spawning.")


## Spawns one instance immediately, bypassing the timer.
func spawn_one() -> void:
	_spawn()


## Resets the spawn count and elapsed time.
func reset() -> void:
	_spawn_count = 0
	_elapsed = 0.0


func _spawn() -> void:
	if not scene:
		if debug_mode:
			print("[Spawner] No scene assigned, skipping spawn.")
		return

	if max_spawns > 0 and _spawn_count >= max_spawns:
		spawn_limit_reached.emit()
		stop_spawning()
		return

	var instance: Node = scene.instantiate()

	# Position the instance using the target node's transform
	var pos_node: Node = self
	if spawn_position_node:
		var resolved := get_node_or_null(spawn_position_node)
		if resolved:
			pos_node = resolved
	if pos_node is Node2D:
		(instance as Node2D).global_position = (pos_node as Node2D).global_position
	elif pos_node is Node3D:
		(instance as Node3D).global_transform = (pos_node as Node3D).global_transform
	elif pos_node is Control:
		(instance as Control).global_position = (pos_node as Control).global_position

	# Parent the instance
	var parent: Node = get_parent()
	if spawn_parent_node:
		var resolved := get_node_or_null(spawn_parent_node)
		if resolved:
			parent = resolved
	parent.add_child(instance)

	_spawn_count += 1
	spawned.emit(instance)

	if debug_mode:
		print("[Spawner] Spawned instance #", _spawn_count, ": ", instance.name)

	if one_shot:
		stop_spawning()
