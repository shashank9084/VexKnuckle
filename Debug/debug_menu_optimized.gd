extends Control

# Assign these in the Inspector, or leave empty to use the existing unique node names.
@export var action_label: RichTextLabel
@export var player_property_label: RichTextLabel
@export var player_move_state_label: RichTextLabel
@export var fps_label: Label
@export var online_players_label: Label
@export var joystick: VirtualJoystickDX
@export var player : PlayerRootMotionMovementComponent

# Used only if the joystick export is not assigned.
@export var player_properties : Array[String]
@export var player_path: NodePath = ^"MainGame/Players/1/ComponentsManeger/PlayerRootMotionMovementComponent"
@export_range(0.05, 1.0, 0.05) var action_poll_interval: float = 0.1

var _player_properties_states : Dictionary = {}
var _action_names: Array[StringName] = []
var _action_states: Dictionary = {}
var _action_timer: float = 0.0


func _ready() -> void:
	# Preserve the existing scene's label references if Inspector exports are empty.
	if not is_instance_valid(fps_label):
		fps_label = get_node_or_null("%FPS") as Label
	if not is_instance_valid(online_players_label):
		online_players_label = get_node_or_null("%OnlinePlayers") as Label

	if not NetworkManeger.players_list_changed.is_connected(update_players):
		NetworkManeger.players_list_changed.connect(update_players)

	_cache_actions()

	update_players(NetworkManeger.players)



func _process(delta: float) -> void:
	if is_instance_valid(fps_label):
		fps_label.text = "FPS : %d" % Engine.get_frames_per_second()

	_action_timer += delta
	if _action_timer >= action_poll_interval:
		_action_timer = 0.0
		_update_action_states()
		_update_player_properties_states()
		_update_player_move_state()
		if ! is_instance_valid(player):
			_resolve_player()

func _update_player_move_state() -> void:
	if !is_instance_valid(player) or ! is_instance_valid(player_move_state_label):
		return
	var output := ""
	var state_text = player.STATES.find_key(player.get("state"))
	if state_text == null : return
	output += "Player State : [color=cyan]%s[/color]\n" % [state_text]
	
	player_move_state_label.text = output


func _cache_player_properties() -> void:
	_player_properties_states.clear()
	
	for p in player_properties:
		if player.get(p) != null:
			_player_properties_states[p] = "Null"
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
	for property in player_properties:
		var boolen = str(player.get(property))
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
	for property in player_properties:
		var boolen = player.get(property)
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
	if is_instance_valid(player):
		return

	# Match the lookup style used in the original script.
	var root := get_parent()
	if is_instance_valid(root) and not player_path.is_empty():
		player = root.get_node_or_null(player_path) as PlayerRootMotionMovementComponent

	if is_instance_valid(player):
		_cache_player_properties()
		


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
