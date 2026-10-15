@icon("res://addons/nodes_plus/icons/node/icon_folder.png")
class_name Load
extends Node
## A load component.
##
## Loads data from a [Save] node and optionally applies it automatically to configured nodes.

#region ─── Signals ───────────────────────────────
signal data_applied(data: Dictionary)
signal load_failed(reason: String)
#endregion


#region ─── Exports ───────────────────────────────
## Reference to the [Save] node to load data from.
@export var save_node: Save

## Optional manual file path to load data from, used if no Save node is assigned.
@export var manual_save_path: String = ""

@export_category("Options")
## Automatically apply data after loading.
@export var auto_apply: bool = true

## Enables detailed debug output.
@export var debug_mode: bool = true

@export_category("Data Mapping")
## Keys are property names from the save file, values are node references to apply to.
@export var apply_targets: Dictionary[String,NodePath] = {}
#endregion


#region ─── Built-in ───────────────────────────────
func _ready() -> void:
	# Try connecting to Save node if it exists
	if save_node and save_node.has_signal("load_completed"):
		save_node.connect("load_completed", Callable(self, "_on_load_completed"))

	# Auto-load logic
	if auto_apply:
		var data: Dictionary

		if save_node:
			if debug_mode:
				print("[Load] Using assigned Save node for loading...")
			data = save_node.load_game()
		elif manual_save_path != "":
			if debug_mode:
				print("[Load] Loading manually from:", manual_save_path)
			data = _load_from_path(manual_save_path)
		else:
			push_warning("[Load] No save_node or manual_save_path provided.")
			return

		if data.is_empty():
			push_warning("[Load] No data loaded.")
		else:
			if debug_mode:
				print("[Load] Auto applying loaded data...")
			apply_loaded_data(data)
#endregion


#region ─── Apply Logic ───────────────────────────────
func _on_load_completed(path: String, data: Dictionary) -> void:
	if debug_mode:
		print("[Load] Loaded file from:", path)
	if auto_apply:
		apply_loaded_data(data)

func apply_loaded_data(data: Dictionary) -> void:
	if debug_mode:
		print("[Load] Applying loaded data:", data)
		print("[Load] Apply targets:", apply_targets)

	for key in data.keys():
		if not apply_targets.has(key):
			push_warning("[Load] Key '%s' not found in apply_targets." % key)
			continue

		var target = apply_targets[key]
		if target is NodePath:
			target = get_node_or_null(target)

		if not is_instance_valid(target):
			push_warning("[Load] Target for key '%s' is invalid or missing." % key)
			continue

		var value = data[key]

		# Apply intelligently
		if target.has_method("set_value"):
			target.set_value(value)
			if debug_mode:
				print("[Load] Applied via set_value:", key, "=", value)
		elif "value" in target:
			target.value = value
			if debug_mode:
				print("[Load] Applied via .value:", key, "=", value)
		elif target.has_method("set"):
			target.set(key, value)
			if debug_mode:
				print("[Load] Applied via set():", key, "=", value)
		elif key in target:
			target.set(key, value)
			if debug_mode:
				print("[Load] Applied directly:", key, "=", value)
		else:
			push_warning("[Load] Cannot apply key '%s' to target '%s'" % [key, target.name])
			load_failed.emit(str("Key '", key, "' could not be applied to '", target.name, "'"))

	data_applied.emit(data)

func _load_from_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		load_failed.emit("Save file not found at: %s" % path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		load_failed.emit("Failed to open save file at: %s" % path)
		return {}

	var json_text := file.get_as_text()
	file.close()

	var result: Variant = JSON.parse_string(json_text)
	if typeof(result) != TYPE_DICTIONARY:
		load_failed.emit("Invalid or corrupted JSON in: %s" % path)
		return {}

	if debug_mode:
		print("[Load] File loaded manually from:", path)
		print("[Load] Data content:", result)

	return result
#endregion
