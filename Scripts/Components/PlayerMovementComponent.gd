extends Node
class_name PlayerMovementComponent

enum MoveState { IDLE, WALK, RUN, SPRINT }

@export var multiplayer_authority_check = false

@export_group("References")
@export var player: CharacterBody3D
@export var character: Node3D
@export var camera_pivot: Node3D
@export var spring_arm: SpringArm3D

@export_group("Movement")
@export var speed: float = 5.0
@export var walk_speed: float = 2.5
@export var run_speed: float = 4.0
@export var sprint_speed: float = 8.0

@export_group("Velocity Smoothing")
@export var acceleration: float = 20.0      # ground: how fast we reach target speed
@export var deceleration: float = 25.0      # ground: how fast we slow to a stop
@export var air_acceleration: float = 6.0   # air control while speeding up
@export var air_deceleration: float = 2.0   # air control while slowing down

@export_group("Jump Velocity")
@export var idle_jump_velocity: float = 4.5
@export var walk_jump_velocity: float = 5.0
@export var run_jump_velocity: float = 5.5
@export var sprint_jump_velocity: float = 6.5

var input_dir := Vector2.ZERO
var direction := Vector3.ZERO
var input_strength := 0.0
var frozen := false

var move_state: MoveState = MoveState.IDLE
var current_speed: float = 0.0

var is_running: bool = false
var is_sprinting: bool = false
var is_walking: bool = false
var is_jumping: bool = false

func _ready() -> void:
	if not player:
		player = get_parent() as CharacterBody3D
	assert(player != null, "PlayerMovementComponent requires a CharacterBody3D.")

func _physics_process(delta: float) -> void:
	if not player or frozen:
		return

	_handle_input()
	_update_move_state()
	_handle_gravity(delta)
	_handle_jump()
	_apply_movement(delta)
	player.move_and_slide()

func _handle_input() -> void:
	input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	input_strength = minf(input_dir.length(), 1.0)

	var camera_basis := Basis(Vector3.UP, camera_pivot.rotation.y)
	direction = (camera_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

func _update_move_state() -> void:
	var moving := input_dir != Vector2.ZERO
	var backward := input_dir.y > 0.6
	current_speed = speed

	if not moving:
		move_state = MoveState.IDLE
		current_speed = 0.0
	elif Input.is_action_pressed("sprint") and not backward:
		move_state = MoveState.SPRINT
		current_speed = sprint_speed
	elif Input.is_action_pressed("walk"):
		move_state = MoveState.WALK
		current_speed = walk_speed
	elif Input.is_action_pressed("run") or backward:
		move_state = MoveState.RUN
		current_speed = run_speed
	else:
		# Moving with no modifier held: uses `speed`, counts as RUN for jumping.
		move_state = MoveState.RUN

	is_sprinting = move_state == MoveState.SPRINT
	is_running = move_state == MoveState.RUN
	is_walking = move_state == MoveState.WALK

func _handle_gravity(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity += player.get_gravity() * delta
	else:
		is_jumping = false

func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and player.is_on_floor():
		player.velocity.y = _get_jump_velocity()
		is_jumping = true

func _get_jump_velocity() -> float:
	match move_state:
		MoveState.WALK:
			return walk_jump_velocity
		MoveState.RUN:
			return run_jump_velocity
		MoveState.SPRINT:
			return sprint_jump_velocity
		_:
			return idle_jump_velocity

func _apply_movement(delta: float) -> void:
	var target_velocity := direction * current_speed * input_strength
	var horizontal := Vector3(player.velocity.x, 0.0, player.velocity.z)

	var rate: float
	if target_velocity.is_zero_approx():
		rate = deceleration if player.is_on_floor() else air_deceleration
	else:
		rate = acceleration if player.is_on_floor() else air_acceleration

	horizontal = horizontal.move_toward(target_velocity, rate * delta)
	player.velocity.x = horizontal.x
	player.velocity.z = horizontal.z
