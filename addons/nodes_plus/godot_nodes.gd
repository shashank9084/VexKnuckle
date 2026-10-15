@tool
extends EditorPlugin

var dock: EditorDock


func _enable_plugin() -> void:
	# Called once when the user enables the plugin in Project Settings.
	# Sub-plugin registration can be added here if needed.
	pass


func _disable_plugin() -> void:
	# Called once when the user disables the plugin in Project Settings.
	# Sub-plugin cleanup can be added here if needed.
	pass


func _enter_tree() -> void:
	# Node-based components
	add_custom_type("Cooldown", "Node", preload("nodes/cooldown.gd"), preload("icons/node/icon_clear.png"))
	add_custom_type("Damage", "Node", preload("nodes/damage.gd"), preload("icons/node/icon_sword.png"))
	add_custom_type("Follow2D", "Node", preload("nodes/follow2D.gd"), preload("icons/node_2D/icon_follow.png"))
	add_custom_type("Follow3D", "Node", preload("nodes/follow3D.gd"), preload("icons/node_3D/icon_follow.png"))
	add_custom_type("Health", "Node", preload("nodes/health.gd"), preload("icons/node/Health.svg"))
	add_custom_type("Lifespan", "Node", preload("nodes/lifespan.gd"), preload("icons/node/icon_event.png"))
	add_custom_type("Load", "Node", preload("nodes/load.gd"), preload("icons/node/icon_folder.png"))
	add_custom_type("ObjectPool", "Node", preload("nodes/object_pool.gd"), preload("icons/node/icon_gear.png"))
	add_custom_type("Regeneration", "Node", preload("nodes/regeneration.gd"), preload("icons/node/Regenerate.svg"))
	add_custom_type("Save", "Node", preload("nodes/save.gd"), preload("icons/node/icon_save.png"))
	add_custom_type("Shaker", "Node", preload("nodes/shake.gd"), preload("icons/node/icon_particle.png"))
	add_custom_type("Shield", "Node", preload("nodes/shield.gd"), preload("icons/node/icon_shield.png"))
	add_custom_type("Spawner", "Node", preload("nodes/spawner.gd"), preload("icons/node/icon_gear.png"))
	add_custom_type("State", "Node", preload("nodes/state.gd"), preload("icons/node/State.svg"))
	add_custom_type("StateMachine", "Node", preload("nodes/state_machine.gd"), preload("icons/node/StateMachine.svg"))
	add_custom_type("StatusEffect", "Node", preload("nodes/status_effect.gd"), preload("icons/node/icon_brain.png"))

	# Area2D-based
	add_custom_type("Hitbox2D", "Area2D", preload("nodes/hitbox2D.gd"), preload("icons/node_2D/icon_area_damage.png"))
	add_custom_type("Hurtbox2D", "Area2D", preload("nodes/hurtbox2D.gd"), preload("icons/node_2D/icon_hitbox.png"))
	add_custom_type("InteractionArea2D", "Area2D", preload("nodes/interaction_area_2D.gd"), preload("icons/node_2D/icon_hand.png"))
	add_custom_type("Target2D", "Area2D", preload("nodes/target2D.gd"), preload("icons/node_2D/icon_target.png"))

	# Area3D-based
	add_custom_type("Hitbox3D", "Area3D", preload("nodes/hitbox_3D.gd"), preload("icons/node_3D/icon_area_damage.png"))
	add_custom_type("Hurtbox3D", "Area3D", preload("nodes/hurtbox_3D.gd"), preload("icons/node_3D/icon_hitbox.png"))
	add_custom_type("InteractionArea3D", "Area3D", preload("nodes/interaction_area_3D.gd"), preload("icons/node_3D/icon_hand.png"))
	add_custom_type("Target3D", "Area3D", preload("nodes/target3D.gd"), preload("icons/node_3D/icon_target.png"))

	# CharacterBody-based
	add_custom_type("Projectile2D", "CharacterBody2D", preload("nodes/projectile2D.gd"), preload("icons/node_2D/icon_projectile.png"))
	add_custom_type("Projectile3D", "CharacterBody3D", preload("nodes/projectile3D.gd"), preload("icons/node_3D/icon_projectile.png"))

	# RichTextLabel-based
	add_custom_type("TimerLabel", "RichTextLabel", preload("nodes/timer_label.gd"), preload("icons/control/icon_dialog.png"))

	dock = preload("nodes_plus_dock.gd").new()
	dock.title = "NodesPlus"
	dock.default_slot = EditorDock.DOCK_SLOT_LEFT_BR
	add_dock(dock)


func _exit_tree() -> void:
	if dock:
		remove_dock(dock)
		dock.queue_free()
		dock = null
	remove_custom_type("Cooldown")
	remove_custom_type("Damage")
	remove_custom_type("Follow2D")
	remove_custom_type("Follow3D")
	remove_custom_type("Health")
	remove_custom_type("Lifespan")
	remove_custom_type("Load")
	remove_custom_type("ObjectPool")
	remove_custom_type("Regeneration")
	remove_custom_type("Save")
	remove_custom_type("Shaker")
	remove_custom_type("Shield")
	remove_custom_type("Spawner")
	remove_custom_type("State")
	remove_custom_type("StateMachine")
	remove_custom_type("StatusEffect")
	remove_custom_type("Hitbox2D")
	remove_custom_type("Hurtbox2D")
	remove_custom_type("InteractionArea2D")
	remove_custom_type("Target2D")
	remove_custom_type("Hitbox3D")
	remove_custom_type("Hurtbox3D")
	remove_custom_type("InteractionArea3D")
	remove_custom_type("Target3D")
	remove_custom_type("Projectile2D")
	remove_custom_type("Projectile3D")
	remove_custom_type("TimerLabel")
