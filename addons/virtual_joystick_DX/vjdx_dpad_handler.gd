# res://addons/virtual_joystick_DX/vjdx_dpad_handler.gd
class_name VJDXDpadHandler
extends RefCounted

signal direction_changed()

var radius: float = 80.0
var deadzone: float = 0.15
var use_textures: bool = true
var preset: int = 0

# Nivel de movimiento actual (VJDXJoystickHandler.MovementLevel). Lo escribe el core.
var movement_level: int = VJDXJoystickHandler.MovementLevel.IDLE

# Texturas personalizadas: 25 slots (idle + 3 niveles x 8 direcciones).
# Indice 0 = idle. Indice = nivel * 8 + octante, con nivel 0..2 (walk, run, sprint)
# y octante 1..8 (up, down, left, right, up_right, up_left, down_right, down_left).
const LEVEL_NAMES: Array[String] = ["walk", "run", "sprint"]
const DIR_NAMES: Array[String] = ["up", "down", "left", "right", "up_right", "up_left", "down_right", "down_left"]
const TEX_COUNT: int = 25

var custom_tex: Array[Texture2D] = []

var active_direction: Vector2 = Vector2.ZERO

var _preset_cache: Array[Texture2D] = []
var _preset_cache_dirty: bool = true

func _init() -> void:
	custom_tex.resize(TEX_COUNT)

func calculate_value(offset: Vector2, dist: float) -> Vector2:
	var dz_px: float = deadzone * radius
	if dist < 0.001 or dist <= dz_px:
		_update_active_dir(Vector2.ZERO)
		return Vector2.ZERO

	var nx: float = offset.x / dist
	var ny: float = offset.y / dist

	const DIAG_T: float = 0.3827

	var dir: Vector2 = Vector2.ZERO
	if nx > DIAG_T: dir.x = 1.0
	elif nx < -DIAG_T: dir.x = -1.0
	if ny > DIAG_T: dir.y = 1.0
	elif ny < -DIAG_T: dir.y = -1.0

	if dir == Vector2.ZERO:
		dir.x = signf(nx)
		dir.y = signf(ny)

	_update_active_dir(dir)
	return dir

func _update_active_dir(new_dir: Vector2) -> void:
	if new_dir != active_direction:
		active_direction = new_dir
		direction_changed.emit()

func mark_cache_dirty() -> void:
	_preset_cache_dirty = true

func load_preset_cache() -> void:
	_preset_cache.clear()
	_preset_cache.resize(TEX_COUNT)
	var folder: String = "res://addons/virtual_joystick_DX/Dpad textures/preset 1/" if preset == 0 else "res://addons/virtual_joystick_DX/Dpad textures/preset 2/"
	_preset_cache[0] = _load_tex(folder + "idle.svg")
	for l in LEVEL_NAMES.size():
		for d in DIR_NAMES.size():
			# Si existe "<nivel>_<dir>.svg" (ej. run_up_left.svg) se usa; si no,
			# se usa el "<dir>.svg" comun a todos los niveles.
			var level_path: String = folder + "%s_%s.svg" % [LEVEL_NAMES[l], DIR_NAMES[d]]
			var path: String = level_path if ResourceLoader.exists(level_path) else folder + DIR_NAMES[d] + ".svg"
			_preset_cache[l * 8 + d + 1] = _load_tex(path)
	_preset_cache_dirty = false

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func get_octant_index() -> int:
	var pos_x: float = active_direction.x
	var pos_y: float = active_direction.y
	if pos_y < 0 and pos_x > 0: return 5
	if pos_y < 0 and pos_x < 0: return 6
	if pos_y > 0 and pos_x > 0: return 7
	if pos_y > 0 and pos_x < 0: return 8
	if pos_y < 0: return 1
	if pos_y > 0: return 2
	if pos_x < 0: return 3
	if pos_x > 0: return 4
	return 0

# Slot (0..24) de la textura segun nivel actual + direccion actual.
func get_texture_index() -> int:
	var octant: int = get_octant_index()
	if octant == 0 or movement_level == VJDXJoystickHandler.MovementLevel.IDLE:
		return 0
	var level_idx: int = clampi(movement_level - 1, 0, LEVEL_NAMES.size() - 1)
	return level_idx * 8 + octant

func set_custom_texture(idx: int, tex: Texture2D) -> void:
	if idx >= 0 and idx < TEX_COUNT:
		custom_tex[idx] = tex

func get_active_texture() -> Texture2D:
	if not use_textures:
		return null

	var idx: int = get_texture_index()
	var custom: Texture2D = custom_tex[idx]
	if custom:
		return custom

	if _preset_cache_dirty:
		load_preset_cache()
	if idx < _preset_cache.size():
		return _preset_cache[idx]
	return null
