extends ComponentsManeger
class_name MultiplayerNodeSyncComponent

@export var _nodes : Array[Node]

func _ready() -> void:
	if !player.is_multiplayer_authority():
		for n in _nodes:
			n.queue_free()
