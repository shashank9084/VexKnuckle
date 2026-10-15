# NetworkManager.gd
# Autoload singleton — add as "Network" in Project > Autoload
#
# Responsibilities:
#   • Host / join / disconnect ENet sessions on LAN
#   • UDP broadcast for zero-config server discovery
#   • Central player registry (id → PlayerInfo)
#   • Scene-change RPC so all peers stay in sync
# ─────────────────────────────────────────────────────────────
extends Node

# ── Signals ──────────────────────────────────────────────────
signal server_created
signal joined_server(peer_id: int)
signal connection_failed
signal server_disconnected
signal player_registered(id: int, info: Dictionary)
signal player_unregistered(id: int)
signal server_discovered(ip: String, info: Dictionary)
signal lobby_count_changed(count: int)
signal game_started
signal output_message(message:String)
signal spawn_item(id : String,scene : PackedScene,spawn_position : Vector3,spawn_rotation : Vector3)
signal delete_item(item_id)
signal get_players_nodes()
signal get_items_nodes()
signal add_item_to_pickup_list(item_id)
signal pick_item(item_id)

# ── Constants ────────────────────────────────────────────────
const GAME_PORT        : int    = 7777
const DISCOVERY_PORT   : int    = 7778
const BROADCAST_ADDR   : String = "255.255.255.255"
const MAX_PLAYERS      : int    = 8
const TICK_RATE        : int    = 60          # physics ticks / sec
const DISCOVERY_HZ     : float  = 1.5        # broadcast interval (s)
const DISCOVERY_TTL    : float  = 5.0        # remove stale entries after (s)

# ── State ────────────────────────────────────────────────────
var peer          : ENetMultiplayerPeer = null
var players       : Dictionary = {}           # id(int) → PlayerInfo(dict)
var local_info    : Dictionary = {}
var players_nodes : Dictionary = {}
var is_hosting    : bool = false
var game_running  : bool = false

# LAN discovery
var _udp_bcast    : PacketPeerUDP = null      # host → broadcasts
var _udp_listen   : PacketPeerUDP = null      # client → listens
var _bcast_timer  : float = 0.0
var _found_servers: Dictionary = {}           # ip → {info, ttl}
var _server_name  : String = "LAN Game"
var save_timer := 0.0
var game_scene_path   : String = "res://scenes/game.tscn"


var main_menu_scene
var game_scene

var command_maneger :CommandManeger = CommandManeger.new()

# ── Lifecycle ─────────────────────────────────────────────────
func _ready() -> void:
	_bind_multiplayer_signals()
	set_process(true)

func _process(delta: float) -> void:
	_tick_discovery(delta)
	_tick_save_all_player_data(delta)

func _tick_save_all_player_data(delta: float) -> void:
	if !game_running:
		return
	if multiplayer.is_server():
		save_timer += delta

		if save_timer >= 30.0:
			save_timer = 0.0
			save_all_player_data()
			save_all_item_data()
# ── Public API ────────────────────────────────────────────────
func quit_to_main_menu() -> void:
	game_running = false
	if multiplayer.is_server():
		save_all_player_data()
		save_all_item_data()
		stop_server()
	game_scene.queue_free()
	main_menu_scene.visible = true
	main_menu_scene.process_mode = Node.PROCESS_MODE_INHERIT
	
## Create a server and begin LAN broadcast.
func host(player_name: String, srv_name: String = "LAN Game") -> Error:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(GAME_PORT, MAX_PLAYERS)
	if err != OK:
		push_error("NetworkManager: failed to create server — %s" % error_string(err))
		return err

	multiplayer.multiplayer_peer = peer
	is_hosting  = true
	_server_name = srv_name

	local_info = _make_player_info(player_name, 1,DataManeger.player_uid)
	players[1] = local_info
	update_local_info_from_data(1)
	_start_broadcast()
	server_created.emit()
	lobby_count_changed.emit(players.size())
	game_running = true
	_stop_broadcast()
	_rpc_load_scene(game_scene_path)
	return OK

## Connect to a host discovered (or entered manually).
func join(ip: String, player_name: String) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, GAME_PORT)
	if err != OK:
		push_error("NetworkManager: failed to connect — %s" % error_string(err))
		return err

	multiplayer.multiplayer_peer = peer
	is_hosting = false
	local_info = _make_player_info(player_name, 0, DataManeger.player_uid)
	return OK

## Gracefully leave or shut down.

## Start listening for LAN broadcasts (call from join lobby).
func start_discovery_listen() -> void:
	if _udp_listen:
		return
	_udp_listen = PacketPeerUDP.new()
	_udp_listen.bind(DISCOVERY_PORT)

## Stop listening (call when leaving lobby or hosting).
func stop_discovery_listen() -> void:
	if _udp_listen:
		_udp_listen.close()
		_udp_listen = null
	_found_servers.clear()


# ── Internals: multiplayer signals ───────────────────────────
func _bind_multiplayer_signals() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_peer_connected(id: int) -> void:
	pass
	#_rpc_load_scene.rpc_id(id,game_scene_path)

func _on_peer_disconnected(id: int) -> void:
	await save_player_data(id)
	_remove_player(id)
	if multiplayer.is_server():
		for peer_id in multiplayer.get_peers():
			_rpc_unregister_player.rpc_id(peer_id, id)

func _on_connected_to_server() -> void:
	_rpc_load_scene(game_scene_path)
	local_info["id"] = multiplayer.get_unique_id()
	players[local_info.id] = local_info
	player_registered.emit(local_info.id, local_info)
	lobby_count_changed.emit(players.size())
	rpc_register_player.rpc_id(1, local_info)
	joined_server.emit(local_info.id)

func _on_connection_failed() -> void:
	peer = null
	multiplayer.multiplayer_peer = null
	connection_failed.emit()

func _on_server_disconnected() -> void:
	server_disconnected.emit()

# ── RPCs: player registry ─────────────────────────────────────
## Called by any client to register themselves with the server.
# REMOVE call_local — handle each case explicitly
@rpc("any_peer", "reliable")
func rpc_register_player(info: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0:
		info["id"] = sender
	_add_player(info)
	lobby_count_changed.emit(players.size())
	if multiplayer.is_server():
		update_local_info_from_data(sender)
		for existing_id in players:
			if existing_id != sender:
				rpc_register_player.rpc_id(sender, players[existing_id])
		for peer_id in multiplayer.get_peers():
			if peer_id != sender:
				rpc_register_player.rpc_id(peer_id, info)
## Server → all: remove a player.

@rpc("authority", "reliable", "call_local")
func _rpc_unregister_player(id: int) -> void:
	_remove_player(id)
	lobby_count_changed.emit(players.size())

## Server → all: load a new scene.
@rpc("authority", "reliable")
func _rpc_load_scene(path: String) -> void:
	game_started.emit()
	main_menu_scene = get_tree().get_current_scene()
	game_scene = load(path).instantiate()
	get_tree().root.add_child(game_scene)
	main_menu_scene.process_mode = Node.PROCESS_MODE_DISABLED
	main_menu_scene.visible = false

# ── Internals: registry helpers ───────────────────────────────
func _add_player(info: Dictionary) -> void:
	var id : int = info.get("id", -1)
	if id == -1:
		return
	players[id] = info
	player_registered.emit(id, info)

func _remove_player(id: int) -> void:
	if players.has(id):
		players.erase(id)
		player_unregistered.emit(id)

func _make_player_info(player_name: String, id: int,_player_uid : String) -> Dictionary:
	return {
		"id"    : id,
		"name"  : player_name,
		"color" : Color(randf_range(0.3, 1.0), randf_range(0.3, 1.0), randf_range(0.3, 1.0)),
		"ready" : false,
		"inventory" : {},
		"player_uid" : _player_uid,
		"saved_position" : Vector3.ZERO,
		"saved_rotation" : Vector3.ZERO,
		"saved_camera_rotation" : Vector3.ZERO
	}

# ── LAN discovery ─────────────────────────────────────────────
func _start_broadcast() -> void:
	stop_discovery_listen()
	_udp_bcast = PacketPeerUDP.new()

func _stop_broadcast() -> void:
	if _udp_bcast:
		_udp_bcast.close()
		_udp_bcast = null
	_bcast_timer = 0.0

func _tick_discovery(delta: float) -> void:
	# Host: broadcast presence
	if is_hosting and _udp_bcast and not game_running:
		_bcast_timer += delta
		if _bcast_timer >= DISCOVERY_HZ:
			_bcast_timer = 0.0
			_broadcast_once()

	# Client: receive broadcasts
	if _udp_listen:
		while _udp_listen.get_available_packet_count() > 0:
			var pkt := _udp_listen.get_packet()
			var ip  := _udp_listen.get_packet_ip()
			_handle_bcast(pkt, ip)

		# Age out stale entries
		for ip in _found_servers.keys():
			_found_servers[ip]["ttl"] -= delta
			if _found_servers[ip]["ttl"] <= 0.0:
				_found_servers.erase(ip)

func _broadcast_once() -> void:
	var payload := JSON.stringify({
		"name"       : _server_name,
		"players"    : players.size(),
		"max_players": MAX_PLAYERS,
	}).to_utf8_buffer()
	_udp_bcast.set_broadcast_enabled(true)
	_udp_bcast.set_dest_address(BROADCAST_ADDR, DISCOVERY_PORT)
	_udp_bcast.put_packet(payload)

func _handle_bcast(pkt: PackedByteArray, ip: String) -> void:
	var json := JSON.new()
	if json.parse(pkt.get_string_from_utf8()) != OK:
		return
	var info : Dictionary = json.get_data()
	var is_new := not _found_servers.has(ip)
	_found_servers[ip] = { "info": info, "ttl": DISCOVERY_TTL }
	if is_new:
		server_discovered.emit(ip, info)

# ── Utility ───────────────────────────────────────────────────
func get_player_info(id: int) -> Dictionary:
	return players.get(id, {})

func get_local_id() -> int:
	return multiplayer.get_unique_id() if multiplayer.multiplayer_peer else 0

func player_count() -> int:
	return players.size()
	
	
	
###----------------------------- MULTIPLAYER  CHAT --------------------------------###

@rpc("any_peer","reliable")
func server_receive_chat(message:String):
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0 : sender = 1
	if !players.has(sender):
		return

	message = message.strip_edges()
	if message.is_empty():
		return
	if message.length() > 200:
		return
	var player_name = players[sender].get("name","Unknown")
	if message.begins_with("/"):
		command_maneger._run_command(sender, message.substr(1))
		return
	receive_chat.rpc(player_name, message)

@rpc("authority","call_local","reliable")
func receive_chat(player_name:String,message:String):
	output_message.emit("[color=cyan]%s[/color]: %s" % [player_name,message])
	print(message)


func send_chat(message:String):
	if multiplayer.is_server():
		server_receive_chat(message)
	else:
		server_receive_chat.rpc_id(1,message)
	

func save_player_data(id):
	if !multiplayer.is_server():
		push_error("called by client")
		return
	update_players_nodes()
	var _player_uid = players[id]["player_uid"]
	var character = players_nodes[id].get_node_or_null("character")
	var camera_pivot = players_nodes[id].get_node_or_null("CameraPivot")
	if !character or !camera_pivot:
		return
	DataManeger.save_player_data(_player_uid,players_nodes[id].position,
		character.rotation,camera_pivot.rotation,players[id]["inventory"])


func load_player_data(id):
	if !multiplayer.is_server():
		push_error("calledby client")
		return {}
	var data = DataManeger.load_player_data(players[id]["player_uid"])
	return data
	
func save_all_player_data():
	if !multiplayer.is_server():
		push_error("calledby client")
		return
	for p in players:
		save_player_data(p)

func update_players_nodes():
	get_players_nodes.emit()
	
func set_players_nodes(nodes):
	players_nodes = nodes

func update_items_nodes():
	get_items_nodes.emit()
	
func set_items_nodes(nodes):
	DataManeger.items_nodes = nodes

func update_local_info_from_data(id):
	var data : Dictionary = load_player_data(id)
	if data.is_empty():
		return
	if data.has("player_position"):
		players[id]["saved_position"] = data["player_position"]
	if data.has("player_rotation"):
		players[id]["saved_rotation"] = data["player_rotation"]
	if data.has("camera_rotation"):
		players[id]["saved_camera_rotation"] = data["camera_rotation"]
	if data.has("inventory"):
		players[id]["inventory"] = data["inventory"]

func stop_server():
	if !multiplayer.is_server():
		return

	for id in multiplayer.get_peers():
		multiplayer.multiplayer_peer.disconnect_peer(id)
		_rpc_unregister_player.rpc(id)

	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	players.clear()
	_stop_broadcast()
	_found_servers.clear()


@rpc("any_peer","reliable")
func validate_item(item_id):
	if !multiplayer.is_server(): return
	update_items_nodes()
	update_players_nodes()
	var id = multiplayer.get_remote_sender_id()
	if id == 0: id = 1
	if DataManeger.items[item_id]["player"] != null:
		_remove_item.rpc_id(id,item_id)
		return
	var dis = players_nodes[id].position.distance_to(DataManeger.items_nodes[item_id].position)
	if dis < 5:
		if multiplayer.is_server():
			_add_item_to_pickup_list(item_id)
		else:
			_add_item_to_pickup_list.rpc_id(id,item_id)
	
@rpc("authority","reliable")
func _add_item_to_pickup_list(item_id):
	add_item_to_pickup_list.emit(item_id,DataManeger.items[item_id]["resource"])
	
@rpc("any_peer","reliable")
func request_pick_item(item_id):
	if !multiplayer.is_server(): return
	update_items_nodes()
	update_players_nodes()
	var id = multiplayer.get_remote_sender_id()
	if id == 0: id = 1
	if DataManeger.items[item_id]["player"] != null:
		_remove_item.rpc_id(id,item_id)
		return
	var dis = players_nodes[id].position.distance_to(DataManeger.items_nodes[item_id].position)
	if dis < 5:
		if id == 1:
			_pick_item(item_id)
		else:
			_pick_item.rpc_id(id,item_id)
		await save_item_data(item_id)
		DataManeger.items[item_id]["player"] = players[id]["player_uid"]
		_remove_item.rpc(item_id)
		players[id]["inventory"][item_id] = true

@rpc("any_peer","reliable")
func _request_throw_item(item_id):
	var id := multiplayer.get_remote_sender_id()
	if !multiplayer.is_server(): return 
	else: if id == 0 : id = 1
	if players[id]["inventory"].has(item_id):
		var data = DataManeger.items[item_id]
		var scene = data["resource"].scene
		var spawn_pos = data["position"] if data["position"] != null else Vector3(0,10,0)
		var spawn_rot = data["rotation"] if data["rotation"] != null else Vector3(0,10,0)
		DataManeger.items[item_id]["player"] = null
		players[id]["inventory"].erase(item_id)
		_spawn_item(item_id,scene,spawn_pos,spawn_rot)
	
@rpc("authority","reliable","call_local")
func _spawn_item(item_id : String, scene : PackedScene, spawn_position : Vector3, spawn_roatation : Vector3):
	spawn_item.emit(item_id,scene,spawn_position,spawn_roatation)

@rpc("authority","reliable","call_local")
func _remove_item(item_id):
	delete_item.emit(item_id)
	
@rpc("authority","reliable")
func _pick_item(item_id):
	pick_item.emit(item_id)


func save_item_data(item_id):
	if !multiplayer.is_server():
		push_error("called by client")
		return
	update_items_nodes()
	await get_tree().create_timer(0.5).timeout
	if DataManeger.items[item_id]["player"] == null:
		var n = DataManeger.items_nodes[item_id]
		await DataManeger.save_item_data(item_id,n.global_position,n.global_rotation,DataManeger.items[item_id]["resource"],
		DataManeger.items[item_id]["player"])
		DataManeger.items[item_id]["position"] = n.global_position
		DataManeger.items[item_id]["rotation"] = n.global_rotation
	else:
		var data = DataManeger.items[item_id]
		await DataManeger.save_item_data(item_id,data["position"],data["rotation"],data["resource"],data["player"])

	
func save_all_item_data():
	if !multiplayer.is_server():
		push_error("calledby client")
		return
	for p in DataManeger.items:
		save_item_data(p)
