# res://addons/virtual_joystick_DX/vjdx_joystick_handler.gd
class_name VJDXJoystickHandler
extends RefCounted

# Modos de joystick, en el mismo orden que el enum JoystickMode del core
const MODE_STATIC: int = 0
const MODE_DYNAMIC: int = 1
const MODE_FOLLOWING: int = 2

# Niveles de movimiento, compartidos entre Joystick y D-Pad
enum MovementLevel {IDLE, WALK, RUN, SPRINT}

var radius: float = 80.0
var thumb_radius: float = 28.0
var deadzone: float = 0.15
var mode: int = MODE_STATIC
var clampzone_ratio: float = 1.5
var run_threshold: float = 0.55
var sprint_threshold: float = 0.85

func get_max_deadzone() -> float:
	if radius > 0.0:
		return minf(thumb_radius / radius, 0.999)
	return 0.9

# Corregido: mode y clampzone_ratio ahora se usan de verdad
func is_dynamic() -> bool:
	return mode == MODE_DYNAMIC

func is_following() -> bool:
	return mode == MODE_FOLLOWING

func is_movable() -> bool:
	return mode == MODE_DYNAMIC or mode == MODE_FOLLOWING

func should_release_by_clampzone(dist: float) -> bool:
	return dist > radius * clampzone_ratio

func compute_reposition_target(global_pos: Vector2, center: Vector2, offset: Vector2, dist: float) -> Vector2:
	var dir: Vector2 = offset / dist
	return (global_pos + center) + offset - dir * radius

func calculate_value(offset: Vector2, dist: float) -> Vector2:
	var dz_px: float = deadzone * radius
	if dist < 0.001 or dist <= dz_px:
		return Vector2.ZERO

	var direction: Vector2 = offset / dist
	if is_zero_approx(deadzone):
		return direction

	# Nuevo: la dirección alcanza magnitud 1.0 justo al llegar a run_threshold,
	# no al borde del radio. Así el rango completo 0.0-1.0 se recorre durante
	# Walk; Run y Sprint solo añaden su acción extra, manteniendo la
	# dirección siempre al máximo (nunca vuelven a escalarla hacia abajo).
	var walk_px: float = run_threshold * radius
	if walk_px <= dz_px:
		return direction

	var t: float = clampf((dist - dz_px) / (walk_px - dz_px), 0.0, 1.0)
	return direction * t

# Nuevo: fuerza normalizada (0.0 a 1.0) del movimiento, independiente del deadzone.
# Se calcula a partir del radio activo (joystick_radius o dpad_radius) para que
# el mismo handler pueda clasificar el nivel de movimiento tanto del Joystick
# como del D-Pad.
func calculate_magnitude(dist: float, active_radius: float) -> float:
	if active_radius <= 0.0:
		return 0.0
	return clampf(dist / active_radius, 0.0, 1.0)

# Nuevo: clasifica la fuerza normalizada en un nivel de movimiento
# (Idle / Walk / Run / Sprint) según deadzone, run_threshold y sprint_threshold.
func calculate_movement_level(magnitude: float) -> int:
	if magnitude <= deadzone:
		return MovementLevel.IDLE
	elif magnitude <= run_threshold:
		return MovementLevel.WALK
	elif magnitude <= sprint_threshold:
		return MovementLevel.RUN
	return MovementLevel.SPRINT