extends CharacterBody3D


func _ready() -> void:
	if get_node_or_null("ComponentsManeger/PlayerMovementComponent").move_state == get_node_or_null("ComponentsManeger/PlayerMovementComponent").MoveState.IDLE:
		print("it's right")
