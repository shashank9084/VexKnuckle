extends Control

# Assign these in the Inspector, or leave empty to use the existing unique node names.
@export var action_label: RichTextLabel
@export var player_property_label: RichTextLabel
@export var player_move_state_label: RichTextLabel
@export var fps_label: Label
@export var online_players_label: Label
@export var latency_label: Label
@export var joystick: VirtualJoystickDX
@export var player : CharacterBody3D
@export var root_motion_movement_component : PlayerRootMotionMovementComponent

# Used only if the joystick export is not assigned.
@export var player_properties : Dictionary[String,String]
@export var player_path: NodePath = ^"MainGame/Players/ID"
@export var root_motion_movement_component_path = ^"ComponentsManeger/PlayerRootMotionMovementComponent"
@export_range(0.05, 1.0, 0.05) var action_poll_interval: float = 0.1

var _player_nodes_properties : Dictionary[String,Node]
var _player_properties_states : Dictionary = {}
var _action_names: Array[StringName] = []
var _action_states: Dictionary = {}
var _action_timer: float = 0.0

# Latency meter (round-trip time / ping)
@export_range(0.25, 5.0, 0.25) var ping_interval: float = 1.0
@export_range(1.0, 10.0, 0.5) var ping_timeout: float = 3.0
var _ping_timer: float = 0.0
var _next_ping_id: int = 0
var _pending_pings: Dictionary = {}
var _latency_ms: int = -1


func _ready() -> void:
	# Preserve the existing scene's label references if Inspector exports are empty.
	if not is_instance_valid(fps_label):
		fps_label = get_node_or_null("%FPS") as Label
	if not is_instance_valid(online_players_label):
		online_players_label = get_node_or_null("%OnlinePlayers") as Label
	if not is_instance_valid(latency_label):
		latency_label = get_node_or_null("%Ping") as Label
	if not is_instance_valid(latency_label):
		latency_label = get_node_or_null("%Latency") as Label

	_update_latency_label("PING: -- ms")
	if not NetworkManeger.players_list_changed.is_connected(update_players):
		NetworkManeger.players_list_changed.connect(update_players)

	_cache_actions()

	update_players(NetworkManeger.players)



func _process(delta: float) -> void:
	if is_instance_valid(fps_label):
		fps_label.text = "FPS : %d" % Engine.get_frames_per_second()

	_update_latency(delta)

	_action_timer += delta
	if _action_timer >= action_poll_interval:
		_action_timer = 0.0
		_update_action_states()
		_update_player_properties_states()
		_update_player_rmmc_move_state()
		if ! is_instance_valid(player):
			_resolve_player()
		

func _update_player_rmmc_move_state() -> void:
	if !is_instance_valid(player) or ! is_instance_valid(player_move_state_label) or ! is_instance_valid(root_motion_movement_component):
		return
	var output := ""
	var state_text = root_motion_movement_component.STATES.find_key(root_motion_movement_component.get("state"))
	if state_text == null : return
	output += "Player State : [color=cyan]%s[/color]\n" % [state_text]
	
	player_move_state_label.text = output


func _cache_player_properties() -> void:
	_player_properties_states.clear()
	
	for p in player_properties.keys():
		var property_node := player.get_node_or_null(NodePath(player_properties[p]))
		if property_node != null && property_node.get(p) != null:
			_player_properties_states[p] = "Null"
			_player_nodes_properties[p] = property_node
	_refresh_player_property_label()

func _cache_actions() -> void:
	_action_names.clear()
	_action_states.clear()

	for action in InputMap.get_actions():
		# Exclude Godot's built-in UI actions.
		if String(action).begins_with("ui_"):
			continue

		_action_names.append(action)
		_action_states[action] = Input.is_action_pressed(action)

	_refresh_action_label()

func _update_player_properties_states() -> void:
	if not is_instance_valid(player_property_label) or not is_instance_valid(player):
		return

	var changed := false
	for property in _player_nodes_properties.keys():
		var boolen = str(_player_nodes_properties[property].get(property))
		if boolen == null: return
		if _player_properties_states[property] != boolen:
			_player_properties_states[property] = boolen
			changed = true

	if changed:
		_refresh_player_property_label()

func _update_action_states() -> void:
	if not is_instance_valid(action_label):
		return

	var changed := false
	for action in _action_names:
		var pressed := Input.is_action_pressed(action)
		if _action_states[action] != pressed:
			_action_states[action] = pressed
			changed = true

	if changed:
		_refresh_action_label()

func _refresh_player_property_label() -> void:
	if not is_instance_valid(player_property_label):
		return

	var output := ""
	for property in _player_nodes_properties.keys():
		var boolen = _player_nodes_properties[property].get(property)
		if boolen == null : return
		match type_string(typeof(boolen)):
			"int":
				boolen = str(boolen)
				output += "%s : [color=%s]%s[/color]\n" % [String(property), "green", boolen]
			"String":
				boolen = str(boolen)
				output += "%s : [color=%s]%s[/color]\n" % [String(property), "black", boolen]
			"Vector2":
				boolen = str(boolen)
				output += "%s : [color=%s]%s[/color]\n" % [String(property), "blue", boolen]
			"bool":
				var state_text := "true" if boolen else "false"
				var color := "green" if boolen else "red"
				output += "%s : [color=%s]%s[/color]\n" % [String(property), color, state_text]
			_:
				boolen = str(boolen)
				output += "%s : [color=%s]%s[/color]\n" % [String(property), "pink", boolen]

	player_property_label.text = output

func _refresh_action_label() -> void:
	if not is_instance_valid(action_label):
		return

	var output := ""
	for action in _action_names:
		var pressed: bool = _action_states[action]
		var state_text := "true" if pressed else "false"
		var color := "green" if pressed else "red"
		output += "%s : [color=%s]%s[/color]\n" % [String(action), color, state_text]

	action_label.text = output


			
func _resolve_player() -> void:
	if is_instance_valid(player) or not _has_active_peer():
		return
	var _player_path = str(player_path).replace("ID",str(multiplayer.get_unique_id()))
	# Match the lookup style used in the original script.
	var root := get_parent()
	if is_instance_valid(root) and not player_path.is_empty():
		player = root.get_node_or_null(_player_path) as CharacterBody3D
	if is_instance_valid(player):
		player_path = _player_path
		_cache_player_properties()
		_resolve_root_motion_movement_component()
		
func _resolve_root_motion_movement_component():
	if !is_instance_valid(player): return
	var rmmc := player.get_node_or_null(root_motion_movement_component_path)
	if rmmc != null:
		root_motion_movement_component = rmmc


func _on_joystick_moved(_value = null) -> void:
	# Intentionally lightweight; action states are checked on the timer.
	pass


func update_players(players) -> void:
	if not is_instance_valid(online_players_label):
		return

	var output := "OnlinePlayers"
	for player_id in players:
		output += "\n " + str(player_id)

	online_players_label.text = output


func _print_tree() -> void:
	get_parent().print_tree_pretty()


# --- LAN latency meter ---
# Assumes the server peer ID is 1 and this script's node has the same NodePath
# on the server and every client. Add a Label and assign it to latency_label,
# or give it the unique name %Ping / %Latency.
func _update_latency(delta: float) -> void:
	if not _has_active_peer():
		_pending_pings.clear()
		_latency_ms = -1
		_update_latency_label("PING: Offline")
		return

	if multiplayer.is_server():
		_update_latency_label("PING: Server")
		return

	_ping_timer += delta
	if _ping_timer >= ping_interval:
		_ping_timer = 0.0
		_next_ping_id += 1
		_pending_pings[_next_ping_id] = Time.get_ticks_msec()
		request_ping.rpc_id(1, _next_ping_id)

	# Expire unanswered requests so the display does not stay stale forever.
	var now := Time.get_ticks_msec()
	for ping_id in _pending_pings.keys():
		var sent_at: int = _pending_pings[ping_id]
		if float(now - sent_at) >= ping_timeout * 1000.0:
			_pending_pings.erase(ping_id)
			_update_latency_label("PING: Timeout")


@rpc("any_peer", "call_remote", "unreliable")
func request_ping(ping_id: int) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	receive_ping.rpc_id(sender_id, ping_id)


@rpc("authority", "call_remote", "unreliable")
func receive_ping(ping_id: int) -> void:
	if not _pending_pings.has(ping_id):
		return
	var sent_at: int = _pending_pings[ping_id]
	_pending_pings.erase(ping_id)
	_latency_ms = Time.get_ticks_msec() - sent_at
	_update_latency_label("PING: %d ms" % _latency_ms)


func _update_latency_label(message: String) -> void:
	if not is_instance_valid(latency_label):
		return
	latency_label.text = message
	if _latency_ms < 0:
		latency_label.add_theme_color_override("font_color", Color.WHITE)
	elif _latency_ms <= 40:
		latency_label.add_theme_color_override("font_color", Color.GREEN)
	elif _latency_ms <= 80:
		latency_label.add_theme_color_override("font_color", Color.YELLOW)
	elif _latency_ms <= 150:
		latency_label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		latency_label.add_theme_color_override("font_color", Color.RED)



func _has_active_peer() -> bool:
	return multiplayer.has_multiplayer_peer() \
		and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
