extends Node
class_name PlayerMovenentComponent

@export var multiplayer_authority_check = false


@export_group("References")
@export var player: CharacterBody3D
@export var character: Node3D
@export var camera_pivot: Node3D
@export var spring_arm: SpringArm3D

@export_group("Movement")
@export var speed: float = 5.0
@export var walk_speed: float = 2.5
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.5
@export var can_walk: bool = true


var input_dir := Vector2.ZERO
var direction := Vector3.ZERO
var input_strength := 0.0
var frozen := false

var is_sprinting: bool = false
var is_walking: bool = false
var is_jumping: bool = false

func _ready() -> void:
	if not player:
		player = get_parent() as CharacterBody3D
	assert(player != null, "PlayerControllerComponent requires a CharacterBody3D.")

func _physics_process(delta: float) -> void:
	if not player or frozen:
		return

	_handle_gravity(delta)
	_handle_input()

	_apply_movement()
	player.move_and_slide()

func _handle_gravity(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity += player.get_gravity() * delta

	if Input.is_action_just_pressed("jump") and player.is_on_floor():
		player.velocity.y = jump_velocity

func _handle_input() -> void:
	input_dir = Input.get_vector(
		"ui_left", "ui_right",
		"ui_up", "ui_down"
	)

	input_strength = minf(input_dir.length(), 1.0)

	var camera_basis := Basis(Vector3.UP, camera_pivot.rotation.y)
	direction = (
		camera_basis * Vector3(input_dir.x, 0, input_dir.y)
	).normalized()



func _apply_movement() -> void:
	var moving := input_dir != Vector2.ZERO

	var current_speed := speed

	if moving and Input.is_action_pressed("sprint"):
		current_speed = sprint_speed
	elif moving and Input.is_action_pressed("walk") and can_walk:
		current_speed = walk_speed

	player.velocity.x = direction.x * current_speed * input_strength
	player.velocity.z = direction.z * current_speed * input_strength
