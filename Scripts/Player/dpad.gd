extends Control


@export var up_button : TouchScreenButton
@export var down_button : TouchScreenButton
@export var left_button : TouchScreenButton
@export var right_button : TouchScreenButton
@export var up_left_button : TouchScreenButton
@export var up_right_button : TouchScreenButton
@export var down_left_button : TouchScreenButton
@export var down_right_button : TouchScreenButton

var main_btns : Array
var side_btns : Array


func _ready() -> void:
	main_btns = [up_button,down_button,left_button,right_button]
	side_btns = [up_right_button,up_left_button,down_right_button,down_left_button]
	for b : TouchScreenButton in main_btns:
		b.pressed.connect(button_pressed.bind(b))
		b.released.connect(button_release.bind(b))
	for b : TouchScreenButton in side_btns:
		b.pressed.connect(button_pressed.bind(b))
		b.released.connect(button_release.bind(b))
	#hide_side_buttons()

func button_pressed(button : TouchScreenButton):
	match button.get_parent().name:
		"up":
			Input.action_press("ui_up")
		"down":
			Input.action_press("ui_down")
		"left":
			Input.action_press("ui_left")
		"right":
			Input.action_press("ui_right")
		"up_left":
			Input.action_press("ui_up")
			Input.action_press("ui_left")
		"up_right":
			Input.action_press("ui_up")
			Input.action_press("ui_right")
		"down_left":
			Input.action_press("ui_down")
			Input.action_press("ui_left")
		"down_right":
			Input.action_press("ui_down")
			Input.action_press("ui_right")
	#show_side_buttons()
			
func button_release(button : TouchScreenButton):
	match button.get_parent().name:
		"up":
			Input.action_release("ui_up")
		"down":
			Input.action_release("ui_down")
		"left":
			Input.action_release("ui_left")
		"right":
			Input.action_release("ui_right")
		"up_left":
			Input.action_release("ui_up")
			Input.action_release("ui_left")
		"up_right":
			Input.action_release("ui_up")
			Input.action_release("ui_right")
		"down_left":
			Input.action_release("ui_down")
			Input.action_release("ui_left")
		"down_right":
			Input.action_release("ui_down")
			Input.action_release("ui_right")
	#hide_side_buttons()
			
func hide_side_buttons():
	for b : TouchScreenButton in side_btns:
		b.hide()
		
func show_side_buttons():
	for b : TouchScreenButton in side_btns:
		b.show()
