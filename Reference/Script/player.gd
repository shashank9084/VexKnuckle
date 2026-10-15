extends CharacterBody3D

enum CameraMode {
	FIRST_PERSON,
	THIRD_PERSON
}

@onready var camera_pivot: Node3D = %CameraPivot
@onready var camera_3d: Camera3D = %Camera3D
@onready var spring_arm: SpringArm3D = camera_pivot.get_node("SpringArm3D")
@onready var character: Node3D = $character
@onready var name_label: Label3D = $NameLabel
@onready var ui: Control = $Ui

@export_group("Movement")
@export_range(0.1, 20.0, 0.1, "or_greater") var speed: float = 5.0
@export_range(0.1, 10.0, 0.1, "or_greater") var walk_speed: float = 2.5
@export_range(0.1, 30.0, 0.1, "or_greater") var sprint_speed: float = 15
@export_range(1.0, 20.0, 0.1) var jump_velocity: float = 4.5
@export var can_walk: bool = true

@export var sync_velocity : Vector3
@export var sync_is_on_floor  : bool
@export var input_dir: Vector2 = Vector2.ZERO
@export var is_sprinting: bool = false
@export var is_walking: bool = false

@export_group("Camera")
@export_range(0.0, 1.0, 0.001) var mouse_sensitivity: float = 0.005
@export var controller_support: bool = true
@export_range(0.1, 10.0, 0.1) var controller_sensitivity: float = 2.0
@export_range(0.0, 1.57, 0.01) var tilt_limit: float = deg_to_rad(75)
@export_range(0.1, 50.0, 0.1) var rotation_speed: float = 10.0
@export var camera_mode: CameraMode = CameraMode.THIRD_PERSON:
	set(value):
		camera_mode = value
		if is_node_ready():
			_update_camera_mode()
## Camera distance (SpringArm length) for third-person mode.
@export_range(0.0, 10.0, 0.1) var camera_distance: float = 3.5
## Speed at which the camera transitions between modes.
@export_range(1.0, 20.0, 0.1) var camera_transition_speed: float = 8.0
## Allow switching between camera modes with V key.
@export var allow_camera_mode_switch: bool = false

var input_strength: float = 0.0
var direction: Vector3 = Vector3.ZERO
var is_jumping: bool = false

# Freeze the character. It may be useful when you want to pause the character.
var frozen: bool = false

var target_camera_distance: float = 3.5
var is_transitioning_camera: bool = false



func _ready() -> void:
	## Captures the mouse cursor for first-person camera control.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	target_camera_distance = 0.0 if camera_mode == CameraMode.FIRST_PERSON else camera_distance
	spring_arm.spring_length = target_camera_distance
	if character:
		character.visible = camera_mode == CameraMode.THIRD_PERSON
	
	if is_multiplayer_authority():
		camera_3d.make_current()
		name_label.visible = false
	else:
		camera_3d.queue_free()
		ui.queue_free()

func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority(): return
	_handle_gravity_and_jump(delta)
	sync_is_on_floor = is_on_floor()
	sync_velocity = velocity
	_handle_camera_transition(delta)
	_handle_controller_camera(delta)

	if frozen:
		handle_frozen_movement()
		move_and_slide()
		return

	_handle_movement_input()
	if camera_mode == CameraMode.THIRD_PERSON:
		_handle_character_rotation(delta)
	_apply_movement()
	sync_is_on_floor = is_on_floor()
	sync_velocity = velocity
	move_and_slide()
	
	

func handle_frozen_movement() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	input_dir = Vector2.ZERO
	is_sprinting = false
	is_walking = false

func _handle_gravity_and_jump(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
		is_jumping = velocity.y > 0
	else:
		is_jumping = false

	if not frozen and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		is_jumping = true
		

## Processes movement input and calculates movement direction relative to camera.
func _handle_movement_input() -> void:
	input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	input_strength = minf(input_dir.length(), 1.0)
	
	var camera_basis = Transform3D(Basis(Vector3.UP, camera_pivot.rotation.y), Vector3.ZERO).basis
	direction = (camera_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

## Rotates the character mesh to face the movement direction smoothly.
func _handle_character_rotation(delta: float) -> void:
	if camera_mode == CameraMode.FIRST_PERSON:
		return
	if input_dir:
		$character/GeneralSkeleton/LookAtModifier3D.active = false
		character.rotation.y = lerp_angle(character.rotation.y, camera_pivot.rotation.y + PI, rotation_speed * delta)
	else:
		$character/GeneralSkeleton/LookAtModifier3D.active = true
		$Head.rotation.y = lerp_angle($Head.rotation.y, camera_pivot.rotation.y + PI, rotation_speed * delta)
## Handles controller stick input for camera rotation.
func _handle_controller_camera(delta: float) -> void:
	if not controller_support or frozen:
		return
	if not InputMap.has_action("look_left") or not InputMap.has_action("look_right") or not InputMap.has_action("look_up") or not InputMap.has_action("look_down"):
		return
	var look_dir = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look_dir != Vector2.ZERO:
		camera_pivot.rotation.y -= look_dir.x * controller_sensitivity * delta
		camera_pivot.rotation.x += look_dir.y * controller_sensitivity * delta
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, -tilt_limit, tilt_limit)

## Handles smooth camera transition between modes.
func _handle_camera_transition(delta: float) -> void:
	spring_arm.spring_length = lerp(spring_arm.spring_length, target_camera_distance, camera_transition_speed * delta)
	
	if character and camera_distance > 0.0:
		var transition_progress = spring_arm.spring_length / camera_distance
		var visibility_threshold = 0.3
		character.visible = transition_progress > visibility_threshold
	elif character:
		character.visible = camera_mode == CameraMode.THIRD_PERSON

## Updates camera mode (sets target for smooth transition).
func _update_camera_mode() -> void:
	if camera_mode == CameraMode.FIRST_PERSON:
		target_camera_distance = 0.0
	else:
		target_camera_distance = camera_distance

## Applies horizontal movement velocity based on input and sprint/walk state.
func _apply_movement() -> void:
	var is_moving = input_dir != Vector2.ZERO and is_on_floor()
	is_sprinting = Input.is_action_pressed("sprint") and is_moving and not Input.is_action_pressed("run") and input_dir.y < 0
	is_walking = Input.is_action_pressed("run") and is_moving and not Input.is_action_pressed("sprint") and can_walk
	
	var current_speed: float
	if is_sprinting:
		current_speed = sprint_speed
		camera_3d.fov = lerp(camera_3d.fov,130.0,0.1)
	elif is_walking and can_walk:
		current_speed = walk_speed
		camera_3d.fov = lerp(camera_3d.fov,60.0,0.1)
	else:
		current_speed = speed
		camera_3d.fov = lerp(camera_3d.fov,75.0,0.1)
	
	if direction:
		velocity.x = direction.x * current_speed * input_strength
		velocity.z = direction.z * current_speed * input_strength
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

## Handles mouse input for camera rotation with tilt limits.
func _input(event: InputEvent) -> void:
	if !is_multiplayer_authority(): return

	if frozen:
		return

	if event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion:
		camera_pivot.rotation.x -= event.relative.y * mouse_sensitivity
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, -tilt_limit, tilt_limit)
		camera_pivot.rotation.y += -event.relative.x * mouse_sensitivity

	if InputMap.has_action("camera_mode_switch") and event.is_action_pressed("camera_mode_switch") and allow_camera_mode_switch:
		camera_mode = CameraMode.THIRD_PERSON if camera_mode == CameraMode.FIRST_PERSON else CameraMode.FIRST_PERSON
		_update_camera_mode()
		

func _update_slot_animations(_slot , _item):
	if $Ui/Inventory.get_item(0) != null:
		$Animation.change_upperbody.rpc("sword")
		change_item_visiblity.rpc("sword",true)
	else:
		$Animation.change_upperbody.rpc("hand")
		change_item_visiblity.rpc("sword",false)
			
@rpc("any_peer","call_local","reliable")
func change_item_visiblity(item_type : String, visibility : bool):
	var node = $character/GeneralSkeleton/Hand.get_node_or_null(item_type)
	if node != null:
		node.visible = visibility

func apply_loaded_player_data(_id: int, _data: Dictionary) -> void:
	if not multiplayer.is_server():
		push_error("apply_loaded_player_data called by client")
		return
