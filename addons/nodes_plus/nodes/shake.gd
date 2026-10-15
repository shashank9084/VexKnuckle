@icon("res://addons/nodes_plus/icons/node/icon_particle.png")
class_name Shaker
extends Node
## A universal shake component.
##
## Applies a shake effect to a target node.
## It automatically detects whether the target uses Vector2 or Vector3 for its position.

#region ─── Signals ───────────────────────────────
## Emitted when a shake effect starts.
signal shake_started()

## Emitted when a shake effect finishes.
signal shake_finished()
#endregion


#region ─── Exports ───────────────────────────────
## The target node to shake. If empty, defaults to the parent node.
@export var target_node: Node

## The duration (in seconds) for the shake effect.
@export var duration: float = 0.8

## The intensity of the shake (in units/pixels).
@export var intensity: float = 2.0

## The frequency (how many times per second to update the shake offset).
@export var frequency: float = 30.0

## Whether to automatically reset position after shaking.
@export var auto_reset: bool = true

## (3D Only) Whether to include the Z-axis in the shake calculation.
@export var shake_z_axis: bool = true
#endregion


#region ─── Private Variables ──────────────────────
# Holds Vector2 or Vector3 depending on the target type.
var _original_position: Variant 
var _elapsed_time: float = 0.0
var _shaking: bool = false
var _is_3d: bool = false
var _time_since_last_update: float = 0.0
#endregion


#region ─── Core Logic ─────────────────────────────

## Starts the shake effect.
func start_shake() -> void:
	if _shaking:
		return
	
	# 1. Determine the target node
	var target = target_node if is_instance_valid(target_node) else get_parent()
	
	if not is_instance_valid(target):
		push_warning("Shake component failed to find a valid target node.")
		return
		
	# 2. Determine the dimension (2D, Control, or 3D) and store original position
	if target is Node3D:
		_is_3d = true
		_original_position = (target as Node3D).transform.origin 
		
		# Critical Check for Physics Bodies (3D only)
		if target is CharacterBody3D or target is RigidBody3D or target is AnimatableBody3D:
			push_error("Cannot shake 3D physics body. Target a Camera3D or a simple Node3D instead.")
			return
			
	elif target is Node2D:
		_is_3d = false
		_original_position = (target as Node2D).position
		
	elif target is Control: # NEW: Control node support
		_is_3d = false
		_original_position = (target as Control).position
		
	else:
		push_warning("Shake component target invalid: %s" % target.get_class())
		return

	target_node = target # Store the validated target reference
	_elapsed_time = 0.0
	_time_since_last_update = 0.0
	_shaking = true
	shake_started.emit()


## Stops the shake effect immediately and restores position if needed.
func stop_shake() -> void:
	if not _shaking:
		return
		
	_shaking = false
	if auto_reset and is_instance_valid(target_node):
		# Reset position using the stored original value, explicitly casting to the correct type.
		if _is_3d:
			var target_3d = target_node as Node3D
			var new_transform = target_3d.transform
			new_transform.origin = _original_position as Vector3
			target_3d.transform = new_transform
		else:
			# Combined 2D and Control reset
			if target_node is Node2D:
				(target_node as Node2D).position = _original_position as Vector2
			elif target_node is Control:
				(target_node as Control).position = _original_position as Vector2
			
	shake_finished.emit()


func _process(delta: float) -> void:
	if not _shaking or not is_instance_valid(target_node):
		return

	_elapsed_time += delta
	_time_since_last_update += delta
	
	# 1. Check if duration has passed
	if _elapsed_time >= duration:
		stop_shake()
		return
	
	# 2. Apply frequency limit using an accumulator
	var interval = 1.0 / max(frequency, 0.01) # Avoid division by zero
	if _time_since_last_update < interval:
		return # Skip update if not enough time has passed

	_time_since_last_update = 0.0 # Reset accumulator

	# 3. Calculate and apply shake offset
	if _is_3d:
		var x = randf_range(-intensity, intensity)
		var y = randf_range(-intensity, intensity)
		var z = 0.0
		if shake_z_axis:
			z = randf_range(-intensity, intensity)
			
		var shake_offset = Vector3(x, y, z)
		
		# Apply shake using transform.origin for 3D nodes
		var target_3d = target_node as Node3D
		var original_pos_3d = _original_position as Vector3
		
		var new_transform = target_3d.transform
		new_transform.origin = original_pos_3d + shake_offset
		target_3d.transform = new_transform
		
	else:
		var x = randf_range(-intensity, intensity)
		var y = randf_range(-intensity, intensity)
		var shake_offset = Vector2(x, y)
		
		var original_pos_2d = _original_position as Vector2
		
		# Apply shake for 2D and Control nodes
		if target_node is Node2D:
			(target_node as Node2D).position = original_pos_2d + shake_offset
		elif target_node is Control:
			(target_node as Control).position = original_pos_2d + shake_offset
#endregion
