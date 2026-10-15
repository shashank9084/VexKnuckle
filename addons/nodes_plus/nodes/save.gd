@icon("res://addons/nodes_plus/icons/node/icon_save.png")
class_name Save
extends Node
## A save component.
##
## Handles saving and loading of game data.
## Designed to store game state (player stats, position, inventory, etc.) into a JSON file.
## You can attach it to any node and connect its signals for autosave or checkpoints.

#region ─── Signals ───────────────────────────────
## Emitted when the save file has been successfully saved.
signal save_completed(path: String)

## Emitted when a save file has been successfully loaded.
signal load_completed(path: String, data: Dictionary)

## Emitted when saving or loading fails.
signal save_error(error_message: String)
#endregion


#region ─── Exports ───────────────────────────────
## The folder path to store save files in (created automatically if missing).
@export var save_folder: String = "user://save/"

## The name of the save file (without extension).
@export var save_name: String = "name"

## The file extension for saves.
@export var file_extension: String = ".save"

@export_category("Options")
## If true, the node will automatically create the save folder if it doesn't exist.
@export var auto_create_folder: bool = true

@export_category("Save Targets")
## A dictionary that defines what data to save automatically.
## Example:
## { "current_health": ^"../Health", "player_position": ^".." }
## When saving, the node will store { "current_health": $Health.current_health, "player_position": $Player.position }.
@export var save_targets: Dictionary[String,NodePath] = {}
#endregion


#region ─── Built-in ───────────────────────────────
func _ready() -> void:
	if auto_create_folder:
		DirAccess.make_dir_recursive_absolute(save_folder)
#endregion


#region ─── Core Save / Load Logic ───────────────────────────────
## Returns the full path to the save file.
func get_save_path() -> String:
	return save_folder.path_join(save_name + file_extension)

## Builds a dictionary automatically from the assigned `save_targets`.
func build_save_data() -> Dictionary:
	var result: Dictionary = {}

	for key in save_targets.keys():
		var target_ref: Variant = save_targets[key]
		var target: Node = null

		# Convert NodePath to Node if needed
		if target_ref is NodePath:
			target = get_node_or_null(target_ref)
		elif target_ref is Node:
			target = target_ref

		if not is_instance_valid(target):
			push_warning("[Save] Invalid target for key '%s'." % key)
			continue

		var value: Variant = null

		# Simplified: if the node has a property or variable with the same name as the key, save it
		if key in target:
			value = target.get(key)
		else:
			push_warning("[Save] Node '%s' does not have a property called '%s'." % [target.name, key])
			continue

		result[key] = value
		print("[Save] Saved key '%s' = %s (from node: %s)" % [key, str(value), target.name])

	return result





## Saves either the provided data or builds one automatically from `save_targets`.
func save_game(data: Dictionary = {}) -> void:
	var file_path = get_save_path()

	# Build automatic data if none is given
	if data.is_empty() and not save_targets.is_empty():
		print("[Save] Building data automatically from save_targets...")
		data = build_save_data()
		print("[Save] Data built:", data)

	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		save_error.emit("Failed to open file for saving: %s" % file_path)
		return

	var json_text := JSON.stringify(data, "\t") # Pretty formatting
	file.store_string(json_text)
	file.close()

	save_completed.emit(file_path)
	print("[Save] File saved successfully at:", file_path)

## Loads the saved data and returns it as a dictionary.
func load_game() -> Dictionary:
	var file_path := get_save_path()
	if not FileAccess.file_exists(file_path):
		save_error.emit("Save file not found: %s" % file_path)
		return {}

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		save_error.emit("Failed to open save file: %s" % file_path)
		return {}

	var json_text := file.get_as_text()
	file.close()

	var json_result: Variant = JSON.parse_string(json_text)

	if typeof(json_result) != TYPE_DICTIONARY:
		save_error.emit("Corrupted save file: %s" % file_path)
		return {}

	var data: Dictionary = json_result
	load_completed.emit(file_path, data)
	return data
#endregion


#region ─── Utility Helpers ───────────────────────────────
## Deletes the save file (useful for debugging or new game).
func delete_save() -> void:
	var path = get_save_path()
	if FileAccess.file_exists(path):
		var err = DirAccess.remove_absolute(path)
		if err != OK:
			save_error.emit("Failed to delete save file: %s" % path)

## Checks if a save file exists.
func has_save() -> bool:
	return FileAccess.file_exists(get_save_path())

## Prints the save data to the output for debugging.
func debug_print_save() -> void:
	if not has_save():
		print("[Save] No save file found at", get_save_path())
		return
	var data = load_game()
	print("[Save] Data in file:", data)
#endregion
