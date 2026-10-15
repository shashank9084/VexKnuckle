# GameWorld.gd
# Attach to the root Node3D of your game scene.
#
# Scene tree:
#   Node3D  (GameWorld)          ← this script
#     WorldEnvironment
#     DirectionalLight3D
#     StaticBody3D  (floor/map)
#     SpawnPoints (Node3D)
#       SpawnPoint0 (Marker3D)
#       SpawnPoint1 (Marker3D)
#       ...
#     Players (Node3D)           ← MultiplayerSpawner spawns here
#       MultiplayerSpawner       (configured below)
# ─────────────────────────────────────────────────────────────
extends Node

# ── Config ───────────────────────────────────────────────────
@export var player_scene    : PackedScene
@export var spawn_points    : NodePath = "SpawnPoints"

# ── Node refs ────────────────────────────────────────────────
@onready var _players_root  : Node3D              = $Players
@onready var _items_root    : Node3D              = $items
@onready var _spawner       : MultiplayerSpawner  = $Players/MultiplayerSpawner
@onready var _spawn_root    : Node3D              = get_node(spawn_points)

# ── State ────────────────────────────────────────────────────
var _spawn_idx : int = 0

# ── Init ─────────────────────────────────────────────────────
func _ready() -> void:
	if not multiplayer.has_multiplayer_peer():
		push_warning("GameWorld: no multiplayer peer set — running in solo mode.")
	_configure_spawner()
	if multiplayer.is_server():
		# Spawn everyone who is already connected
		for id in Network.players:
			_spawn_player(id)
		# Spawn future joiners (if mid-game join is desired)
		Network.player_registered.connect(_on_player_registered)
		Network.player_unregistered.connect(_on_player_unregistered)

	# Every peer: set the physics tick rate
	Engine.physics_ticks_per_second = Network.TICK_RATE
	Network.spawn_item.connect(_spawn_item)
	Network.delete_item.connect(_delete_item)
	Network.get_players_nodes.connect(get_players_nodes)
	Network.get_items_nodes.connect(get_items_nodes)
	var data = DataManeger.load_item_data()
	for i in data:
		var res = data[i]["item_resource"]
		var player_uid = data[i]["player_uid"]
		var pos = data[i]["item_position"]
		var rot = data[i]["item_rotation"]
		DataManeger.items[i] = {"player" : player_uid, "position" : pos,"rotation" : rot, "resource" : res}
		if player_uid == null:
			_spawn_item(i,res.scene,pos,rot)
		
	
func _configure_spawner() -> void:
	_spawner.spawn_function = _spawn_func
	# Spawnable scene must also be registered in MultiplayerSpawner inspector
	# (drag player_scene into the Spawnable Scenes list)

# ── Spawning ─────────────────────────────────────────────────
func _spawn_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var data := { "id": peer_id, "spawn_idx": _spawn_idx }
	_spawn_idx = (_spawn_idx + 1) % _get_spawn_count()
	_spawner.spawn(data)
	var _data = Network.get_player_info(peer_id)
	#if multiplayer.is_server():
		#Network._update_inventory(_data["inventory"])
	#else:
		#Network._update_inventory.rpc_id(_data["inventory"])
	apply_loaded_player_data(peer_id,_data)

func _spawn_func(data: Dictionary) -> Node:
	var player := player_scene.instantiate() as CharacterBody3D
	player.name = str(data["id"])
	player.set_multiplayer_authority(data["id"])
	var _data = Network.get_player_info(data["id"])
	player.position = _get_spawn_position(data["spawn_idx"])
	
	return player

func _get_spawn_position(idx: int) -> Vector3:
	var count := _get_spawn_count()
	if count == 0:
		print("point not found")
		return Vector3(randf_range(-4, 4), 1.0, randf_range(-4, 4))
	var marker := _spawn_root.get_child(idx % count) as Marker3D
	return marker.global_position if marker else Vector3.ZERO

func _get_spawn_count() -> int:
	return _spawn_root.get_child_count() if _spawn_root else 0

# ── Dynamic join/leave (server-side) ─────────────────────────
func _on_player_registered(id: int, _info: Dictionary) -> void:
	if not _players_root.has_node(str(id)):
		_spawn_player(id)
	print("spawned by game")

func _on_player_unregistered(id: int) -> void:
	var node := _players_root.get_node_or_null(str(id))
	if node:
		node.queue_free()

# ── Optional: return-to-lobby RPC ────────────────────────────
@rpc("authority", "reliable", "call_local")
func rpc_return_to_lobby(lobby_path: String) -> void:
	get_tree().change_scene_to_file(lobby_path)


func _spawn_item(item_id,_scene,position,rotation = Vector3.ZERO):
	var scene = _scene.instantiate()
	scene.id = item_id
	scene.position = position
	scene.rotation = rotation
	scene.name = str(item_id)
	_items_root.add_child(scene,true)
	
func _delete_item(id):
	if _items_root.get_child_count() < 0:
		return
	for c in _items_root.get_children():
		if ! c is MultiplayerSpawner:
			if c.id == id:
				c.queue_free()
				break
				
func get_items_nodes():
	var nodes = {}
	for c in _items_root.get_children():
		if c is RigidBody3D:
			var id = str(c.id)
			nodes[id] = c
	Network.set_items_nodes(nodes)


func get_players_nodes():
	var nodes = {}
	for c in _players_root.get_children():
		if c is CharacterBody3D:
			var id = c.name.to_int()
			nodes[id] = c
		
	Network.set_players_nodes(nodes)


func apply_loaded_player_data(id: int, data: Dictionary) -> void:
	if not multiplayer.is_server():
		push_error("apply_loaded_player_data called by client")
		return
	var player
	for p in  _players_root.get_children():
		if p.name == str(id):
			player = p
			break
	if data.has("saved_position"):
		var pos_data = data["saved_position"]

		player.position = pos_data
	if data.has("saved_rotation"):
		var rot_data = data["saved_rotation"]
		var character = player.get_node_or_null("character")
		if character:
			character.rotation = rot_data
	if data.has("saved_camera_rotation"):
		var camera_data = data["saved_camera_rotation"]
		var camera_pivot = player.get_node_or_null("CameraPivot")
		if camera_pivot:
			camera_pivot.rotation = camera_data
