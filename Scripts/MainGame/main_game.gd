extends Node

@onready var _spawner : MultiplayerSpawner = $Players/MultiplayerSpawner

const PLAYER_SCENE := preload("res://Debug/player.tscn")


func _ready() -> void:
	_configure_spawner()
	if ! multiplayer.is_server(): return
	for p in NetworkManeger.players:
		_spawn_player(p)
	NetworkManeger.spawn_player.connect(_spawn_player)
	NetworkManeger.despawn_player.connect(
		func(id):
		_despawn_player(id)
		)

func _configure_spawner() -> void:
	_spawner.spawn_function = Callable(self,"_spawn_func")
	
@rpc("authority", "call_local", "reliable")
func _despawn_player(id: int) -> void:
	var node := %Players.get_node_or_null(str(id))
	if node:
		node.queue_free()
	
func _spawn_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var data := { "id": peer_id}
	_spawner.spawn(data)


func _spawn_func(data: Dictionary) -> Node:
	var player := PLAYER_SCENE.instantiate() as CharacterBody3D
	player.name = str(data["id"])
	player.set_multiplayer_authority(data["id"])
	
	return player
