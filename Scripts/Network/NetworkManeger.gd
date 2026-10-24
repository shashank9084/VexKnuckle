extends Node

signal despawn_player(id : int)
signal spawn_player(id : int)
signal players_list_changed(_players : Dictionary)

const GAME_PORT        : int    = 7777
const MAX_PLAYERS      : int    = 8
const GAME_SCENE_PATH  : String = "res://Scenes/MainGame/MainGame.tscn"
const MAINMENU_SCENE_PATH  : String = "res://Scenes/MainMenu/MainMenu.tscn"

var peer : ENetMultiplayerPeer = null

var local_info    : Dictionary = {}
var players       : Dictionary = {}

var main_menu_scene
var main_game_scene

func _ready() -> void:
	_bind_multiplayer_signals()
	
func host(player_name : String) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(GAME_PORT, MAX_PLAYERS)
	if err != OK:
		push_error("NetworkManager: failed to create server — %s" % error_string(err))
		return err

	multiplayer.multiplayer_peer = peer
	local_info = _make_player_info(player_name)
	players[1] = local_info
	players_list_changed.emit(players)
	load_main_game_scene()
	return OK
	
func join(ip: String, player_name: String) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, GAME_PORT)
	if err != OK:
		push_error("NetworkManager: failed to connect — %s" % error_string(err))
		return err

	multiplayer.multiplayer_peer = peer
	local_info = _make_player_info(player_name)
	return OK


func _bind_multiplayer_signals() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
func _on_connected_to_server() -> void:
	var id : int = multiplayer.get_unique_id()
	load_main_game_scene()
	_add_player(id ,local_info)
	rpc_register_player.rpc_id(1 ,id ,local_info)
	printt("Connected to Server Successfully")
	
func _on_connection_failed() -> void:
	printt("Failed to Join Server")
	
func _on_server_disconnected() -> void:
	players.clear()
	players_list_changed.emit({})
	local_info = {}
	if peer == null:
		return
	peer.close()
	peer = null
	load_main_menu_scene()
	printt("Server Disconnected")
	
func _on_peer_connected(id : int) -> void:
	printt("Peer Connected :" , id)
	
func _on_peer_disconnected(id : int) -> void:
	_remove_player(id)
	printt("Peer Disconnected :" , id)

func _add_player(id : int , info : Dictionary):
	players[id] = info
	if multiplayer.is_server():
		spawn_player.emit(id)
	players_list_changed.emit(players)

func _remove_player(id : int):
	players.erase(id)
	if multiplayer.is_server():
		despawn_player.emit(id)
	players_list_changed.emit(players)
	
func _make_player_info(player_name : String) -> Dictionary:
	return {
		"name"  : player_name
	}

@rpc("any_peer", "reliable")
func rpc_register_player(id: int, info: Dictionary) -> void:
	if multiplayer.is_server():
		id = multiplayer.get_remote_sender_id()  # don't trust the id the client sends
		_add_player(id, info)
		for existing_id in players:
			if existing_id != id:
				rpc_register_player.rpc_id(id, existing_id, players[existing_id])
		for peer_id in multiplayer.get_peers():
			if peer_id != id:
				rpc_register_player.rpc_id(peer_id, id, info)
	else:
		_add_player(id, info)
				
func load_main_menu_scene() -> void:
	main_game_scene = get_tree().get_current_scene()
	main_menu_scene = load(MAINMENU_SCENE_PATH).instantiate()
	get_tree().root.add_child(main_menu_scene)
	main_game_scene.process_mode = Node.PROCESS_MODE_DISABLED
	main_game_scene.queue_free()
	get_tree().current_scene = main_menu_scene

func load_main_game_scene() -> void:
	main_menu_scene = get_tree().get_current_scene()
	main_game_scene = load(GAME_SCENE_PATH).instantiate()
	get_tree().root.add_child(main_game_scene)
	main_menu_scene.process_mode = Node.PROCESS_MODE_DISABLED
	main_menu_scene.queue_free()
	main_menu_scene = null
	get_tree().current_scene = main_game_scene


func close_server() -> void:
	players.clear()
	players_list_changed.emit({})
	if peer == null:
		return
	peer.close()
	peer = null
	local_info = {}
	load_main_menu_scene()
	
func leave_server() -> void:
	players.clear()
	players_list_changed.emit({})
	if peer == null:
		return
	peer.close()
	peer = null
	local_info = {}
	load_main_menu_scene()
