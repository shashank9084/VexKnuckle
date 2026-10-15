extends Node
class_name ComponentsManeger

@export var player : Node3D

func _enter_tree() -> void:
	for c : Node in get_children():
		if c.get("multiplayer_authority_check") and c.get("multiplayer_authority_check") == true:
			if !is_multiplayer_authority():
				c.queue_free()
			
			
			
			
