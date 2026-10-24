extends ComponentsManeger
class_name PlayerRootMotionMovementComponent


# =============================================================================
# 1. STATES
# =============================================================================

# Every state the player can be in.
enum STATES { IDLE, WALK, RUN, SPRINT, STRAFE, JUMPING, FALLING }

# Must match the input order of the "JumpType" node in the AnimationTree.
enum JumpType { RunJump, WalkJump, SprintJump, IdleJump }


# =============================================================================
# 2. SETTINGS (you can change these in the Inspector)
# =============================================================================

@export var charector: Node3D
@export var animation_tree: AnimationTree
@export var apply_gravity := true

@export_group("Jump")
@export_range(0.0, 30.0, 0.1, "suffix:m/s") var jump_velocity := 5.0
@export_range(0.0, 0.5, 0.01, "suffix:s") var coyote_time := 0.1
@export_range(0.0, 0.5, 0.01, "suffix:s") var jump_buffer_time := 0.1
@export_range(0.0, 1.0, 0.05) var jump_cut_multiplier := 0.5

@export_group("Air Momentum")
@export_range(0.0, 50.0, 0.1, "suffix:m/s²") var air_drag := 0.0

@export_group("Animation")
@export_range(0.1, 20.0, 0.1) var sprint_blend_speed := 3.0
## SprintBlend value while running. -1 = RunBlendSpace.
@export_range(-1.0, 1.0, 0.05) var run_blend_value := -1.0
## SprintBlend value while sprinting. 0 = PlayerAnimationLibrary/Sprint.
@export_range(-1.0, 1.0, 0.05) var sprint_blend_value := 0.0


# =============================================================================
# 3. ANIMATION TREE PATHS
# If you rename a node in the AnimationTree, change it here.
# =============================================================================

const PATH_PLAYER_STATE := &"parameters/PlayerStates/transition_request"
const PATH_MOVE_MODE := &"parameters/MovementStates/transition_request"
const PATH_JUMP_TYPE := &"parameters/JumpType/transition_request"
const PATH_RUN_BLEND := &"parameters/RunBlendSpace/blend_position"
const PATH_WALK_BLEND := &"parameters/WalkBlendSpace/blend_position"
const PATH_STRAFE_BLEND := &"parameters/StrafeBlendSpace/blend_position"
const PATH_SPRINT_BLEND := &"parameters/SprintBlend/blend_amount"
const PATH_LAND_SHOT := &"parameters/LandShot/request"


# =============================================================================
# 4. ANIMATION TREE NAMES
# These must match the input names shown in the AnimationTree editor.
# =============================================================================

const ANIM_IDLE := &"Idle"          # PlayerStates input
const ANIM_MOVEMENT := &"Movement"  # PlayerStates input
const ANIM_JUMP := &"Jump"          # PlayerStates input
const ANIM_FALL := &"Fall"          # PlayerStates input
const MODE_RUN := &"Run"            # MovementStates input 0
const MODE_STRAFE := &"Strafe"      # MovementStates input 1
const MODE_WALK := &"Walk"          # MovementStates input 2
const JUMP_NAMES := [&"RunJump", &"WalkJump", &"SprintJump", &"IdleJump"]


# =============================================================================
# 5. RUNTIME VARIABLES
# =============================================================================

# Synced to all peers by a MultiplayerSynchronizer (path ":state").
# The setter runs on every peer, so remote animations follow automatically.
var state: int = STATES.IDLE:
	set(value):
		if value == state:
			return
		state = value
		_on_state_changed()

# Synced to all peers (path ":move_input"). Lets remote peers blend animations
# without having their own input.
var move_input := Vector2.ZERO

# Local only. Toggled by the "strafe" input action.
var strafe_mode := false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _air_velocity := Vector3.ZERO
var _sprint_blend := 0.0
var _last_ground_state: int = STATES.IDLE
var _was_on_floor := true


# =============================================================================
# 6. SETUP
# =============================================================================

func _ready() -> void:
	# We advance the tree ourselves in _physics_process, so root motion is
	# always read from this frame (no one-frame lag).
	animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	#animation_tree.animation_started.connect(func(s : StringName): print(str(s),randi()))
	# RPCs check THIS node's authority, so copy it from the player.
	# The spawner must set the player's authority before add_child().
	set_multiplayer_authority(player.get_multiplayer_authority())

	animation_tree.set(PATH_PLAYER_STATE, ANIM_IDLE)
	_sprint_blend = run_blend_value
	animation_tree.set(PATH_SPRINT_BLEND, _sprint_blend)


# =============================================================================
# 7. MAIN LOOP
# Every peer advances its animation. Only the owner simulates movement.
# =============================================================================

func _physics_process(delta: float) -> void:
	animation_tree.advance(delta)

	if _is_owner():
		_read_input()
		_simulate(delta)

	_update_blends(delta)


func _is_owner() -> bool:
	return player.is_multiplayer_authority()


# =============================================================================
# 8. INPUT (owning peer only)
# =============================================================================

func _read_input() -> void:
	# Press "strafe" to turn strafe mode on or off.
	if Input.is_action_just_pressed(&"strafe"):
		strafe_mode = not strafe_mode

	var dir := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")

	# Strafe mode only allows forward and backward movement.
	if strafe_mode:
		dir.x = 0.0

	move_input = dir


# =============================================================================
# 9. MOVEMENT SIMULATION (owning peer only)
# =============================================================================

func _simulate(delta: float) -> void:
	# Apply the animation's turn first, so the motion below uses the new facing.
	charector.quaternion *= animation_tree.get_root_motion_rotation()
	var root_velocity := _get_root_motion_velocity(delta)

	if not apply_gravity:
		player.velocity = root_velocity
		player.move_and_slide()
		_update_state()
		return

	var on_floor: bool = player.is_on_floor()
	_update_timers(delta, on_floor)

	# Gravity
	var vertical: float = player.velocity.y
	if not on_floor:
		vertical -= _gravity * delta
	elif vertical < 0.0:
		vertical = 0.0

	# Jump
	var jumped := _try_jump()
	if jumped:
		vertical = jump_velocity

	# Variable jump height: releasing the button early shortens the jump
	if vertical > 0.0 and Input.is_action_just_released(&"jump"):
		vertical *= jump_cut_multiplier

	# Stop upward movement when hitting a ceiling
	if player.is_on_ceiling() and vertical > 0.0:
		vertical = 0.0

	# Horizontal: root motion on the ground, air momentum in the air
	var horizontal := Vector3(root_velocity.x, 0.0, root_velocity.z)
	var airborne := jumped or not on_floor

	if airborne:
		_air_velocity = _air_velocity.move_toward(Vector3.ZERO, air_drag * delta)
		horizontal = _air_velocity
	else:
		_air_velocity = horizontal

	player.velocity = Vector3(horizontal.x, vertical, horizontal.z)
	player.move_and_slide()

	if airborne:
		_air_velocity = Vector3(player.velocity.x, 0.0, player.velocity.z)

	_update_state()


func _get_root_motion_velocity(delta: float) -> Vector3:
	if delta <= 0.0:
		return Vector3.ZERO
	# Root motion is a local delta. Rotate it by the character's current facing.
	var local_motion := animation_tree.get_root_motion_position()
	return (charector.global_basis * local_motion) / delta


func _update_timers(delta: float, on_floor: bool) -> void:
	# Coyote time: a short grace period to jump after leaving a ledge
	_coyote_timer = coyote_time if on_floor else maxf(_coyote_timer - delta, 0.0)
	# Jump buffer: remembers a jump press that happened just before landing
	_jump_buffer_timer = jump_buffer_time if Input.is_action_just_pressed(&"jump") \
			else maxf(_jump_buffer_timer - delta, 0.0)


# =============================================================================
# 10. STATE DECISION (owning peer only)
# =============================================================================

func _update_state() -> void:
	var on_floor := player.is_on_floor()

	if on_floor:
		# Just touched the ground this frame
		if not _was_on_floor:
			idle()
			_net_land.rpc()
		_last_ground_state = _choose_ground_state()
		state = _last_ground_state
	else:
		state = STATES.JUMPING if player.velocity.y > 0.0 else STATES.FALLING

	_was_on_floor = on_floor


func _choose_ground_state() -> int:
	if move_input.is_zero_approx():
		return STATES.IDLE
	if strafe_mode:
		return STATES.STRAFE          # no run or sprint while strafing
	if Input.is_action_pressed(&"sprint"):
		return STATES.SPRINT
	if Input.is_action_pressed(&"run"):
		return STATES.RUN
	return STATES.WALK                # default movement


# =============================================================================
# 11. JUMP (owning peer decides, everyone plays the animation)
# =============================================================================

func _try_jump() -> bool:
	if _jump_buffer_timer <= 0.0 or _coyote_timer <= 0.0:
		return false

	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0

	# Use the ground state from before leaving the floor, so a coyote jump
	# still picks the correct jump clip.
	state = STATES.JUMPING
	_net_jump.rpc(_jump_type_for(_last_ground_state))
	return true


func _jump_type_for(ground_state: int) -> int:
	match ground_state:
		STATES.RUN:
			return JumpType.RunJump
		STATES.SPRINT:
			return JumpType.SprintJump
		STATES.WALK, STATES.STRAFE:
			return JumpType.WalkJump
		_:
			return JumpType.IdleJump


# =============================================================================
# 12. ANIMATION ACTIONS
# These only change the AnimationTree, so they run safely on every peer.
# =============================================================================

func idle() -> void:
	animation_tree.set(PATH_PLAYER_STATE, ANIM_IDLE)


func movement(mode: StringName) -> void:
	animation_tree.set(PATH_PLAYER_STATE, ANIM_MOVEMENT)
	animation_tree.set(PATH_MOVE_MODE, mode)


func jump(jump_type: int) -> void:
	animation_tree.set(PATH_JUMP_TYPE, JUMP_NAMES[jump_type])
	animation_tree.set(PATH_PLAYER_STATE, ANIM_JUMP)


func fall() -> void:
	animation_tree.set(PATH_PLAYER_STATE, ANIM_FALL)


func land() -> void:
	# Plays Land on top of the locomotion. The base state is already
	# switching to Idle or Movement, so Land is not overwritten.
	animation_tree.set(PATH_LAND_SHOT, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _mode_for(movement_state: int) -> StringName:
	match movement_state:
		STATES.WALK:
			return MODE_WALK
		STATES.STRAFE:
			return MODE_STRAFE
		_:
			return MODE_RUN   # RUN and SPRINT both use the run tree


# =============================================================================
# 13. NETWORKING (RPCs)
# "authority" = only the owning peer can call these.
# "call_local" = the owner plays the animation too.
# =============================================================================

@rpc("authority", "call_local", "reliable")
func _net_jump(jump_type: int) -> void:
	if jump_type < 0 or jump_type >= JUMP_NAMES.size():
		return  # reject bad values
	jump(jump_type)


@rpc("authority", "call_local", "reliable")
func _net_land() -> void:
	land()


# =============================================================================
# 14. STATE -> ANIMATION (runs on every peer)
# =============================================================================

func _on_state_changed() -> void:
	match state:
		STATES.IDLE:
			idle()
		STATES.WALK, STATES.RUN, STATES.SPRINT, STATES.STRAFE:
			movement(_mode_for(state))
		STATES.FALLING:
			fall()
		_:
			pass  # JUMPING is started by the _net_jump RPC


# =============================================================================
# 15. BLEND VALUES (runs on every peer)
# =============================================================================

func _update_blends(delta: float) -> void:
	match state:
		STATES.WALK:
			animation_tree.set(PATH_WALK_BLEND, move_input)
		STATES.RUN, STATES.SPRINT:
			animation_tree.set(PATH_RUN_BLEND, move_input)
		STATES.STRAFE:
			animation_tree.set(PATH_STRAFE_BLEND, move_input)

	# Smoothly move between running and sprinting
	var target := sprint_blend_value if state == STATES.SPRINT else run_blend_value
	_sprint_blend = lerpf(_sprint_blend, target, 1.0 - exp(-sprint_blend_speed * delta))
	animation_tree.set(PATH_SPRINT_BLEND, _sprint_blend)
