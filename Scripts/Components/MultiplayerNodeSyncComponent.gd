extends Node
class_name MultiplayerNodeSyncComponent


@export var player : Node3D
@export var nodes : Array[Node]

func _ready() -> void:
	if !player.is_multiplayer_authority():
		for n in nodes:
			n.queue_free()
