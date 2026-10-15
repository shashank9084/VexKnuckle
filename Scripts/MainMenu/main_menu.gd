extends Control


func _on_host_pressed() -> void:
	var player_name : String = %NameLineEdit.text if %NameLineEdit.text != "" else "Noob"
	var err := NetworkManeger.host(player_name)
	if err != OK:
		%HostBtn.disabled = true
		push_error(err)


func _on_join_pressed() -> void:
	var player_name : String = %NameLineEdit.text if %NameLineEdit.text != "" else "Noob"
	var ip_address : String = %IpLineEdit.text if %IpLineEdit.text != "" else %IpLineEdit.placeholder_text
	var err := NetworkManeger.join(ip_address,player_name)
	if err == OK:
		%JoinBtn.disabled = true
	else:
		push_error(err)
		
	
