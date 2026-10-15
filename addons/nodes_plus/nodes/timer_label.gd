@icon("res://addons/nodes_plus/icons/control/icon_dialog.png")
class_name TimerLabel
extends RichTextLabel
## A countdown timer label component.
##
## Automatically displays the remaining time from a linked [Cooldown], [Lifespan],
## or [StatusEffect] node. Supports visual formatting, color changes, and
## custom text templates.

#region ─── Exports ───────────────────────────────
## The [Cooldown] node to display time from.
@export var cooldown: Cooldown

## The [Lifespan] node to display time from.
@export var lifespan: Lifespan

## The [StatusEffect] node to display time from.
@export var status_effect: StatusEffect

## Text template. Use {time} for the formatted time value.
@export var template: String = "{time}"

## Format string for the time value ("seconds", "mmss", or "raw").
@export var time_format: String = "seconds":
	set(value):
		time_format = value
		if is_inside_tree():
			_update_display()

## Color when the remaining time is above the warning threshold.
@export var normal_color: Color = Color.WHITE

## Color when the remaining time is below the warning threshold.
@export var warning_color: Color = Color.ORANGE_RED

## Time threshold (in seconds) below which the warning color is used.
@export var warning_threshold: float = 3.0

## Update interval in seconds (0 = every frame).
@export var update_interval: float = 0.1

## Show the label only when a timer is active.
@export var hide_when_inactive: bool = false

@export_category("Debug")
## Enable or disable debug output.
@export var debug_mode: bool = false
#endregion


#region ─── Internal Vars ───────────────────────────────
var _elapsed_since_update: float = 0.0
#endregion


#region ─── Lifecycle ───────────────────────────────
func _ready() -> void:
	if hide_when_inactive:
		visible = false
	_update_display()


func _process(delta: float) -> void:
	_elapsed_since_update += delta

	if update_interval > 0.0 and _elapsed_since_update < update_interval:
		return

	_elapsed_since_update = 0.0
	_update_display()
#endregion


#region ─── Public API ───────────────────────────────
## Manually sets the time value to display.
func set_time(value: float) -> void:
	text = template.replace("{time}", _format_time(value))
	_apply_color(value)


## Returns the current remaining time from whichever source is connected.
func get_current_time() -> float:
	if cooldown and cooldown.is_ready() == false:
		return cooldown.get_remaining_time()
	if lifespan:
		return lifespan.get_remaining_time()
	if status_effect:
		return status_effect.get_remaining_time()
	return 0.0


## Returns true if any timer source is active.
func is_timer_active() -> bool:
	if cooldown:
		return not cooldown.is_ready()
	if lifespan:
		return lifespan.get_remaining_time() > 0.0
	if status_effect:
		return status_effect.get_remaining_time() > 0.0
	return false
#endregion


#region ─── Internal ───────────────────────────────
func _update_display() -> void:
	var time := get_current_time()

	if hide_when_inactive:
		var active := is_timer_active()
		visible = active
		if not active:
			return

	text = template.replace("{time}", _format_time(time))
	_apply_color(time)


func _format_time(value: float) -> String:
	match time_format:
		"mmss":
			var total_seconds := int(ceil(value))
			var minutes := total_seconds / 60
			var seconds := total_seconds % 60
			return "%02d:%02d" % [minutes, seconds]
		"raw":
			return str(value)
		_: # "seconds"
			return "%.1f" % value


func _apply_color(time: float) -> void:
	if time <= warning_threshold and time > 0.0:
		modulate = warning_color
	else:
		modulate = normal_color
#endregion
