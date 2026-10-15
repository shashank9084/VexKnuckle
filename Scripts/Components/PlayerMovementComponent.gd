extends Node
class_name PlayerMovenentComponent

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

@export var multiplayer_authority_check = false
@export var player : CharacterBody3D

func  _ready() -> void:
	if !player:
		assert(false , "Player Not Found")
		
func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not player.is_on_floor():
		player.velocity += player.get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and player.is_on_floor():
		player.velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		player.velocity.x = direction.x * SPEED
		player.velocity.z = direction.z * SPEED
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, SPEED)
		player.velocity.z = move_toward(player.velocity.z, 0, SPEED)

	player.move_and_slide()
