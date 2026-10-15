@icon("res://addons/nodes_plus/icons/node_2D/icon_projectile.png")
class_name Projectile2D
extends CharacterBody2D
## A 2D projectile component.
##
## Moves in a set direction at a configured speed, detects collisions,
## and works synergistically with [Lifespan] and [Hitbox2D]/[Damage].
## Automatically queue_frees on collision or lifespan expiry.

#region ─── Signals ───────────────────────────────
## Emitted when the projectile collides with something.
signal collided(collision: KinematicCollision2D, collider: Node)
## Emitted when the projectile expires (lifespan ends or reaches max distance).
signal expired
#endregion


#region ─── Exports ───────────────────────────────
## Movement speed in pixels per second.
@export var speed: float = 500.0

## Direction the projectile moves in (normalized automatically).
@export var direction: Vector2 = Vector2.RIGHT

## Gravity applied each second (useful for arcing projectiles).
@export var gravity: float = 0.0

## Maximum distance the projectile can travel before expiring (0 = unlimited).
@export var max_distance: float = 0.0

@export_category("Damage")
## Linked [Damage] node for calculating hit damage.
@export var damage_node: Damage

## Linked [Hitbox2D] area for dealing damage to hurtboxes.
@export var hitbox: Hitbox2D

@export_category("Lifespan")
## Linked [Lifespan] for timed auto-destruction.
@export var lifespan: Lifespan

## If true, the lifespan starts automatically in _ready().
@export var auto_start: bool = true

@export_category("Debug")
## Enable or disable debug output.
@export var debug_mode: bool = false
#endregion


#region ─── Internal Vars ───────────────────────────────
var _start_position: Vector2
var _direction_normalized: Vector2
var _destroyed: bool = false
#endregion


#region ─── Lifecycle ───────────────────────────────
func _ready() -> void:
	_start_position = global_position
	_direction_normalized = direction.normalized()

	if auto_start and lifespan:
		lifespan.start()

	if lifespan:
		lifespan.timeout.connect(_on_lifespan_timeout)
#endregion


#region ─── Physics ───────────────────────────────
func _physics_process(delta: float) -> void:
	if _destroyed:
		return

	var velocity := _direction_normalized * speed

	if gravity != 0.0:
		velocity.y += gravity * delta

	var collision := move_and_collide(velocity * delta)

	if collision:
		var collider := collision.get_collider()
		_destroyed = true
		collided.emit(collision, collider)
		if debug_mode:
			print("[Projectile2D] Collided with: ", collider.name)
		queue_free()
		return

	# Max distance check
	if max_distance > 0.0:
		if global_position.distance_to(_start_position) >= max_distance:
			_destroyed = true
			expired.emit()
			if debug_mode:
				print("[Projectile2D] Max distance reached, expiring.")
			queue_free()
#endregion


#region ─── Public API ───────────────────────────────
## Launches the projectile in a given direction with an optional custom speed.
func launch(new_direction: Vector2, new_speed: float = -1.0) -> void:
	direction = new_direction
	_direction_normalized = new_direction.normalized()
	if new_speed >= 0.0:
		speed = new_speed
	_start_position = global_position
	if lifespan:
		lifespan.start()
	if debug_mode:
		print("[Projectile2D] Launched at speed: ", speed, " direction: ", _direction_normalized)
#endregion


#region ─── Internal ───────────────────────────────
func _on_lifespan_timeout() -> void:
	if _destroyed:
		return
	_destroyed = true
	expired.emit()
	if debug_mode:
		print("[Projectile2D] Lifespan expired.")
	queue_free()


#endregion
