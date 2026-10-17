extends Control


func _on_exit_pressed() -> void:
	if multiplayer.is_server():
		NetworkManeger.close_server()
	else:
		NetworkManeger.leave_server()
