@icon("res://addons/nodes_plus/icons/node/State.svg")
extends Node
class_name State

var state_machine: StateMachine
var character: Node


## Called when the [State] is entered. Use [param data] to share data between states.
func enter(_data := {}) -> void:
	pass


## Called when the state is exited.
func exit() -> void:
	pass


## Handle player input. Use [member character] to access the owning entity.
func handle_input(_event: InputEvent) -> void:
	pass


## Per-frame update logic.
func update(_delta: float) -> void:
	pass


## Per-physics-frame update logic.
func physics_update(_delta: float) -> void:
	pass
