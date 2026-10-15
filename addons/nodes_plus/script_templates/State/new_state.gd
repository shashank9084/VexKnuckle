# meta-default: true
extends State

# Use the "character" built-in variable to get the entity the StateMachine is attached to.
# Use the "state_machine" built-in variable to get the StateMachine that handles this state.

func enter(_data := {}):
	# Called when the state starts
	pass

func exit():
	# Called when leaving the state
	pass

func handle_input(_event: InputEvent) -> void:
	# Handle player input
	pass

func update(_delta: float) -> void:
	# Per-frame update
	pass

func physics_update(_delta: float) -> void:
	# Per-physics-frame update (for movement, etc.)
	pass
