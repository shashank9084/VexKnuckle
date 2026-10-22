extends CharacterBody3D

enum STATES {IDLE , RUN , SPRINT , STARFE}

var jumping := false
var state := STATES.IDLE
@export var root_motion_movement_component : PlayerRootMotionMovementComponent


func _process(delta: float) -> void:
	var rmmc = root_motion_movement_component.State.find_key(root_motion_movement_component._state)
	match rmmc:
		"IDLE":
			state = STATES.IDLE
		"MOVING":
			state = STATES.RUN
