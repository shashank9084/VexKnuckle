@icon("res://addons/nodes_plus/icons/node_3D/icon_area_damage.png")
class_name Hitbox3D
extends Area3D
## Physical striking volume. Reports impacts from real relative motion
## and reduced-mass kinetic energy. Carries no health or damage values.

## One physical contact between a hitbox and a hurtbox.
class Impact:
	var source: Hitbox3D
	var target: Hurtbox3D
	## Relative speed of the two bodies at contact (m/s).
	var relative_speed: float = 0.0
	## Speed directed into the target along the contact normal (m/s).
	var approach_speed: float = 0.0
	## Kinetic energy of the approach using reduced mass (J).
	var energy: float = 0.0
	## Unit vector pointing from the target toward the source.
	var normal: Vector3 = Vector3.ZERO
	## Approximate world-space contact point.
	var position: Vector3 = Vector3.ZERO

signal impact_detected(impact: Impact)
signal activated
signal deactivated

@export var active: bool = true:
	get:
		return _active
	set(value):
		_active = value
		if is_inside_tree():
			set_monitoring(value)
		if value:
			activated.emit()
		else:
			deactivated.emit()

@export var one_shot: bool = false
@export var debug_mode: bool = false

## Effective mass of the striking body or limb (kg).
@export var mass: float = 1.0
## Approach speeds below this (m/s) are ignored.
@export var min_approach_speed: float = 0.5

var velocity: Vector3 = Vector3.ZERO

var _active: bool = true
var _hit_targets: Array[Hurtbox3D] = []
var _last_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	_last_position = global_position
	set_monitoring(active)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return

	var current_position := global_position
	velocity = (current_position - _last_position) / delta
	_last_position = current_position


func _on_area_entered(area: Area3D) -> void:
	if not _active:
		return

	if not area is Hurtbox3D:
		if debug_mode:
			print("[Hitbox3D] Ignored non-Hurtbox3D area: ", area.name)
		return

	var hurt := area as Hurtbox3D

	if one_shot and hurt in _hit_targets:
		return

	var impact := _build_impact(hurt)
	if impact == null:
		return

	# The hurtbox decides whether it accepts the impact (groups, cooldown).
	if not hurt.receive_impact(impact):
		return

	if one_shot:
		_hit_targets.append(hurt)

	impact_detected.emit(impact)

	if debug_mode:
		print(
			"[Hitbox3D] Impact on ", hurt.name,
			" | Approach: ", snappedf(impact.approach_speed, 0.01), " m/s",
			" | Energy: ", snappedf(impact.energy, 0.01), " J"
		)


func _build_impact(hurt: Hurtbox3D) -> Impact:
	var total_mass := mass + hurt.mass
	if total_mass <= 0.0:
		return null

	var relative_velocity := velocity - hurt.velocity

	var normal := global_position - hurt.global_position
	var distance := normal.length()
	if distance > 0.0001:
		normal /= distance
	elif relative_velocity.length() > 0.0001:
		normal = -relative_velocity.normalized()
	else:
		return null

	# Positive when the hitbox is moving into the hurtbox.
	var approach := maxf(0.0, -relative_velocity.dot(normal))
	if approach < min_approach_speed:
		return null

	var reduced_mass := (mass * hurt.mass) / total_mass

	var impact := Impact.new()
	impact.source = self
	impact.target = hurt
	impact.relative_speed = relative_velocity.length()
	impact.approach_speed = approach
	impact.energy = 0.5 * reduced_mass * approach * approach
	impact.normal = normal
	impact.position = (global_position + hurt.global_position) * 0.5
	return impact


func reset_hitbox() -> void:
	_hit_targets.clear()


func set_active(value: bool) -> void:
	active = value
