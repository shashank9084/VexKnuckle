extends RigidBody3D
## Hanging punching bag. Responds to Hitbox3D impacts with real momentum
## transfer, so the swing, spin and rebound follow from the physics.

## Coefficient of restitution: 0 = dead stop, 1 = perfectly elastic.
## A filled bag is soft and absorbs most of the energy, so keep this low.
@export_range(0.0, 1.0) var restitution: float = 0.2

## Mass of the bag (kg). A typical heavy bag is 30-70 kg.
@export var bag_mass: float = 40.0

## Safety cap on a single impulse (N·s). Raise it or set it very high
## if you don't want any clamping.
@export var max_impulse: float = 2000.0

var _hurtbox: Hurtbox3D


func _ready() -> void:
	mass = bag_mass
	gravity_scale = 1.0
	# Light damping only, for air drag. The swing itself is physical.
	linear_damp = 0.05
	angular_damp = 0.3
	continuous_cd = true
	can_sleep = false

	_hurtbox = get_node_or_null("Hurtbox3D") as Hurtbox3D
	if _hurtbox:
		# Keep the hurtbox's mass in sync so the reduced-mass math matches the bag.
		_hurtbox.mass = bag_mass


func _on_hurtbox_3d_impacted(impact: Hitbox3D.Impact) -> void:
	if not is_instance_valid(impact.source):
		return

	var striker_mass: float = impact.source.mass
	var total_mass: float = striker_mass + mass
	if total_mass <= 0.0:
		return

	# Two-body impulse along the contact normal:
	# J = mu * (1 + e) * v_approach
	var reduced_mass: float = (striker_mass * mass) / total_mass
	var impulse_strength: float = reduced_mass * (1.0 + restitution) * impact.approach_speed
	impulse_strength = minf(impulse_strength, max_impulse)

	# impact.normal points from the bag toward the striker, so push the other way.
	var impulse: Vector3 = -impact.normal * impulse_strength

	# Applying at the contact point gives the correct torque automatically.
	var contact_offset: Vector3 = impact.position - global_position
	apply_impulse(impulse, contact_offset)
