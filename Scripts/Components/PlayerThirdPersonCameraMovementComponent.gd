extends Node
class_name  PlayerThirdPersonCameraMovementComponent

@export var multiplayer_authority_check = false

@export var drag_area : Control
@export var camera : Camera3D
@export var camera_pivot: Node3D
@export var spring_arm: SpringArm3D
@export var character : Node3D

@export var camera_distance: float = 3.5
@export var mouse_sensitivity: float = 0.005
@export var tilt_limit: float = deg_to_rad(75.0)
@export var rotation_speed: float = 10.0

func _ready() -> void:
	if !drag_area:
		assert(false,"Please Select A Drag Area Node")
	drag_area.gui_input.connect(screen_input)

func _process(delta: float) -> void:
	_handle_controller_camera(delta)
	
func _handle_controller_camera(delta: float) -> void:
	character.rotation.y = lerp_angle(character.rotation.y, camera_pivot.rotation.y + PI, rotation_speed * delta)


func screen_input(event: InputEvent) -> void:

	if event is InputEventMouseMotion:
		camera_pivot.rotation.x -= event.relative.y * mouse_sensitivity
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, -tilt_limit, tilt_limit)
		camera_pivot.rotation.y += -event.relative.x * mouse_sensitivity
