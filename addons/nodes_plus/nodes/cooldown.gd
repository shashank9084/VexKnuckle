@icon("res://addons/nodes_plus/icons/node/icon_clear.png")
class_name Cooldown
extends Node
## A cooldown component.
##
## A simple timer that tracks a "ready/not ready" cycle.
## Perfect for abilities, attacks, dashes, and any repeating action.
## Works with [TimerLabel] for UI display and [StatusEffect] for duration tracking.

#region ─── Signals ───────────────────────────────
## Emitted when the cooldown finishes (timer reaches zero).
signal finished
## Emitted when the cooldown starts.
signal started(duration: float)
## Emitted when the cooldown is paused.
signal paused
## Emitted when the cooldown resumes.
signal resumed
## Emitted when the cooldown is reset before finishing.
signal cooldown_reset
#endregion


#region ─── Exports ───────────────────────────────
## Total cooldown duration in seconds.
@export var duration: float = 1.0

## If true, the cooldown starts automatically in _ready().
@export var auto_start: bool = false

## If true, the cooldown restarts automatically when it finishes.
@export var auto_restart: bool = false

## If true, the timer pauses when the SceneTree is paused.
@export var pause_aware: bool = true

## If true, calling start() again while running restarts the timer.
@export var can_restart: bool = true

@export_category("Debug")
## Enable or disable debug output.
@export var debug_mode: bool = false
#endregion


#region ─── Internal Vars ───────────────────────────────
var _elapsed: float = 0.0
var _active: bool = false
var _paused: bool = false
#endregion


#region ─── Lifecycle ───────────────────────────────
func _ready() -> void:
	if auto_start:
		start()


func _process(delta: float) -> void:
	if not _active or _paused:
		return
	if pause_aware and get_tree().paused:
		return

	_elapsed += delta

	if _elapsed >= duration:
		_finish()
#endregion


#region ─── Public API ───────────────────────────────
## Starts the cooldown (restarts if already running and can_restart is true).
func start(new_duration: float = -1.0) -> void:
	if _active and not can_restart:
		return

	_elapsed = 0.0
	if new_duration >= 0.0:
		duration = new_duration
	_active = true
	_paused = false
	started.emit(duration)

	if debug_mode:
		print("[Cooldown] Started: ", duration, "s")


## Pauses the cooldown.
func pause() -> void:
	if not _active or _paused:
		return
	_paused = true
	paused.emit()

	if debug_mode:
		print("[Cooldown] Paused at: ", _elapsed)


## Resumes the cooldown.
func resume() -> void:
	if not _active or not _paused:
		return
	_paused = false
	resumed.emit()

	if debug_mode:
		print("[Cooldown] Resumed at: ", _elapsed)


## Resets the cooldown without emitting the ready signal.
func reset_cooldown() -> void:
	_elapsed = 0.0
	_active = false
	_paused = false
	cooldown_reset.emit()

	if debug_mode:
		print("[Cooldown] Reset.")


## Stops and resets the cooldown (alias for reset).
func stop() -> void:
	reset_cooldown()


## Returns true if the cooldown is ready (not running).
func is_ready() -> bool:
	return not _active


## Returns the remaining time in seconds.
func get_remaining_time() -> float:
	return max(duration - _elapsed, 0.0)


## Returns the progress ratio (0.0–1.0).
func get_progress_ratio() -> float:
	if duration <= 0.0:
		return 1.0
	return clamp(_elapsed / duration, 0.0, 1.0)
#endregion


#region ─── Internal ───────────────────────────────
func _finish() -> void:
	_active = false
	_elapsed = 0.0
	finished.emit()

	if debug_mode:
		print("[Cooldown] Ready.")

	if auto_restart:
		start()
#endregion
