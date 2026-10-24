extends Control

var joystick : VirtualJoystickDX

var btn : bool = false:
	set(b):
		_print_tree()
		
func _ready() -> void:
	NetworkManeger.players_list_changed.connect(update_players)
	update_players(0)
	
func _print_tree():
	get_parent().print_tree_pretty()

func _process(delta: float) -> void:
	%FPS.text = "FPS : " + str(int(Engine.get_frames_per_second()))
	if !joystick:
		joystick = get_parent().get_node_or_null("MainGame/Players/1/Ui/Joystick")
		if joystick:
			joystick.joystick_moved.connect(update_players)


func update_players(_players):
	var text := ""
	for p in _players:
		text += "
		 " + str(p)
	%OnlinePlayers.text = "OnlinePlayers" + text
