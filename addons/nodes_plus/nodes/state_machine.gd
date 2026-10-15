@icon("res://addons/nodes_plus/icons/node/StateMachine.svg")
extends Node
class_name StateMachine

@export var character: Node
@export var initial_state: NodePath

var current_state: State


func _ready() -> void:
	if initial_state:
		var node = get_node(initial_state)
		change_state(node)


func change_state(new_state: State, data := {}) -> void:
	if current_state:
		current_state.exit()

	current_state = new_state

	if current_state:
		current_state.state_machine = self
		current_state.character = character
		current_state.enter(data)


func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)


func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)
