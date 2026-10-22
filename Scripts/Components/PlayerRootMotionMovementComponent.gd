class_name PlayerRootMotionMovementComponent
extends Node

enum State { IDLE, MOVING }

@export var body: CharacterBody3D
@export var charector: Node3D
@export var animation_tree: AnimationTree
@export var debug_label: Label
@export var apply_gravity := true

@export_group("Jump")
@export_range(0.0, 30.0, 0.1, "suffix:m/s") var jump_velocity := 5.0
@export_range(0.0, 0.5, 0.01, "suffix:s") var coyote_time := 0.1
@export_range(0.0, 0.5, 0.01, "suffix:s") var jump_buffer_time := 0.1
@export_range(0.0, 1.0, 0.05) var jump_cut_multiplier := 0.5

@export_group("Air Momentum")
@export_range(0.0, 50.0, 0.1, "suffix:m/s²") var air_drag := 0.0

@export_group("Animation")
@export_range(0.1, 20.0, 0.1) var sprint_blend_speed := 3.0

const _P_STATE := &"parameters/IdleState/transition_request"
const _P_BLEND_POS := &"parameters/RunBlendSpace/blend_position"
const _P_SPRINT := &"parameters/SprintBlend/blend_amount"
const _P_JUMP := &"parameters/JumpOneShot/request"

const _STATE_IDLE := &"Idle"
const _STATE_MOVE := &"Movement"

var _state := State.IDLE
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _air_velocity := Vector3.ZERO
var _sprint_blend := -1.0


func _ready() -> void:
	animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	animation_tree.set(_P_STATE, _STATE_IDLE)


func _physics_process(delta: float) -> void:
	_update_animation_inputs(delta)

	charector.quaternion *= animation_tree.get_root_motion_rotation()

	var root_velocity := _get_root_motion_velocity(delta)

	if not apply_gravity:
		body.velocity = root_velocity
		body.move_and_slide()
		_update_debug()
		return

	var on_floor := body.is_on_floor()
	_update_timers(delta, on_floor)

	var vertical := body.velocity.y
	if not on_floor:
		vertical -= _gravity * delta
	elif vertical < 0.0:
		vertical = 0.0

	var jumped := _try_jump()
	if jumped:
		vertical = jump_velocity

	if vertical > 0.0 and Input.is_action_just_released(&"jump"):
		vertical *= jump_cut_multiplier

	if body.is_on_ceiling() and vertical > 0.0:
		vertical = 0.0

	var horizontal := Vector3(root_velocity.x, 0.0, root_velocity.z)
	var airborne := jumped or not on_floor

	if airborne:
		_air_velocity = _air_velocity.move_toward(Vector3.ZERO, air_drag * delta)
		horizontal = _air_velocity
	else:
		_air_velocity = horizontal

	body.velocity = Vector3(horizontal.x, vertical, horizontal.z)
	body.move_and_slide()

	if airborne:
		_air_velocity = Vector3(body.velocity.x, 0.0, body.velocity.z)

	_update_debug()


func _get_root_motion_velocity(delta: float) -> Vector3:
	var facing := charector.global_basis.get_rotation_quaternion()
	var accumulated := animation_tree.get_root_motion_rotation_accumulator()
	return (accumulated.inverse() * facing) * animation_tree.get_root_motion_position() / delta


func _update_timers(delta: float, on_floor: bool) -> void:
	_coyote_timer = coyote_time if on_floor else maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = jump_buffer_time if Input.is_action_just_pressed(&"jump") \
			else maxf(_jump_buffer_timer - delta, 0.0)


func _try_jump() -> bool:
	if _jump_buffer_timer <= 0.0 or _coyote_timer <= 0.0:
		return false
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	animation_tree.set(_P_JUMP, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	return true


func _update_animation_inputs(delta: float) -> void:
	var input_dir := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	var next_state := State.IDLE if input_dir.is_zero_approx() else State.MOVING

	if next_state != _state:
		_state = next_state
		animation_tree.set(_P_STATE, _STATE_MOVE if _state == State.MOVING else _STATE_IDLE)
	if _state == State.MOVING:
		animation_tree.set(_P_BLEND_POS, input_dir)

	var target := 1.0 if Input.is_action_pressed(&"sprint") else -1.0
	_sprint_blend = lerpf(_sprint_blend, target, 1.0 - exp(-sprint_blend_speed * delta))
	animation_tree.set(_P_SPRINT, _sprint_blend)


func _update_debug() -> void:
	if debug_label == null or not debug_label.is_visible_in_tree():
		return
	debug_label.text = "position : %s\nrotation : %s\nposition accumulator : %s\nrotation accumulator : %s\nscale : %s\nair velocity : %s" % [
		animation_tree.get_root_motion_position(),
		animation_tree.get_root_motion_rotation(),
		animation_tree.get_root_motion_position_accumulator(),
		animation_tree.get_root_motion_rotation_accumulator(),
		animation_tree.get_root_motion_scale(),
		_air_velocity,
	]
