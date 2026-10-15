@icon("res://addons/nodes_plus/icons/node_3D/icon_hand.png")
class_name InteractionArea3D
extends Area3D
## A 3D interaction area component.
##
## Detects when a [CharacterBody3D] enters or exits its range and emits signals
## for interaction prompts. Use with an input action (e.g. "interact") to trigger.
## Supports one-shot interactions, cooldowns, and filtering by group.

#region ─── Signals ───────────────────────────────
## Emitted when an eligible body interacts with this area.
signal interacted(body: Node)
## Emitted when an eligible body enters the interaction range.
signal body_entered_range(body: Node)
## Emitted when an eligible body leaves the interaction range.
signal body_exited_range(body: Node)
#endregion


#region ─── Exports ───────────────────────────────
## If true, the interaction can only trigger once.
@export var one_shot: bool = false

## Cooldown in seconds before the area can be interacted with again.
@export var cooldown: float = 0.0

## If true, automatically listens for the input action.
@export var auto_connect_input: bool = true

## The input action that triggers interaction (defaults to "ui_accept").
@export var interact_action: String = "ui_accept"

## Optional prompt text shown when a body is in range (for UI binding).
@export var prompt_text: String = "Interact"

@export_category("Filtering")
## Only bodies in these groups can interact (empty = accept all).
@export var valid_groups: Array[String] = []

@export_category("Debug")
## Enable or disable debug output.
@export var debug_mode: bool = false
#endregion


#region ─── Internal Vars ───────────────────────────────
var _bodies_in_range: Array[Node3D] = []
var _has_interacted: bool = false
var _cooldown_timer: float = 0.0
#endregion


#region ─── Lifecycle ───────────────────────────────
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta


func _input(event: InputEvent) -> void:
	if not auto_connect_input:
		return
	if event.is_action_pressed(interact_action) and not event.is_echo():
		_try_interact()
#endregion


#region ─── Public API ───────────────────────────────
## Returns true if there are bodies in interaction range.
func has_bodies_in_range() -> bool:
	return _bodies_in_range.size() > 0


## Returns the list of bodies currently in range.
func get_bodies_in_range() -> Array[Node3D]:
	return _bodies_in_range


## Manually triggers an interaction with the nearest body.
func interact() -> void:
	_try_interact()


## Resets one-shot flag, allowing interaction again.
func reset() -> void:
	_has_interacted = false
#endregion


#region ─── Core Logic ───────────────────────────────
func _on_body_entered(body: Node3D) -> void:
	if not _is_valid_body(body):
		return

	if body not in _bodies_in_range:
		_bodies_in_range.append(body)
		body_entered_range.emit(body)
		if debug_mode:
			print("[InteractionArea3D] Body entered: ", body.name)


func _on_body_exited(body: Node3D) -> void:
	if body in _bodies_in_range:
		_bodies_in_range.erase(body)
		body_exited_range.emit(body)
		if debug_mode:
			print("[InteractionArea3D] Body exited: ", body.name)


func _try_interact() -> void:
	if one_shot and _has_interacted:
		return
	if _cooldown_timer > 0.0:
		return
	if _bodies_in_range.is_empty():
		return

	var nearest := _get_nearest_body()
	if not nearest:
		return

	_has_interacted = true
	_cooldown_timer = cooldown
	interacted.emit(nearest)

	if debug_mode:
		print("[InteractionArea3D] Interacted with: ", nearest.name)


func _get_nearest_body() -> Node3D:
	var nearest: Node3D
	var nearest_dist := INF
	var origin := global_position

	for body in _bodies_in_range:
		if not is_instance_valid(body):
			continue
		var dist := origin.distance_squared_to(body.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = body

	return nearest


func _is_valid_body(body: Node) -> bool:
	if valid_groups.is_empty():
		return true
	for group in valid_groups:
		if body.is_in_group(group):
			return true
	return false
#endregion
