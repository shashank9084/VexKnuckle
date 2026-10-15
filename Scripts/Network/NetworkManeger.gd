extends Node

signal server_created
signal game_started
signal spawn_player(id: int)

const GAME_PORT        : int    = 7777
const MAX_PLAYERS      : int    = 8
const GAME_SCENE_PATH  : String = "res://Scenes/MainGame/MainGame.tscn"

var peer : ENetMultiplayerPeer = null

var local_info    : Dictionary = {}
var players       : Dictionary = {}

var main_menu_scene
var game_menu_scene

func _ready() -> void:
	_bind_multiplayer_signals()
	
func host(player_name : String) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(GAME_PORT, MAX_PLAYERS)
	if err != OK:
		push_error("NetworkManager: failed to create server — %s" % error_string(err))
		return err

	multiplayer.multiplayer_peer = peer
	local_info = _make_player_info(player_name, 1)
	players[1] = local_info
	server_created.emit()
	_rpc_load_main_game_scene()
	return OK
	
func join(ip: String, player_name: String) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, GAME_PORT)
	if err != OK:
		push_error("NetworkManager: failed to connect — %s" % error_string(err))
		return err

	multiplayer.multiplayer_peer = peer
	local_info = _make_player_info(player_name, 0)
	_rpc_load_main_game_scene()
	return OK


func _bind_multiplayer_signals() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
func _on_connected_to_server() -> void:
	printt("Connected to Server Successfully")
	
func _on_connection_failed() -> void:
	printt("Failed to Join Server")
	
func _on_server_disconnected() -> void:
	printt("Server Disconnected")
	
func _on_peer_connected(id : int) -> void:
	printt("Peer Connected :" , id)
	if multiplayer.is_server():
		#_rpc_load_main_game_scene.rpc_id(id)
		#await get_tree().create_timer(10).timeout
		spawn_player.emit(id)
	
func _on_peer_disconnected(id : int) -> void:
	printt("Peer Disconnected :" , id)


func _make_player_info(player_name : String, id : int) -> Dictionary:
	return {
		"id"    : id,
		"name"  : player_name
	}
	

@rpc("authority", "reliable")
func _rpc_load_main_game_scene() -> void:
	game_started.emit()
	main_menu_scene = get_tree().get_current_scene()
	game_menu_scene = load(GAME_SCENE_PATH).instantiate()
	get_tree().root.add_child(game_menu_scene)
	main_menu_scene.process_mode = Node.PROCESS_MODE_DISABLED
	main_menu_scene.visible = false
