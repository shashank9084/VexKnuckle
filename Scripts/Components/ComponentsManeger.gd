extends Node
class_name ComponentsManeger

@export var player : CharacterBody3D
@export var component_nodes : Array[ComponentsManeger]

func _ready() -> void:
	if !player.is_multiplayer_authority():
		for n in component_nodes:
			if is_instance_valid(n):
				n.queue_free()
			
			
			
			
