@icon("res://addons/nodes_plus/icons/node/icon_event.png")
class_name Lifespan
extends Node
## A lifespan component.
##
## Automatically counts down and emits a signal when time runs out.
## Useful for temporary objects, projectiles, status effects, and timed events.
## Supports pausing, early termination, and automatic parent cleanup.

#region ─── Signals ───────────────────────────────
## Emitted when the lifespan reaches zero.
signal timeout
## Emitted when the countdown starts.
signal started(duration: float)
## Emitted when the countdown is paused.
signal paused
## Emitted when the countdown resumes.
signal resumed
#endregion

#region ─── Exports ───────────────────────────────
## Total duration in seconds before timeout.
@export var duration: float = 2.0

## If true, the countdown begins automatically in _ready().
@export var auto_start: bool = true

@export_category("Behavior")
## What happens when the lifespan elapses.
@export var timeout_action: TimeoutAction = TimeoutAction.QUEUE_FREE

## If true, the countdown pauses when the SceneTree is paused.
@export var pause_aware: bool = true

## Enable or disable debug output.
@export var debug_mode: bool = false
#endregion

#region ─── Internal Vars ───────────────────────────────
var _elapsed: float = 0.0
var _active: bool = false
var _paused: bool = false
#endregion

enum TimeoutAction {
	QUEUE_FREE,    ## Removes the parent node from the scene tree.
	HIDE,          ## Hides the parent node.
	SIGNAL_ONLY,   ## Only emits the timeout signal; parent handles cleanup.
}


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
		_timeout()


## Returns the remaining time ratio (1.0 = just started, 0.0 = about to timeout).
func get_remaining_ratio() -> float:
	if duration <= 0.0:
		return 0.0
	return clamp(1.0 - (_elapsed / duration), 0.0, 1.0)


## Returns the remaining time in seconds.
func get_remaining_time() -> float:
	return max(duration - _elapsed, 0.0)


## Starts or restarts the countdown with an optional custom duration.
func start(new_duration: float = -1.0) -> void:
	_elapsed = 0.0
	if new_duration >= 0.0:
		duration = new_duration
	_active = true
	_paused = false
	started.emit(duration)
	if debug_mode:
		print("[Lifespan] Started with duration:", duration)


## Pauses the countdown.
func pause() -> void:
	if not _active or _paused:
		return
	_paused = true
	paused.emit()
	if debug_mode:
		print("[Lifespan] Paused at", _elapsed)


## Resumes the countdown.
func resume() -> void:
	if not _active or not _paused:
		return
	_paused = false
	resumed.emit()
	if debug_mode:
		print("[Lifespan] Resumed at", _elapsed)


## Stops the countdown and resets elapsed time without triggering timeout.
func stop() -> void:
	_active = false
	_paused = false
	_elapsed = 0.0


## Immediately triggers the timeout action and signal.
func expire() -> void:
	_timeout()


func _timeout() -> void:
	_active = false
	_elapsed = 0.0
	timeout.emit()

	match timeout_action:
		TimeoutAction.QUEUE_FREE:
			get_parent().queue_free()
		TimeoutAction.HIDE:
			get_parent().visible = false
		TimeoutAction.SIGNAL_ONLY:
			pass
