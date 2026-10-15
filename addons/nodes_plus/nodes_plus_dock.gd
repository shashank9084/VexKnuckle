@tool
extends EditorDock

const NODES := {
	"Various": [
		{ "name": "ObjectPool", "base": "Node", "script": "res://addons/nodes_plus/nodes/object_pool.gd", "icon": "res://addons/nodes_plus/icons/node/icon_gear.png" },
		{ "name": "Spawner", "base": "Node", "script": "res://addons/nodes_plus/nodes/spawner.gd", "icon": "res://addons/nodes_plus/icons/node/icon_gear.png" },
		{ "name": "Shaker", "base": "Node", "script": "res://addons/nodes_plus/nodes/shake.gd", "icon": "res://addons/nodes_plus/icons/node/icon_particle.png" },
	],
	
	"Stats": [
		{ "name": "Health", "base": "Node", "script": "res://addons/nodes_plus/nodes/health.gd", "icon": "res://addons/nodes_plus/icons/node/Health.svg" },
		{ "name": "Damage", "base": "Node", "script": "res://addons/nodes_plus/nodes/damage.gd", "icon": "res://addons/nodes_plus/icons/node/icon_sword.png" },
		{ "name": "Shield", "base": "Node", "script": "res://addons/nodes_plus/nodes/shield.gd", "icon": "res://addons/nodes_plus/icons/node/icon_shield.png" },
		{ "name": "Regeneration", "base": "Node", "script": "res://addons/nodes_plus/nodes/regeneration.gd", "icon": "res://addons/nodes_plus/icons/node/Regenerate.svg" },
		{ "name": "Cooldown", "base": "Node", "script": "res://addons/nodes_plus/nodes/cooldown.gd", "icon": "res://addons/nodes_plus/icons/node/icon_clear.png" },
		{ "name": "Lifespan", "base": "Node", "script": "res://addons/nodes_plus/nodes/lifespan.gd", "icon": "res://addons/nodes_plus/icons/node/icon_event.png" },
		{ "name": "StatusEffect", "base": "Node", "script": "res://addons/nodes_plus/nodes/status_effect.gd", "icon": "res://addons/nodes_plus/icons/node/icon_brain.png" },
	],
	
	"Save/Load":[
		{ "name": "Save", "base": "Node", "script": "res://addons/nodes_plus/nodes/save.gd", "icon": "res://addons/nodes_plus/icons/node/icon_save.png" },
		{ "name": "Load", "base": "Node", "script": "res://addons/nodes_plus/nodes/load.gd", "icon": "res://addons/nodes_plus/icons/node/icon_folder.png" },
	],
	
	"State Machine":[
		{ "name": "StateMachine", "base": "Node", "script": "res://addons/nodes_plus/nodes/state_machine.gd", "icon": "res://addons/nodes_plus/icons/node/StateMachine.svg" },
		{ "name": "State", "base": "Node", "script": "res://addons/nodes_plus/nodes/state.gd", "icon": "res://addons/nodes_plus/icons/node/State.svg" },
	],
	
	"2D": [
		{ "name": "Follow2D", "base": "Node", "script": "res://addons/nodes_plus/nodes/follow2D.gd", "icon": "res://addons/nodes_plus/icons/node_2D/icon_follow.png" },
		{ "name": "Hitbox2D", "base": "Area2D", "script": "res://addons/nodes_plus/nodes/hitbox2D.gd", "icon": "res://addons/nodes_plus/icons/node_2D/icon_area_damage.png" },
		{ "name": "Hurtbox2D", "base": "Area2D", "script": "res://addons/nodes_plus/nodes/hurtbox2D.gd", "icon": "res://addons/nodes_plus/icons/node_2D/icon_hitbox.png" },
		{ "name": "InteractionArea2D", "base": "Area2D", "script": "res://addons/nodes_plus/nodes/interaction_area_2D.gd", "icon": "res://addons/nodes_plus/icons/node_2D/icon_hand.png" },
		{ "name": "Projectile2D", "base": "CharacterBody2D", "script": "res://addons/nodes_plus/nodes/projectile2D.gd", "icon": "res://addons/nodes_plus/icons/node_2D/icon_projectile.png" },
		{ "name": "Target2D", "base": "Area2D", "script": "res://addons/nodes_plus/nodes/target2D.gd", "icon": "res://addons/nodes_plus/icons/node_2D/icon_target.png" },
	],
	"3D": [
		{ "name": "Follow3D", "base": "Node", "script": "res://addons/nodes_plus/nodes/follow3D.gd", "icon": "res://addons/nodes_plus/icons/node_3D/icon_follow.png" },
		{ "name": "Hitbox3D", "base": "Area3D", "script": "res://addons/nodes_plus/nodes/hitbox_3D.gd", "icon": "res://addons/nodes_plus/icons/node_3D/icon_area_damage.png" },
		{ "name": "Hurtbox3D", "base": "Area3D", "script": "res://addons/nodes_plus/nodes/hurtbox_3D.gd", "icon": "res://addons/nodes_plus/icons/node_3D/icon_hitbox.png" },
		{ "name": "InteractionArea3D", "base": "Area3D", "script": "res://addons/nodes_plus/nodes/interaction_area_3D.gd", "icon": "res://addons/nodes_plus/icons/node_3D/icon_hand.png" },
		{ "name": "Projectile3D", "base": "CharacterBody3D", "script": "res://addons/nodes_plus/nodes/projectile3D.gd", "icon": "res://addons/nodes_plus/icons/node_3D/icon_projectile.png" },
		{ "name": "Target3D", "base": "Area3D", "script": "res://addons/nodes_plus/nodes/target3D.gd", "icon": "res://addons/nodes_plus/icons/node_3D/icon_target.png" },
	],
	"UI": [
		{ "name": "TimerLabel", "base": "RichTextLabel", "script": "res://addons/nodes_plus/nodes/timer_label.gd", "icon": "res://addons/nodes_plus/icons/control/icon_dialog.png" },
	],
}

const CATEGORY_ORDER := ["Stats","Various","Save/Load","State Machine","2D","3D","UI"]

var _search_box: LineEdit
var _list: VBoxContainer
var _doc_cache: Dictionary = {}


func _ready() -> void:
	title = "NodesPlus"
	closable = true
	default_slot = DOCK_SLOT_LEFT_BR
	dock_icon = preload("icons/node/icon_gear.png")

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	vbox.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(vbox)

	_search_box = LineEdit.new()
	_search_box.placeholder_text = "Filter nodes..."
	_search_box.text_changed.connect(_on_filter_changed)
	vbox.add_child(_search_box)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_list)

	_populate_list()


func _populate_list(filter: String = "") -> void:
	for child in _list.get_children():
		child.queue_free()

	var filter_lower := filter.to_lower()

	for category in CATEGORY_ORDER:
		var nodes: Array = NODES[category]
		var filtered: Array[Dictionary] = []

		for node in nodes:
			if filter.is_empty() or node["name"].to_lower().contains(filter_lower):
				filtered.append(node)

		if filtered.is_empty():
			continue

		var header := Label.new()
		header.text = "%s (%d)" % [category, filtered.size()]
		header.size_flags_horizontal = SIZE_EXPAND_FILL
		header.add_theme_font_size_override("font_size", 11)
		_list.add_child(header)

		for node in filtered:
			var entry := Button.new()
			entry.text = node["name"]
			entry.icon = load(node["icon"])
			entry.flat = true
			entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
			entry.size_flags_horizontal = SIZE_EXPAND_FILL
			entry.tooltip_text = _node_tooltip(node)
			var entry_data := node
			entry.pressed.connect(func(): _add_node(entry_data))
			_list.add_child(entry)


func _add_node(data: Dictionary) -> void:
	var root := EditorInterface.get_edited_scene_root()
	if not root:
		printerr("NodesPlus: No scene open to add node to.")
		return

	var new_node := ClassDB.instantiate(data["base"])
	if not new_node:
		printerr("NodesPlus: Failed to instantiate base type '%s'." % data["base"])
		return

	new_node.set_script(load(data["script"]))
	new_node.name = data["name"]
	root.add_child(new_node, true)
	new_node.owner = root


func _node_tooltip(data: Dictionary) -> String:
	var desc := _get_doc_description(data["script"])
	if desc.is_empty():
		return "%s (%s)" % [data["name"], data["base"]]
	return "%s (%s)\n%s" % [data["name"], data["base"], desc]


func _get_doc_description(script_path: String) -> String:
	if _doc_cache.has(script_path):
		return _doc_cache[script_path]

	var file := FileAccess.open(script_path, FileAccess.READ)
	if not file:
		return ""

	var lines: Array[String] = []
	while file.get_position() < file.get_length():
		var line := file.get_line()
		if line.begins_with("##"):
			lines.append(line.trim_prefix("##").strip_edges())
		elif not lines.is_empty() and not line.begins_with("##") and not line.strip_edges().is_empty():
			break

	file.close()

	lines = lines.filter(func(l): return not l.is_empty())

	var desc := "\n".join(lines)
	_doc_cache[script_path] = desc
	return desc


func _on_filter_changed(new_text: String) -> void:
	_populate_list(new_text)
