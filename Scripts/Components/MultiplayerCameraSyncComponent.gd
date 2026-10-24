extends ComponentsManeger
class_name MultiplayerCameraSyncComponent

@export var camera : Camera3D

func _ready() -> void:
	if !player:
		assert(false , "Player Not Found")
	if !camera:
		assert(false , "Camera Not Found")
	camera.current = player.is_multiplayer_authority()
