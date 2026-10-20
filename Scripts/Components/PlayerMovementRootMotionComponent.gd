extends Node
class_name PlayerMovementRootMotionComponent

@export var body : CharacterBody3D
@export var charector : Node3D   # child of the CharacterBody3D, holds the model and camera yaw
@export var animation_tree : AnimationTree
@export var debug_label : Label
@export var apply_gravity := true

@export_group("Jump")
@export var jump_velocity := 5.0          # upward speed at takeoff (m/s)
@export var coyote_time := 0.1            # grace period after leaving a ledge
@export var jump_buffer_time := 0.1       # early presses still count
@export var jump_cut_multiplier := 0.5    # <1 = shorter hop when jump is released early

var _gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0

var input_dir

func _ready() -> void:
	animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS

func _process(delta: float) -> void:
	_check_action_input(delta)
	_update_animation_input(delta)

func _update_animation_input(_delta):
	input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir:
		if animation_tree.get("parameters/IdleState/transition_request") != "Movement":
			animation_tree.set("parameters/IdleState/transition_request","Movement")
		animation_tree.set("parameters/RunBlendSpace/blend_position", input_dir)
	else:
		if animation_tree.get("parameters/IdleState/transition_request") != "Idle":
			animation_tree.set("parameters/IdleState/transition_request","Idle")

func _check_action_input(_delta):
	var target_sprint_blend : float = 1 if Input.is_action_pressed("sprint") else -1
	var current_sprint_blend : float = animation_tree.get("parameters/SprintBlend/blend_amount")
	animation_tree.set("parameters/SprintBlend/blend_amount", lerp(current_sprint_blend, target_sprint_blend, 3 * _delta))

func _physics_process(delta: float) -> void:
	# Root motion rotation turns the charector (not the body)
	charector.quaternion = charector.quaternion * animation_tree.get_root_motion_rotation()

	# Root motion position -> world space using the charector's facing
	var facing : Quaternion = charector.global_basis.get_rotation_quaternion()
	var rot_accum : Quaternion = animation_tree.get_root_motion_rotation_accumulator()
	var world_delta : Vector3 = (rot_accum.inverse() * facing) * animation_tree.get_root_motion_position()
	var move_velocity : Vector3 = world_delta / delta

	var vertical := _update_vertical(delta, move_velocity.y)

	body.velocity = Vector3(move_velocity.x, vertical, move_velocity.z)
	body.move_and_slide()

	_update_debug()

func _update_vertical(delta: float, root_motion_y: float) -> float:
	if not apply_gravity:
		return root_motion_y

	var vertical := body.velocity.y

	# Timers
	if body.is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = max(_coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)

	# Gravity
	if not body.is_on_floor():
		vertical -= _gravity * delta

	# Jump
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		vertical = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		animation_tree.set("parameters/JumpOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

	# Variable jump height: release early to cut the jump short
	if Input.is_action_just_released("jump") and vertical > 0.0:
		vertical *= jump_cut_multiplier

	return vertical

func _update_debug() -> void:
	if debug_label == null:
		return
	debug_label.text = "position : %s\nrotation : %s\nposition accumulator : %s\nrotation accumulator : %s\nscale : %s" % [
		animation_tree.get_root_motion_position(),
		animation_tree.get_root_motion_rotation(),
		animation_tree.get_root_motion_position_accumulator(),
		animation_tree.get_root_motion_rotation_accumulator(),
		animation_tree.get_root_motion_scale(),
	]
